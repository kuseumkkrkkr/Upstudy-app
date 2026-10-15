"""Server-only content administration; membership and API key are both required."""
from __future__ import annotations

import copy
import hashlib
import hmac
import os
import time
from pathlib import Path
from typing import Any, Literal

from fastapi import Depends, Header, HTTPException, Query
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, ConfigDict, Field
import jwt


class ContentInput(BaseModel):
    """Only canonical question references, no executable HTML or client prices."""
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{2,119}$")
    kind: Literal["course", "exam", "problem_set"]
    title: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=2000)
    grade_band: str = Field(default="수학", min_length=1, max_length=40)
    difficulty: str = Field(default="기본", min_length=1, max_length=40)
    problem_ids: list[str] = Field(min_length=1, max_length=50)
    version: int = Field(default=0, ge=0)


def enabled() -> bool:
    return os.getenv("CONTENT_ADMIN_ENABLED", "").lower() == "true"


def stored_rows(data_api) -> list[dict[str, Any]]:
    """Read persisted overrides without hiding DB errors as an empty catalogue."""
    if not enabled():
        return []
    try:
        rows = []
        for offset in range(0, 10000, 500):
            page = data_api().request("GET", "canary_content", query={
                "select": "id,payload,version,archived", "order": "id.asc",
                "limit": "500", "offset": str(offset),
            }) or []
            rows.extend(page)
            if len(page) < 500:
                return rows
        raise RuntimeError("Content catalogue exceeds configured limit")
    except RuntimeError as error:
        raise HTTPException(503, "Content storage unavailable") from error


def catalogue(seed, data_api, *, include_archived=False):
    """Overlay stored changes on bundled content; archived ownership remains readable."""
    items = {item["id"]: copy.deepcopy(item) for item in seed}
    for row in stored_rows(data_api):
        if row["archived"] and not include_archived:
            items.pop(row["id"], None)
        else:
            items[row["id"]] = {**row["payload"], "_admin_content": True, "_archived": row["archived"]}
    return list(items.values())


class AdminLogin(BaseModel):
    model_config = ConfigDict(extra="forbid")
    username: str = Field(pattern=r"^[A-Za-z0-9]{4,32}$")
    password: str = Field(min_length=1, max_length=128)


def admin_secret():
    secret = os.getenv('ADMIN_JWT_SECRET', '').strip()
    if len(secret) < 32 or secret == os.getenv('OMJ_JWT_SECRET', '').strip():
        raise HTTPException(503, 'Independent admin token secret is not configured')
    return secret


def install(app, data_api, seed, find_question):
    """Admin accounts and catalog changes live exclusively in the separate admin DB."""
    def require_key(x_admin_api_key: str | None = Header(default=None)):
        if not enabled():
            raise HTTPException(503, "Content administration is not enabled")
        expected = os.getenv("CONTENT_ADMIN_API_KEY_SHA256", "").strip().lower()
        if len(expected) != 64:
            raise HTTPException(503, "Admin API key is not configured")
        supplied = hashlib.sha256((x_admin_api_key or "").encode()).hexdigest()
        if not x_admin_api_key or len(x_admin_api_key) > 512 or not hmac.compare_digest(supplied, expected):
            raise HTTPException(403, "Admin account and API key required")

    def account(user_id):
        try:
            rows = data_api().request("GET", "content_admin_accounts", query={
                "select": "id,session_version", "id": f"eq.{user_id}", "active": "eq.true", "limit": "1",
            }) or []
        except RuntimeError as error:
            raise HTTPException(503, "Admin membership storage unavailable") from error
        if not rows:
            raise HTTPException(403, "Admin account and API key required")
        return rows[0]

    def admin(authorization: str | None = Header(default=None), x_admin_api_key: str | None = Header(default=None)):
        if not authorization or not authorization.startswith('Bearer '):
            raise HTTPException(401, 'Admin bearer token required')
        require_key(x_admin_api_key)
        try:
            claims = jwt.decode(authorization[7:], admin_secret(), algorithms=['HS256'],
                issuer='aiflow-content-admin', audience='content-admin',
                options={'require':['sub','exp','iat','iss','aud','session_version']})
        except jwt.PyJWTError as error:
            raise HTTPException(401, 'Invalid admin token') from error
        user_id = str(claims['sub'])
        if account(user_id)['session_version'] != claims['session_version']:
            raise HTTPException(401, 'Admin session revoked')
        return user_id

    @app.post('/admin/api/login')
    def login(payload: AdminLogin, _key=Depends(require_key)):
        secret = admin_secret()
        try:
            allowed = data_api().request('POST', 'rpc/claim_content_admin_login', body={'p_username':payload.username})
            if allowed is not True:
                raise HTTPException(429, 'Too many admin login attempts; retry later')
            rows = data_api().request('GET', 'content_admin_accounts', query={
                'select':'id,password_hash,salt,session_version,active',
                'username':f'eq.{payload.username}', 'limit':'1',
            }) or []
        except RuntimeError as error:
            raise HTTPException(503, 'Admin authentication storage unavailable') from error
        row = rows[0] if rows else {}
        digest = hashlib.pbkdf2_hmac('sha256', payload.password.encode(),
            str(row.get('salt') or 'nonexistent-admin-dummy-salt').encode(), 600_000).hex()
        if not row.get('active') or not hmac.compare_digest(digest, str(row.get('password_hash') or '0'*64)):
            raise HTTPException(401, 'Invalid admin credentials')
        now = int(time.time())
        token = jwt.encode({'sub':str(row['id']), 'iat':now, 'exp':now+1800,
            'iss':'aiflow-content-admin', 'aud':'content-admin', 'session_version':row['session_version']}, secret, algorithm='HS256')
        return JSONResponse({'token':token}, headers={'Cache-Control':'no-store'})

    def write(actor, content_id, payload, version, archived, key, operation="save"):
        if not key or len(key) > 160:
            raise HTTPException(422, "X-Idempotency-Key required (1..160 characters)")
        try:
            result = data_api().request("POST", "rpc/admin_write_content", body={
                "p_actor": actor, "p_id": content_id, "p_payload": payload,
                "p_version": version, "p_archived": archived, "p_key": key,
                "p_operation": operation,
            })
        except RuntimeError as error:
            raise HTTPException(503, "Content write unavailable; retry with the same key") from error
        if not isinstance(result, dict):
            raise HTTPException(503, "Invalid content storage response")
        if result.get("error"):
            raise HTTPException(403 if result["error"] == "not_admin" else 409, result["error"])
        return result

    @app.get("/admin", include_in_schema=False)
    @app.get("/admin/", include_in_schema=False)
    def page():
        return Response((Path(__file__).resolve().parents[1] / "data/content/admin.html").read_text(encoding="utf-8"),
                        media_type="text/html", headers={
            "Cache-Control": "no-store", "X-Frame-Options": "DENY",
            "Content-Security-Policy": "default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
            "Referrer-Policy": "no-referrer", "X-Content-Type-Options": "nosniff",
        })

    @app.get("/admin/app.js", include_in_schema=False)
    def script():
        return Response((Path(__file__).resolve().parents[1] / "data/content/admin.js").read_text(encoding="utf-8"),
                        media_type="application/javascript", headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"})

    @app.get("/admin/api/content")
    def listing(actor: str = Depends(admin)):
        changes = {row["id"]: row for row in stored_rows(data_api)}
        items = {item["id"]: {"id": item["id"], "payload": item, "version": 0, "archived": False} for item in seed}
        items.update(changes)
        return {"items": list(items.values())}

    @app.put("/admin/api/content/{content_id}")
    def save(content_id: str, value: ContentInput, actor: str = Depends(admin),
             x_idempotency_key: str | None = Header(default=None)):
        if content_id != value.id or len(set(value.problem_ids)) != len(value.problem_ids):
            raise HTTPException(422, "Invalid ID or duplicate questions")
        if any(len(question_id) > 200 or find_question(question_id) is None for question_id in value.problem_ids):
            raise HTTPException(422, "Unknown canonical question ID")
        existing = next((item for item in seed if item["id"] == content_id), None)
        # Published question lists are immutable: existing student attempts must keep their meaning.
        stored = next((row for row in stored_rows(data_api) if row["id"] == content_id), None)
        previous = stored["payload"] if stored else existing
        if previous and (previous["kind"] != value.kind or previous.get("problem_ids") != value.problem_ids):
            raise HTTPException(409, "Create a new ID to change published questions or content kind")
        payload = {**value.model_dump(exclude={"version"}), "asset_id": (previous or {}).get("asset_id", value.id),
                   "item_count": len(value.problem_ids), "price_points": 0, "featured_rank": 0,
                   "subject": "수학", "_canonical_questions": True}
        return write(actor, content_id, payload, value.version, False, x_idempotency_key)

    @app.delete("/admin/api/content/{content_id}")
    def archive(content_id: str, version: int = Query(ge=0), actor: str = Depends(admin),
                x_idempotency_key: str | None = Header(default=None)):
        # The transaction checks the expected version and preserves the original payload.
        original = next((item for item in seed if item["id"] == content_id), None)
        stored = next((row for row in stored_rows(data_api) if row["id"] == content_id), None)
        if not stored and not original:
            raise HTTPException(404, "Content not found")
        return write(actor, content_id, (stored or {}).get("payload", original), version, True, x_idempotency_key, "archive")

    @app.post("/admin/api/content/{content_id}/restore")
    def restore(content_id: str, version: int = Query(ge=1), actor: str = Depends(admin),
                x_idempotency_key: str | None = Header(default=None)):
        stored = next((row for row in stored_rows(data_api) if row["id"] == content_id), None)
        if not stored:
            raise HTTPException(404, "Content not found")
        return write(actor, content_id, stored["payload"], version, False, x_idempotency_key, "restore")
