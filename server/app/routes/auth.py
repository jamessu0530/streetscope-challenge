from datetime import datetime, timedelta
import logging

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import (
    PASSWORD_RESET_EXPIRE_MINUTES,
    PASSWORD_RESET_EXPOSE_TOKEN,
)
from app.database import as_utc_aware, utc_now, users_collection
from app.facebook_auth import (
    looks_like_jwt,
    verify_facebook_access_token,
    verify_limited_authentication_token,
)
from app.github_auth import exchange_code_for_token, fetch_github_profile
from app.google_auth import verify_google_id_token
from app.schemas import (
    AuthResponse,
    GitHubSignInRequest,
    ChangePasswordRequest,
    FacebookSignInRequest,
    ForgotPasswordRequest,
    GoogleSignInRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    UserPublic,
)
from app.security import (
    create_access_token,
    decode_user_id,
    generate_reset_token,
    hash_password,
    hash_reset_token,
    verify_password,
    verify_reset_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])
_bearer = HTTPBearer(auto_error=False)
_log = logging.getLogger("uvicorn.error")


def _doc_to_public(doc: dict) -> UserPublic:
    return UserPublic(
        id=str(doc["_id"]),
        email=doc["email"],
        displayName=doc["displayName"],
        provider=doc.get("provider", "email"),
        createdAt=doc["createdAt"],
    )


def _auth_response(doc: dict) -> AuthResponse:
    user = _doc_to_public(doc)
    token = create_access_token(user.id)
    return AuthResponse(accessToken=token, tokenType="bearer", user=user)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    user_id = decode_user_id(credentials.credentials)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    try:
        oid = ObjectId(user_id)
    except InvalidId:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject",
        )
    doc = users_collection().find_one({"_id": oid})
    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return doc


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(body: RegisterRequest) -> AuthResponse:
    email = body.email.strip().lower()
    col = users_collection()
    if col.find_one({"email": email, "provider": "email"}):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )
    now = utc_now()
    doc = {
        "email": email,
        "displayName": body.display_name.strip(),
        "provider": "email",
        "passwordHash": hash_password(body.password),
        "createdAt": now,
        "updatedAt": now,
    }
    result = col.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _auth_response(doc)


@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest) -> AuthResponse:
    email = body.email.strip().lower()
    doc = users_collection().find_one({"email": email, "provider": "email"})
    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="此 Email 尚未註冊，請先按「還沒有帳號？註冊」",
        )
    if not verify_password(body.password, doc.get("passwordHash", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="密碼錯誤，請再試一次",
        )
    return _auth_response(doc)


@router.post("/google", response_model=AuthResponse)
async def google_sign_in(body: GoogleSignInRequest) -> AuthResponse:
    idinfo = verify_google_id_token(body.id_token)
    google_id = idinfo.get("sub")
    if not google_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google 帳號資料不完整",
        )

    email = (idinfo.get("email") or "").strip().lower()
    raw_name = (idinfo.get("name") or "").strip()
    if raw_name:
        display_name = raw_name
    elif email:
        display_name = email.split("@")[0]
    else:
        display_name = "Google User"

    col = users_collection()
    doc = col.find_one({"googleId": google_id})
    now = utc_now()

    if doc is None:
        doc = {
            "googleId": google_id,
            "email": email or f"{google_id}@google.local",
            "displayName": display_name,
            "provider": "google",
            "createdAt": now,
            "updatedAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
    else:
        col.update_one(
            {"_id": doc["_id"]},
            {
                "$set": {
                    "displayName": display_name,
                    "email": email or doc.get("email"),
                    "updatedAt": now,
                }
            },
        )
        doc = col.find_one({"_id": doc["_id"]}) or doc

    return _auth_response(doc)


@router.post("/github", response_model=AuthResponse)
async def github_sign_in(body: GitHubSignInRequest) -> AuthResponse:
    access_token = exchange_code_for_token(body.code)
    profile = fetch_github_profile(access_token)

    github_id = profile["id"]
    display_name = profile["displayName"]
    email = profile.get("email")
    login = profile.get("login") or ""

    col = users_collection()
    doc = col.find_one({"githubId": github_id})
    now = utc_now()

    if doc is None:
        doc = {
            "githubId": github_id,
            "githubLogin": login,
            "email": email or f"{github_id}@github.local",
            "displayName": display_name,
            "provider": "github",
            "createdAt": now,
            "updatedAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
    else:
        updates: dict = {
            "displayName": display_name,
            "githubLogin": login,
            "updatedAt": now,
        }
        if email:
            updates["email"] = email
        col.update_one({"_id": doc["_id"]}, {"$set": updates})
        doc = col.find_one({"_id": doc["_id"]}) or doc

    return _auth_response(doc)


@router.post("/facebook", response_model=AuthResponse)
async def facebook_sign_in(body: FacebookSignInRequest) -> AuthResponse:
    login_type = (body.login_type or "").strip().lower()
    auth_token = (body.authentication_token or "").strip()
    access_token = (body.access_token or "").strip()

    if not auth_token and looks_like_jwt(access_token):
        auth_token = access_token
        access_token = ""

    is_limited = login_type == "limited" or bool(auth_token)

    _log.info(
        "facebook sign-in limited=%s loginType=%s authTokenLen=%d accessTokenLen=%d userId=%s",
        is_limited,
        login_type or "(none)",
        len(auth_token),
        len(access_token),
        body.user_id or "(none)",
    )

    if is_limited:
        if not auth_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="缺少 authenticationToken",
            )
        payload = verify_limited_authentication_token(
            auth_token,
            nonce=body.nonce,
            expected_user_id=(body.user_id or "").strip() or None,
        )
        facebook_id = str(payload.get("sub") or body.user_id or "").strip()
        raw_name = (body.user_name or payload.get("name") or "").strip()
        email = (body.user_email or payload.get("email") or "").strip().lower() or None
    else:
        if not access_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="缺少 accessToken",
            )
        profile = verify_facebook_access_token(access_token)
        facebook_id = str(profile["id"])
        raw_name = (profile.get("name") or "").strip()
        email = (profile.get("email") or "").strip().lower() or None

    if not facebook_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Facebook 帳號資料不完整",
        )

    if raw_name:
        display_name = raw_name
    elif email:
        display_name = email.split("@")[0]
    else:
        display_name = f"FB-{facebook_id[-6:]}"

    col = users_collection()
    doc = col.find_one({"facebookId": facebook_id})
    now = utc_now()

    if doc is None:
        doc = {
            "facebookId": facebook_id,
            "email": email or f"{facebook_id}@facebook.local",
            "displayName": display_name,
            "provider": "facebook",
            "createdAt": now,
            "updatedAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
    else:
        col.update_one(
            {"_id": doc["_id"]},
            {
                "$set": {
                    "displayName": display_name,
                    **({"email": email} if email else {}),
                    "updatedAt": now,
                }
            },
        )
        doc = col.find_one({"_id": doc["_id"]}) or doc

    return _auth_response(doc)


@router.get("/me", response_model=UserPublic)
async def me(user: dict = Depends(get_current_user)) -> UserPublic:
    return _doc_to_public(user)


@router.post("/forgot-password")
async def forgot_password(body: ForgotPasswordRequest) -> dict:
    """建立重設碼。教育版可在回應中回傳 resetToken；正式環境應改寄 Email。"""
    email = body.email.strip().lower()
    doc = users_collection().find_one({"email": email, "provider": "email"})
    if doc is None:
        # 不透露 Email 是否存在（仍回相同訊息）
        return {
            "ok": True,
            "message": "若此 Email 已註冊，請使用重設碼完成重設。",
        }

    plain_token = generate_reset_token()
    expires = utc_now() + timedelta(minutes=PASSWORD_RESET_EXPIRE_MINUTES)
    users_collection().update_one(
        {"_id": doc["_id"]},
        {
            "$set": {
                "resetTokenHash": hash_reset_token(plain_token),
                "resetTokenExpires": expires,
                "updatedAt": utc_now(),
            }
        },
    )

    payload: dict = {
        "ok": True,
        "message": "重設碼已建立，請在 App 輸入重設碼與新密碼。",
        "expiresInMinutes": PASSWORD_RESET_EXPIRE_MINUTES,
    }
    if PASSWORD_RESET_EXPOSE_TOKEN:
        payload["resetToken"] = plain_token
    return payload


@router.post("/reset-password")
async def reset_password(body: ResetPasswordRequest) -> dict:
    email = body.email.strip().lower()
    doc = users_collection().find_one({"email": email, "provider": "email"})
    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="重設碼無效或已過期",
        )

    expires = doc.get("resetTokenExpires")
    token_hash = doc.get("resetTokenHash")
    if not token_hash or not expires:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="請先申請忘記密碼以取得重設碼",
        )
    if not isinstance(expires, datetime):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="重設碼無效或已過期",
        )
    if utc_now() > as_utc_aware(expires):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="重設碼已過期，請重新申請",
        )
    if not verify_reset_token(body.reset_token, token_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="重設碼錯誤",
        )

    users_collection().update_one(
        {"_id": doc["_id"]},
        {
            "$set": {
                "passwordHash": hash_password(body.new_password),
                "updatedAt": utc_now(),
            },
            "$unset": {
                "resetTokenHash": "",
                "resetTokenExpires": "",
            },
        },
    )
    return {"ok": True, "message": "密碼已重設，請用新密碼登入"}


@router.post("/change-password")
async def change_password(
    body: ChangePasswordRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    if user.get("provider") != "email":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="只有 Email 帳號可以更改密碼",
        )
    if not verify_password(body.current_password, user.get("passwordHash", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="目前密碼錯誤",
        )
    users_collection().update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "passwordHash": hash_password(body.new_password),
                "updatedAt": utc_now(),
            }
        },
    )
    return {"ok": True, "message": "密碼已更新"}
