from datetime import datetime, timezone

from pymongo import ASCENDING, DESCENDING, MongoClient
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


def play_history_collection() -> Collection:
    return get_db()["play_history_entries"]


def memes_collection() -> Collection:
    return get_db()["user_memes"]


def _ensure_named_index(
    col: Collection,
    keys: list,
    name: str,
    **kwargs,
) -> None:
    """建立索引；若同名索引的 key 定義不同，先刪除再重建（避免 IndexKeySpecsConflict）。"""
    requested = list(keys)
    try:
        info = col.index_information()
    except Exception:
        info = {}
    if name in info:
        existing = list(info[name]["key"])
        if existing != requested:
            col.drop_index(name)
    col.create_index(requested, name=name, **kwargs)


def _collapse_leaderboard_duplicates(lb: Collection) -> None:
    """合併舊資料：每個 (userId, mode, region) 只留最高分一筆。"""
    pipeline = [
        {
            "$group": {
                "_id": {
                    "userId": "$userId",
                    "mode": "$mode",
                    "region": "$region",
                },
                "docs": {
                    "$push": {
                        "id": "$_id",
                        "totalScore": "$totalScore",
                        "playedAt": "$playedAt",
                    }
                },
                "count": {"$sum": 1},
            }
        },
        {"$match": {"count": {"$gt": 1}}},
    ]
    for group in lb.aggregate(pipeline):
        docs = group["docs"]

        def _sort_key(item: dict) -> tuple[int, float]:
            score = int(item.get("totalScore") or 0)
            played = item.get("playedAt")
            ts = 0.0
            if isinstance(played, datetime):
                ts = as_utc_aware(played).timestamp()
            return (score, ts)

        docs.sort(key=_sort_key, reverse=True)
        for duplicate in docs[1:]:
            lb.delete_one({"_id": duplicate["id"]})


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
    else:
        _collapse_leaderboard_duplicates(lb)
    _ensure_named_index(lb, [("playedAt", ASCENDING)], name="leaderboard_played_at")
    _ensure_named_index(
        lb, [("totalScore", ASCENDING)], name="leaderboard_total_score"
    )
    _ensure_named_index(lb, [("mode", ASCENDING)], name="leaderboard_mode")
    _ensure_named_index(lb, [("region", ASCENDING)], name="leaderboard_region")
    _ensure_named_index(
        lb,
        [("userId", ASCENDING), ("mode", ASCENDING), ("region", ASCENDING)],
        name="leaderboard_user_mode_region_unique",
        unique=True,
    )

    ph = play_history_collection()
    _ensure_named_index(
        ph,
        [("userId", ASCENDING), ("playedAt", DESCENDING)],
        name="play_history_user_played",
    )

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
