import base64
import hashlib
import hmac
import json
import os
import re
import sqlite3
import time
import uuid
from datetime import datetime
from typing import Optional

from storage.storage import DB_PATH

try:
    import jwt as pyjwt
except Exception:
    pyjwt = None

_HAS_PYJWT = bool(
    pyjwt
    and hasattr(pyjwt, "encode")
    and hasattr(pyjwt, "decode")
)

ALGORITHM = "HS256"
TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7

USERNAME_RE = re.compile(r"^[A-Za-z0-9]{4,16}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,20}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
NAME_RE = re.compile(r"^[가-힣A-Za-z0-9 ]{1,20}$")

SCHOOL_CATALOG = [
    "서울예빛중학교",
    "해솔중학교",
    "푸른숲중학교",
    "한강중학교",
    "별빛중학교",
    "도담고등학교",
    "새봄고등학교",
    "청솔고등학교",
    "동해고등학교",
    "미래고등학교",
]


def validate_username(username: str) -> Optional[str]:
    if not username or not USERNAME_RE.match(username.strip()):
        return "형식이 다릅니다"
    return None


def validate_password(password: str) -> Optional[str]:
    if not password or not PASSWORD_RE.match(password):
        return "형식이 다릅니다"
    return None


def validate_email(email: Optional[str]) -> Optional[str]:
    if email is None or not email.strip():
        return None
    if not EMAIL_RE.match(email.strip()):
        return "형식이 다릅니다"
    return None


def validate_name(name: str) -> Optional[str]:
    if not name or not NAME_RE.match(name.strip()):
        return "형식이 다릅니다"
    return None


def validate_school(school: str) -> Optional[str]:
    if not school or not school.strip():
        return "학교명을 입력해주세요"
    if school.strip() not in SCHOOL_CATALOG:
        return "서비스 대상 학교가 아닙니다"
    return None


def _get_secret() -> str:
    secret = os.environ.get("OMJ_JWT_SECRET")
    if secret:
        return secret
    return "dev-secret-change-me"


def create_token(user_id: str) -> str:
    payload = {
        "sub": user_id,
        "exp": int(time.time()) + TOKEN_TTL_SECONDS,
        "iat": int(time.time()),
    }
    if _HAS_PYJWT:
        return pyjwt.encode(payload, _get_secret(), algorithm=ALGORITHM)
    return _encode_fallback(payload, _get_secret())


def decode_token(token: str) -> Optional[str]:
    secret = _get_secret()
    if _HAS_PYJWT:
        try:
            payload = pyjwt.decode(token, secret, algorithms=[ALGORITHM])
        except Exception:
            return None
        return payload.get("sub")
    try:
        payload = _decode_fallback(token, secret)
    except Exception:
        return None
    return payload.get("sub")


def _encode_fallback(payload: dict, secret: str) -> str:
    header = {"alg": ALGORITHM, "typ": "JWT"}
    header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    signature = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    signature_b64 = _b64url_encode(signature)
    return f"{header_b64}.{payload_b64}.{signature_b64}"


def _decode_fallback(token: str, secret: str) -> dict:
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("invalid token")
    signing_input = f"{parts[0]}.{parts[1]}".encode("ascii")
    signature = _b64url_decode(parts[2])
    expected = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    if not hmac.compare_digest(signature, expected):
        raise ValueError("invalid signature")
    payload_json = _b64url_decode(parts[1]).decode("utf-8")
    payload = json.loads(payload_json)
    exp = payload.get("exp")
    if exp is not None and int(exp) < int(time.time()):
        raise ValueError("token expired")
    return payload


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


# ============
# User storage
# ============


def _ensure_user_table() -> None:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            grade TEXT NOT NULL,
            track TEXT,
            subject TEXT,
            school TEXT,
            profile_image TEXT,
            email TEXT,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """
    )

    # Add missing columns for existing DBs
    cur.execute("PRAGMA table_info(users)")
    cols = {row[1] for row in cur.fetchall()}
    if "name" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN name TEXT")
    if "grade" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN grade TEXT")
    if "track" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN track TEXT")
    if "subject" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN subject TEXT")
    if "school" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN school TEXT")
    if "profile_image" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN profile_image TEXT")
    conn.commit()
    conn.close()


def get_user_id_by_username(username: str) -> Optional[str]:
    """Return user_id for an existing username, or None."""
    username = username.strip()
    if not username:
        return None
    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT user_id FROM users WHERE username = ?", (username,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else None


def init_user_db() -> None:
    """Create user table if missing (idempotent)."""
    _ensure_user_table()


def _hash_password(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        120_000,
    ).hex()


def register_user(
    *,
    username: str,
    password: str,
    name: str,
    grade: str,
    track: Optional[str] = None,
    subject: Optional[str] = None,
    school: Optional[str] = None,
    profile_image: Optional[str] = None,
    email: Optional[str] = None,
) -> str:
    username = username.strip()
    name = name.strip()
    grade = grade.strip()
    track = (track or "").strip()
    subject = (subject or "").strip()
    school = (school or "").strip()
    profile_image = (profile_image or "").strip()
    if not username or not password or not name or not grade:
        raise ValueError("username, password, name, and grade are required")

    is_kakao = username.startswith("kakao:")
    if not is_kakao:
        error = validate_username(username)
        if error:
            raise ValueError(error)
        error = validate_password(password)
        if error:
            raise ValueError(error)
        error = validate_name(name)
        if error:
            raise ValueError(error)
    error = validate_email(email)
    if error:
        raise ValueError(error)
    if school:
        error = validate_school(school)
        if error:
            raise ValueError(error)

    _ensure_user_table()
    user_id = str(uuid.uuid4())
    salt = uuid.uuid4().hex
    password_hash = _hash_password(password, salt)
    created_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT INTO users (
                user_id,
                username,
                name,
                grade,
                track,
                subject,
                school,
                profile_image,
                email,
                password_hash,
                salt,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                username,
                name,
                grade,
                track or None,
                subject or None,
                school or None,
                profile_image or None,
                email,
                password_hash,
                salt,
                created_at,
            ),
        )
        conn.commit()
    except sqlite3.IntegrityError as exc:
        conn.rollback()
        # Unique username violation
        raise ValueError("username already exists") from exc
    finally:
        conn.close()

    return user_id


def authenticate_user(*, username: str, password: str) -> Optional[str]:
    username = username.strip()
    if not username or not password:
        return None

    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT user_id, password_hash, salt FROM users WHERE username = ?",
        (username,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    user_id, stored_hash, salt = row
    computed = _hash_password(password, salt)
    if hmac.compare_digest(stored_hash, computed):
        return user_id
    return None
