from datetime import datetime, timezone

from pymongo import ASCENDING, MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

from app.config import MONGODB_URI

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


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def as_utc_aware(value: datetime) -> datetime:
    """MongoDB 讀出的 datetime 可能是 naive UTC，統一成 aware 再比較。"""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
