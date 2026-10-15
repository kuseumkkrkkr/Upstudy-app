"""Bounded real admin DB/API checks; creates and archives only unique QA content.

Supply ADMIN_SUPABASE_URL, ADMIN_SUPABASE_SERVICE_ROLE_KEY, ADMIN_QA_ACTOR,
ADMIN_QA_PASSWORD, ADMIN_QA_API_KEY and ADMIN_QA_ORIGIN in the process environment.
No credentials, tokens or response bodies are logged.
"""
import concurrent.futures
import json
import os
import time
import urllib.error
import urllib.request
import uuid


def request(base, path, method="GET", body=None, headers=None):
    req = urllib.request.Request(base + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json", "User-Agent": "AIFlow-Admin-QA/1.0", **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code, None


def main():
    base = os.environ["ADMIN_SUPABASE_URL"]
    assert base == "https://ekogkwhvyqwdxibjfnko.supabase.co", "QA must use dedicated admin DB"
    headers = {"apikey": os.environ["ADMIN_SUPABASE_SERVICE_ROLE_KEY"]}
    actor = os.environ["ADMIN_QA_ACTOR"]
    run = "qa-admin-" + uuid.uuid4().hex
    payload = {"id": run, "kind": "course", "title": "Disposable admin QA", "problem_ids": ["001/260715/151557852092"]}

    def write(key, version=0, operation="save", value=None, who=actor):
        return request(base, "/rest/v1/rpc/admin_write_content", "POST", {
            "p_actor": who, "p_id": run, "p_payload": value or payload,
            "p_version": version, "p_archived": operation == "archive",
            "p_key": key, "p_operation": operation}, headers)

    started = time.monotonic()
    key = uuid.uuid4().hex
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as pool:
        results = list(pool.map(lambda _: write(key), range(200)))
    expected = {"id": run, "version": 1, "archived": False}
    assert all(status == 200 and result == expected for status, result in results), "Same-key concurrency failed"
    assert write(key, value={**payload, "title": "Changed"})[1] == {"error": "idempotency_conflict"}
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        edits = list(pool.map(lambda title: write(uuid.uuid4().hex, 1, value={**payload, "title": title}), ["Edit A", "Edit B"]))
    assert sorted(result.get("error", "ok") for _, result in edits) == ["ok", "version_conflict"]
    assert write(uuid.uuid4().hex, who=str(uuid.uuid4()))[1] == {"error": "not_admin"}
    # Even the backend service role may not bypass transactional content RPC writes.
    assert request(base, "/rest/v1/canary_content", "POST", {
        "id": run + "-forbidden", "payload": payload, "version": 1, "updated_by": actor}, headers)[0] in (401, 403)
    assert request(base, "/rest/v1/canary_content_changes?select=content_id", headers=headers)[0] in (401, 403)
    archive_key = uuid.uuid4().hex
    archived = write(archive_key, 2, "archive")
    assert archived == (200, {"id": run, "version": 3, "archived": True})
    assert write(uuid.uuid4().hex, 3, "restore")[1]["version"] == 4
    assert write(archive_key, 2, "archive", {**payload, "title": "Later metadata"}) == archived
    assert write(uuid.uuid4().hex, 4, "archive")[1]["version"] == 5
    status, rows = request(base, "/rest/v1/canary_content?select=id,version,archived&id=eq." + run, headers=headers)
    assert status == 200 and rows == [{"id": run, "version": 5, "archived": True}], "Persistent state mismatch"

    origin = os.environ["ADMIN_QA_ORIGIN"]
    api_key = {"X-Admin-Api-Key": os.environ["ADMIN_QA_API_KEY"]}
    status, login = request(origin, "/admin/api/login", "POST", {
        "username": "admin", "password": os.environ["ADMIN_QA_PASSWORD"]}, api_key)
    assert status == 200 and login.get("token"), "Real admin login failed"
    auth = {**api_key, "Authorization": "Bearer " + login["token"]}
    assert request(origin, "/admin/api/content", headers=auth)[0] == 200
    assert request(origin, "/admin/api/content")[0] == 401
    assert request(origin, "/admin/api/content", headers={"Authorization": auth["Authorization"]})[0] == 403
    assert request(origin, "/admin/api/content", headers={**auth, "X-Admin-Api-Key": "invalid"})[0] == 403
    for kind in ("course", "exam", "problem_set"):
        content_id = run + "-" + kind.replace("_", "-")
        content = {**payload, "id": content_id, "kind": kind, "version": 0}
        path = "/admin/api/content/" + content_id
        write_headers = {**auth, "X-Idempotency-Key": uuid.uuid4().hex}
        status, saved = request(origin, path, "PUT", content, write_headers)
        assert status == 200 and saved["version"] == 1, "API create failed: " + kind
        assert request(origin, path, "PUT", content, write_headers) == (status, saved)
        assert request(origin, path, "PUT", {**content, "title": "Altered retry"}, write_headers)[0] == 409
        status, listing = request(origin, "/admin/api/content", headers=auth)
        found = next(row for row in listing["items"] if row["id"] == content_id)
        assert status == 200 and found["version"] == 1 and found["payload"]["kind"] == kind
        assert request(origin, path, "DELETE", headers={**auth, "X-Idempotency-Key": uuid.uuid4().hex})[0] == 422
        status, archived_api = request(origin, path + "?version=1", "DELETE",
            headers={**auth, "X-Idempotency-Key": uuid.uuid4().hex})
        assert status == 200 and archived_api["archived"] and archived_api["version"] == 2
    print(json.dumps({"same_key_requests": 200, "max_parallel_http_workers": 20,
        "same_key_single_version": True, "optimistic_conflict": True, "non_admin_denied": True,
        "direct_table_write_denied": True, "audit_table_read_denied": True,
        "archive_retry_after_restore": True, "persistent_final_version": 5,
        "admin_login_and_key_checks": True, "api_crud_kinds": ["course", "exam", "problem_set"], "qa_content": run,
        "elapsed_seconds": round(time.monotonic() - started, 2)}))


if __name__ == "__main__":
    main()
