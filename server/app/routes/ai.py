# =============================================================================
# AI 對戰路由 — /ai/guess
#
# Flutter 送 panoId（或座標）+ mode，後端抓街景圖 → Gemini 猜經緯度 → 回 lat/lng。
# 失敗一律回 502，讓 Flutter 端 fallback（該回合 AI 0 分），不影響玩家流程。
# =============================================================================

import logging

from fastapi import APIRouter, HTTPException, status

from app.ai_geo import (
    build_streetview_images,
    build_trail_images,
    gemini_guess_location,
    resolve_streetview_target,
)
from app.schemas import AiGuessRequest, AiGuessResponse

router = APIRouter(prefix="/ai", tags=["ai"])
_log = logging.getLogger("uvicorn.error")

_VALID_STRENGTHS = {"weak", "medium", "strong"}

# 各強度對應的圖數設定
_MOVE_TRAIL_POINTS = {"medium": 8, "strong": 16}
_NOMOVE_HEADINGS = {
    "weak": [0],
    "medium": [0, 180],
    "strong": [0, 90, 180, 270],
}


def _normalize_strength(s: str | None) -> str:
    value = (s or "medium").strip().lower()
    return value if value in _VALID_STRENGTHS else "medium"


def _collect_images(body: AiGuessRequest, strength: str) -> list[bytes]:
    """依 mode + strength 決定要抓哪些街景圖。抓不到回空 list。"""
    # move 中 / 強 + 有沿路足跡 → 看整段路線（多點各一張）
    if body.mode == "move" and strength != "weak" and body.pano_trail:
        max_points = _MOVE_TRAIL_POINTS[strength]
        _log.info(
            "ai guess mode=move strength=%s trail_len=%d max=%d",
            strength,
            len(body.pano_trail),
            max_points,
        )
        return build_trail_images(body.pano_trail, max_points=max_points)

    # 其餘情況需要單一定位點（picture / noMove / move-弱 / move-沒走動）
    if not body.pano_id and (body.lat is None or body.lng is None):
        return []
    target = resolve_streetview_target(
        pano_id=body.pano_id, lat=body.lat, lng=body.lng
    )
    if target is None:
        return []

    if body.mode == "picture":
        headings = [int(body.heading or 0)]
    elif body.mode == "noMove":
        headings = _NOMOVE_HEADINGS[strength]
    else:  # move
        # 弱 = 只看終點（一張）；中/強但沒 trail = 終點四周
        headings = [0] if strength == "weak" else [0, 90, 180, 270]

    _log.info(
        "ai guess mode=%s strength=%s pano=%s latlng=%s headings=%s",
        body.mode,
        strength,
        target.pano_id or "-",
        f"{target.lat},{target.lng}" if target.lat is not None else "-",
        headings,
    )
    return build_streetview_images(
        pano_id=target.pano_id,
        lat=target.lat,
        lng=target.lng,
        headings=headings,
    )


@router.post("/guess", response_model=AiGuessResponse)
async def ai_guess(body: AiGuessRequest) -> AiGuessResponse:
    strength = _normalize_strength(body.strength)

    images = _collect_images(body, strength)
    if not images:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="無法取得街景圖（檢查 panoId / 座標、GOOGLE_API_KEY 是否啟用 Street View Static 且未被限制）",
        )

    result = gemini_guess_location(images)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI 無法判讀（檢查 GEMINI_API_KEY）",
        )

    return AiGuessResponse(
        lat=result["lat"],
        lng=result["lng"],
        confidence=result.get("confidence"),
        reasoning=result.get("reasoning"),
    )
