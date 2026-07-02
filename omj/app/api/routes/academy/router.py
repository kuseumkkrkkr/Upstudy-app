"""Academy domain API router.

Provides CRUD + business-logic endpoints for:
- Academy
- AcademyGroup (with friend verification, group limits, group type separation)
- AcademyGroupMember (with event logging)
- AttendanceLog (with statistics)
- TuitionPayment (with summary)
- FinanceLedger (with summary)
- ParentConsultNote
- GroupAssignment / GroupSubmission / SubmissionReport (3-stage pipeline)
- TimetablePreference / TimetablePlan (heuristic v1)
- StudentOverviewSnapshot (auto-build)
"""
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.api.deps import get_current_user
from domain.academy import repository as repo
from storage.social_storage import are_friends
from storage.social_storage import search_users_by_username

router = APIRouter(prefix="/academy", tags=["academy"])

MAX_GROUPS_PER_USER = 3
MAX_GROUPS_CREATED_PER_USER = 3


def _is_teacher_admin(role: str) -> bool:
    role_norm = (role or "").strip().lower()
    return role_norm in {"teacher", "admin", "academy_admin", "academy_teacher"}


def _ensure_friend_access_or_403(caller_user_id: str, target_user_id: str) -> None:
    if not target_user_id or caller_user_id == target_user_id:
        return
    if not are_friends(caller_user_id, target_user_id):
        raise HTTPException(status_code=403, detail="Only friend students are accessible")


# ---------------------------------------------------------------------------
# Response wrapper
# ---------------------------------------------------------------------------

class ApiResponse(BaseModel):
    success: bool = True
    data: Optional[dict] = None
    message: Optional[str] = None


@router.get("/friends/search-nickname", response_model=ApiResponse)
def search_friends_by_nickname(
    q: str = Query(..., min_length=1, max_length=50),
    limit: int = Query(default=20, ge=1, le=50),
    user: dict = Depends(get_current_user),
):
    """Search users by nickname/username inside academy feature flow.

    Used before academy group features are fully enabled so teachers/students
    can still add friends from academy context.
    """
    items = search_users_by_username(
        q,
        exclude_user_id=user.get("user_id"),
        limit=limit,
    )
    return ApiResponse(data={"items": items})


# ---------------------------------------------------------------------------
# Academy
# ---------------------------------------------------------------------------

class AcademyCreate(BaseModel):
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None


class AcademyUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    admin_user_id: Optional[str] = None


@router.post("", response_model=ApiResponse)
def create_academy(body: AcademyCreate, user: dict = Depends(get_current_user)):
    if not _is_teacher_admin(str(user.get("role") or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create academies")
    data = repo.create_academy(
        name=body.name,
        address=body.address,
        phone=body.phone,
        admin_user_id=user.get("user_id"),
    )
    return ApiResponse(data=data)


@router.get("", response_model=ApiResponse)
def list_academies(user: dict = Depends(get_current_user)):
    data = repo.list_academies()
    return ApiResponse(data={"items": data})


# ---------------------------------------------------------------------------
# AcademyGroup
# ---------------------------------------------------------------------------

class GroupCreate(BaseModel):
    academy_id: str
    name: str
    grade: Optional[str] = None
    subject: Optional[str] = None
    group_type: str = Field(default="academy_tutoring_group", description="academy_tutoring_group | social_study_group")
    searchable: bool = False
    friend_verification_required: bool = True
    max_members: int = Field(default=20, ge=1, le=100)
    style_border_color: Optional[str] = None
    style_badge_text: Optional[str] = None
    schedule_json: Optional[str] = None


class GroupUpdate(BaseModel):
    name: Optional[str] = None
    grade: Optional[str] = None
    subject: Optional[str] = None
    teacher_user_id: Optional[str] = None
    group_type: Optional[str] = None
    searchable: Optional[bool] = None
    friend_verification_required: Optional[bool] = None
    max_members: Optional[int] = None
    style_border_color: Optional[str] = None
    style_badge_text: Optional[str] = None
    schedule_json: Optional[str] = None


@router.post("/groups", response_model=ApiResponse)
def create_group(body: GroupCreate, user: dict = Depends(get_current_user)):
    """Create a new academy group.

    Enforces:
    - Max 3 groups created per user per academy
    - Max 3 total academy groups per user
    """
    user_id = user.get("user_id")
    role = user.get("role")

    # Only teachers/admins can create academy_tutoring_group
    if body.group_type == "academy_tutoring_group" and not _is_teacher_admin(str(role or "")):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create academy tutoring groups")

    # Enforce: max 1 group created per user per academy
    created_count = repo.count_groups_created_by_user(user_id, body.academy_id)
    if created_count >= MAX_GROUPS_CREATED_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already created {MAX_GROUPS_CREATED_PER_USER} group(s) in this academy")

    # Enforce: max 3 total academy groups per user
    total_count = repo.count_groups_for_user(user_id)
    if total_count >= MAX_GROUPS_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already joined {MAX_GROUPS_PER_USER} academy groups")

    data = repo.create_group(
        academy_id=body.academy_id,
        name=body.name,
        grade=body.grade,
        subject=body.subject,
        teacher_user_id=user_id,
        group_type=body.group_type,
        searchable=body.searchable,
        friend_verification_required=body.friend_verification_required,
        max_members=body.max_members,
        style_border_color=body.style_border_color,
        style_badge_text=body.style_badge_text,
        schedule_json=body.schedule_json,
    )

    # Auto-add creator as teacher member
    repo.add_group_member(
        group_id=data["group_id"],
        user_id=user_id,
        role="teacher",
        status="active",
    )

    return ApiResponse(data=data)


@router.get("/groups", response_model=ApiResponse)
def list_groups(
    academy_id: Optional[str] = None,
    group_type: Optional[str] = None,
    searchable: Optional[bool] = None,
    user: dict = Depends(get_current_user),
):
    """List academy groups.

    - academy_tutoring_group: only visible to academy members
    - social_study_group: visible if searchable=True
    """
    data = repo.list_groups(academy_id=academy_id, group_type=group_type, searchable=searchable)
    return ApiResponse(data={"items": data})


@router.get("/groups/{group_id}", response_model=ApiResponse)
def get_group(group_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_group(group_id)
    if not data:
        raise HTTPException(status_code=404, detail="Group not found")
    return ApiResponse(data=data)


@router.put("/groups/{group_id}", response_model=ApiResponse)
def update_group(group_id: str, body: GroupUpdate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update groups")
    data = repo.update_group(
        group_id,
        name=body.name,
        grade=body.grade,
        subject=body.subject,
        teacher_user_id=body.teacher_user_id,
        group_type=body.group_type,
        searchable=body.searchable,
        friend_verification_required=body.friend_verification_required,
        max_members=body.max_members,
        style_border_color=body.style_border_color,
        style_badge_text=body.style_badge_text,
        schedule_json=body.schedule_json,
    )
    return ApiResponse(data=data)


@router.delete("/groups/{group_id}", response_model=ApiResponse)
def delete_group(group_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete groups")
    deleted = repo.delete_group(group_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


@router.get("/{academy_id}", response_model=ApiResponse)
def get_academy(academy_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_academy(academy_id)
    if not data:
        raise HTTPException(status_code=404, detail="Academy not found")
    return ApiResponse(data=data)


@router.put("/{academy_id}", response_model=ApiResponse)
def update_academy(academy_id: str, body: AcademyUpdate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update academies")
    data = repo.update_academy(
        academy_id,
        name=body.name,
        address=body.address,
        phone=body.phone,
        admin_user_id=body.admin_user_id,
    )
    return ApiResponse(data=data)


@router.delete("/{academy_id}", response_model=ApiResponse)
def delete_academy(academy_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete academies")
    deleted = repo.delete_academy(academy_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# AcademyGroupMember
# ---------------------------------------------------------------------------

class MemberCreate(BaseModel):
    group_id: str
    user_id: str
    role: str = "student"


class MemberInvite(BaseModel):
    group_id: str
    invited_user_id: str


@router.post("/members", response_model=ApiResponse)
def add_group_member(body: MemberCreate, user: dict = Depends(get_current_user)):
    """Add a member to a group.

    Enforces:
    - Max 3 academy groups per user
    - Friend verification if group requires it
    - Group capacity limit
    """
    group = repo.get_group(body.group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    # Check group capacity
    member_count = repo.get_group_member_count(body.group_id)
    if member_count >= group.get("max_members", 20):
        raise HTTPException(status_code=400, detail="Group is full")

    # Check user's group limit
    current_count = repo.count_groups_for_user(body.user_id)
    if current_count >= MAX_GROUPS_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already joined {MAX_GROUPS_PER_USER} academy groups")

    # Friend verification
    if group.get("friend_verification_required", True):
        inviter_id = user.get("user_id")
        if not are_friends(inviter_id, body.user_id):
            raise HTTPException(status_code=403, detail="Active friendship required to join this group")

    data = repo.add_group_member(
        group_id=body.group_id,
        user_id=body.user_id,
        role=body.role,
        status="active",
    )

    # Log event
    repo.log_member_event(
        group_id=body.group_id,
        user_id=body.user_id,
        event_type="joined",
        triggered_by_user_id=user.get("user_id"),
        reason="direct_add",
    )

    return ApiResponse(data=data)


@router.post("/members/invite", response_model=ApiResponse)
def invite_member(body: MemberInvite, user: dict = Depends(get_current_user)):
    """Invite a member via friend verification.

    Creates a pending member record; actual join requires acceptance.
    """
    group = repo.get_group(body.group_id)
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    # Check group capacity
    member_count = repo.get_group_member_count(body.group_id)
    if member_count >= group.get("max_members", 20):
        raise HTTPException(status_code=400, detail="Group is full")

    # Check invitee's group limit
    current_count = repo.count_groups_for_user(body.invited_user_id)
    if current_count >= MAX_GROUPS_PER_USER:
        raise HTTPException(status_code=400, detail=f"User already joined {MAX_GROUPS_PER_USER} academy groups")

    # Friend verification
    if group.get("friend_verification_required", True):
        inviter_id = user.get("user_id")
        if not are_friends(inviter_id, body.invited_user_id):
            raise HTTPException(status_code=403, detail="Active friendship required to invite this user")

    data = repo.add_group_member(
        group_id=body.group_id,
        user_id=body.invited_user_id,
        role="student",
        status="pending",
    )

    # Log event
    repo.log_member_event(
        group_id=body.group_id,
        user_id=body.invited_user_id,
        event_type="invited",
        triggered_by_user_id=user.get("user_id"),
    )

    return ApiResponse(data=data, message="Invitation sent")


@router.post("/members/{member_id}/accept", response_model=ApiResponse)
def accept_invitation(member_id: str, user: dict = Depends(get_current_user)):
    """Accept a pending group invitation."""
    member = repo.get_group_member(member_id)
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.get("status") != "pending":
        raise HTTPException(status_code=400, detail="Member is not in pending status")
    if member.get("user_id") != user.get("user_id"):
        raise HTTPException(status_code=403, detail="Can only accept your own invitations")

    data = repo.update_member_status(member_id, "active")

    # Log event
    repo.log_member_event(
        group_id=member.get("group_id"),
        user_id=member.get("user_id"),
        event_type="joined",
        triggered_by_user_id=user.get("user_id"),
        reason="accepted_invitation",
    )

    return ApiResponse(data=data)


@router.get("/groups/{group_id}/members", response_model=ApiResponse)
def list_group_members(group_id: str, user: dict = Depends(get_current_user)):
    data = repo.list_group_members(group_id=group_id)
    return ApiResponse(data={"items": data})


@router.delete("/members/{member_id}", response_model=ApiResponse)
def remove_group_member(member_id: str, reason: Optional[str] = None, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        # Allow self-removal
        member = repo.get_group_member(member_id)
        if not member or member.get("user_id") != user.get("user_id"):
            raise HTTPException(status_code=403, detail="Only teachers/admins can remove members")
    deleted = repo.remove_group_member(member_id, reason=reason)
    return ApiResponse(success=deleted, message="Removed" if deleted else "Not found")


@router.get("/groups/{group_id}/events", response_model=ApiResponse)
def list_member_events(
    group_id: str,
    event_type: Optional[str] = None,
    limit: int = Query(default=100, le=500),
    user: dict = Depends(get_current_user),
):
    data = repo.list_member_events(group_id=group_id, event_type=event_type, limit=limit)
    return ApiResponse(data={"items": data})


# ---------------------------------------------------------------------------
# AttendanceLog
# ---------------------------------------------------------------------------

class AttendanceCreate(BaseModel):
    group_id: str
    user_id: str
    date: str  # YYYY-MM-DD
    status: str = Field(..., pattern=r"^(present|late|absent)$")
    note: Optional[str] = None


class AttendanceUpdate(BaseModel):
    status: Optional[str] = None
    note: Optional[str] = None


@router.post("/attendance", response_model=ApiResponse)
def record_attendance(body: AttendanceCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can record attendance")
    data = repo.record_attendance(
        group_id=body.group_id,
        user_id=body.user_id,
        date=body.date,
        status=body.status,
        checked_by_user_id=user.get("user_id"),
        note=body.note,
    )
    return ApiResponse(data=data)


@router.get("/attendance", response_model=ApiResponse)
def list_attendance(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    date: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_attendance(
        group_id=group_id,
        user_id=user_id,
        date=date,
        date_from=date_from,
        date_to=date_to,
    )
    return ApiResponse(data={"items": data})


@router.put("/attendance/{log_id}", response_model=ApiResponse)
def update_attendance(log_id: str, body: AttendanceUpdate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update attendance")
    data = repo.update_attendance(log_id, status=body.status, note=body.note)
    return ApiResponse(data=data)


@router.delete("/attendance/{log_id}", response_model=ApiResponse)
def delete_attendance(log_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete attendance")
    deleted = repo.delete_attendance(log_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


@router.get("/attendance/stats/{group_id}/{user_id}", response_model=ApiResponse)
def get_attendance_stats(
    group_id: str,
    user_id: str,
    days: int = Query(default=30, ge=1, le=365),
    user: dict = Depends(get_current_user),
):
    data = repo.get_attendance_stats(user_id, group_id, days=days)
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# TuitionPayment
# ---------------------------------------------------------------------------

class TuitionCreate(BaseModel):
    academy_id: str
    user_id: str
    amount: int = Field(..., ge=0)
    month_label: str  # YYYY-MM
    method: Optional[str] = None
    receipt_url: Optional[str] = None
    memo: Optional[str] = None


class TuitionUpdate(BaseModel):
    amount: Optional[int] = None
    method: Optional[str] = None
    receipt_url: Optional[str] = None
    memo: Optional[str] = None


@router.post("/tuition", response_model=ApiResponse)
def create_tuition_payment(body: TuitionCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can record tuition")
    data = repo.create_tuition_payment(
        academy_id=body.academy_id,
        user_id=body.user_id,
        amount=body.amount,
        month_label=body.month_label,
        method=body.method,
        receipt_url=body.receipt_url,
        memo=body.memo,
    )
    return ApiResponse(data=data)


@router.get("/tuition", response_model=ApiResponse)
def list_tuition_payments(
    academy_id: Optional[str] = None,
    user_id: Optional[str] = None,
    month_label: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_tuition_payments(academy_id=academy_id, user_id=user_id, month_label=month_label)
    return ApiResponse(data={"items": data})


@router.get("/tuition/summary/{academy_id}", response_model=ApiResponse)
def get_tuition_summary(
    academy_id: str,
    month_label: str,
    user: dict = Depends(get_current_user),
):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can view tuition summary")
    data = repo.get_tuition_summary(academy_id, month_label)
    return ApiResponse(data=data)


@router.put("/tuition/{payment_id}", response_model=ApiResponse)
def update_tuition_payment(payment_id: str, body: TuitionUpdate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update tuition")
    data = repo.update_tuition_payment(
        payment_id,
        amount=body.amount,
        method=body.method,
        receipt_url=body.receipt_url,
        memo=body.memo,
    )
    return ApiResponse(data=data)


@router.delete("/tuition/{payment_id}", response_model=ApiResponse)
def delete_tuition_payment(payment_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete tuition")
    deleted = repo.delete_tuition_payment(payment_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# FinanceLedger
# ---------------------------------------------------------------------------

class LedgerCreate(BaseModel):
    academy_id: str
    category: str = Field(..., pattern=r"^(income|expense)$")
    amount: int = Field(..., ge=0)
    description: Optional[str] = None
    transaction_date: str  # YYYY-MM-DD


class LedgerUpdate(BaseModel):
    category: Optional[str] = None
    amount: Optional[int] = None
    description: Optional[str] = None
    transaction_date: Optional[str] = None


@router.post("/ledger", response_model=ApiResponse)
def create_ledger_entry(body: LedgerCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can record ledger entries")
    data = repo.create_ledger_entry(
        academy_id=body.academy_id,
        category=body.category,
        amount=body.amount,
        description=body.description,
        transaction_date=body.transaction_date,
        recorded_by_user_id=user.get("user_id"),
    )
    return ApiResponse(data=data)


@router.get("/ledger", response_model=ApiResponse)
def list_ledger_entries(
    academy_id: Optional[str] = None,
    category: Optional[str] = None,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_ledger_entries(
        academy_id=academy_id,
        category=category,
        transaction_date_from=transaction_date_from,
        transaction_date_to=transaction_date_to,
    )
    return ApiResponse(data={"items": data})


@router.get("/ledger/summary/{academy_id}", response_model=ApiResponse)
def get_ledger_summary(
    academy_id: str,
    transaction_date_from: Optional[str] = None,
    transaction_date_to: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can view ledger summary")
    data = repo.get_ledger_summary(academy_id, transaction_date_from, transaction_date_to)
    return ApiResponse(data=data)


@router.put("/ledger/{ledger_id}", response_model=ApiResponse)
def update_ledger_entry(ledger_id: str, body: LedgerUpdate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update ledger")
    data = repo.update_ledger_entry(
        ledger_id,
        category=body.category,
        amount=body.amount,
        description=body.description,
        transaction_date=body.transaction_date,
    )
    return ApiResponse(data=data)


@router.delete("/ledger/{ledger_id}", response_model=ApiResponse)
def delete_ledger_entry(ledger_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete ledger entries")
    deleted = repo.delete_ledger_entry(ledger_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# ParentConsultNote
# ---------------------------------------------------------------------------

class ConsultCreate(BaseModel):
    academy_id: str
    student_user_id: str
    parent_name: Optional[str] = None
    parent_contact: Optional[str] = None
    topic: Optional[str] = None
    content: Optional[str] = None
    follow_up_date: Optional[str] = None


class ConsultUpdate(BaseModel):
    parent_name: Optional[str] = None
    parent_contact: Optional[str] = None
    topic: Optional[str] = None
    content: Optional[str] = None
    follow_up_date: Optional[str] = None


@router.post("/consult", response_model=ApiResponse)
def create_consult_note(body: ConsultCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create consult notes")
    data = repo.create_consult_note(
        academy_id=body.academy_id,
        student_user_id=body.student_user_id,
        parent_name=body.parent_name,
        parent_contact=body.parent_contact,
        topic=body.topic,
        content=body.content,
        consulted_by_user_id=user.get("user_id"),
        follow_up_date=body.follow_up_date,
    )
    return ApiResponse(data=data)


@router.get("/consult", response_model=ApiResponse)
def list_consult_notes(
    academy_id: Optional[str] = None,
    student_user_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_consult_notes(academy_id=academy_id, student_user_id=student_user_id)
    return ApiResponse(data={"items": data})


@router.put("/consult/{note_id}", response_model=ApiResponse)
def update_consult_note(note_id: str, body: ConsultUpdate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can update consult notes")
    data = repo.update_consult_note(
        note_id,
        parent_name=body.parent_name,
        parent_contact=body.parent_contact,
        topic=body.topic,
        content=body.content,
        follow_up_date=body.follow_up_date,
    )
    return ApiResponse(data=data)


@router.delete("/consult/{note_id}", response_model=ApiResponse)
def delete_consult_note(note_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete consult notes")
    deleted = repo.delete_consult_note(note_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# GroupAssignment
# ---------------------------------------------------------------------------

class AssignmentCreate(BaseModel):
    group_id: str
    kind: str = Field(..., pattern=r"^(exam|problem|course)$")
    ref_id: str
    title: Optional[str] = None
    message: Optional[str] = None
    due_date: Optional[str] = None  # YYYY-MM-DD


@router.post("/assignments", response_model=ApiResponse)
def create_assignment(body: AssignmentCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create assignments")
    data = repo.create_assignment(
        group_id=body.group_id,
        sender_user_id=user.get("user_id"),
        kind=body.kind,
        ref_id=body.ref_id,
        title=body.title,
        message=body.message,
        due_date=body.due_date,
    )
    return ApiResponse(data=data)


@router.get("/assignments", response_model=ApiResponse)
def list_assignments(
    group_id: Optional[str] = None,
    kind: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_assignments(group_id=group_id, kind=kind)
    return ApiResponse(data={"items": data})


@router.delete("/assignments/{assignment_id}", response_model=ApiResponse)
def delete_assignment(assignment_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete assignments")
    deleted = repo.delete_assignment(assignment_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# GroupSubmission
# ---------------------------------------------------------------------------

class SubmissionUpdate(BaseModel):
    status: Optional[str] = None
    data_json: Optional[str] = None


@router.get("/submissions", response_model=ApiResponse)
def list_submissions(
    assignment_id: Optional[str] = None,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_submissions(assignment_id=assignment_id, user_id=user_id, status=status)
    return ApiResponse(data={"items": data})


@router.post("/submissions/{submission_id}/submit", response_model=ApiResponse)
def submit_submission(submission_id: str, body: SubmissionUpdate, user: dict = Depends(get_current_user)):
    """Student submits their work."""
    submission = repo.get_submission(submission_id)
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    if submission.get("user_id") != user.get("user_id"):
        raise HTTPException(status_code=403, detail="Can only submit your own work")

    data = repo.update_submission_status(
        submission_id,
        status=body.status or "submitted",
        data_json=body.data_json,
    )
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# SubmissionReport
# ---------------------------------------------------------------------------

class ReportCreate(BaseModel):
    submission_id: str
    correct_rate: Optional[float] = None
    time_spent_seconds: Optional[int] = None
    weak_tags: Optional[List[str]] = None
    feedback: Optional[str] = None


@router.post("/reports", response_model=ApiResponse)
def create_submission_report(body: ReportCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create reports")
    data = repo.create_submission_report(
        submission_id=body.submission_id,
        correct_rate=body.correct_rate,
        time_spent_seconds=body.time_spent_seconds,
        weak_tags=body.weak_tags,
        feedback=body.feedback,
    )
    return ApiResponse(data=data)


@router.get("/reports/{report_id}", response_model=ApiResponse)
def get_submission_report(report_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_submission_report(report_id)
    if not data:
        raise HTTPException(status_code=404, detail="Report not found")
    return ApiResponse(data=data)


@router.get("/submissions/{submission_id}/report", response_model=ApiResponse)
def get_report_by_submission(submission_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_report_by_submission(submission_id)
    if not data:
        raise HTTPException(status_code=404, detail="Report not found")
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# TimetablePreference
# ---------------------------------------------------------------------------

class TimetablePreferenceCreate(BaseModel):
    group_id: str
    day_of_week: str = Field(..., pattern=r"^(mon|tue|wed|thu|fri|sat|sun)$")
    time_slot: str  # HH:MM-HH:MM
    priority: int = Field(default=1, ge=1, le=5)


@router.post("/timetable/preferences", response_model=ApiResponse)
def create_timetable_preference(body: TimetablePreferenceCreate, user: dict = Depends(get_current_user)):
    data = repo.create_timetable_preference(
        group_id=body.group_id,
        user_id=user.get("user_id"),
        day_of_week=body.day_of_week,
        time_slot=body.time_slot,
        priority=body.priority,
    )
    return ApiResponse(data=data)


@router.get("/timetable/preferences", response_model=ApiResponse)
def list_timetable_preferences(
    group_id: Optional[str] = None,
    user_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    data = repo.list_timetable_preferences(group_id=group_id, user_id=user_id)
    return ApiResponse(data={"items": data})


@router.delete("/timetable/preferences/{preference_id}", response_model=ApiResponse)
def delete_timetable_preference(preference_id: str, user: dict = Depends(get_current_user)):
    deleted = repo.delete_timetable_preference(preference_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")


# ---------------------------------------------------------------------------
# TimetablePlan
# ---------------------------------------------------------------------------

@router.post("/timetable/generate/{group_id}", response_model=ApiResponse)
def generate_timetable(group_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can generate timetables")
    data = repo.generate_timetable_heuristic_v1(group_id)
    return ApiResponse(data=data)


@router.get("/timetable/plans/{group_id}", response_model=ApiResponse)
def list_timetable_plans(group_id: str, user: dict = Depends(get_current_user)):
    data = repo.list_timetable_plans(group_id)
    return ApiResponse(data={"items": data})


@router.post("/timetable/plans/{plan_id}/apply", response_model=ApiResponse)
def apply_timetable_plan(plan_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can apply timetable plans")
    data = repo.apply_timetable_plan(plan_id)
    if not data:
        raise HTTPException(status_code=404, detail="Plan not found")
    return ApiResponse(data=data)


# ---------------------------------------------------------------------------
# StudentOverviewSnapshot
# ---------------------------------------------------------------------------

class SnapshotCreate(BaseModel):
    user_id: str
    academy_id: str
    group_id: Optional[str] = None
    overall_score: Optional[float] = None
    attendance_rate: Optional[float] = None
    tuition_status: Optional[str] = None
    last_consult_note_id: Optional[str] = None
    summary_json: Optional[str] = None


@router.post("/snapshots", response_model=ApiResponse)
def create_snapshot(body: SnapshotCreate, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can create snapshots")
    _ensure_friend_access_or_403(user.get("user_id"), body.user_id)
    data = repo.create_snapshot(
        user_id=body.user_id,
        academy_id=body.academy_id,
        group_id=body.group_id,
        overall_score=body.overall_score,
        attendance_rate=body.attendance_rate,
        tuition_status=body.tuition_status,
        last_consult_note_id=body.last_consult_note_id,
        summary_json=body.summary_json,
    )
    return ApiResponse(data=data)


@router.post("/snapshots/build/{user_id}", response_model=ApiResponse)
def build_student_overview(
    user_id: str,
    academy_id: str,
    group_id: Optional[str] = None,
    user: dict = Depends(get_current_user),
):
    """Auto-build a comprehensive student overview from multiple data sources."""
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can build snapshots")
    _ensure_friend_access_or_403(user.get("user_id"), user_id)
    data = repo.build_student_overview(user_id=user_id, academy_id=academy_id, group_id=group_id)
    return ApiResponse(data=data)


@router.get("/snapshots", response_model=ApiResponse)
def list_snapshots(
    user_id: Optional[str] = None,
    academy_id: Optional[str] = None,
    group_id: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    user: dict = Depends(get_current_user),
):
    caller_user_id = user.get("user_id")
    if user_id:
        _ensure_friend_access_or_403(caller_user_id, user_id)
    data = repo.list_snapshots(user_id=user_id, academy_id=academy_id, group_id=group_id, limit=limit)
    if not user_id:
        data = [
            row
            for row in data
            if row.get("user_id") == caller_user_id or are_friends(caller_user_id, row.get("user_id"))
        ]
    return ApiResponse(data={"items": data})


@router.get("/snapshots/{snapshot_id}", response_model=ApiResponse)
def get_snapshot(snapshot_id: str, user: dict = Depends(get_current_user)):
    data = repo.get_snapshot(snapshot_id)
    if not data:
        raise HTTPException(status_code=404, detail="Snapshot not found")
    _ensure_friend_access_or_403(user.get("user_id"), data.get("user_id"))
    return ApiResponse(data=data)


@router.delete("/snapshots/{snapshot_id}", response_model=ApiResponse)
def delete_snapshot(snapshot_id: str, user: dict = Depends(get_current_user)):
    if user.get("role") not in ("teacher", "admin"):
        raise HTTPException(status_code=403, detail="Only teachers/admins can delete snapshots")
    deleted = repo.delete_snapshot(snapshot_id)
    return ApiResponse(success=deleted, message="Deleted" if deleted else "Not found")
