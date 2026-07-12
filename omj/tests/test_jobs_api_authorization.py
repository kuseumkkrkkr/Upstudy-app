from pathlib import Path
import sys

from fastapi import HTTPException

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.jobs import api as jobs_api


class FakeStateMachine:
    def __init__(self, state):
        self.state = state
        self.list_user_id = None
        self.cancel_user_id = None

    def get_status(self, job_id):
        return dict(self.state, job_id=job_id)

    def list_jobs(self, *, user_id=None, status=None, limit=200):
        self.list_user_id = user_id
        return []

    def cancel_job(self, job_id, user_id):
        self.cancel_user_id = user_id
        return dict(self.state, job_id=job_id, status="rejected")


def test_teacher_cannot_view_another_users_job():
    sm = FakeStateMachine({"user_id": "student-1", "status": "queued"})

    try:
        jobs_api.get_job("job-1", user={"user_id": "teacher-1", "role": "teacher"}, sm=sm)
    except HTTPException as exc:
        assert exc.status_code == 403
    else:
        raise AssertionError("teacher viewed another user's job")


def test_teacher_job_list_is_forced_to_own_user_id():
    sm = FakeStateMachine({"user_id": "student-1", "status": "queued"})

    jobs_api.list_jobs(
        user_id="student-1",
        status=None,
        limit=200,
        user={"user_id": "teacher-1", "role": "teacher"},
        sm=sm,
    )

    assert sm.list_user_id == "teacher-1"


def test_teacher_cannot_cancel_another_users_job():
    sm = FakeStateMachine({"user_id": "student-1", "status": "queued"})

    try:
        jobs_api.cancel_job(
            "job-1",
            user={"user_id": "teacher-1", "role": "teacher"},
            sm=sm,
        )
    except HTTPException as exc:
        assert exc.status_code == 403
    else:
        raise AssertionError("teacher cancelled another user's job")
    assert sm.cancel_user_id is None


def test_admin_can_cancel_another_users_job(monkeypatch):
    sm = FakeStateMachine({"user_id": "student-1", "status": "queued"})
    monkeypatch.setattr(jobs_api, "cancel_token", lambda job_id: None)
    monkeypatch.setattr(jobs_api, "hard_cancel_process_pool", lambda: False)
    monkeypatch.setattr(jobs_api, "release_token", lambda job_id: None)

    jobs_api.cancel_job(
        "job-1",
        user={"user_id": "admin-1", "role": "admin"},
        sm=sm,
    )

    assert sm.cancel_user_id == "student-1"
