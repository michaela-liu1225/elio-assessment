"""Record non-secret, read-only Snowflake environment and quality evidence."""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'ingest'))
from connection import connect, identifier
from dataset import TABLES


def main():
    db = identifier(os.environ.get('SNOWFLAKE_DATABASE', 'ELIO_ASSESSMENT'))
    schema = identifier(os.environ.get('DBT_SCHEMA', 'DEV'))
    warehouse = identifier(os.environ.get('SNOWFLAKE_WAREHOUSE', 'ELIO_ASSESSMENT_WH'))
    result = {'engine': 'snowflake', 'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
              'queries': {}}
    with connect() as conn:
        cur = conn.cursor()

        def query(name, sql):
            cur.execute(sql)
            fields = [col[0].lower() for col in cur.description]
            rows = [dict(zip(fields, row)) for row in cur.fetchall()]
            result['queries'][name] = {'query_id': cur.sfqid, 'sql': sql, 'rows': rows}
            return rows

        query('runtime', 'select current_version() as snowflake_version, current_region() as region, '
              'current_role() as role, current_database() as database_name, current_warehouse() as warehouse')
        cur.execute(f"show warehouses like '{warehouse}'")
        fields = [col[0].lower() for col in cur.description]
        wh = next(row for row in (dict(zip(fields, r)) for r in cur.fetchall()) if row['name'] == warehouse)
        result['warehouse'] = {key: wh[key] for key in ['name', 'size', 'auto_suspend', 'auto_resume']}
        result['warehouse_query_id'] = cur.sfqid
        query('load_audit', f'select table_name, file_sha256, row_count from {db}.RAW.LOAD_AUDIT order by table_name, file_sha256')
        for table in TABLES:
            query(f'raw_count_{table}', f'select count(*) as source_rows from {db}.RAW.{identifier(table)}')
        query('catalogue_quality', f"select count(case when category_name='__unknown__' then 1 end) as missing_category_products, "
              f"count(distinct case when not has_translation and category_name<>'__unknown__' then category_name end) as untranslated_categories "
              f'from {db}.{schema}_MARTS.DIM_PRODUCT')
        query('zero_payments', f'select payment_type, count(*) as payment_records from {db}.{schema}_STAGING.STG_PAYMENTS '
              'where payment_value=0 group by payment_type order by payment_type')
    output = ROOT / 'docs/evidence/snowflake_environment.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, default=str) + '\n')
    print(f'Recorded {len(result["queries"])} read-only evidence queries and warehouse settings.')


if __name__ == '__main__':
    main()
