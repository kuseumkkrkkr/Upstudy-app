"""One synthetic API OCR/grading journey; never changes an existing student's account."""
import argparse
import base64
import json
from pathlib import Path
import secrets
import time
import urllib.request
from urllib.parse import urlsplit

from verify_texteller_sample import sample


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Never forward an app authentication token to a deployment-protection login."""
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    host = urlsplit(args.base)
    if (Path.cwd().resolve() != root or root.drive.upper() != 'D:'
            or host.scheme != 'https' or not (host.hostname or '').endswith('.vercel.app')
            or host.username or host.password or host.query or host.fragment):
        raise SystemExit('guarded D: checkout and HTTPS Vercel API are required')
    base = args.base.rstrip('/')
    token = None
    opener = urllib.request.build_opener(NoRedirect())

    def call(path, body=None, extra=None):
        headers = {'Content-Type': 'application/json', **(extra or {})}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(base+path, headers=headers,
            data=None if body is None else json.dumps(body).encode())
        with opener.open(request, timeout=40) as response:
            return json.load(response)

    credentials_path = root/'build'/'temp'/'.ocr-qa-account.json'
    if credentials_path.exists():
        credentials = json.loads(credentials_path.read_text(encoding='utf-8'))
    else:
        credentials = {'username': 'OcrQA261013', 'password': 'A1'+secrets.token_hex(8)}
        registered = call('/auth/register', {**credentials, 'name': 'OCR QA', 'grade': '고1'})
        assert registered.get('user_id') and registered.get('token')
        credentials_path.write_text(json.dumps(credentials), encoding='utf-8')
    token = call('/auth/login', credentials)['token']
    assert call('/auth/me').get('username') == credentials['username']
    image, events = sample()
    job_body = {'mode': 'ocr', 'payload': {'student_work_image': base64.b64encode(image).decode(),
        'writing_events': events, 'grade_after_ocr': True,
        'quest_id': 'ui-test-20261008-problem-set-q1', 'submission_id': 'ocr-qa-20261013'}}
    key = 'ocr-qa-20261013'
    created = call('/api/ocr/jobs', job_body, {'X-Idempotency-Key': key})
    job_id = created['job_id']
    print(json.dumps({'phase': 'queued', 'job_id': job_id, 'synthetic': True}), flush=True)
    deadline = time.monotonic()+180
    while time.monotonic() < deadline:
        status = call('/api/ocr/jobs/'+job_id)
        if status['status'] in ('completed', 'failed'):
            break
        time.sleep(3)
    print(json.dumps({'phase': 'ocr', 'status': status['status'], 'result': status.get('result'),
                      'error': status.get('error')}, ensure_ascii=False), flush=True)
    assert status['status'] == 'completed' and status['result']['accepted'], 'real OCR failed'
    grade = call('/api/ocr/jobs/'+job_id+'/grade', {})
    assert grade['status'] == 'completed', 'real grading failed'
    replay = call('/api/ocr/jobs/'+job_id+'/grade', {})
    assert grade == replay, 'grading replay changed the result'
    print(json.dumps({'phase': 'grade', 'same_on_retry': True, 'grade': grade},
                     ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
