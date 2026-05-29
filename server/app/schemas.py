from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(min_length=1, max_length=32, alias="displayName")

    model_config = {"populate_by_name": True}


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class GoogleSignInRequest(BaseModel):
    id_token: str = Field(min_length=10, alias="idToken")

    model_config = {"populate_by_name": True}


class FacebookSignInRequest(BaseModel):
    login_type: str | None = Field(default=None, alias="loginType")
    access_token: str | None = Field(default=None, alias="accessToken")
    authentication_token: str | None = Field(
        default=None, alias="authenticationToken"
    )
    user_id: str | None = Field(default=None, alias="userId")
    user_name: str | None = Field(default=None, alias="userName")
    user_email: str | None = Field(default=None, alias="userEmail")
    nonce: str | None = None

    model_config = {"populate_by_name": True}


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    reset_token: str = Field(min_length=4, max_length=64, alias="resetToken")
    new_password: str = Field(min_length=6, max_length=128, alias="newPassword")

    model_config = {"populate_by_name": True}


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(
        min_length=1, max_length=128, alias="currentPassword"
    )
    new_password: str = Field(min_length=6, max_length=128, alias="newPassword")

    model_config = {"populate_by_name": True}


class UserPublic(BaseModel):
    id: str
    email: str
    display_name: str = Field(alias="displayName")
    provider: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {"populate_by_name": True}


class AuthResponse(BaseModel):
    access_token: str = Field(alias="accessToken")
    token_type: str = Field(default="bearer", alias="tokenType")
    user: UserPublic

    model_config = {"populate_by_name": True}


class AiGuessRequest(BaseModel):
    pano_id: str | None = Field(
        default=None,
        alias="panoId",
        description="Google Street View panorama id；測試 lat/lng 時請刪除此欄，勿填 Swagger 預設的 string",
    )
    lat: float | None = Field(default=None, examples=[25.0339639])
    lng: float | None = Field(default=None, examples=[121.5644722])
    # picture | noMove | move
    mode: str = Field(default="picture", examples=["picture"])
    # AI 強度：weak | medium | strong（picture 不受影響）
    strength: str = Field(default="medium", examples=["medium"])
    # picture 模式可帶玩家視角朝向（度）
    heading: float | None = Field(default=None, examples=[0])
    # move 模式：玩家沿路經過的 panorama id（依序），AI 會看整段路線而非只看終點
    pano_trail: list[str] | None = Field(default=None, alias="panoTrail")

    model_config = {
        "populate_by_name": True,
        "json_schema_extra": {
            "examples": [
                {
                    "lat": 25.0339639,
                    "lng": 121.5644722,
                    "mode": "picture",
                    "heading": 0,
                }
            ]
        },
    }


class AiGuessResponse(BaseModel):
    lat: float
    lng: float
    confidence: float | None = None
    reasoning: str | None = None

    model_config = {"populate_by_name": True}
