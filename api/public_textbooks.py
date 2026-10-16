"""Immutable, server-published free textbooks; per-user acquisition is insert-only."""
from __future__ import annotations

import copy
import json
import re
from functools import lru_cache
from pathlib import Path

from fastapi import Depends, HTTPException
from api.textbook_import import parse_import

BUNDLE = Path(__file__).resolve().parents[1] / 'data/content/published-textbooks.json'
OWNED_PREFIX = 'textbook.public.owned.'


@lru_cache(maxsize=1)
def books():
    """Validate deployment-owned content once. No client-supplied publication paths."""
    if not BUNDLE.exists():
        return {}
    bundle = json.loads(BUNDLE.read_text(encoding='utf-8'))
    if set(bundle) != {'version', 'books'} or bundle['version'] != 1:
        raise ValueError('Invalid public textbook bundle')
    result = {}
    for entry in bundle['books']:
        if set(entry) != {'source', 'sha256', 'source_metadata'}:
            raise ValueError('Invalid public textbook entry')
        book, digest = parse_import(entry['source'], entry['sha256'])
        metadata = entry['source_metadata']
        approval = metadata.get('approval', {}) if isinstance(metadata, dict) else {}
        if (approval.get('publication_approved') is not True
                or approval.get('rights_status') != 'cleared'
                or approval.get('teacher_review_status') != 'approved'
                or approval.get('math_review_status') != 'approved'
                or not re.fullmatch(r'[0-9a-f]{64}', str(approval.get('sha256', '')))
                or approval.get('sha256') != metadata.get('original_sha256')):
            raise ValueError('Public textbook publication approval is incomplete')
        book_id = 'published-' + digest
        if book_id in result:
            raise ValueError('Duplicate public textbook')
        result[book_id] = {**book, 'textbook_id': book_id, 'source_sha256': digest,
            'price_points': 0, 'publication': 'public', 'progress': 0,
            'progress_label': '시작 전'}
    return result


def headers(book):
    """Catalogue/library metadata only; retain full pages in the reader endpoint."""
    return {key: copy.deepcopy(value) for key, value in book.items() if key != 'chapters'}


def owned_ids(data_api, user_id):
    result = set()
    for offset in range(0, 10000, 500):
        rows = data_api().request('GET', 'canary_user_kv', query={
            'select': 'key', 'user_id': f'eq.{user_id}',
            'key': f'like.{OWNED_PREFIX}*', 'order': 'key.asc',
            'offset': str(offset), 'limit': '500'}) or []
        for row in rows:
            key = row['key']
            if key.startswith(OWNED_PREFIX):
                result.add(key[len(OWNED_PREFIX):])
        if len(rows) < 500:
            return result
    raise RuntimeError('Public textbook ownership limit exceeded')


def library(data_api, user_id):
    """Only acquired public books are added; never return another user's drafts."""
    if not books():
        return []
    try:
        owned = owned_ids(data_api, user_id)
        return [headers(book) for key, book in books().items() if key in owned]
    except RuntimeError as error:
        raise HTTPException(503, 'Public textbook storage unavailable') from error


def get_owned(data_api, user_id, book_id):
    book = books().get(book_id)
    if book is None:
        return None
    try:
        if book_id not in owned_ids(data_api, user_id):
            raise HTTPException(403, 'textbook_acquisition_required')
    except RuntimeError as error:
        raise HTTPException(503, 'Public textbook storage unavailable') from error
    return copy.deepcopy(book)


def install(app, data_api, current_user):
    @app.get('/marketplace/textbooks/owned')
    def owned_library(user_id: str = Depends(current_user)):
        return {'items': library(data_api, user_id)}

    @app.get('/marketplace/textbooks')
    def catalogue(user_id: str = Depends(current_user)):
        if not books():
            return {'items': []}
        try:
            owned = owned_ids(data_api, user_id)
            return {'items': [{**headers(book), 'owned': key in owned}
                for key, book in books().items()]}
        except RuntimeError as error:
            raise HTTPException(503, 'Public textbook storage unavailable') from error

    @app.post('/marketplace/textbooks/{book_id}/purchase')
    def acquire(book_id: str, user_id: str = Depends(current_user)):
        # There is deliberately no client price, wallet call or whole-library overwrite.
        if not re.fullmatch(r'published-[0-9a-f]{64}', book_id) or book_id not in books():
            raise HTTPException(404, 'public_textbook_not_found')
        digest = books()[book_id]['source_sha256']
        try:
            data_api().request('POST', 'canary_user_kv',
                query={'on_conflict': 'user_id,key'},
                body={'user_id': user_id, 'key': OWNED_PREFIX + book_id,
                      'value': json.dumps({'source_sha256': digest, 'price_points': 0})},
                prefer='resolution=ignore-duplicates,return=minimal')
            if book_id not in owned_ids(data_api, user_id):
                raise RuntimeError('Acquisition could not be verified')
        except RuntimeError as error:
            raise HTTPException(503, 'Acquisition unavailable; retry the same book') from error
        return {**headers(books()[book_id]), 'owned': True}
