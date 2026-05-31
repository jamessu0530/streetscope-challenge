from datetime import datetime

from bson import ObjectId
from fastapi import APIRouter, Depends, Query

from app.database import as_utc_aware, leaderboard_collection, utc_now
from app.routes.auth import get_current_user
from app.schemas import LeaderboardEntryPublic, LeaderboardSubmitRequest

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])


def _played_ts(doc: dict) -> float:
    played = doc.get("playedAt")
    if isinstance(played, datetime):
        return as_utc_aware(played).timestamp()
    return 0.0


def _doc_to_public(doc: dict, *, viewer_id: str | None = None) -> LeaderboardEntryPublic:
    user_id = str(doc.get("userId", ""))
    return LeaderboardEntryPublic(
        id=str(doc["_id"]),
        user_id=user_id,
        display_name=doc.get("displayName", "Player"),
        total_score=int(doc.get("totalScore", 0)),
        rounds=int(doc.get("rounds", 0)),
        seconds_per_round=int(doc.get("secondsPerRound", 0)),
        mode=str(doc.get("mode", "move")),
        region=str(doc.get("region", "world")),
        played_at=doc.get("playedAt"),
        is_me=viewer_id is not None and user_id == viewer_id,
    )


def _dedupe_best_per_user(docs: list[dict]) -> list[dict]:
    """同一玩家只保留目前篩選範圍內最高分的一筆。"""
    best_by_user: dict[str, dict] = {}
    for doc in docs:
        uid = str(doc.get("userId", ""))
        if not uid:
            continue
        prev = best_by_user.get(uid)
        if prev is None:
            best_by_user[uid] = doc
            continue
        score = int(doc.get("totalScore", 0))
        prev_score = int(prev.get("totalScore", 0))
        if score > prev_score or (
            score == prev_score and _played_ts(doc) > _played_ts(prev)
        ):
            best_by_user[uid] = doc
    return list(best_by_user.values())


@router.post("", response_model=LeaderboardEntryPublic)
async def submit_entry(
    body: LeaderboardSubmitRequest,
    user: dict = Depends(get_current_user),
) -> LeaderboardEntryPublic:
    now = utc_now()
    user_id = user["_id"]
    viewer_id = str(user_id)
    col = leaderboard_collection()

    bucket_filter = {
        "userId": user_id,
        "mode": body.mode,
        "region": body.region,
    }
    existing = col.find_one(bucket_filter)

    display_name = user.get("displayName", "Player")
    if existing is None:
        doc = {
            **bucket_filter,
            "displayName": display_name,
            "totalScore": body.total_score,
            "rounds": body.rounds,
            "secondsPerRound": body.seconds_per_round,
            "playedAt": now,
            "createdAt": now,
        }
        result = col.insert_one(doc)
        doc["_id"] = result.inserted_id
        return _doc_to_public(doc, viewer_id=viewer_id)

    old_score = int(existing.get("totalScore", 0))
    updates: dict = {"displayName": display_name}
    if body.total_score > old_score:
        updates.update(
            {
                "totalScore": body.total_score,
                "rounds": body.rounds,
                "secondsPerRound": body.seconds_per_round,
                "playedAt": now,
            }
        )

    col.update_one({"_id": existing["_id"]}, {"$set": updates})
    refreshed = col.find_one({"_id": existing["_id"]})
    assert refreshed is not None
    return _doc_to_public(refreshed, viewer_id=viewer_id)


@router.get("", response_model=list[LeaderboardEntryPublic])
async def list_entries(
    sort: str = Query(default="top", pattern="^(top|recent)$"),
    mode: str | None = None,
    region: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    user: dict = Depends(get_current_user),
) -> list[LeaderboardEntryPublic]:
    query: dict = {}
    if mode:
        query["mode"] = mode
    if region:
        query["region"] = region

    col = leaderboard_collection()
    docs = _dedupe_best_per_user(list(col.find(query)))
    viewer_id = str(user["_id"])

    if sort == "top":
        docs.sort(
            key=lambda d: (-int(d.get("totalScore", 0)), -_played_ts(d)),
        )
    else:
        docs.sort(key=_played_ts, reverse=True)

    return [
        _doc_to_public(doc, viewer_id=viewer_id) for doc in docs[:limit]
    ]


@router.get("/me/latest", response_model=LeaderboardEntryPublic | None)
async def my_latest_entry(
    user: dict = Depends(get_current_user),
) -> LeaderboardEntryPublic | None:
    """回傳該玩家所有模式／地區中的個人最高分紀錄。"""
    docs = list(leaderboard_collection().find({"userId": user["_id"]}))
    if not docs:
        return None
    best = max(
        docs,
        key=lambda d: (int(d.get("totalScore", 0)), _played_ts(d)),
    )
    return _doc_to_public(best, viewer_id=str(user["_id"]))
