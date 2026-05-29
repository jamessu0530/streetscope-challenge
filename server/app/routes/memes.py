from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status

from app.database import memes_collection, utc_now
from app.routes.auth import get_current_user
from app.schemas import MemeAddRequest, MemePublic

router = APIRouter(prefix="/memes", tags=["memes"])


def _normalize_country(raw: str | None) -> str:
    label = (raw or "").strip()
    return label if label else "Unknown"


def _doc_to_public(doc: dict) -> MemePublic:
    return MemePublic(
        id=str(doc["_id"]),
        title=doc.get("title", ""),
        image_url=doc.get("imageUrl", ""),
        post_url=doc.get("postUrl", ""),
        subreddit=doc.get("subreddit", ""),
        ups=int(doc.get("ups", 0)),
        country=doc.get("country", "Unknown"),
        score=int(doc.get("score", 0)),
        collected_at=doc.get("collectedAt"),
    )


@router.post("", response_model=MemePublic, status_code=status.HTTP_201_CREATED)
async def add_meme(
    body: MemeAddRequest,
    user: dict = Depends(get_current_user),
) -> MemePublic:
    image_url = body.image_url.strip()
    if not image_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="缺少 imageUrl",
        )

    country = _normalize_country(body.country)
    col = memes_collection()
    existing = col.find_one({"userId": user["_id"], "imageUrl": image_url})
    if existing is not None:
        return _doc_to_public(existing)

    now = utc_now()
    doc = {
        "userId": user["_id"],
        "title": body.title.strip() or "Meme",
        "imageUrl": image_url,
        "postUrl": body.post_url.strip(),
        "subreddit": body.subreddit.strip(),
        "ups": body.ups,
        "country": country,
        "score": body.score,
        "collectedAt": now,
        "createdAt": now,
    }
    result = col.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _doc_to_public(doc)


@router.get("", response_model=list[MemePublic])
async def list_my_memes(
    country: str | None = None,
    user: dict = Depends(get_current_user),
) -> list[MemePublic]:
    query: dict = {"userId": user["_id"]}
    if country and country.strip():
        query["country"] = _normalize_country(country)

    docs = list(
        memes_collection()
        .find(query)
        .sort("collectedAt", -1)
        .limit(500)
    )
    return [_doc_to_public(doc) for doc in docs]


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
async def clear_my_memes(
    user: dict = Depends(get_current_user),
) -> None:
    memes_collection().delete_many({"userId": user["_id"]})
