"""Exercise failure boundaries and the actual loader's rerun behaviour."""
import csv
import subprocess
import sys
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'ingest'))
from dataset import TABLES, preflight
from connection import identifier


def test_bom_and_portuguese_preserved(tmp_path):
    path = tmp_path / 'source.csv'
    path.write_text('\ufeffid,city\n1,São Paulo\n', encoding='utf-8')
    assert preflight(path, ['id', 'city'])['rows'] == 1
    assert 'São Paulo' in path.read_text()


@pytest.mark.parametrize('payload', [b'id,city\n1,Sao,Paulo\n', b'id,city\n1,\xff\n'])
def test_malformed_csv_and_invalid_utf8_fail(tmp_path, payload):
    path = tmp_path / 'source.csv'
    path.write_bytes(payload)
    with pytest.raises((ValueError, UnicodeDecodeError)):
        preflight(path, ['id', 'city'])


def test_identifiers_cannot_inject_sql():
    with pytest.raises(ValueError):
        identifier('db; drop database other')


def test_actual_loader_is_idempotent(tmp_path):
    import duckdb
    raw = tmp_path / 'raw'
    raw.mkdir()
    for filename, columns in TABLES.values():
        with (raw / filename).open('w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(columns)
            writer.writerow(['original value'] * len(columns))
    database = tmp_path / 'fixture.duckdb'
    command = [sys.executable, str(ROOT / 'ingest/load_raw.py'), '--target', 'local',
               '--data-dir', str(raw), '--local-db', str(database)]
    subprocess.run(command, check=True, cwd=tmp_path, capture_output=True)
    subprocess.run(command, check=True, cwd=tmp_path, capture_output=True)
    with duckdb.connect(str(database), read_only=True) as conn:
        assert conn.execute('select count(*) from raw.load_audit').fetchone()[0] == len(TABLES)
        for table in TABLES:
            assert conn.execute(f'select count(*) from raw.{table}').fetchone()[0] == 1
