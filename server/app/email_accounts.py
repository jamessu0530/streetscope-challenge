"""Email 密碼帳號查詢（與 Google / Facebook / GitHub 帳號分開）。"""

from __future__ import annotations

from fastapi import HTTPException, status

_PROVIDER_LABELS: dict[str, str] = {
    "google": "Google（Gmail）",
    "facebook": "Facebook",
    "github": "GitHub",
}


def normalize_email(email: str) -> str:
    return email.strip().lower()


def provider_label(provider: str) -> str:
    return _PROVIDER_LABELS.get(provider, provider)


def find_email_password_user(col, email: str) -> dict | None:
    """有 passwordHash 的 Email 帳號（含舊資料未標 provider）。"""
    norm = normalize_email(email)
    doc = col.find_one({"email": norm, "provider": "email"})
    if doc is not None:
        return doc
    return col.find_one(
        {
            "email": norm,
            "passwordHash": {"$exists": True, "$ne": ""},
            "$or": [
                {"provider": {"$exists": False}},
                {"provider": None},
                {"provider": ""},
            ],
        }
    )


def find_oauth_user_by_email(col, email: str) -> dict | None:
    norm = normalize_email(email)
    return col.find_one(
        {
            "email": norm,
            "provider": {"$in": list(_PROVIDER_LABELS.keys())},
        }
    )


def oauth_login_hint_detail(oauth_doc: dict) -> str:
    label = provider_label(str(oauth_doc.get("provider") or ""))
    return f"此 Email 已使用 {label} 登入，請改用該方式，無法使用 Email 密碼"


def raise_login_not_found(col, email: str) -> None:
    oauth = find_oauth_user_by_email(col, email)
    if oauth is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=oauth_login_hint_detail(oauth),
        )
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="此 Email 尚未註冊，請先按「還沒有帳號？註冊」",
    )


def require_email_password_user(col, email: str) -> dict:
    doc = find_email_password_user(col, email)
    if doc is not None:
        return doc
    oauth = find_oauth_user_by_email(col, email)
    if oauth is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=oauth_login_hint_detail(oauth),
        )
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="此 Email 尚未註冊 Email 帳號",
    )
