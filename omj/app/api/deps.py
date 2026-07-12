from typing import Any, Dict, Optional

from fastapi import HTTPException, Request, status

from auth import decode_token, resolve_token_payload_user


def get_current_user(request: Request) -> Dict[str, Any]:
    auth_header: Optional[str] = request.headers.get('Authorization')
    if not auth_header:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid token')

    scheme, _, token = auth_header.partition(' ')
    if scheme.lower() != 'bearer' or not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid token')

    payload = decode_token(token)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid token')

    user = resolve_token_payload_user(payload)
    request.state.user_id = user['user_id']
    request.state.username = user['username']
    request.state.role = user['role']
    return user
