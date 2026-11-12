"""Execute the same named analytics SQL against marts and record its engine.

Local execution transpiles Snowflake syntax with SQLGlot. It is not evidence of
Snowflake execution; successful Snowflake runs also record Snowflake query IDs.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'ingest'))
from connection import connect, identifier


def serialise(value):
    if isinstance(value, Decimal):
        return float(value)
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    raise TypeError(type(value).__name__)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', choices=['snowflake', 'local'], default='snowflake')
    parser.add_argument('--database', default='ELIO_ASSESSMENT')
    parser.add_argument('--schema', default='DEV_MARTS')
    args = parser.parse_args()
    sql_path = ROOT / 'sql/analytics_queries.sql'
    sql = sql_path.read_text()
    parts = re.split(r'^-- name: ([a-z_]+)\s*$', sql, flags=re.MULTILINE)
    if args.target == 'local':
        import duckdb
        import sqlglot
        conn = duckdb.connect(str(ROOT / 'data/olist.duckdb'), read_only=True)
        cur = conn
        database = 'OLIST'
    else:
        conn = connect()
        cur = conn.cursor()
        database = identifier(args.database)
    schema = identifier(args.schema)
    output = ROOT / 'analysis' / 'results' / args.target
    output.mkdir(parents=True, exist_ok=True)
    metadata = {'engine': args.target, 'executed_at_utc': datetime.now(timezone.utc).isoformat(),
                'sql_sha256': hashlib.sha256(sql.encode()).hexdigest(), 'queries': {}}
    try:
        for index in range(1, len(parts), 2):
            name, query = parts[index], parts[index + 1].strip()
            query = query.replace('ELIO_ASSESSMENT.DEV_MARTS.', f'{database}.{schema}.')
            if args.target == 'local':
                query = sqlglot.transpile(query, read='snowflake', write='duckdb')[0]
            cur.execute(query)
            columns = [col[0].lower() for col in cur.description]
            rows = [dict(zip(columns, row)) for row in cur.fetchall()]
            (output / f'{name}.json').write_text(json.dumps(rows, indent=2, default=serialise) + '\n')
            with (output / f'{name}.csv').open('w', newline='') as file:
                writer = csv.DictWriter(file, fieldnames=columns, lineterminator='\n')
                writer.writeheader()
                writer.writerows(rows)
            metadata['queries'][name] = {'rows': len(rows), 'query_id': getattr(cur, 'sfqid', None)}
            print(f'{args.target}: {name}: {len(rows)} rows')
    finally:
        conn.close()
    (output / 'execution_metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')


if __name__ == '__main__':
    main()
