from pathlib import Path

from dotenv import load_dotenv
import os

# 讀專案根目錄的 .env（與 Flutter 共用）
_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(_ROOT / ".env")

MONGODB_URI: str = os.getenv("MONGODB_URI", "").strip()
JWT_SECRET: str = os.getenv("JWT_SECRET", "change-me-in-env").strip()
JWT_ALGORITHM: str = "HS256"
JWT_EXPIRE_DAYS: int = 30
PORT: int = int(os.getenv("PORT", "3000"))
# 教育版：忘記密碼 API 會回傳重設碼給 App 顯示（正式環境應改寄 Email 且設 false）
PASSWORD_RESET_EXPOSE_TOKEN: bool = os.getenv(
    "PASSWORD_RESET_EXPOSE_TOKEN", "true"
).strip().lower() in ("1", "true", "yes")
PASSWORD_RESET_EXPIRE_MINUTES: int = int(
    os.getenv("PASSWORD_RESET_EXPIRE_MINUTES", "60")
)
# Google OAuth — 驗證 idToken（有 Web 用 Web；否則用 iOS Client ID）
GOOGLE_WEB_CLIENT_ID: str = os.getenv("GOOGLE_WEB_CLIENT_ID", "").strip()
GOOGLE_IOS_CLIENT_ID: str = os.getenv("GOOGLE_IOS_CLIENT_ID", "").strip()
FACEBOOK_APP_ID: str = os.getenv("FACEBOOK_APP_ID", "").strip()
# 教育版：Limited Login JWT 簽章驗證失敗時，改檢查 aud/exp/sub（勿用於正式環境）
FACEBOOK_LIMITED_LOGIN_RELAXED: bool = os.getenv(
    "FACEBOOK_LIMITED_LOGIN_RELAXED", "true"
).strip().lower() in ("1", "true", "yes")
# GitHub OAuth — App 用 code 換 token，secret 僅放後端
GITHUB_CLIENT_ID: str = os.getenv("GITHUB_CLIENT_ID", "").strip()
GITHUB_CLIENT_SECRET: str = os.getenv("GITHUB_CLIENT_SECRET", "").strip()
GITHUB_OAUTH_REDIRECT_URI: str = os.getenv(
    "GITHUB_OAUTH_REDIRECT_URI",
    "com.example.geoGuesser://github-callback",
).strip()

# 啟動時清空 leaderboard_entries（僅開發用，清空後請改回 false）
LEADERBOARD_CLEAR_ON_START: bool = os.getenv(
    "LEADERBOARD_CLEAR_ON_START", "false"
).strip().lower() in ("1", "true", "yes")

# 啟動時清空 user_memes（僅開發用）
MEME_CLEAR_ON_START: bool = os.getenv(
    "MEME_CLEAR_ON_START", "false"
).strip().lower() in ("1", "true", "yes")

# AI 對戰 — 抓 Street View Static 圖（須啟用 Street View Static API；
# 若這把 key 在 Google Cloud 限制成只給 iOS app，後端抓圖會失敗，需放寬或另開一把）
GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "").strip()
# Gemini（Google AI Studio）— 看圖猜經緯度
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()
