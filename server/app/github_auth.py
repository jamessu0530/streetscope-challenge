import logging

import requests
from fastapi import HTTPException, status

from app.config import (
    GITHUB_CLIENT_ID,
    GITHUB_CLIENT_SECRET,
    GITHUB_OAUTH_REDIRECT_URI,
)

logger = logging.getLogger(__name__)

GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
GITHUB_USER_URL = "https://api.github.com/user"
GITHUB_EMAILS_URL = "https://api.github.com/user/emails"


def exchange_code_for_token(code: str) -> str:
    if not GITHUB_CLIENT_ID or not GITHUB_CLIENT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="伺服器未設定 GITHUB_CLIENT_ID 或 GITHUB_CLIENT_SECRET",
        )

    try:
        response = requests.post(
            GITHUB_TOKEN_URL,
            headers={"Accept": "application/json"},
            data={
                "client_id": GITHUB_CLIENT_ID,
                "client_secret": GITHUB_CLIENT_SECRET,
                "code": code.strip(),
                "redirect_uri": GITHUB_OAUTH_REDIRECT_URI,
            },
            timeout=12,
        )
    except requests.RequestException as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="無法連線 GitHub，請稍後再試",
        ) from e

    if response.status_code != 200:
        logger.warning("github token exchange failed: %s", response.text[:200])
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="GitHub 授權碼無效或已過期",
        )

    data = response.json()
    if data.get("error"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(data.get("error_description") or data["error"]),
        )

    token = (data.get("access_token") or "").strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="無法取得 GitHub access token",
        )
    return token


def fetch_github_profile(access_token: str) -> dict:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    try:
        user_resp = requests.get(GITHUB_USER_URL, headers=headers, timeout=12)
    except requests.RequestException as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="無法連線 GitHub，請稍後再試",
        ) from e

    if user_resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="GitHub 登入驗證失敗",
        )

    user = user_resp.json()
    github_id = str(user.get("id") or "").strip()
    if not github_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="GitHub 帳號資料不完整",
        )

    login = (user.get("login") or "").strip()
    name = (user.get("name") or "").strip()
    email = (user.get("email") or "").strip().lower()

    if not email:
        try:
            emails_resp = requests.get(
                GITHUB_EMAILS_URL, headers=headers, timeout=12
            )
            if emails_resp.status_code == 200:
                for item in emails_resp.json():
                    if not isinstance(item, dict):
                        continue
                    if item.get("primary") and item.get("verified"):
                        email = (item.get("email") or "").strip().lower()
                        break
                if not email:
                    for item in emails_resp.json():
                        if isinstance(item, dict) and item.get("verified"):
                            email = (item.get("email") or "").strip().lower()
                            if email:
                                break
        except requests.RequestException:
            pass

    if name:
        suggested_name = login or name
    elif login:
        suggested_name = login
    else:
        suggested_name = f"GitHub-{github_id[-6:]}"

    display_name = login or name or suggested_name

    return {
        "id": github_id,
        "login": login,
        "displayName": display_name,
        "suggestedDisplayName": suggested_name,
        "email": email or None,
    }
