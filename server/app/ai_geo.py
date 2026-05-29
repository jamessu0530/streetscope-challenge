# =============================================================================
# AI 對戰 — 用 Street View Static 圖讓 Gemini 猜經緯度
#
# 流程：
#   1. build_streetview_images()：依 panoId / 座標 + headings 抓 1~4 張街景圖
#   2. gemini_guess_location()：把圖丟給 Gemini，回 {lat, lng, confidence, reasoning}
#
# 設計原則（沿用本專案：嚴格 timeout + 失敗回 None，不可拖垮主流程）。
# =============================================================================

import base64
import json
import logging

import requests

from app.config import GEMINI_API_KEY, GEMINI_MODEL, GOOGLE_API_KEY

logger = logging.getLogger("uvicorn.error")

STREETVIEW_STATIC_URL = "https://maps.googleapis.com/maps/api/streetview"
STREETVIEW_META_URL = (
    "https://maps.googleapis.com/maps/api/streetview/metadata"
)
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/"
    f"models/{GEMINI_MODEL}:generateContent"
)

_PROMPT = (
    "You are an expert GeoGuessr player. Carefully analyze these street view "
    "images. They may show different directions from the same spot, OR a "
    "sequence of points along a route the player walked through. Treat all "
    "images together as evidence for ONE location. Use road signs, "
    "text/language, license plates, driving side, road markings, vegetation, "
    "terrain, architecture, utility poles and sun position to estimate the "
    "single most likely real-world location. "
    "Respond with ONLY JSON containing: lat, lng (decimal degrees), an "
    "optional confidence 0-1, and reasoning. "
    "IMPORTANT: the reasoning field MUST be written in Traditional Chinese "
    "(繁體中文), 2-4 sentences, explaining which visual clues led to your "
    "guess (e.g. 路標文字、車牌、靠左/靠右行駛、建築風格、植被、太陽位置)."
)

_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "lat": {"type": "number"},
        "lng": {"type": "number"},
        "confidence": {"type": "number"},
        "reasoning": {"type": "string"},
    },
    "required": ["lat", "lng"],
}

# Swagger /docs 預設常會填 "string"，不能當成真 panoId
_PLACEHOLDER_PANO_IDS = frozenset(
    {"string", "example", "pano_id", "panoid", "null", "none"}
)


def normalize_pano_id(pano_id: str | None) -> str | None:
    if pano_id is None:
        return None
    s = pano_id.strip()
    if not s or s.lower() in _PLACEHOLDER_PANO_IDS:
        return None
    return s


class StreetViewTarget:
    """實際用來抓圖的 pano 或座標（二擇一）。"""

    __slots__ = ("pano_id", "lat", "lng")

    def __init__(
        self,
        *,
        pano_id: str | None = None,
        lat: float | None = None,
        lng: float | None = None,
    ) -> None:
        self.pano_id = pano_id
        self.lat = lat
        self.lng = lng


def resolve_streetview_target(
    *,
    pano_id: str | None,
    lat: float | None,
    lng: float | None,
) -> StreetViewTarget | None:
    """有效 pano 優先；無效 pano（含 docs 的 \"string\"）則改用地點座標。"""
    pid = normalize_pano_id(pano_id)
    if pid and streetview_imagery_exists(pano_id=pid, lat=None, lng=None):
        return StreetViewTarget(pano_id=pid)
    if lat is not None and lng is not None:
        if streetview_imagery_exists(pano_id=None, lat=lat, lng=lng):
            return StreetViewTarget(lat=lat, lng=lng)
    return None


def streetview_imagery_exists(
    *, pano_id: str | None, lat: float | None, lng: float | None
) -> bool:
    """先打 metadata 確認該點真的有街景，避免抓到灰色 no-imagery 圖。"""
    if not GOOGLE_API_KEY:
        return False
    params: dict = {"key": GOOGLE_API_KEY}
    if pano_id:
        params["pano"] = pano_id
    elif lat is not None and lng is not None:
        params["location"] = f"{lat},{lng}"
    else:
        return False
    try:
        r = requests.get(STREETVIEW_META_URL, params=params, timeout=8)
        return r.status_code == 200 and r.json().get("status") == "OK"
    except (requests.RequestException, ValueError):
        return False


def build_streetview_images(
    *,
    pano_id: str | None,
    lat: float | None,
    lng: float | None,
    headings: list[int],
    width: int = 640,
    height: int = 400,
    fov: int = 90,
) -> list[bytes]:
    """抓 len(headings) 張 JPEG bytes。抓不到的角度略過。"""
    if not GOOGLE_API_KEY:
        logger.warning("ai_geo: GOOGLE_API_KEY 未設定，無法抓街景圖")
        return []

    out: list[bytes] = []
    for h in headings:
        params: dict = {
            "size": f"{width}x{height}",
            "heading": h,
            "pitch": 0,
            "fov": fov,
            "key": GOOGLE_API_KEY,
        }
        if pano_id:
            params["pano"] = pano_id
        elif lat is not None and lng is not None:
            params["location"] = f"{lat},{lng}"
        else:
            continue
        try:
            r = requests.get(STREETVIEW_STATIC_URL, params=params, timeout=10)
            ctype = r.headers.get("content-type", "")
            if r.status_code == 200 and r.content and ctype.startswith("image"):
                out.append(r.content)
            else:
                logger.warning(
                    "ai_geo: 街景圖抓取失敗 status=%s ctype=%s", r.status_code, ctype
                )
        except requests.RequestException as e:
            logger.warning("ai_geo: 街景圖請求例外 %s", e)
    return out


def sample_pano_trail(trail: list[str], max_points: int = 8) -> list[str]:
    """去重連續重複後，沿路徑均勻取樣最多 max_points 個 pano（保留頭尾）。"""
    cleaned: list[str] = []
    for raw in trail:
        pid = normalize_pano_id(raw)
        if pid and (not cleaned or cleaned[-1] != pid):
            cleaned.append(pid)

    if len(cleaned) <= max_points:
        return cleaned

    step = (len(cleaned) - 1) / (max_points - 1)
    idxs = sorted({round(i * step) for i in range(max_points)})
    return [cleaned[i] for i in idxs]


def build_trail_images(
    trail: list[str],
    *,
    max_points: int = 8,
) -> list[bytes]:
    """move 模式：沿路每個取樣 pano 抓一張街景圖（朝向 0°）。"""
    panos = sample_pano_trail(trail, max_points=max_points)
    out: list[bytes] = []
    for pid in panos:
        imgs = build_streetview_images(
            pano_id=pid, lat=None, lng=None, headings=[0]
        )
        out.extend(imgs)
    return out


def gemini_guess_location(images: list[bytes]) -> dict | None:
    """把圖丟給 Gemini，回 {lat, lng, confidence?, reasoning?}；失敗回 None。"""
    if not GEMINI_API_KEY:
        logger.warning("ai_geo: GEMINI_API_KEY 未設定")
        return None
    if not images:
        return None

    parts: list[dict] = [{"text": _PROMPT}]
    for img in images:
        parts.append(
            {
                "inline_data": {
                    "mime_type": "image/jpeg",
                    "data": base64.b64encode(img).decode("ascii"),
                }
            }
        )

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": _RESPONSE_SCHEMA,
        },
    }

    try:
        r = requests.post(
            GEMINI_URL,
            params={"key": GEMINI_API_KEY},
            json=payload,
            timeout=20,
        )
    except requests.RequestException as e:
        logger.warning("ai_geo: Gemini 請求例外 %s", e)
        return None

    if r.status_code != 200:
        logger.warning("ai_geo: Gemini 回應 %s %s", r.status_code, r.text[:300])
        return None

    try:
        text = r.json()["candidates"][0]["content"]["parts"][0]["text"]
        data = json.loads(text)
        lat = float(data["lat"])
        lng = float(data["lng"])
    except (KeyError, IndexError, ValueError, TypeError) as e:
        logger.warning("ai_geo: Gemini 回應解析失敗 %s", e)
        return None

    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        logger.warning("ai_geo: Gemini 回傳座標超出範圍 lat=%s lng=%s", lat, lng)
        return None

    conf = data.get("confidence")
    reasoning = data.get("reasoning")
    return {
        "lat": lat,
        "lng": lng,
        "confidence": float(conf) if isinstance(conf, (int, float)) else None,
        "reasoning": str(reasoning) if reasoning else None,
    }
