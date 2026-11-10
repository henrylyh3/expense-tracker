"""Export the original Android keystore as a local GitHub Secret paste file."""
import argparse
import base64
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('keystore', nargs='?', type=Path)
    args = parser.parse_args()
    source = args.keystore or Path(input('Path to your original Android keystore: ').strip().strip('"'))
    if not source.is_file():
        parser.error('Original keystore file does not exist. No replacement key will be generated.')
    os.umask(0o077)
    folder = ROOT / '.local/signing/github-secrets'
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / 'ANDROID_KEYSTORE_BASE64.txt'
    with output.open('x') as stream:
        stream.write(base64.b64encode(source.read_bytes()).decode() + '\n')
    output.chmod(0o600)
    print(f'Created {output}; paste its contents into ANDROID_KEYSTORE_BASE64. No private value printed.')


if __name__ == '__main__':
    main()
