from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi import Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from auth import decode_token
from fastapi import Response
from storage.study_group_storage import (
    add_group_exam,
    append_group_message,
    create_study_group,
    get_group_by_invite_code,
    get_group_topic,
    join_group,
    join_group_by_invite_code,
    list_member_ids,
    list_group_exams,
    list_group_messages,
    list_groups_for_user,
    list_shared_group_exams,
    list_shared_group_problems,
    list_shared_group_flows,
    get_shared_flow,
    share_group_exam,
    share_group_problem,
    share_group_flow,
    delete_shared_flow,
    search_study_groups,
    set_group_topic,
)
from storage.social_storage import get_user_by_id


study_group_router = APIRouter(prefix="/social/study-groups", tags=["study-groups"])
_security = HTTPBearer(auto_error=False)


def _get_auth_payload(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
) -> dict:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing token")
    token = credentials.credentials
    payload = decode_token(token)
    if isinstance(payload, dict):
        user_id = payload.get("user_id") or payload.get("sub")
        role = str(payload.get("role") or "student").strip().lower()
    else:
        user_id = payload
        role = "student"
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    return {"user_id": str(user_id), "role": role}


def _get_user_id(auth_payload: dict = Depends(_get_auth_payload)) -> str:
    return str(auth_payload["user_id"])


def _is_teacher_role(auth_payload: dict) -> bool:
    return str(auth_payload.get("role") or "").lower() in {"teacher", "admin"}


class StudyGroupCreateRequest(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    max_members: int = Field(ge=1)
    is_public: bool = True
    logo_index: Optional[int] = None
    lock_enabled: bool = False
    password: Optional[str] = None
    invite_code: Optional[str] = None
    member_ids: List[str] = Field(default_factory=list)


class StudyGroupResponse(BaseModel):
    group_id: str
    name: str
    description: str
    max_members: int
    is_public: bool
    logo_index: Optional[int] = None
    lock_enabled: bool
    owner_role: str = "student"
    invite_code: Optional[str] = None
    is_teacher_group: bool = False
    created_at: str
    creator_id: str
    member_ids: List[str]


class StudyGroupListItem(StudyGroupResponse):
    members: int = 0


class StudyGroupListResponse(BaseModel):
    groups: List[StudyGroupListItem]


class StudyGroupJoinRequest(BaseModel):
    password: Optional[str] = None


class StudyGroupMessageRequest(BaseModel):
    text: str = Field(min_length=1)


class StudyGroupMessageResponse(BaseModel):
    message_id: str
    group_id: str
    user_id: str
    text: str
    created_at: str


class SharedFlowRequest(BaseModel):
    codebase_id: int
    seed: int
    quest_id: Optional[str] = None
    quest_title: Optional[str] = None
    status_json: str
    all_formulas: str = ""
    answer_riddle: str = ""
    tags: Optional[List[str]] = None
    difficulty: Optional[int] = None


class SharedFlowItem(BaseModel):
    share_id: str
    group_id: str
    user_id: str
    codebase_id: int
    seed: int
    quest_id: str
    quest_title: str
    status_json: str
    all_formulas: str
    answer_riddle: str
    tags: List[str] = Field(default_factory=list)
    difficulty: Optional[int] = None
    created_at: str


class StudyGroupMessagesResponse(BaseModel):
    messages: List[StudyGroupMessageResponse]


class StudyGroupTopicRequest(BaseModel):
    topic: str = Field(min_length=1)


class StudyGroupTopicResponse(BaseModel):
    group_id: str
    topic: str
    updated_at: str


class StudyGroupExamRequest(BaseModel):
    exam_id: str = Field(min_length=1)
    title: Optional[str] = None


class StudyGroupExamResponse(BaseModel):
    group_id: str
    exam_id: str
    title: Optional[str] = None
    created_at: str


class StudyGroupExamListResponse(BaseModel):
    exams: List[StudyGroupExamResponse]


class StudyGroupSharedProblemRequest(BaseModel):
    codebase_id: int = Field(ge=1)
    seed: int


class StudyGroupSharedProblem(BaseModel):
    share_id: str
    group_id: str
    user_id: str
    codebase_id: int
    seed: int
    created_at: str


class StudyGroupSharedProblemListResponse(BaseModel):
    items: List[StudyGroupSharedProblem]


class StudyGroupSharedExamRequest(BaseModel):
    exam_id: str = Field(min_length=1)
    seed: int


class StudyGroupSharedExam(BaseModel):
    share_id: str
    group_id: str
    user_id: str
    exam_id: str
    seed: int
    created_at: str


class StudyGroupSharedExamListResponse(BaseModel):
    items: List[StudyGroupSharedExam]


class StudyGroupSearchItem(BaseModel):
    group_id: str
    name: str
    description: str
    max_members: int
    members: int
    is_public: bool
    logo_index: Optional[int] = None
    lock_enabled: bool
    owner_role: str = "student"
    is_teacher_group: bool = False


class StudyGroupSearchResponse(BaseModel):
    groups: List[StudyGroupSearchItem]


class StudyGroupInviteMetaResponse(BaseModel):
    group_id: str
    name: str
    description: str
    max_members: int
    members: int
    lock_enabled: bool
    owner_role: str = "teacher"
    is_teacher_group: bool = True
    invite_code: str


class StudyGroupJoinByCodeRequest(BaseModel):
    invite_code: str = Field(min_length=1)
    password: Optional[str] = None


def _to_group_response(group: dict) -> StudyGroupResponse:
    owner_role = str(group.get("owner_role") or "student")
    return StudyGroupResponse(
        group_id=group["group_id"],
        name=group["name"],
        description=group["description"],
        max_members=group["max_members"],
        is_public=group["is_public"],
        logo_index=group.get("logo_index"),
        lock_enabled=group["lock_enabled"],
        owner_role=owner_role,
        invite_code=group.get("invite_code"),
        is_teacher_group=owner_role == "teacher",
        created_at=group["created_at"],
        creator_id=group["creator_id"],
        member_ids=group.get("member_ids", []),
    )


@study_group_router.post("", response_model=StudyGroupResponse, status_code=201)
def create_study_group_handler(
    payload: StudyGroupCreateRequest,
    auth_payload: dict = Depends(_get_auth_payload),
) -> StudyGroupResponse:
    user_id = str(auth_payload["user_id"])
    is_teacher = _is_teacher_role(auth_payload)
    try:
        group = create_study_group(
            name=payload.name,
            description=payload.description,
            max_members=payload.max_members,
            is_public=False if is_teacher else payload.is_public,
            creator_id=user_id,
            logo_index=payload.logo_index,
            lock_enabled=payload.lock_enabled,
            password=payload.password,
            owner_role="teacher" if is_teacher else "student",
            invite_code=payload.invite_code,
            member_ids=payload.member_ids,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return _to_group_response(group)


@study_group_router.get("/mine", response_model=StudyGroupListResponse)
def list_my_study_groups(
    user_id: str = Depends(_get_user_id),
) -> StudyGroupListResponse:
    groups = list_groups_for_user(user_id)
    items = [
        StudyGroupListItem(
            group_id=g["group_id"],
            name=g["name"],
            description=g["description"],
            max_members=g["max_members"],
            is_public=g["is_public"],
            logo_index=g.get("logo_index"),
            lock_enabled=g["lock_enabled"],
            owner_role=g.get("owner_role") or "student",
            invite_code=g.get("invite_code"),
            is_teacher_group=(g.get("owner_role") or "student") == "teacher",
            created_at=g["created_at"],
            creator_id=g["creator_id"],
            member_ids=g.get("member_ids", []),
            members=g.get("members", len(g.get("member_ids", []))),
        )
        for g in groups
    ]
    return StudyGroupListResponse(groups=items)


class StudyGroupMember(BaseModel):
    user_id: str
    username: str


@study_group_router.get(
    "/{group_id}/members",
    response_model=List[StudyGroupMember],
)
def list_group_members_handler(
    group_id: str,
    user_id: str = Depends(_get_user_id),
) -> List[StudyGroupMember]:
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")
    members = []
    for mid in list_member_ids(group_id):
        profile = get_user_by_id(mid) or {}
        username = (profile.get("username") or profile.get("name") or mid) if isinstance(profile, dict) else mid
        members.append(StudyGroupMember(user_id=mid, username=str(username)))
    return members


@study_group_router.get("/search", response_model=StudyGroupSearchResponse)
def search_study_groups_handler(
    q: str = Query(..., min_length=1, description="Study group name keyword"),
    limit: int = Query(20, ge=1, le=50),
    user_id: str = Depends(_get_user_id),
) -> StudyGroupSearchResponse:
    results = search_study_groups(keyword=q, limit=limit, exclude_user_id=user_id)
    items = [
        StudyGroupSearchItem(
            group_id=g["group_id"],
            name=g["name"],
            description=g["description"],
            max_members=g["max_members"],
            members=g.get("members", len(g.get("member_ids", []))),
            is_public=g["is_public"],
            logo_index=g.get("logo_index"),
            lock_enabled=g["lock_enabled"],
            owner_role=g.get("owner_role") or "student",
            is_teacher_group=(g.get("owner_role") or "student") == "teacher",
        )
        for g in results
    ]
    return StudyGroupSearchResponse(groups=items)


@study_group_router.get(
    "/invite/{invite_code}",
    response_model=StudyGroupInviteMetaResponse,
)
def get_study_group_invite_handler(invite_code: str) -> StudyGroupInviteMetaResponse:
    group = get_group_by_invite_code(invite_code)
    if not group:
        raise HTTPException(status_code=404, detail="invite code not found")
    owner_role = str(group.get("owner_role") or "student")
    if owner_role != "teacher":
        raise HTTPException(status_code=404, detail="invite code not found")
    member_ids = group.get("member_ids", [])
    return StudyGroupInviteMetaResponse(
        group_id=group["group_id"],
        name=group["name"],
        description=group["description"],
        max_members=group["max_members"],
        members=len(member_ids),
        lock_enabled=group["lock_enabled"],
        owner_role=owner_role,
        is_teacher_group=True,
        invite_code=str(group.get("invite_code") or "").upper(),
    )


@study_group_router.post(
    "/join-by-code",
    response_model=StudyGroupResponse,
    status_code=200,
)
def join_study_group_by_code_handler(
    payload: StudyGroupJoinByCodeRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupResponse:
    try:
        group = join_group_by_invite_code(
            user_id,
            payload.invite_code,
            payload.password,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return _to_group_response(group)


def _assert_group_member(user_id: str, group_id: str) -> None:
    # Ensure only members can read/write group resources.
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")


@study_group_router.get(
    "/{group_id}/shared-problems",
    response_model=StudyGroupSharedProblemListResponse,
)
def list_shared_problems_handler(
    group_id: str,
    limit: int = Query(30, ge=1, le=30),
    user_id: str = Depends(_get_user_id),
) -> StudyGroupSharedProblemListResponse:
    _assert_group_member(user_id, group_id)
    items = list_shared_group_problems(group_id, limit=limit)
    return StudyGroupSharedProblemListResponse(
        items=[StudyGroupSharedProblem(**item) for item in items]
    )


@study_group_router.post(
    "/{group_id}/shared-problems",
    response_model=StudyGroupSharedProblem,
    status_code=201,
)
def share_problem_handler(
    group_id: str,
    payload: StudyGroupSharedProblemRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupSharedProblem:
    _assert_group_member(user_id, group_id)
    shared = share_group_problem(
        group_id,
        user_id,
        codebase_id=payload.codebase_id,
        seed=payload.seed,
    )
    return StudyGroupSharedProblem(**shared)


@study_group_router.get(
    "/{group_id}/shared-flows",
    response_model=List[SharedFlowItem],
)
def list_shared_flows_handler(
    group_id: str,
    limit: int = Query(30, ge=1, le=50),
    tags: Optional[str] = Query(None, description="comma separated tags"),
    user_id_filter: Optional[str] = Query(
        None, description="filter by user_id of sharer"
    ),
    date_from: Optional[str] = Query(None),
    date_to: Optional[str] = Query(None),
    user_id: str = Depends(_get_user_id),
):
    _assert_group_member(user_id, group_id)
    tag_list = (
        [t.strip() for t in tags.split(",") if t.strip()] if tags else None
    )
    items = list_shared_group_flows(
        group_id,
        limit=limit,
        tags=tag_list,
        user_id=user_id_filter,
        date_from=date_from,
        date_to=date_to,
    )
    mapped: List[SharedFlowItem] = []
    for item in items:
        profile = get_user_by_id(item.get("user_id", "")) or {}
        username = profile.get("username") or profile.get("name") or item.get("user_id", "")
        item["user_id"] = str(username)
        mapped.append(SharedFlowItem(**item))
    return mapped


@study_group_router.post(
    "/{group_id}/shared-flows",
    response_model=SharedFlowItem,
    status_code=201,
)
def share_flow_handler(
    group_id: str,
    payload: SharedFlowRequest,
    user_id: str = Depends(_get_user_id),
):
    _assert_group_member(user_id, group_id)
    shared = share_group_flow(
        group_id=group_id,
        user_id=user_id,
        codebase_id=payload.codebase_id,
        seed=payload.seed,
        quest_id=payload.quest_id,
        quest_title=payload.quest_title,
        status_json=payload.status_json,
        all_formulas=payload.all_formulas,
        answer_riddle=payload.answer_riddle,
        tags=",".join(payload.tags) if payload.tags else "",
        difficulty=payload.difficulty,
    )
    # 그룹 문제풀기 목록에도 등재
    try:
        share_group_problem(
            group_id,
            user_id,
            codebase_id=payload.codebase_id,
            seed=payload.seed,
        )
    except Exception:
        # 실패해도 플로우 공유는 유지
        pass
    append_group_message(
        group_id=group_id,
        user_id=user_id,
        text=f"사용자가 질문을 했어요 (함께보기) FLOW_SHARE:{shared['share_id']}",
    )
    return SharedFlowItem(**shared)


@study_group_router.get(
    "/shared-flows/{share_id}",
    response_model=SharedFlowItem,
)
def get_shared_flow_handler(
    share_id: str,
    user_id: str = Depends(_get_user_id),
):
    shared = get_shared_flow(share_id)
    if not shared:
        raise HTTPException(status_code=404, detail="shared flow not found")
    _assert_group_member(user_id, shared["group_id"])
    return SharedFlowItem(**shared)


@study_group_router.delete(
    "/shared-flows/{share_id}",
    status_code=204,
)
def delete_shared_flow_handler(
    share_id: str,
    user_id: str = Depends(_get_user_id),
):
    ok = delete_shared_flow(share_id, user_id=user_id)
    if not ok:
        raise HTTPException(status_code=403, detail="not allowed")
    return {}


@study_group_router.get(
    "/{group_id}/shared-exams",
    response_model=StudyGroupSharedExamListResponse,
)
def list_shared_exams_handler(
    group_id: str,
    limit: int = Query(5, ge=1, le=50),
    user_id: str = Depends(_get_user_id),
) -> StudyGroupSharedExamListResponse:
    _assert_group_member(user_id, group_id)
    items = list_shared_group_exams(group_id, limit=limit)
    return StudyGroupSharedExamListResponse(
        items=[StudyGroupSharedExam(**item) for item in items]
    )


@study_group_router.post(
    "/{group_id}/shared-exams",
    response_model=StudyGroupSharedExam,
    status_code=201,
)
def share_exam_handler(
    group_id: str,
    payload: StudyGroupSharedExamRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupSharedExam:
    _assert_group_member(user_id, group_id)
    shared = share_group_exam(
        group_id,
        user_id,
        exam_id=payload.exam_id,
        seed=payload.seed,
    )
    return StudyGroupSharedExam(**shared)


@study_group_router.post(
    "/{group_id}/join",
    response_model=StudyGroupResponse,
    status_code=200,
)
def join_study_group_handler(
    group_id: str,
    payload: StudyGroupJoinRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupResponse:
    try:
        group = join_group(group_id, user_id, payload.password)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return _to_group_response(group)


@study_group_router.get(
    "/{group_id}/messages",
    response_model=StudyGroupMessagesResponse,
)
def list_group_messages_handler(
    group_id: str,
    limit: int = 50,
    before: Optional[str] = None,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupMessagesResponse:
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")
    messages = list_group_messages(group_id=group_id, limit=limit, before=before)
    mapped = [
        StudyGroupMessageResponse(
            message_id=msg["message_id"],
            group_id=msg["group_id"],
            user_id=msg["user_id"],
            text=msg["text"],
            created_at=msg["created_at"],
        )
        for msg in messages
    ]
    return StudyGroupMessagesResponse(messages=mapped)


@study_group_router.post(
    "/{group_id}/messages",
    response_model=StudyGroupMessageResponse,
    status_code=201,
)
def post_group_message_handler(
    group_id: str,
    payload: StudyGroupMessageRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupMessageResponse:
    try:
        message = append_group_message(
            group_id=group_id,
            user_id=user_id,
            text=payload.text,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupMessageResponse(**message)


@study_group_router.put(
    "/{group_id}/topic",
    response_model=StudyGroupTopicResponse,
)
def update_group_topic_handler(
    group_id: str,
    payload: StudyGroupTopicRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupTopicResponse:
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")
    try:
        topic = set_group_topic(group_id, payload.topic)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupTopicResponse(**topic)


@study_group_router.get(
    "/{group_id}/topic",
    response_model=StudyGroupTopicResponse,
)
def get_group_topic_handler(
    group_id: str,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupTopicResponse:
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")
    topic = get_group_topic(group_id)
    if not topic:
        return StudyGroupTopicResponse(
            group_id=group_id,
            topic="",
            updated_at=datetime.utcnow().isoformat(),
        )
    return StudyGroupTopicResponse(**topic)


@study_group_router.get(
    "/{group_id}/exams",
    response_model=StudyGroupExamListResponse,
)
def list_group_exams_handler(
    group_id: str,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupExamListResponse:
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")
    exams = list_group_exams(group_id)
    return StudyGroupExamListResponse(
        exams=[
            StudyGroupExamResponse(
                group_id=group_id,
                exam_id=item["exam_id"],
                title=item.get("title"),
                created_at=item["created_at"],
            )
            for item in exams
        ]
    )


@study_group_router.post(
    "/{group_id}/exams",
    response_model=StudyGroupExamResponse,
    status_code=201,
)
def add_group_exam_handler(
    group_id: str,
    payload: StudyGroupExamRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupExamResponse:
    member_group_ids = {g["group_id"] for g in list_groups_for_user(user_id)}
    if group_id not in member_group_ids:
        raise HTTPException(status_code=403, detail="Not a member of the group")
    try:
        exam = add_group_exam(group_id, payload.exam_id, payload.title)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupExamResponse(**exam)
