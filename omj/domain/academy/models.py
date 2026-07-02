"""Pydantic models for the Academy domain.

Covers:
- Academy            (학원/기관)
- AcademyGroup     (반/그룹)
- AcademyGroupMember (반 소속 학생/교사)
- AttendanceLog    (출결 기록)
- TuitionPayment   (수납/납부)
- FinanceLedger    (장부/회계)
- ParentConsultNote (학부모 상담 노트)
- StudentOverviewSnapshot (학생 종합 스냅샷)
- MemberEventLog   (입퇴장 이벤트 로그)
- GroupAssignment  (그룹 과제)
- GroupSubmission  (그룹 제출)
- SubmissionReport (제출 리포트)
- TimetablePreference (시간표 선호도)
- TimetablePlan    (시간표 계획)
"""
from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, ConfigDict, Field


class Academy(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    academy_id: str = Field(..., description="UUID primary key")
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None
    admin_user_id: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class AcademyGroup(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    group_id: str = Field(..., description="UUID primary key")
    academy_id: str
    name: str
    grade: Optional[str] = None
    subject: Optional[str] = None
    teacher_user_id: Optional[str] = None
    group_type: str = Field(default="academy_tutoring_group", description="academy_tutoring_group | social_study_group")
    searchable: bool = Field(default=False, description="Whether this group appears in public search")
    friend_verification_required: bool = Field(default=True, description="Require active friendship for invitation")
    max_members: int = Field(default=20, ge=1, le=100)
    style_border_color: Optional[str] = None
    style_badge_text: Optional[str] = None
    schedule_json: Optional[str] = None
    timetable_plan_json: Optional[str] = None
    timetable_version: Optional[str] = None
    timetable_generated_at: Optional[datetime] = None
    created_at: Optional[datetime] = None


class AcademyGroupMember(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    member_id: str = Field(..., description="UUID primary key")
    group_id: str
    user_id: str
    role: str = Field(default="student", description="student | teacher")
    joined_at: Optional[datetime] = None
    removed_at: Optional[datetime] = None
    status: str = Field(default="active", description="active | removed | pending")


class MemberEventLog(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    event_id: str = Field(..., description="UUID primary key")
    group_id: str
    user_id: str
    event_type: str = Field(..., description="joined | removed | invited | rejected_invite | left")
    triggered_by_user_id: Optional[str] = None
    reason: Optional[str] = None
    created_at: Optional[datetime] = None


class AttendanceLog(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    log_id: str = Field(..., description="UUID primary key")
    group_id: str
    user_id: str
    date: str = Field(..., description="ISO date YYYY-MM-DD")
    status: str = Field(..., description="present | late | absent")
    checked_by_user_id: Optional[str] = None
    checked_at: Optional[datetime] = None
    note: Optional[str] = None


class TuitionPayment(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    payment_id: str = Field(..., description="UUID primary key")
    academy_id: str
    user_id: str
    amount: int = Field(..., ge=0)
    month_label: str = Field(..., description="YYYY-MM")
    method: Optional[str] = None
    paid_at: Optional[datetime] = None
    receipt_url: Optional[str] = None
    memo: Optional[str] = None


class FinanceLedger(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    ledger_id: str = Field(..., description="UUID primary key")
    academy_id: str
    category: str = Field(..., description="income | expense")
    amount: int = Field(..., ge=0)
    description: Optional[str] = None
    transaction_date: str = Field(..., description="ISO date YYYY-MM-DD")
    recorded_by_user_id: Optional[str] = None
    created_at: Optional[datetime] = None


class ParentConsultNote(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    note_id: str = Field(..., description="UUID primary key")
    academy_id: str
    student_user_id: str
    parent_name: Optional[str] = None
    parent_contact: Optional[str] = None
    topic: Optional[str] = None
    content: Optional[str] = None
    consulted_by_user_id: Optional[str] = None
    consulted_at: Optional[datetime] = None
    follow_up_date: Optional[str] = None


class GroupAssignment(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    assignment_id: str = Field(..., description="UUID primary key")
    group_id: str
    sender_user_id: str
    kind: str = Field(..., description="exam | problem | course")
    ref_id: str = Field(..., description="exam_id | quest_id | course_id")
    title: Optional[str] = None
    message: Optional[str] = None
    due_date: Optional[str] = None
    created_at: Optional[datetime] = None


class GroupSubmission(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    submission_id: str = Field(..., description="UUID primary key")
    assignment_id: str
    user_id: str
    status: str = Field(default="pending", description="pending | submitted | late")
    submitted_at: Optional[datetime] = None
    data_json: Optional[str] = None


class SubmissionReport(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    report_id: str = Field(..., description="UUID primary key")
    submission_id: str
    correct_rate: Optional[float] = None
    time_spent_seconds: Optional[int] = None
    weak_tags_json: Optional[str] = None
    feedback: Optional[str] = None
    created_at: Optional[datetime] = None


class TimetablePreference(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    preference_id: str = Field(..., description="UUID primary key")
    group_id: str
    user_id: str
    day_of_week: str = Field(..., description="mon | tue | wed | thu | fri | sat | sun")
    time_slot: str = Field(..., description="HH:MM-HH:MM")
    priority: int = Field(default=1, ge=1, le=5)
    created_at: Optional[datetime] = None


class TimetablePlan(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    plan_id: str = Field(..., description="UUID primary key")
    group_id: str
    plan_json: str
    version: str = Field(default="v1")
    generated_at: Optional[datetime] = None
    applied: bool = Field(default=False)


class StudentOverviewSnapshot(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    snapshot_id: str = Field(..., description="UUID primary key")
    user_id: str
    academy_id: str
    group_id: Optional[str] = None
    overall_score: Optional[float] = None
    attendance_rate: Optional[float] = None
    tuition_status: Optional[str] = None
    last_consult_note_id: Optional[str] = None
    summary_json: Optional[str] = None
    created_at: Optional[datetime] = None
