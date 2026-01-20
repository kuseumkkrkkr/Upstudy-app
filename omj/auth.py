import base64
import hashlib
import hmac
import json
import os
import time
from typing import Optional

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
