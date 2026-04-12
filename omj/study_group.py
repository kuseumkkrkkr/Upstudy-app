from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from auth import decode_token
from storage.study_group_storage import (
    add_group_exam,
    append_group_message,
    create_study_group,
    get_group_topic,
    join_group,
    list_group_exams,
    list_group_messages,
    list_groups_for_user,
    set_group_topic,
)


study_group_router = APIRouter(prefix="/social/study-groups", tags=["study-groups"])
_security = HTTPBearer()


def _get_user_id(credentials: HTTPAuthorizationCredentials = Depends(_security)) -> str:
    token = credentials.credentials
    payload = decode_token(token)
    if isinstance(payload, dict):
        user_id = payload.get("user_id")
    else:
        # Some deployments return user_id string directly
        user_id = payload
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    return str(user_id)


class StudyGroupCreateRequest(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    max_members: int = Field(ge=1)
    is_public: bool = True
    logo_index: Optional[int] = None
    lock_enabled: bool = False
    password: Optional[str] = None
    member_ids: List[str] = Field(default_factory=list)


class StudyGroupResponse(BaseModel):
    group_id: str
    name: str
    description: str
    max_members: int
    is_public: bool
    logo_index: Optional[int] = None
    lock_enabled: bool
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


@study_group_router.post("", response_model=StudyGroupResponse, status_code=201)
def create_study_group_handler(
    payload: StudyGroupCreateRequest,
    user_id: str = Depends(_get_user_id),
) -> StudyGroupResponse:
    try:
        group = create_study_group(
            name=payload.name,
            description=payload.description,
            max_members=payload.max_members,
            is_public=payload.is_public,
            creator_id=user_id,
            logo_index=payload.logo_index,
            lock_enabled=payload.lock_enabled,
            password=payload.password,
            member_ids=payload.member_ids,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return StudyGroupResponse(**group)


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
            created_at=g["created_at"],
            creator_id=g["creator_id"],
            member_ids=g.get("member_ids", []),
            members=g.get("members", len(g.get("member_ids", []))),
        )
        for g in groups
    ]
    return StudyGroupListResponse(groups=items)


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
    return StudyGroupResponse(**group)


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
