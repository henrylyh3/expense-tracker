"""Package an already-built desktop app on its native operating system."""
import argparse
import platform
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def version():
    return re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$',
                     (ROOT / 'pubspec.yaml').read_text(), re.M).groups()


def package(target, source=None, iscc='ISCC.exe'):
    name, build = version()
    output = ROOT / 'release'
    output.mkdir(exist_ok=True)
    prefix = output / f'expense-tracker-{name}'
    if target == 'macos':
        if platform.system() != 'Darwin':
            raise RuntimeError('A macOS host is required to create the DMG.')
        app = source or ROOT / 'build/macos/Build/Products/Release/expense_tracker.app'
        if not (app / 'Contents/Info.plist').is_file():
            raise RuntimeError('Build the macOS release app first.')
        with (app / 'Contents/Info.plist').open('rb') as source_plist:
            info = plistlib.load(source_plist)
        if (info.get('CFBundleShortVersionString') != name
                or info.get('CFBundleVersion') != build):
            raise RuntimeError('The macOS app is stale; rebuild the current version before packaging.')
        dmg, archive = Path(f'{prefix}-macos.dmg'), Path(f'{prefix}-macos-update.zip')
        for path in (dmg, archive):
            if path.exists():
                raise RuntimeError(f'Refusing to overwrite {path.name}.')
        with tempfile.TemporaryDirectory() as temp:
            stage = Path(temp)
            subprocess.run(['ditto', str(app), str(stage / app.name)], check=True)
            (stage / 'Applications').symlink_to('/Applications')
            subprocess.run(['hdiutil', 'create', '-volname', 'Expense Tracker',
                            '-srcfolder', str(stage), '-format', 'UDZO', str(dmg)], check=True)
        subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent',
                        str(app), str(archive)], check=True)
        return [dmg, archive]
    if platform.system() != 'Windows':
        raise RuntimeError('A Windows host is required to package the Windows build.')
    source = source or ROOT / 'build/windows/x64/runner/Release'
    for required in ('expense_tracker.exe', 'flutter_windows.dll', 'data/flutter_assets'):
        if not (source / required).exists():
            raise RuntimeError(f'Missing Windows bundle component: {required}')
    archive, installer = Path(f'{prefix}-windows-x64.zip'), Path(f'{prefix}-windows-x64-setup.exe')
    for path in (archive, installer):
        if path.exists():
            raise RuntimeError(f'Refusing to overwrite {path.name}.')
    # Include DLLs, native assets and data; an EXE alone cannot run Flutter.
    shutil.make_archive(str(archive.with_suffix('')), 'zip', source)
    subprocess.run([iscc, f'/DAppVersion={name}', f'/DBuildNumber={build}',
                    f'/DBundleDir={source.resolve()}', f'/DOutputDir={output}',
                    str(ROOT / 'tool/windows_installer.iss')], check=True)
    if not installer.is_file():
        raise RuntimeError('Inno Setup did not produce the expected installer.')
    return [archive, installer]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['macos', 'windows'])
    parser.add_argument('--source', type=Path)
    parser.add_argument('--iscc', default='ISCC.exe')
    args = parser.parse_args()
    for result in package(args.platform, args.source, args.iscc):
        print(result.relative_to(ROOT))
