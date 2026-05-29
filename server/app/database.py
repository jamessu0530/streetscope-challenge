from datetime import datetime, timezone

from pymongo import ASCENDING, MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

from app.config import LEADERBOARD_CLEAR_ON_START, MEME_CLEAR_ON_START, MONGODB_URI

_client: MongoClient | None = None


def get_client() -> MongoClient:
    global _client
    if _client is None:
        if not MONGODB_URI:
            raise RuntimeError("MONGODB_URI is not set in .env")
        _client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=8000)
    return _client


def get_db() -> Database:
    return get_client().get_default_database()


def users_collection() -> Collection:
    return get_db()["users"]


def leaderboard_collection() -> Collection:
    return get_db()["leaderboard_entries"]


def memes_collection() -> Collection:
    return get_db()["user_memes"]


def ensure_indexes() -> None:
    """啟動時建立 users 索引（collection 不存在會自動建立）。"""
    col = users_collection()
    col.create_index(
        [("email", ASCENDING)],
        unique=True,
        name="email_unique",
        partialFilterExpression={"provider": "email"},
    )
    col.create_index([("createdAt", ASCENDING)], name="created_at")
    col.create_index(
        [("googleId", ASCENDING)],
        unique=True,
        name="google_id_unique",
        partialFilterExpression={"provider": "google"},
    )
    col.create_index(
        [("facebookId", ASCENDING)],
        unique=True,
        name="facebook_id_unique",
        partialFilterExpression={"provider": "facebook"},
    )
    col.create_index(
        [("githubId", ASCENDING)],
        unique=True,
        name="github_id_unique",
        partialFilterExpression={"provider": "github"},
    )

    lb = leaderboard_collection()
    if LEADERBOARD_CLEAR_ON_START:
        lb.delete_many({})
    lb.create_index([("playedAt", ASCENDING)], name="leaderboard_played_at")
    lb.create_index([("totalScore", ASCENDING)], name="leaderboard_total_score")
    lb.create_index([("userId", ASCENDING), ("playedAt", ASCENDING)], name="leaderboard_user_played")
    lb.create_index([("mode", ASCENDING)], name="leaderboard_mode")
    lb.create_index([("region", ASCENDING)], name="leaderboard_region")

    memes = memes_collection()
    if MEME_CLEAR_ON_START:
        memes.delete_many({})
    memes.create_index(
        [("userId", ASCENDING), ("collectedAt", ASCENDING)],
        name="memes_user_collected",
    )
    memes.create_index(
        [("userId", ASCENDING), ("country", ASCENDING)],
        name="memes_user_country",
    )
    memes.create_index(
        [("userId", ASCENDING), ("imageUrl", ASCENDING)],
        unique=True,
        name="memes_user_image_unique",
    )


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def as_utc_aware(value: datetime) -> datetime:
    """MongoDB 讀出的 datetime 可能是 naive UTC，統一成 aware 再比較。"""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
