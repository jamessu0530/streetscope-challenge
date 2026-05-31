from fastapi import APIRouter, Depends, Query

from app.database import play_history_collection, utc_now
from app.routes.auth import get_current_user
from app.schemas import PlayHistoryEntryPublic, PlayHistorySubmitRequest

router = APIRouter(prefix="/play-history", tags=["play-history"])

_VALID_PLAY_TYPES = frozenset({"solo", "ai", "friend"})


def _doc_to_public(doc: dict) -> PlayHistoryEntryPublic:
    return PlayHistoryEntryPublic(
        id=str(doc["_id"]),
        user_id=str(doc.get("userId", "")),
        display_name=doc.get("displayName", "Player"),
        total_score=int(doc.get("totalScore", 0)),
        rounds=int(doc.get("rounds", 0)),
        seconds_per_round=int(doc.get("secondsPerRound", 0)),
        mode=str(doc.get("mode", "move")),
        region=str(doc.get("region", "world")),
        play_type=str(doc.get("playType", "solo")),
        opponent_user_id=(
            str(doc["opponentUserId"]) if doc.get("opponentUserId") else None
        ),
        opponent_display_name=doc.get("opponentDisplayName"),
        opponent_score=(
            int(doc["opponentScore"])
            if doc.get("opponentScore") is not None
            else None
        ),
        won=doc.get("won"),
        ai_strength=doc.get("aiStrength"),
        played_at=doc.get("playedAt"),
    )


@router.post("", response_model=PlayHistoryEntryPublic)
async def submit_entry(
    body: PlayHistorySubmitRequest,
    user: dict = Depends(get_current_user),
) -> PlayHistoryEntryPublic:
    play_type = (
        body.play_type if body.play_type in _VALID_PLAY_TYPES else "solo"
    )

    now = utc_now()
    doc = {
        "userId": user["_id"],
        "displayName": user.get("displayName", "Player"),
        "totalScore": body.total_score,
        "rounds": body.rounds,
        "secondsPerRound": body.seconds_per_round,
        "mode": body.mode,
        "region": body.region,
        "playType": play_type,
        "opponentUserId": body.opponent_user_id,
        "opponentDisplayName": body.opponent_display_name,
        "opponentScore": body.opponent_score,
        "won": body.won,
        "aiStrength": body.ai_strength,
        "playedAt": now,
        "createdAt": now,
    }
    result = play_history_collection().insert_one(doc)
    doc["_id"] = result.inserted_id
    return _doc_to_public(doc)


@router.get("", response_model=list[PlayHistoryEntryPublic])
async def list_my_history(
    limit: int = Query(default=50, ge=1, le=200),
    skip: int = Query(default=0, ge=0),
    user: dict = Depends(get_current_user),
) -> list[PlayHistoryEntryPublic]:
    cursor = (
        play_history_collection()
        .find({"userId": user["_id"]})
        .sort("playedAt", -1)
        .skip(skip)
        .limit(limit)
    )
    return [_doc_to_public(doc) for doc in cursor]
