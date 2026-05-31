from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(min_length=2, max_length=32, alias="displayName")

    @field_validator("display_name")
    @classmethod
    def _strip_display_name(cls, value: str) -> str:
        return value.strip()

    model_config = {"populate_by_name": True}


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class GoogleSignInRequest(BaseModel):
    id_token: str = Field(min_length=10, alias="idToken")

    model_config = {"populate_by_name": True}


class GitHubSignInRequest(BaseModel):
    code: str = Field(min_length=4)

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


class UpdateProfileRequest(BaseModel):
    display_name: str = Field(min_length=2, max_length=32, alias="displayName")

    model_config = {"populate_by_name": True}

    @field_validator("display_name")
    @classmethod
    def _strip_display_name(cls, value: str) -> str:
        return value.strip()


class UserPublic(BaseModel):
    id: str
    email: str
    display_name: str = Field(alias="displayName")
    provider: str
    created_at: datetime = Field(alias="createdAt")
    display_name_customized: bool = Field(default=True, alias="displayNameCustomized")
    needs_nickname_setup: bool = Field(default=False, alias="needsNicknameSetup")
    suggested_display_name: str | None = Field(
        default=None, alias="suggestedDisplayName"
    )

    model_config = {"populate_by_name": True}


class AuthResponse(BaseModel):
    access_token: str = Field(alias="accessToken")
    token_type: str = Field(default="bearer", alias="tokenType")
    user: UserPublic

    model_config = {"populate_by_name": True}


class LeaderboardSubmitRequest(BaseModel):
    total_score: int = Field(ge=0, alias="totalScore")
    rounds: int = Field(ge=1, alias="rounds")
    seconds_per_round: int = Field(ge=1, alias="secondsPerRound")
    mode: str
    region: str

    model_config = {"populate_by_name": True}


class MemeAddRequest(BaseModel):
    title: str = Field(min_length=1, max_length=512)
    image_url: str = Field(min_length=4, alias="imageUrl")
    post_url: str = Field(default="", alias="postUrl")
    subreddit: str = Field(default="")
    ups: int = Field(default=0, ge=0)
    country: str | None = None
    score: int = Field(default=0, ge=0)

    model_config = {"populate_by_name": True}


class MemePublic(BaseModel):
    id: str
    title: str
    image_url: str = Field(alias="imageUrl")
    post_url: str = Field(alias="postUrl")
    subreddit: str
    ups: int
    country: str
    score: int
    collected_at: datetime = Field(alias="collectedAt")

    model_config = {"populate_by_name": True}


class LeaderboardEntryPublic(BaseModel):
    id: str
    user_id: str = Field(alias="userId")
    display_name: str = Field(alias="displayName")
    total_score: int = Field(alias="totalScore")
    rounds: int
    seconds_per_round: int = Field(alias="secondsPerRound")
    mode: str
    region: str
    played_at: datetime = Field(alias="playedAt")
    is_me: bool = Field(default=False, alias="isMe")

    model_config = {"populate_by_name": True}


class PlayHistorySubmitRequest(BaseModel):
    total_score: int = Field(ge=0, alias="totalScore")
    rounds: int = Field(ge=1, alias="rounds")
    seconds_per_round: int = Field(ge=1, alias="secondsPerRound")
    mode: str
    region: str
    play_type: str = Field(alias="playType")
    opponent_user_id: str | None = Field(default=None, alias="opponentUserId")
    opponent_display_name: str | None = Field(
        default=None, alias="opponentDisplayName"
    )
    opponent_score: int | None = Field(default=None, alias="opponentScore")
    won: bool | None = None
    ai_strength: str | None = Field(default=None, alias="aiStrength")

    model_config = {"populate_by_name": True}


class PlayHistoryEntryPublic(BaseModel):
    id: str
    user_id: str = Field(alias="userId")
    display_name: str = Field(alias="displayName")
    total_score: int = Field(alias="totalScore")
    rounds: int
    seconds_per_round: int = Field(alias="secondsPerRound")
    mode: str
    region: str
    play_type: str = Field(alias="playType")
    opponent_user_id: str | None = Field(default=None, alias="opponentUserId")
    opponent_display_name: str | None = Field(
        default=None, alias="opponentDisplayName"
    )
    opponent_score: int | None = Field(default=None, alias="opponentScore")
    won: bool | None = None
    ai_strength: str | None = Field(default=None, alias="aiStrength")
    played_at: datetime = Field(alias="playedAt")

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
