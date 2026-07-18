from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi import Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from auth import decode_token, resolve_token_payload_user
from fastapi import Response
from storage.study_group_storage import (
    add_group_exam,
    append_group_message,
    create_study_group,
    create_group_schedule,
    delete_group_notice_by_title,
    get_group,
    get_group_by_invite_code,
    get_group_topic,
    join_group,
    join_group_by_invite_code,
    list_member_ids,
    list_group_notices,
    list_group_exams,
    list_group_messages,
    list_active_group_schedules,
    list_groups_for_user,
    list_system_notices_for_user,
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
    upsert_group_notice,
)
from storage.social_storage import get_user_by_id
from storage.exam_storage import get_exam


study_group_router = APIRouter(prefix="/social/study-groups", tags=["study-groups"])
_security = HTTPBearer(auto_error=False)


def _get_auth_payload(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
) -> dict:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing token")
    token = credentials.credentials
    payload = decode_token(token)
    if not isinstance(payload, dict):
        raise HTTPException(status_code=401, detail="Invalid token")
    user = resolve_token_payload_user(payload)
    if not user["user_id"]:
        raise HTTPException(status_code=401, detail="Invalid token")
    return {"user_id": user["user_id"], "role": user["role"]}


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


class StudyGroupScheduleCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    scheduled_date: str = Field(min_length=10, max_length=10)
    scheduled_time: Optional[str] = Field(default=None, max_length=5)


class StudyGroupScheduleResponse(BaseModel):
    schedule_id: str
    group_id: str
    title: str
    scheduled_date: str
    scheduled_time: Optional[str] = None
    created_at: str


class StudyGroupScheduleListResponse(BaseModel):
    schedules: List[StudyGroupScheduleResponse]


class StudyGroupMessageResponse(BaseModel):
    message_id: str
    group_id: str
    user_id: str
    sender_name: str = ""
    text: str
    message_type: str = "text"
    payload: Optional[dict] = None
    created_at: str


class StudyGroupNoticeRequest(BaseModel):
    title: str = Field(min_length=1)
    content_html: str = Field(min_length=1)


class StudyGroupNoticeResponse(BaseModel):
    notice_id: str
    group_id: str
    title: str
    content_html: str
    created_by_user_id: str
    created_at: str
    updated_at: str
    group_name: Optional[str] = None


class StudyGroupNoticeListResponse(BaseModel):
    notices: List[StudyGroupNoticeResponse]


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


class StudyGroupSharedExam(BaseModel):
    share_id: str
    group_id: str
    user_id: str
    exam_id: str
    title: str
    sender_name: str
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


def _assert_group_owner(user_id: str, group_id: str) -> None:
    """필요 변수: 로그인 사용자 ID와 그룹 ID다.

    작동 원리: 멤버 역할이 아닌 생성자 ID를 그룹 원장과 직접 비교해, 그룹장만
    일정을 추가할 수 있게 한다. 관리자 계정도 임의 그룹의 일정을 만들 수 없다.
    """
    group = get_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="group not found")
    if str(group.get("creator_id") or "") != user_id:
        raise HTTPException(status_code=403, detail="Only the group owner can create schedules")


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


def _assert_notice_manager(auth_payload: dict, group_id: str) -> dict:
    user_id = str(auth_payload["user_id"])
    _assert_group_member(user_id, group_id)
    group = get_group(group_id)
    if not group:
        raise HTTPException(status_code=404, detail="group not found")
    if str(group.get("owner_role") or "student").lower() != "teacher":
        raise HTTPException(status_code=400, detail="system notices are only available for teacher groups")
    if not _is_teacher_role(auth_payload):
        raise HTTPException(status_code=403, detail="Only teachers/admins can manage system notices")
    return group


@study_group_router.get(
    "/notices/my/system",
    response_model=StudyGroupNoticeListResponse,
)
def list_my_system_notices_handler(
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(_get_user_id),
) -> StudyGroupNoticeListResponse:
    items = list_system_notices_for_user(user_id, limit=limit)
    return StudyGroupNoticeListResponse(
        notices=[StudyGroupNoticeResponse(**item) for item in items]
    )


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
    """본인 소유 시험지만 공유하고, 답안 없이 채팅용 카드 메시지를 함께 생성한다."""
    _assert_group_member(user_id, group_id)
    exam_id = payload.exam_id.strip()
    exam = get_exam(exam_id)
    if not exam or str(exam.get("user_id") or "") != user_id:
        raise HTTPException(status_code=403, detail="Only your own exam can be shared")
    params = exam.get("params") if isinstance(exam.get("params"), dict) else {}
    title = str(params.get("title") or "내 시험지").strip() or "내 시험지"
    profile = get_user_by_id(user_id) or {}
    sender_name = str(profile.get("name") or profile.get("username") or "알 수 없음")
    shared = share_group_exam(
        group_id,
        user_id,
        exam_id=exam_id,
        seed=0,
        title=title,
        sender_name=sender_name,
    )
    append_group_message(
        group_id=group_id,
        user_id=user_id,
        text="시험지를 공유했어요.",
        message_type="shared_exam",
        payload_json=json.dumps(
            {
                "share_id": shared["share_id"],
                "exam_id": exam_id,
                "title": title,
                "sender_name": sender_name,
                "created_at": shared["created_at"],
            },
            ensure_ascii=False,
        ),
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
    "/{group_id}/notices",
    response_model=StudyGroupNoticeListResponse,
)
def list_group_notices_handler(
    group_id: str,
    limit: int = Query(20, ge=1, le=100),
    user_id: str = Depends(_get_user_id),
) -> StudyGroupNoticeListResponse:
    _assert_group_member(user_id, group_id)
    items = list_group_notices(group_id, limit=limit)
    return StudyGroupNoticeListResponse(
        notices=[StudyGroupNoticeResponse(**item) for item in items]
    )


@study_group_router.put(
    "/{group_id}/notices",
    response_model=StudyGroupNoticeResponse,
)
def upsert_group_notice_handler(
    group_id: str,
    payload: StudyGroupNoticeRequest,
    auth_payload: dict = Depends(_get_auth_payload),
) -> StudyGroupNoticeResponse:
    _assert_notice_manager(auth_payload, group_id)
    try:
        item = upsert_group_notice(
            group_id,
            title=payload.title,
            content_html=payload.content_html,
            created_by_user_id=str(auth_payload["user_id"]),
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupNoticeResponse(**item)


@study_group_router.delete(
    "/{group_id}/notices",
    status_code=204,
)
def delete_group_notice_handler(
    group_id: str,
    title: str = Query(..., min_length=1),
    auth_payload: dict = Depends(_get_auth_payload),
):
    _assert_notice_manager(auth_payload, group_id)
    try:
        deleted = delete_group_notice_by_title(group_id, title)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if not deleted:
        raise HTTPException(status_code=404, detail="notice not found")
    return Response(status_code=204)


@study_group_router.get(
    "/{group_id}/schedules",
    response_model=StudyGroupScheduleListResponse,
)
def list_group_schedules_handler(
    group_id: str,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupScheduleListResponse:
    """필요 변수: 그룹 ID와 로그인 사용자 ID다.

    작동 원리: 멤버 여부를 확인한 후 저장소의 만료 정리를 거친 당일·미래 일정만
    반환한다. 응답에는 과거 일정이 절대 포함되지 않는다.
    """
    _assert_group_member(user_id, group_id)
    return StudyGroupScheduleListResponse(
        schedules=[
            StudyGroupScheduleResponse(**item)
            for item in list_active_group_schedules(group_id)
        ]
    )


@study_group_router.post(
    "/{group_id}/schedules",
    response_model=StudyGroupScheduleResponse,
    status_code=201,
)
def create_group_schedule_handler(
    group_id: str,
    payload: StudyGroupScheduleCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupScheduleResponse:
    """필요 변수: 그룹 ID, 일정 입력값과 로그인 사용자 ID다.

    작동 원리: 그룹 생성자만 통과시키고 날짜 검증·만료 정책은 저장소에 위임한다.
    클라이언트의 버튼 노출과 무관하게 서버가 최종 권한을 보장한다.
    """
    _assert_group_owner(user_id, group_id)
    try:
        item = create_group_schedule(
            group_id=group_id,
            title=payload.title,
            scheduled_date=payload.scheduled_date,
            scheduled_time=payload.scheduled_time,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupScheduleResponse(**item)


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
    profile_cache = {}
    mapped = []
    for msg in messages:
        user_id = msg["user_id"]
        profile = profile_cache.setdefault(user_id, get_user_by_id(user_id) or {})
        mapped.append(
            StudyGroupMessageResponse(
                message_id=msg["message_id"],
                group_id=msg["group_id"],
                user_id=user_id,
                sender_name=str(
                    profile.get("name") or profile.get("username") or user_id
                ),
                text=msg["text"],
                message_type=str(msg.get("message_type") or "text"),
                payload=json.loads(msg["payload"]) if msg.get("payload") else None,
                created_at=msg["created_at"],
            )
        )
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
    profile = get_user_by_id(message["user_id"]) or {}
    return StudyGroupMessageResponse(
        **message,
        sender_name=str(profile.get("name") or profile.get("username") or message["user_id"]),
    )


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
