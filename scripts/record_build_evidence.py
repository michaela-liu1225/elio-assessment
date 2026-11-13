"""Export only non-secret fields from actual dbt results, including failed nodes."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    for engine in ['local', 'snowflake']:
        directory = ROOT / 'dbt_project/target' / engine
        run = json.loads((directory/'run_results.json').read_text())
        manifest = json.loads((directory/'manifest.json').read_text())
        resources = []
        kinds = Counter()
        for row in run['results']:
            uid = row['unique_id']
            kind = uid.split('.')[0]
            kinds[kind] += 1
            resources.append({'unique_id': uid, 'status': row['status'],
                              'execution_seconds': row['execution_time'],
                              'query_id': row.get('adapter_response', {}).get('query_id')})
        assert run['metadata']['invocation_id'] == manifest['metadata']['invocation_id'], 'Mismatched artifacts'
        result = {'engine': engine, 'generated_at_utc': run['metadata']['generated_at'],
                  'dbt_version': run['metadata']['dbt_version'],
                  'invocation_id': run['metadata']['invocation_id'],
                  'elapsed_seconds': run['elapsed_time'],
                  'status_counts': dict(Counter(r['status'] for r in resources)),
                  'resource_counts': dict(kinds), 'resources': resources}
        path = ROOT / f'docs/evidence/dbt_build_{engine}.json'
        path.write_text(json.dumps(result, indent=2)+'\n')
        print(engine, result['status_counts'], result['resource_counts'])


if __name__ == '__main__':
    main()
