import logging
import time

import jwt
import requests
from fastapi import HTTPException, status
from jwt import PyJWKClient, PyJWTError

from app.config import FACEBOOK_APP_ID, FACEBOOK_LIMITED_LOGIN_RELAXED

logger = logging.getLogger(__name__)

GRAPH_API = "https://graph.facebook.com/v21.0"
LIMITED_JWKS_URL = "https://limited.facebook.com/.well-known/oauth/openid/jwks/"
LIMITED_ISSUERS = ("https://www.facebook.com", "https://facebook.com")
_jwk_client = PyJWKClient(LIMITED_JWKS_URL, cache_keys=True)


def looks_like_jwt(value: str | None) -> bool:
    if not value:
        return False
    parts = value.strip().split(".")
    return len(parts) == 3 and parts[0].startswith("eyJ")


def _audience_matches(payload_aud: object, app_id: str) -> bool:
    expected = str(app_id)
    if isinstance(payload_aud, list):
        return expected in [str(item) for item in payload_aud]
    return str(payload_aud) == expected


def verify_facebook_access_token(access_token: str) -> dict:
    """Classic Login：用 Graph API 驗證 access token 並取得 id / name。"""
    token = access_token.strip()
    if looks_like_jwt(token):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="收到 JWT，請使用 Limited Login 流程（authenticationToken）",
        )

    try:
        response = requests.get(
            f"{GRAPH_API}/me",
            params={
                "fields": "id,name",
                "access_token": token,
            },
            timeout=12,
        )
    except requests.RequestException as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="無法連線 Facebook，請稍後再試",
        ) from e

    if response.status_code != 200:
        detail = "Facebook 登入驗證失敗"
        try:
            err = response.json().get("error", {})
            if isinstance(err, dict) and err.get("message"):
                detail = str(err["message"])
        except Exception:
            pass
        logger.warning("facebook classic verify failed: %s", detail)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
        )

    data = response.json()
    if not data.get("id"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Facebook 帳號資料不完整",
        )
    return data


def _decode_limited_payload_relaxed(
    token: str,
    *,
    expected_user_id: str | None,
) -> dict:
    """教育版後備：不驗簽章，只檢查 aud / exp / iss / sub。"""
    payload = jwt.decode(
        token,
        options={
            "verify_signature": False,
            "verify_aud": False,
            "verify_iss": False,
            "verify_exp": True,
        },
        algorithms=["RS256"],
    )

    iss = str(payload.get("iss") or "")
    if iss and iss not in LIMITED_ISSUERS:
        raise PyJWTError(f"issuer 不符：{iss}")

    if not _audience_matches(payload.get("aud"), FACEBOOK_APP_ID):
        raise PyJWTError("audience 與 FACEBOOK_APP_ID 不符")

    sub = str(payload.get("sub") or "")
    if expected_user_id and sub and expected_user_id != sub:
        logger.warning(
            "relaxed jwt: user id mismatch sdk=%s sub=%s",
            expected_user_id,
            sub,
        )

    exp = payload.get("exp")
    if isinstance(exp, (int, float)) and exp < time.time():
        raise PyJWTError("token 已過期")

    logger.warning("facebook limited login: using relaxed JWT validation")
    return payload


def verify_limited_authentication_token(
    authentication_token: str,
    *,
    nonce: str | None = None,
    expected_user_id: str | None = None,
) -> dict:
    """iOS Limited Login OIDC JWT — Meta 官方 JWKS（2024+）。"""
    if not FACEBOOK_APP_ID:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="伺服器未設定 FACEBOOK_APP_ID",
        )

    token = authentication_token.strip()
    payload: dict | None = None
    last_error: Exception | None = None

    try:
        signing_key = _jwk_client.get_signing_key_from_jwt(token)
        for issuer in LIMITED_ISSUERS:
            try:
                payload = jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=["RS256"],
                    audience=FACEBOOK_APP_ID,
                    issuer=issuer,
                )
                break
            except PyJWTError as e:
                last_error = e
                payload = None
    except PyJWTError as e:
        last_error = e

    if payload is None and FACEBOOK_LIMITED_LOGIN_RELAXED:
        try:
            payload = _decode_limited_payload_relaxed(
                token,
                expected_user_id=expected_user_id,
            )
        except PyJWTError as e:
            last_error = e
            payload = None

    if payload is None:
        detail = f"Facebook Limited Login 驗證失敗：{last_error}"
        logger.warning(detail)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
        )

    token_nonce = payload.get("nonce")
    if nonce and token_nonce and nonce != token_nonce:
        logger.warning("facebook nonce mismatch (ignored for login)")

    sub = str(payload.get("sub") or "")
    if expected_user_id and sub and expected_user_id != sub:
        if FACEBOOK_LIMITED_LOGIN_RELAXED:
            logger.warning(
                "facebook user id mismatch sdk=%s jwt=%s (using jwt sub)",
                expected_user_id,
                sub,
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Facebook user id 不符",
            )

    return payload
