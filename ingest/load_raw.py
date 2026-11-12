"""Load uncleaned source strings with provenance and content-based rerun checks.

Snowflake is the submission platform. The local target is a regression harness.
Run this single-writer batch loader serially; concurrent production ingestion needs
an orchestrator lock. Checksum tracking is not a general CDC solution.
"""
import argparse
import json
import os
from pathlib import Path
from dataset import TABLES, preflight
from connection import connect, identifier


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', choices=['snowflake', 'local'], default='snowflake')
    parser.add_argument('--data-dir', type=Path, default=Path('data/raw'))
    parser.add_argument('--local-db', type=Path, default=Path('data/olist.duckdb'))
    parser.add_argument('--bootstrap', action='store_true', help='Create assessment database and X-Small warehouse if absent')
    args = parser.parse_args()
    # Validate every input before any warehouse write.
    inputs = [(table, filename, columns, preflight(args.data_dir / filename, columns))
              for table, (filename, columns) in TABLES.items()]
    is_sf = args.target == 'snowflake'
    db = identifier(os.environ.get('SNOWFLAKE_DATABASE', 'ELIO_ASSESSMENT')) if is_sf else 'olist'
    if is_sf:
        conn = connect(database=not args.bootstrap)
        cur = conn.cursor()
        warehouse = identifier(os.environ.get('SNOWFLAKE_WAREHOUSE', 'ELIO_ASSESSMENT_WH'))
        if args.bootstrap:
            cur.execute(f"create warehouse if not exists {warehouse} warehouse_size='XSMALL' auto_suspend=60 auto_resume=true initially_suspended=true")
            cur.execute(f'create database if not exists {db}')
        cur.execute(f'use warehouse {warehouse}')
    else:
        import duckdb
        args.local_db.parent.mkdir(parents=True, exist_ok=True)
        conn = duckdb.connect(str(args.local_db))
        cur = conn
        db = identifier(args.local_db.stem)
    raw = f'{db}.RAW'
    cur.execute(f'create schema if not exists {raw}')
    timestamp_type = 'TIMESTAMP_NTZ' if is_sf else 'TIMESTAMP'
    cur.execute(f'create table if not exists {raw}.LOAD_AUDIT (table_name varchar, file_sha256 varchar, source_file varchar, row_count bigint, loaded_at {timestamp_type})')
    if is_sf:
        cur.execute(f"create file format if not exists {raw}.OLIST_CSV type=CSV compression=AUTO field_delimiter=',' skip_header=1 field_optionally_enclosed_by='\"' escape_unenclosed_field=NONE encoding='UTF8' skip_byte_order_mark=TRUE empty_field_as_null=FALSE null_if=() error_on_column_count_mismatch=TRUE replace_invalid_characters=FALSE")
        cur.execute(f'create stage if not exists {raw}.OLIST_STAGE file_format={raw}.OLIST_CSV')
    report = {'engine': args.target, 'files': []}
    try:
        for table, filename, columns, info in inputs:
            relation = f'{raw}.{identifier(table)}'
            column_ddl = ', '.join(f'{identifier(c)} varchar' for c in columns)
            cur.execute(f'create table if not exists {relation} ({column_ddl}, _source varchar, _source_row_number bigint, _loaded_at {timestamp_type}, _file_sha256 varchar)')
            sha = literal(info['sha256'])
            existing = cur.execute(f'select count(*) from {relation} where _file_sha256={sha}').fetchone()[0]
            audit = cur.execute(f'select count(*) from {raw}.LOAD_AUDIT where table_name={literal(table)} and file_sha256={sha}').fetchone()[0]
            if existing == info['rows'] and audit:
                report['files'].append({**info, 'status': 'already_loaded'})
                continue
            if existing or audit:
                raise ValueError(f'{table}: partial or inconsistent prior load; investigate before retrying')
            local_path = (args.data_dir / filename).resolve()
            if is_sf:
                stage_path = f'@{raw}.OLIST_STAGE/{info["sha256"]}/'
                cur.execute(f'PUT {literal(local_path.as_uri())} {stage_path} AUTO_COMPRESS=TRUE OVERWRITE=FALSE')
                fields = ', '.join(f't.${i}' for i in range(1, len(columns) + 1))
                query = f"COPY INTO {relation} FROM (SELECT {fields}, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$START_SCAN_TIME::TIMESTAMP_NTZ, {sha} FROM {stage_path} t) FILE_FORMAT=(FORMAT_NAME={raw}.OLIST_CSV) ON_ERROR=ABORT_STATEMENT"
            else:
                fields = ', '.join(identifier(c) for c in columns)
                query = f"insert into {relation} select {fields}, {literal(filename)}, row_number() over (), current_timestamp, {sha} from read_csv({literal(local_path)}, header=true, all_varchar=true, nullstr='__ELIO_NO_NULL_SENTINEL__', parallel=false)"
            cur.execute('begin')
            try:
                cur.execute(query)
                copy_result = cur.fetchall() if is_sf else []
                count = cur.execute(f'select count(*) from {relation} where _file_sha256={sha}').fetchone()[0]
                if count != info['rows']:
                    raise ValueError(f'{table}: loaded {count}, expected {info["rows"]}')
                cur.execute(f'insert into {raw}.LOAD_AUDIT values ({literal(table)}, {sha}, {literal(filename)}, {count}, current_timestamp)')
                cur.execute('commit')
            except Exception:
                cur.execute('rollback')
                raise
            report['files'].append({**info, 'status': 'loaded', 'copy_result': copy_result})
        output = Path('data') / f'load_report_{args.target}.json'
        output.parent.mkdir(exist_ok=True)
        output.write_text(json.dumps(report, indent=2, default=str) + '\n')
        print(json.dumps(report, indent=2, default=str))
    finally:
        conn.close()


if __name__ == '__main__':
    main()
