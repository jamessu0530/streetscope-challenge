import json
import logging

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.database import users_collection
from app.duel_manager import duel_manager
from app.realtime_hub import hub
from app.security import SESSION_SUPERSEDED_MESSAGE, decode_access_token

router = APIRouter(tags=["realtime"])
_log = logging.getLogger("uvicorn.error")


def _user_from_token(token: str) -> tuple[dict | None, str | None]:
    claims = decode_access_token(token.strip())
    if not claims:
        return None, None
    user_id = claims["sub"]
    try:
        oid = ObjectId(user_id)
    except InvalidId:
        return None, None
    doc = users_collection().find_one({"_id": oid})
    if doc is None:
        return None, None
    if int(doc.get("sessionVersion") or 0) != int(claims["sv"]):
        return None, SESSION_SUPERSEDED_MESSAGE
    return doc, None


@router.websocket("/ws")
async def websocket_lobby(
    websocket: WebSocket,
    token: str = Query(default=""),
) -> None:
    doc, reject_reason = _user_from_token(token)
    if doc is None:
        await websocket.close(
            code=4001 if reject_reason else 1008,
            reason=reject_reason or "Unauthorized",
        )
        return

    user_id = str(doc["_id"])
    display_name = str(doc.get("displayName") or "Player")

    await websocket.accept()
    await hub.register(websocket, user_id, display_name)
    await hub.send_presence_to(websocket)
    await duel_manager.on_connect(user_id)

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if not isinstance(payload, dict):
                continue
            await hub.handle_message(user_id, payload)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        _log.warning("WebSocket closed for %s: %s", user_id, e)
    finally:
        await duel_manager.on_disconnect(user_id)
        await hub.unregister(user_id, websocket)
