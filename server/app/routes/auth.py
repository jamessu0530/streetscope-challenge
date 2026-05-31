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
from app.display_name import (
    allocate_unique_display_name,
    assert_display_name_available,
    display_name_key,
    nickname_seed,
)
from app.facebook_auth import (
    looks_like_jwt,
    verify_facebook_access_token,
    verify_limited_authentication_token,
)
from app.github_auth import exchange_code_for_token, fetch_github_profile
from app.google_auth import verify_google_id_token
from app.realtime_hub import hub
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
    UpdateProfileRequest,
    UserPublic,
)
from app.security import (
    SESSION_SUPERSEDED_MESSAGE,
    create_access_token,
    decode_access_token,
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
    customized = doc.get("displayNameCustomized")
    if customized is None:
        customized = True
    needs_setup = not bool(customized)
    suggested = doc.get("suggestedDisplayName")
    return UserPublic(
        id=str(doc["_id"]),
        email=doc["email"],
        displayName=doc["displayName"],
        provider=doc.get("provider", "email"),
        createdAt=doc["createdAt"],
        displayNameCustomized=bool(customized),
        needsNicknameSetup=needs_setup,
        suggestedDisplayName=(str(suggested) if needs_setup and suggested else None),
    )


def _auth_response(doc: dict) -> AuthResponse:
    user = _doc_to_public(doc)
    session_version = int(doc.get("sessionVersion") or 0)
    token = create_access_token(user.id, session_version)
    return AuthResponse(accessToken=token, tokenType="bearer", user=user)


async def _complete_sign_in(col, doc: dict, *, new_account: bool) -> AuthResponse:
    """新登入／註冊：建立 session，並踢掉舊連線。"""
    user_id = doc["_id"]
    if new_account:
        col.update_one(
            {"_id": user_id},
            {"$set": {"sessionVersion": 1, "updatedAt": utc_now()}},
        )
    else:
        col.update_one(
            {"_id": user_id},
            {"$inc": {"sessionVersion": 1}, "$set": {"updatedAt": utc_now()}},
        )
        await hub.disconnect_user(
            str(user_id),
            code=4001,
            reason=SESSION_SUPERSEDED_MESSAGE,
        )
    refreshed = col.find_one({"_id": user_id}) or doc
    return _auth_response(refreshed)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    claims = decode_access_token(credentials.credentials)
    if not claims:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    user_id = claims["sub"]
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
    if int(doc.get("sessionVersion") or 0) != int(claims["sv"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=SESSION_SUPERSEDED_MESSAGE,
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
    display_name = assert_display_name_available(col, body.display_name.strip())
    doc = {
        "email": email,
        "displayName": display_name,
        "displayNameKey": display_name_key(display_name),
        "displayNameCustomized": True,
        "provider": "email",
        "passwordHash": hash_password(body.password),
        "sessionVersion": 1,
        "createdAt": now,
        "updatedAt": now,
    }
    result = col.insert_one(doc)
    doc["_id"] = result.inserted_id
    return await _complete_sign_in(col, doc, new_account=True)


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
    return await _complete_sign_in(col, doc, new_account=False)


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
        suggested_raw = raw_name
    elif email:
        suggested_raw = email.split("@")[0]
    else:
        suggested_raw = "GoogleUser"

    col = users_collection()
    doc = col.find_one({"googleId": google_id})
    now = utc_now()
    created = False

    if doc is None:
        created = True
        suggested = nickname_seed(suggested_raw, fallback="GoogleUser")
        display_name = allocate_unique_display_name(
            col, suggested, fallback="GoogleUser"
        )
        doc = {
            "googleId": google_id,
            "email": email or f"{google_id}@google.local",
            "displayName": display_name,
            "displayNameKey": display_name_key(display_name),
            "suggestedDisplayName": suggested,
            "displayNameCustomized": False,
            "provider": "google",
            "createdAt": now,
            "updatedAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
    else:
        updates: dict = {
            "email": email or doc.get("email"),
            "updatedAt": now,
        }
        col.update_one({"_id": doc["_id"]}, {"$set": updates})
        doc = col.find_one({"_id": doc["_id"]}) or doc

    return await _complete_sign_in(col, doc, new_account=created)


@router.post("/github", response_model=AuthResponse)
async def github_sign_in(body: GitHubSignInRequest) -> AuthResponse:
    access_token = exchange_code_for_token(body.code)
    profile = fetch_github_profile(access_token)

    github_id = profile["id"]
    suggested_raw = profile.get("suggestedDisplayName") or profile["displayName"]
    email = profile.get("email")
    login = profile.get("login") or ""

    col = users_collection()
    doc = col.find_one({"githubId": github_id})
    now = utc_now()
    created = False

    if doc is None:
        created = True
        suggested = nickname_seed(suggested_raw, fallback=login or "GitHubUser")
        display_name = allocate_unique_display_name(
            col, suggested, fallback=login or "GitHubUser"
        )
        doc = {
            "githubId": github_id,
            "githubLogin": login,
            "email": email or f"{github_id}@github.local",
            "displayName": display_name,
            "displayNameKey": display_name_key(display_name),
            "suggestedDisplayName": suggested,
            "displayNameCustomized": False,
            "provider": "github",
            "createdAt": now,
            "updatedAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
    else:
        updates: dict = {
            "githubLogin": login,
            "updatedAt": now,
        }
        if email:
            updates["email"] = email
        col.update_one({"_id": doc["_id"]}, {"$set": updates})
        doc = col.find_one({"_id": doc["_id"]}) or doc

    return await _complete_sign_in(col, doc, new_account=created)


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
        suggested_raw = raw_name
    elif email:
        suggested_raw = email.split("@")[0]
    else:
        suggested_raw = f"FB{facebook_id[-6:]}"

    col = users_collection()
    doc = col.find_one({"facebookId": facebook_id})
    now = utc_now()
    created = False

    if doc is None:
        created = True
        suggested = nickname_seed(suggested_raw, fallback=f"FB{facebook_id[-6:]}")
        display_name = allocate_unique_display_name(
            col, suggested, fallback=f"FB{facebook_id[-6:]}"
        )
        doc = {
            "facebookId": facebook_id,
            "email": email or f"{facebook_id}@facebook.local",
            "displayName": display_name,
            "displayNameKey": display_name_key(display_name),
            "suggestedDisplayName": suggested,
            "displayNameCustomized": False,
            "provider": "facebook",
            "createdAt": now,
            "updatedAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
    else:
        updates: dict = {"updatedAt": now}
        if email:
            updates["email"] = email
        col.update_one({"_id": doc["_id"]}, {"$set": updates})
        doc = col.find_one({"_id": doc["_id"]}) or doc

    return await _complete_sign_in(col, doc, new_account=created)


@router.get("/me", response_model=UserPublic)
async def me(user: dict = Depends(get_current_user)) -> UserPublic:
    return _doc_to_public(user)


@router.patch("/me/profile", response_model=UserPublic)
async def update_profile(
    body: UpdateProfileRequest,
    user: dict = Depends(get_current_user),
) -> UserPublic:
    col = users_collection()
    display_name = assert_display_name_available(
        col,
        body.display_name,
        exclude_user_id=user["_id"],
    )
    now = utc_now()
    col.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "displayName": display_name,
                "displayNameKey": display_name_key(display_name),
                "displayNameCustomized": True,
                "updatedAt": now,
            },
            "$unset": {"suggestedDisplayName": ""},
        },
    )
    doc = col.find_one({"_id": user["_id"]})
    if doc is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    await hub.update_display_name(str(doc["_id"]), display_name)
    return _doc_to_public(doc)


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
