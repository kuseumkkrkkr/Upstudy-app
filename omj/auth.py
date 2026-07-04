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
from typing import List, Optional

from storage.storage import DB_PATH
from env_loader import load_env

load_env()

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
    return "dev-secret-change-me-use-omj-jwt-secret-in-production"


def create_token(user_id: str, role: Optional[str] = None) -> str:
    payload = {
        "sub": user_id,
        "exp": int(time.time()) + TOKEN_TTL_SECONDS,
        "iat": int(time.time()),
    }
    if role:
        payload["role"] = role
    if _HAS_PYJWT:
        return pyjwt.encode(payload, _get_secret(), algorithm=ALGORITHM)
    return _encode_fallback(payload, _get_secret())


def decode_token(token: str) -> Optional[dict]:
    secret = _get_secret()
    if _HAS_PYJWT:
        try:
            payload = pyjwt.decode(token, secret, algorithms=[ALGORITHM])
        except Exception:
            return None
        return payload
    try:
        payload = _decode_fallback(token, secret)
    except Exception:
        return None
    return payload


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
            ovr INTEGER DEFAULT 0,
            status TEXT DEFAULT '',
            role TEXT DEFAULT 'student',
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
    if "ovr" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN ovr INTEGER DEFAULT 0")
    if "status" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN status TEXT DEFAULT ''")
    if "role" not in cols:
        cur.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'student'")
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


def register_teacher(
    *,
    email: str,
    password: str,
    name: str,
) -> str:
    """Register a new teacher account. Email is used as the username."""
    email = email.strip().lower()
    name = name.strip()
    if not email or not password or not name:
        raise ValueError("email, password, and name are required")

    error = validate_email(email)
    if error:
        raise ValueError(error)
    # Teachers use email as username; relax password rules slightly
    if len(password) < 6:
        raise ValueError("password must be at least 6 characters")

    _ensure_user_table()
    promoted_user = _promote_existing_teacher_account(
        email=email,
        password=password,
        name=name,
    )
    if promoted_user:
        return promoted_user["user_id"]

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
                role,
                password_hash,
                salt,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                email,           # username = email
                name,
                "teacher",       # grade placeholder
                None,
                None,
                None,
                None,
                email,
                "teacher",
                password_hash,
                salt,
                created_at,
            ),
        )
        conn.commit()
    except sqlite3.IntegrityError as exc:
        conn.rollback()
        raise ValueError("email already registered") from exc
    finally:
        conn.close()

    return user_id


def _looks_like_teacher_account(username: str, email: Optional[str], grade: Optional[str]) -> bool:
    normalized_username = (username or "").strip().lower()
    normalized_email = (email or "").strip().lower()
    normalized_grade = (grade or "").strip().lower()
    if not EMAIL_RE.match(normalized_username):
        return False
    return normalized_grade == "teacher" or normalized_email == normalized_username


def _promote_existing_teacher_account(
    *,
    email: str,
    password: str,
    name: Optional[str] = None,
) -> Optional[dict]:
    email = email.strip().lower()
    if not email or not password:
        return None

    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT user_id, username, name, grade, email, role, password_hash, salt
        FROM users
        WHERE username = ?
        """,
        (email,),
    )
    row = cur.fetchone()
    if not row:
        conn.close()
        return None

    user_id, username, stored_name, grade, stored_email, role, stored_hash, salt = row
    computed = _hash_password(password, salt)
    if not hmac.compare_digest(stored_hash, computed):
        conn.close()
        return None

    if str(role or "").strip().lower() == "teacher":
        conn.close()
        return {
            "user_id": user_id,
            "username": username,
            "name": stored_name,
            "role": "teacher",
        }

    if not _looks_like_teacher_account(username, stored_email, grade):
        conn.close()
        return None

    update_name = (name or stored_name or "").strip()
    cur.execute(
        """
        UPDATE users
        SET role = 'teacher',
            grade = 'teacher',
            email = ?,
            name = COALESCE(NULLIF(?, ''), name)
        WHERE user_id = ?
        """,
        (email, update_name, user_id),
    )
    conn.commit()
    conn.close()
    return {
        "user_id": user_id,
        "username": username,
        "name": update_name or stored_name,
        "role": "teacher",
    }


def authenticate_teacher(*, email: str, password: str) -> Optional[dict]:
    """Authenticate a teacher by email/password. Returns dict with user_id, username, name, role or None."""
    email = email.strip().lower()
    if not email or not password:
        return None

    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT user_id, username, name, grade, email, role, password_hash, salt
        FROM users
        WHERE username = ?
        """,
        (email,),
    )
    row = cur.fetchone()
    if not row:
        conn.close()
        return None
    user_id, username, name, grade, stored_email, role, stored_hash, salt = row
    computed = _hash_password(password, salt)
    if not hmac.compare_digest(stored_hash, computed):
        conn.close()
        return None

    normalized_role = str(role or "").strip().lower()
    if normalized_role != "teacher":
        if not _looks_like_teacher_account(username, stored_email, grade):
            conn.close()
            return None
        cur.execute(
            """
            UPDATE users
            SET role = 'teacher',
                grade = 'teacher',
                email = ?
            WHERE user_id = ?
            """,
            (email, user_id),
        )
        conn.commit()
        normalized_role = "teacher"
    conn.close()
    return {
        "user_id": user_id,
        "username": username,
        "name": name,
        "role": normalized_role,
    }


def get_user_by_id(user_id: str) -> Optional[dict]:
    user_id = user_id.strip()
    if not user_id:
        return None
    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT
            user_id,
            username,
            name,
            grade,
            track,
            subject,
            school,
            profile_image,
            email,
            role
        FROM users
        WHERE user_id = ?
        """,
        (user_id,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "user_id": row[0],
        "username": row[1],
        "name": row[2],
        "grade": row[3],
        "track": row[4],
        "subject": row[5],
        "school": row[6],
        "profile_image": row[7],
        "email": row[8],
        "role": row[9],
    }


def update_user_profile(
    *,
    user_id: str,
    username: Optional[str] = None,
    name: Optional[str] = None,
    grade: Optional[str] = None,
    track: Optional[str] = None,
    subject: Optional[str] = None,
    school: Optional[str] = None,
    profile_image: Optional[str] = None,
    email: Optional[str] = None,
    password: Optional[str] = None,
) -> dict:
    current = get_user_by_id(user_id)
    if not current:
        raise ValueError("user not found")

    updates: List[tuple[str, str]] = []
    params: List[str] = []

    role = current.get("role") or "student"

    if username is not None:
        value = username.strip()
        if not value:
            raise ValueError("username is required")
        if role == "teacher":
            value = value.lower()
            error = validate_email(value)
            if error:
                raise ValueError(error)
        else:
            error = validate_username(value)
            if error:
                raise ValueError(error)
        _ensure_user_table()
        cur = sqlite3.connect(DB_PATH).cursor()
        cur.execute("SELECT user_id FROM users WHERE username = ?", (value,))
        row = cur.fetchone()
        cur.connection.close()
        existed_user_id = row[0] if row else None
        if existed_user_id and existed_user_id != user_id:
            raise ValueError("username already exists")
        updates.append(("username", value))
        if role == "teacher":
            updates.append(("email", value))

    if email is not None and role != "teacher":
        normalized_email = email.strip().lower()
        if normalized_email:
            error = validate_email(normalized_email)
            if error:
                raise ValueError(error)
            updates.append(("email", normalized_email))

    if name is not None:
        value = name.strip()
        error = validate_name(value)
        if error:
            raise ValueError(error)
        updates.append(("name", value))

    if grade is not None:
        updates.append(("grade", grade.strip() or None))
    if track is not None:
        updates.append(("track", track.strip() or None))
    if subject is not None:
        updates.append(("subject", subject.strip() or None))
    if school is not None:
        school_value = school.strip()
        if school_value:
            error = validate_school(school_value)
            if error:
                raise ValueError(error)
            updates.append(("school", school_value))
        else:
            updates.append(("school", None))
    if profile_image is not None:
        updates.append(("profile_image", profile_image.strip() or None))

    if password is not None:
        new_password = password.strip()
        if not new_password:
            raise ValueError("password is required")
        if role == "teacher":
            if len(new_password) < 6:
                raise ValueError("password must be at least 6 characters")
        else:
            error = validate_password(new_password)
            if error:
                raise ValueError(error)
        salt = uuid.uuid4().hex
        updates.append(("password_hash", _hash_password(new_password, salt)))
        updates.append(("salt", salt))

    if not updates:
        return current

    sets = ", ".join([f"{column} = ?" for column, _ in updates])
    params = [value for _, value in updates]
    params.append(user_id)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    try:
        cur.execute(f"UPDATE users SET {sets} WHERE user_id = ?", params)
        conn.commit()
    except sqlite3.IntegrityError as exc:
        conn.rollback()
        if "UNIQUE" in str(exc).upper():
            raise ValueError("username already exists") from exc
        raise
    finally:
        conn.close()

    updated = get_user_by_id(user_id)
    if updated is None:
        raise ValueError("user not found")
    return updated


def delete_user_account(user_id: str, *, password: str) -> None:
    current = get_user_by_id(user_id)
    if not current:
        raise ValueError("user not found")

    if not password:
        raise ValueError("password is required")

    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT password_hash, salt FROM users WHERE user_id = ?",
        (user_id,),
    )
    row = cur.fetchone()
    if not row:
        conn.close()
        raise ValueError("user not found")

    stored_hash, salt = row
    computed = _hash_password(password, salt)
    if not hmac.compare_digest(stored_hash, computed):
        conn.close()
        raise ValueError("invalid password")

    # Best effort user-data cleanup (no hard dependency on other schemas).
    cur.execute("DELETE FROM users WHERE user_id = ?", (user_id,))
    conn.commit()
    conn.close()


def get_user_role(user_id: str) -> Optional[str]:
    """Return the role for a given user_id, or None if not found."""
    if not user_id:
        return None
    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT role FROM users WHERE user_id = ?", (user_id,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else None


def get_user_by_email(email: str) -> Optional[dict]:
    """Return user dict for a given email (username), or None if not found."""
    email = email.strip().lower()
    if not email:
        return None
    _ensure_user_table()
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        "SELECT user_id, username, name, grade, role FROM users WHERE username = ?",
        (email,),
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "user_id": row[0],
        "username": row[1],
        "name": row[2],
        "grade": row[3],
        "role": row[4],
    }
