from datetime import datetime

from fastapi import APIRouter, Depends, Query

from app.database import leaderboard_collection, utc_now
from app.routes.auth import get_current_user
from app.schemas import LeaderboardEntryPublic, LeaderboardSubmitRequest

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])


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


@router.post("", response_model=LeaderboardEntryPublic)
async def submit_entry(
    body: LeaderboardSubmitRequest,
    user: dict = Depends(get_current_user),
) -> LeaderboardEntryPublic:
    now = utc_now()
    user_id = user["_id"]
    doc = {
        "userId": user_id,
        "displayName": user.get("displayName", "Player"),
        "totalScore": body.total_score,
        "rounds": body.rounds,
        "secondsPerRound": body.seconds_per_round,
        "mode": body.mode,
        "region": body.region,
        "playedAt": now,
        "createdAt": now,
    }
    result = leaderboard_collection().insert_one(doc)
    doc["_id"] = result.inserted_id
    return _doc_to_public(doc, viewer_id=str(user_id))


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
    cursor = col.find(query)
    docs = list(cursor)
    viewer_id = str(user["_id"])

    def _played_ts(doc: dict) -> float:
        played = doc.get("playedAt")
        if isinstance(played, datetime):
            return played.timestamp()
        return 0.0

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
    doc = leaderboard_collection().find_one(
        {"userId": user["_id"]},
        sort=[("playedAt", -1)],
    )
    if doc is None:
        return None
    return _doc_to_public(doc, viewer_id=str(user["_id"]))
