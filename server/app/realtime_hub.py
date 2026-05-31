"""In-memory WebSocket hub: presence list + lobby chat broadcast."""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass

from fastapi import WebSocket

from app.database import utc_now
from app.security import SESSION_SUPERSEDED_MESSAGE

_log = logging.getLogger("uvicorn.error")


@dataclass
class ConnectedClient:
    user_id: str
    display_name: str
    websocket: WebSocket


class RealtimeHub:
    def __init__(self) -> None:
        self._clients: dict[str, ConnectedClient] = {}
        self._lock = asyncio.Lock()

    def get_client(self, user_id: str) -> ConnectedClient | None:
        return self._clients.get(user_id)

    def snapshot(self) -> list[dict[str, str]]:
        return [
            {"id": c.user_id, "displayName": c.display_name}
            for c in self._clients.values()
        ]

    async def register(
        self,
        websocket: WebSocket,
        user_id: str,
        display_name: str,
    ) -> None:
        async with self._lock:
            previous = self._clients.get(user_id)
            if previous is not None and previous.websocket is not websocket:
                try:
                    await previous.websocket.close(
                        code=4001,
                        reason=SESSION_SUPERSEDED_MESSAGE[:123],
                    )
                except Exception:
                    pass
            self._clients[user_id] = ConnectedClient(
                user_id=user_id,
                display_name=display_name,
                websocket=websocket,
            )
        await self._broadcast_presence()

    async def unregister(self, user_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            current = self._clients.get(user_id)
            if current is None or current.websocket is not websocket:
                return
            del self._clients[user_id]
        await self._broadcast_presence()

    async def disconnect_user(
        self,
        user_id: str,
        *,
        code: int = 1000,
        reason: str = "",
    ) -> None:
        async with self._lock:
            client = self._clients.pop(user_id, None)
        if client is None:
            return
        try:
            await client.websocket.close(code=code, reason=reason[:123])
        except Exception:
            pass
        await self._broadcast_presence()

    async def update_display_name(self, user_id: str, display_name: str) -> None:
        async with self._lock:
            client = self._clients.get(user_id)
            if client is None:
                return
            client.display_name = display_name
        await self._broadcast_presence()

    async def send_presence_to(self, websocket: WebSocket) -> None:
        await websocket.send_text(
            json.dumps({"type": "presence", "players": self.snapshot()})
        )

    async def handle_message(self, user_id: str, payload: dict) -> None:
        msg_type = payload.get("type")
        if isinstance(msg_type, str) and msg_type.startswith("duel_"):
            from app.duel_manager import duel_manager

            await duel_manager.handle(user_id, payload)
            return

        if msg_type == "ping":
            async with self._lock:
                client = self._clients.get(user_id)
            if client is None:
                return
            try:
                await client.websocket.send_text(json.dumps({"type": "pong"}))
            except Exception:
                pass
            return

        if msg_type != "chat":
            return

        text = str(payload.get("text") or "").strip()
        if not text or len(text) > 500:
            return

        async with self._lock:
            client = self._clients.get(user_id)
        if client is None:
            return

        await self._broadcast(
            {
                "type": "chat",
                "from": {
                    "id": client.user_id,
                    "displayName": client.display_name,
                },
                "text": text,
                "at": utc_now().isoformat(),
            }
        )

    async def _broadcast_presence(self) -> None:
        await self._broadcast({"type": "presence", "players": self.snapshot()})

    async def _broadcast(self, payload: dict) -> None:
        message = json.dumps(payload)
        async with self._lock:
            clients = list(self._clients.values())
        dead: list[str] = []
        for client in clients:
            try:
                await client.websocket.send_text(message)
            except Exception:
                dead.append(client.user_id)
        if dead:
            async with self._lock:
                for user_id in dead:
                    self._clients.pop(user_id, None)


hub = RealtimeHub()
