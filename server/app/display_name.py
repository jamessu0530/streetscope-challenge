"""遊戲暱稱驗證、唯一性與預設值分配。"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING

from bson import ObjectId
from fastapi import HTTPException, status

if TYPE_CHECKING:
    from pymongo.collection import Collection

_DISPLAY_NAME_RE = re.compile(r"^\S{2,32}$")

# 簡易禁詞（大小寫不敏感、子字串比對）
_BANNED_SUBSTRINGS = (
    "fuck",
    "shit",
    "bitch",
    "asshole",
    "操你",
    "幹你",
    "傻逼",
    "白痴",
    "婊子",
)


def normalize_display_name(raw: str) -> str:
    return (raw or "").strip()


def display_name_key(name: str) -> str:
    return normalize_display_name(name).casefold()


def contains_profanity(name: str) -> bool:
    lowered = name.casefold()
    return any(token in lowered for token in _BANNED_SUBSTRINGS)


def validate_display_name(raw: str) -> str:
    name = normalize_display_name(raw)
    if not _DISPLAY_NAME_RE.match(name):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="暱稱需 2～32 字，且不可含空白",
        )
    if contains_profanity(name):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="暱稱含有不當用字，請換一個",
        )
    return name


def nickname_seed(raw: str, fallback: str = "Player") -> str:
    """把 OAuth 原名轉成可當遊戲 ID 的種子（去空白）。"""
    compact = re.sub(r"\s+", "", normalize_display_name(raw))
    if len(compact) >= 2:
        return compact[:32]
    fb = re.sub(r"\s+", "", normalize_display_name(fallback))
    if len(fb) >= 2:
        return fb[:32]
    return "Player"


def is_display_name_taken(
    col: Collection,
    name: str,
    *,
    exclude_user_id: ObjectId | None = None,
) -> bool:
    key = display_name_key(name)
    query: dict = {"displayNameKey": key}
    if exclude_user_id is not None:
        query["_id"] = {"$ne": exclude_user_id}
    return col.find_one(query, projection={"_id": 1}) is not None


def allocate_unique_display_name(
    col: Collection,
    raw_seed: str,
    *,
    exclude_user_id: ObjectId | None = None,
    fallback: str = "Player",
) -> str:
    """分配全站唯一暱稱；若種子已被使用則加 -2、-3…"""
    seed = nickname_seed(raw_seed, fallback=fallback)
    try:
        validate_display_name(seed)
    except HTTPException:
        seed = "Player"

    if not is_display_name_taken(col, seed, exclude_user_id=exclude_user_id):
        return seed

    for suffix in range(2, 10_000):
        candidate = f"{seed[:28]}-{suffix}"
        if len(candidate) < 2:
            continue
        if not is_display_name_taken(col, candidate, exclude_user_id=exclude_user_id):
            return candidate

    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="暱稱分配失敗，請稍後再試",
    )


def assert_display_name_available(
    col: Collection,
    name: str,
    *,
    exclude_user_id: ObjectId | None = None,
) -> str:
    validated = validate_display_name(name)
    if is_display_name_taken(col, validated, exclude_user_id=exclude_user_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="此暱稱已被使用，請換一個",
        )
    return validated
