"""Recognize a synthetic x=2 stroke sample using the existing CPU model cache."""
import io
import argparse
import base64
import json
import os
from pathlib import Path
import sys
import time

os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['OCR_USE_CUDA'] = '0'
sys.path.insert(0, str(Path.cwd() / 'omj'))
from PIL import Image, ImageDraw
from services.ocr.texteller_grid import extract_math_with_texteller_grid


def sample():
    lines = [
        [(40, 50), (56, 66), (73, 88), (91, 109)],
        [(90, 49), (76, 67), (58, 89), (40, 109)],
        [(122, 72), (139, 73), (160, 72)],
        [(121, 91), (141, 90), (161, 91)],
        [(206, 61), (214, 49), (231, 46), (247, 52), (253, 66),
         (244, 82), (225, 97), (208, 111), (230, 111), (254, 111)],
    ]
    image = Image.new('RGB', (300, 155), 'white')
    draw = ImageDraw.Draw(image)
    events = []
    for index, points in enumerate(lines):
        draw.line(points, fill='black', width=5)
        events.append({'stroke_id': index, 'width': 5,
                       'points': [{'x': x, 'y': y} for x, y in points]})
    output = io.BytesIO()
    image.save(output, format='PNG')
    return output.getvalue(), events


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--queue-sql', action='store_true')
    args = parser.parse_args()
    started = time.monotonic()
    image, events = sample()
    if args.queue_sql:
        root = Path(__file__).resolve().parents[1]
        if root.drive.upper() != 'D:' or Path.cwd().resolve() != root:
            raise SystemExit('SQL generation requires the guarded D: checkout')
        payload = json.dumps({'student_work_image': base64.b64encode(image).decode(),
                              'writing_events': events}, separators=(',', ':')).replace("'", "''")
        sql = ("insert into public.ocr_jobs(user_id,idempotency_key,mode,payload,expires_at) "
               "values ('qa-ocr-cutover-20261013','qa-ocr-cutover-20261013','ocr','"
               + payload + "'::jsonb,now()+interval '10 minutes') "
               "on conflict(user_id,idempotency_key) do nothing; "
               "select id,status from public.ocr_jobs where user_id='qa-ocr-cutover-20261013' "
               "and idempotency_key='qa-ocr-cutover-20261013';")
        (root/'build'/'temp'/'ocr-live-synthetic.sql').write_text(sql, encoding='utf-8')
        print(json.dumps({'synthetic_bytes': len(image), 'stroke_count': len(events)}))
        raise SystemExit(0)
    result = extract_math_with_texteller_grid(image, events)
    print(json.dumps({'synthetic': True, 'expected': 'x=2',
                      'elapsed_seconds': round(time.monotonic()-started, 2),
                      'result': result}, ensure_ascii=False))
    if not result.get('accepted'):
        raise SystemExit(1)
