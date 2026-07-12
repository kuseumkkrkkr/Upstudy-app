"""RBAC middleware for FastAPI auth routes.

Provides:
- require_role(*roles): dependency that validates JWT Bearer token,
  checks role against allowed set, and injects user metadata into
  request.state.
"""
from typing import Optional

from fastapi import Request, HTTPException, status

from auth import decode_token, resolve_token_payload_user


def require_role(*roles: str):
    """FastAPI dependency factory.

    Usage:
        @router.get("/admin-only")
        async def admin_endpoint(user=Depends(require_role("academy_admin"))):
            ...

    Validates:
      - Authorization: Bearer <token> header present and well-formed.
      - JWT signature / expiry (via omj.auth.decode_token).
      - persisted DB role is one of the allowed *roles.

    Injects into request.state:
      - user_id   (from payload["sub"])
      - username  (from payload.get("username") or payload["sub"])
      - role      (resolved from DB, token role only for non-elevated anonymous users)

    Raises:
      - 401 if token missing, malformed, expired, or invalid.
      - 403 if role not in allowed set.
    """

    def _dependency(request: Request):
        auth_header: Optional[str] = request.headers.get("Authorization")
        if not auth_header:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            )

        scheme, _, token = auth_header.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            )

        payload = decode_token(token)
        if payload is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            )

        user = resolve_token_payload_user(payload)
        user_role = user["role"]
        allowed = set(roles)
        if user_role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient role",
            )

        request.state.user_id = user["user_id"]
        request.state.username = user["username"]
        request.state.role = user_role

        return user

    return _dependency
