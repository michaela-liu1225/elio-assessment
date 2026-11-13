"""Compare actual Snowflake and local aggregate query results, never credentials."""
import json
import math
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def compare(left, right, path='root'):
    if isinstance(left, dict):
        assert isinstance(right, dict) and left.keys() == right.keys(), path
        for key in left:
            compare(left[key], right[key], f'{path}.{key}')
    elif isinstance(left, list):
        assert isinstance(right, list) and len(left) == len(right), path
        for index, (a, b) in enumerate(zip(left, right)):
            compare(a, b, f'{path}[{index}]')
    elif isinstance(left, float) or isinstance(right, float):
        assert isinstance(left, (int, float)) and isinstance(right, (int, float)), path
        assert math.isclose(left, right, rel_tol=1e-12, abs_tol=1e-6), (path, left, right)
    else:
        assert left == right, (path, left, right)


def main():
    base = ROOT / 'analysis/results'
    local = json.loads((base / 'local/execution_metadata.json').read_text())
    cloud = json.loads((base / 'snowflake/execution_metadata.json').read_text())
    assert local['sql_sha256'] == cloud['sql_sha256'], 'Different analytics SQL versions'
    assert local['queries'].keys() == cloud['queries'].keys(), 'Different query sets'
    checks = {}
    for name in local['queries']:
        assert cloud['queries'][name]['query_id'], f'{name}: missing Snowflake query ID'
        a = json.loads((base / 'local' / f'{name}.json').read_text())
        b = json.loads((base / 'snowflake' / f'{name}.json').read_text())
        compare(a, b, name)
        checks[name] = {'rows': len(a), 'status': 'matched'}
    derived = {}
    for name in ['decision_metrics', 'commercial_decision']:
        a = json.loads((base / 'local' / f'{name}.json').read_text())
        b = json.loads((base / 'snowflake' / f'{name}.json').read_text())
        assert a.pop('engine') == 'local' and b.pop('engine') == 'snowflake', name
        compare(a, b, name)
        derived[name] = {'status': 'matched'}
    result = {'compared_at_utc': datetime.now(timezone.utc).isoformat(),
              'sql_sha256': cloud['sql_sha256'], 'checks': checks,
              'derived_calculations': derived,
              'numeric_tolerance': {'absolute': 1e-6, 'relative': 1e-12},
              'note': 'Counts, labels, dates and nulls match exactly; floating results allow numerical rounding.'}
    output = ROOT / 'docs/evidence'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'engine_parity.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f"Matched {len(checks)} query outputs and {len(derived)} derived scenario files across local and Snowflake execution.")


if __name__ == '__main__':
    main()
