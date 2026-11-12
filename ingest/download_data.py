"""Download the publisher's public Kaggle archive; do not commit the CSVs."""
import argparse
import io
import json
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile
from dataset import TABLES, preflight


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', type=Path, default=Path('data/raw'))
    args = parser.parse_args()
    args.directory.mkdir(parents=True, exist_ok=True)
    url = 'https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce'
    request = Request(url, headers={'User-Agent': 'Elio-assessment-reproduction/1.0'})
    with urlopen(request, timeout=120) as response:
        archive = response.read()
    manifest = {'source': 'https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce',
                'license': 'CC BY-NC-SA 4.0', 'files': []}
    with ZipFile(io.BytesIO(archive)) as zipped:
        for filename, columns in TABLES.values():
            path = args.directory / filename
            payload = zipped.read(filename)
            if path.exists() and path.read_bytes() != payload:
                raise ValueError(f'{path} differs from the download; use a new directory to preserve the old version')
            path.write_bytes(payload)
            manifest['files'].append(preflight(path, columns))
    output = args.directory.parent / 'source_manifest.json'
    output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Validated {len(manifest["files"])} source files. Manifest: {output}')


if __name__ == '__main__':
    main()
