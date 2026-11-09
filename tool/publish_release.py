"""Prepare and publish the signed APK already committed to origin/main.

Uses Git Credential Manager in memory; never embeds credentials in the app.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = 'henrylyh3/expense-tracker'
API = f'https://api.github.com/repos/{REPO}'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def artifact():
    version, build = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', (ROOT / 'pubspec.yaml').read_text(), re.M).groups()
    apk = ROOT / 'release' / f'expense-tracker-{version}-arm64-release.apk'
    raw = apk.read_bytes()
    manifest = dict(schema=1, version=version, version_code=2000 + int(build), package='com.example.expense_tracker', abi='arm64-v8a', apk=apk.name, size=len(raw), sha256=hashlib.sha256(raw).hexdigest())
    return apk, ROOT / 'release' / f'update-{version}.json', manifest


def credential():
    result = subprocess.run(['git', 'credential', 'fill'], cwd=ROOT, input='protocol=https\nhost=github.com\n\n', text=True, capture_output=True, check=True)
    fields = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    token = fields.get('password')
    if not token:
        raise RuntimeError('No GitHub publishing credential is available.')
    return token


def request(token, url, method='GET', data=None, content_type='application/json'):
    headers = {'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json', 'User-Agent': 'ExpenseTracker-Release', 'X-GitHub-Api-Version': '2022-11-28'}
    if data is not None:
        headers['Content-Type'] = content_type
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=180) as response:
            return None if response.status == 204 else json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f'GitHub release operation failed (HTTP {error.code}).') from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--auth-check', action='store_true')
    parser.add_argument('--notes-file', type=Path)
    args = parser.parse_args()
    if args.auth_check:
        repo = request(credential(), API)
        if not repo.get('permissions', {}).get('push'):
            raise RuntimeError('GitHub credential cannot publish to this repository.')
        print('GitHub release publishing access verified.')
        return
    apk, manifest_path, manifest = artifact()
    if args.prepare:
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        print(f'Prepared {manifest_path.relative_to(ROOT)}')
        return
    if not args.notes_file:
        parser.error('--notes-file is required for publishing')
    if json.loads(manifest_path.read_text()) != manifest:
        raise RuntimeError('Prepare and commit the matching update manifest first.')
    for path in [apk, manifest_path]:
        relative = str(path.relative_to(ROOT)).replace('\\', '/')
        if subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--', relative], cwd=ROOT).returncode:
            raise RuntimeError('Commit release artifacts before publishing.')
        git('ls-files', '--error-unmatch', relative)
    commit = git('rev-parse', 'HEAD')
    if git('ls-remote', 'origin', 'refs/heads/main').split()[0] != commit:
        raise RuntimeError('Push the completed release commit to origin/main first.')
    token = credential()
    tag = 'v' + manifest['version']
    releases = request(token, API + '/releases?per_page=100')
    existing = next((r for r in releases if r['tag_name'] == tag), None)
    if existing and not existing['draft']:
        raise RuntimeError('This version is already published; never overwrite a published APK.')
    if existing and existing['target_commitish'] != commit:
        raise RuntimeError('The existing draft belongs to another commit; resolve it before publishing.')
    notes = args.notes_file.read_text(encoding='utf-8')
    release = existing or request(token, API + '/releases', 'POST', json.dumps(dict(tag_name=tag, target_commitish=commit, name=f'Expense Tracker {manifest["version"]}', body=notes, draft=True, prerelease=False)).encode())
    # Only draft assets may be replaced after an interrupted publication.
    for asset in release.get('assets', []):
        if asset['name'] in [apk.name, 'update.json']:
            request(token, API + f'/releases/assets/{asset["id"]}', 'DELETE')
    upload_url = release['upload_url'].split('{')[0]
    for name, path, mime in [(apk.name, apk, 'application/vnd.android.package-archive'), ('update.json', manifest_path, 'application/json')]:
        asset = request(token, upload_url + '?name=' + urllib.parse.quote(name), 'POST', path.read_bytes(), mime)
        if asset.get('digest') != 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest():
            raise RuntimeError('GitHub upload checksum verification failed; release remains a draft.')
    published = request(token, API + f'/releases/{release["id"]}', 'PATCH', json.dumps(dict(draft=False, body=notes, make_latest='true')).encode())
    print('Published ' + published['html_url'])


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError) as error:
        # Do not print request objects, headers, credential-helper output or tokens.
        print(str(error) if isinstance(error, RuntimeError) else 'Release operation failed. Check local artifacts and publishing access.', file=sys.stderr)
        sys.exit(1)
