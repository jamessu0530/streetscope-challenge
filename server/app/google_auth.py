from fastapi import HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.config import GOOGLE_IOS_CLIENT_ID, GOOGLE_WEB_CLIENT_ID


def _google_audiences() -> list[str]:
    out: list[str] = []
    for client_id in (GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID):
        if client_id and client_id not in out:
            out.append(client_id)
    return out


def verify_google_id_token(token: str) -> dict:
    audiences = _google_audiences()
    if not audiences:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="伺服器未設定 GOOGLE_IOS_CLIENT_ID 或 GOOGLE_WEB_CLIENT_ID",
        )

    last_error: ValueError | None = None
    for audience in audiences:
        try:
            return id_token.verify_oauth2_token(
                token,
                google_requests.Request(),
                audience,
            )
        except ValueError as e:
            last_error = e

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=f"Google 登入驗證失敗：{last_error}",
    ) from last_error
