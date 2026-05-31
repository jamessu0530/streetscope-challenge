"""WebSocket duel rooms: invite, shared places, per-round score sync."""

from __future__ import annotations

import asyncio
import json
import logging
import secrets
import uuid
from dataclasses import dataclass, field
from typing import Any

from app.realtime_hub import hub

_log = logging.getLogger("uvicorn.error")


@dataclass
class DuelInvite:
    invite_id: str
    from_user_id: str
    from_display_name: str
    to_user_id: str
    settings: dict[str, Any]


@dataclass
class DuelRoom:
    room_id: str
    host_id: str
    guest_id: str
    host_name: str
    guest_name: str
    settings: dict[str, Any]
    places: list[dict[str, Any]] = field(default_factory=list)
    round_index: int = 0
    round_guesses: dict[int, dict[str, dict[str, Any]]] = field(
        default_factory=dict
    )
    total_scores: dict[str, int] = field(default_factory=dict)
    completed_rounds: set[int] = field(default_factory=set)

    def player_ids(self) -> list[str]:
        return [self.host_id, self.guest_id]

    def opponent_of(self, user_id: str) -> str:
        return self.guest_id if user_id == self.host_id else self.host_id

    def display_name(self, user_id: str) -> str:
        if user_id == self.host_id:
            return self.host_name
        return self.guest_name


class DuelManager:
    def __init__(self) -> None:
        self._invites: dict[str, DuelInvite] = {}
        self._rooms: dict[str, DuelRoom] = {}
        self._user_room: dict[str, str] = {}
        self._lock = asyncio.Lock()

    async def handle(self, user_id: str, payload: dict[str, Any]) -> None:
        msg_type = payload.get("type")
        if msg_type == "duel_invite":
            await self._invite(user_id, payload)
        elif msg_type == "duel_invite_reply":
            await self._invite_reply(user_id, payload)
        elif msg_type == "duel_places":
            await self._submit_places(user_id, payload)
        elif msg_type == "duel_round_submit":
            await self._round_submit(user_id, payload)
        elif msg_type == "duel_advance_round":
            await self._advance_round(user_id, payload)

    async def on_disconnect(self, user_id: str) -> None:
        async with self._lock:
            room_id = self._user_room.pop(user_id, None)
            if not room_id:
                return
            room = self._rooms.get(room_id)
            if room is None:
                return
            for pid in room.player_ids():
                self._user_room.pop(pid, None)
            opp = room.opponent_of(user_id)
        await self._send_user(
            opp,
            {
                "type": "duel_cancelled",
                "roomId": room_id,
                "reason": "opponent_disconnected",
            },
        )

    async def _invite(self, from_user_id: str, payload: dict[str, Any]) -> None:
        to_user_id = str(payload.get("toUserId") or "").strip()
        settings = payload.get("settings")
        if not to_user_id or to_user_id == from_user_id:
            await self._send_user(
                from_user_id,
                {"type": "duel_error", "message": "invalid_target"},
            )
            return
        if not isinstance(settings, dict):
            await self._send_user(
                from_user_id,
                {"type": "duel_error", "message": "invalid_settings"},
            )
            return
        async with self._lock:
            if to_user_id in self._user_room or from_user_id in self._user_room:
                await self._send_user(
                    from_user_id,
                    {"type": "duel_error", "message": "player_busy"},
                )
                return

        client = hub.get_client(from_user_id)
        if client is None:
            return

        invite_id = secrets.token_urlsafe(8)
        self._invites[invite_id] = DuelInvite(
            invite_id=invite_id,
            from_user_id=from_user_id,
            from_display_name=client.display_name,
            to_user_id=to_user_id,
            settings=settings,
        )

        await self._send_user(
            to_user_id,
            {
                "type": "duel_invite_incoming",
                "inviteId": invite_id,
                "from": {
                    "id": from_user_id,
                    "displayName": client.display_name,
                },
                "settings": settings,
            },
        )
        await self._send_user(
            from_user_id,
            {
                "type": "duel_invite_sent",
                "inviteId": invite_id,
                "toUserId": to_user_id,
            },
        )

    async def _invite_reply(self, user_id: str, payload: dict[str, Any]) -> None:
        invite_id = str(payload.get("inviteId") or "").strip()
        accept = bool(payload.get("accept"))
        invite = self._invites.pop(invite_id, None)
        if invite is None or invite.to_user_id != user_id:
            await self._send_user(
                user_id,
                {"type": "duel_error", "message": "invite_expired"},
            )
            return

        if not accept:
            await self._send_user(
                invite.from_user_id,
                {"type": "duel_invite_declined", "inviteId": invite_id},
            )
            return

        host_client = hub.get_client(invite.from_user_id)
        guest_client = hub.get_client(invite.to_user_id)
        if host_client is None or guest_client is None:
            await self._send_user(
                invite.from_user_id,
                {"type": "duel_error", "message": "player_offline"},
            )
            await self._send_user(
                invite.to_user_id,
                {"type": "duel_error", "message": "player_offline"},
            )
            return

        room_id = str(uuid.uuid4())
        room = DuelRoom(
            room_id=room_id,
            host_id=invite.from_user_id,
            guest_id=invite.to_user_id,
            host_name=host_client.display_name,
            guest_name=guest_client.display_name,
            settings=invite.settings,
        )

        async with self._lock:
            if invite.from_user_id in self._user_room or invite.to_user_id in self._user_room:
                await self._send_user(
                    invite.from_user_id,
                    {"type": "duel_error", "message": "player_busy"},
                )
                await self._send_user(
                    invite.to_user_id,
                    {"type": "duel_error", "message": "player_busy"},
                )
                return
            self._rooms[room_id] = room
            self._user_room[invite.from_user_id] = room_id
            self._user_room[invite.to_user_id] = room_id

        ready_payload = {
            "type": "duel_room_ready",
            "roomId": room_id,
            "settings": invite.settings,
        }
        await self._send_user(
            invite.from_user_id,
            {
                **ready_payload,
                "role": "host",
                "opponent": {
                    "id": invite.to_user_id,
                    "displayName": guest_client.display_name,
                },
            },
        )
        await self._send_user(
            invite.to_user_id,
            {
                **ready_payload,
                "role": "guest",
                "opponent": {
                    "id": invite.from_user_id,
                    "displayName": host_client.display_name,
                },
            },
        )

    async def _submit_places(self, user_id: str, payload: dict[str, Any]) -> None:
        room_id = str(payload.get("roomId") or "").strip()
        places = payload.get("places")
        async with self._lock:
            room = self._rooms.get(room_id)
            if room is None or room.host_id != user_id:
                return
            if not isinstance(places, list) or len(places) == 0:
                return
            room.places = [p for p in places if isinstance(p, dict)]

        await self._broadcast_duel_start(room_id)

    async def _broadcast_duel_start(self, room_id: str) -> None:
        async with self._lock:
            room = self._rooms.get(room_id)
            if room is None or not room.places:
                return
            host_id, guest_id = room.host_id, room.guest_id
            host_name, guest_name = room.host_name, room.guest_name
            settings = room.settings
            places = list(room.places)

        for pid, opp_id, opp_name in (
            (host_id, guest_id, guest_name),
            (guest_id, host_id, host_name),
        ):
            await self._send_user(
                pid,
                {
                    "type": "duel_start",
                    "roomId": room_id,
                    "settings": settings,
                    "places": places,
                    "opponent": {"id": opp_id, "displayName": opp_name},
                },
            )

    async def _round_submit(self, user_id: str, payload: dict[str, Any]) -> None:
        room_id = str(payload.get("roomId") or "").strip()
        round_index = self._parse_round_index(payload)
        if round_index is None:
            _log.warning("duel submit: missing or invalid round")
            return
        score = int(payload.get("score") or 0)
        distance_km = payload.get("distanceKm")

        async with self._lock:
            room = self._rooms.get(room_id)
            if room is None:
                _log.warning("duel submit: room missing %s", room_id)
                return
            if user_id not in room.player_ids():
                _log.warning("duel submit: user %s not in room", user_id)
                return
            if round_index != room.round_index:
                _log.warning(
                    "duel submit: round mismatch got=%s expected=%s",
                    round_index,
                    room.round_index,
                )
                return

            guesses = room.round_guesses.setdefault(round_index, {})
            guesses[user_id] = {
                "score": score,
                "distanceKm": distance_km,
                "guessedLat": payload.get("guessedLat"),
                "guessedLng": payload.get("guessedLng"),
            }
            opp_id = room.opponent_of(user_id)
            ready_to_close = len(guesses) >= 2
            already_done = round_index in room.completed_rounds

        await self._send_user(
            user_id,
            {"type": "duel_round_ack", "roomId": room_id, "round": round_index},
        )

        client = hub.get_client(user_id)
        display_name = (
            client.display_name if client else room.display_name(user_id)
        )
        await self._send_user(
            opp_id,
            {
                "type": "duel_opponent_submitted",
                "roomId": room_id,
                "round": round_index,
                "opponent": {"id": user_id, "displayName": display_name},
            },
        )

        if already_done:
            await self._broadcast_round_complete(room_id, round_index)
            return

        if not ready_to_close:
            return

        await self._broadcast_round_complete(room_id, round_index)

    @staticmethod
    def _parse_round_index(payload: dict[str, Any]) -> int | None:
        round_raw = payload.get("round")
        if round_raw is None:
            return None
        try:
            return int(round_raw)
        except (TypeError, ValueError):
            return None

    async def _advance_round(self, user_id: str, payload: dict[str, Any]) -> None:
        """玩家按下「下一回合」→ 通知對手同步進入。"""
        room_id = str(payload.get("roomId") or "").strip()
        finished_round = self._parse_round_index(payload)
        if not room_id or finished_round is None:
            _log.warning("duel advance: missing roomId or round")
            return

        async with self._lock:
            room = self._rooms.get(room_id)
            if room is None:
                _log.warning("duel advance: room missing %s", room_id)
                return
            if user_id not in room.player_ids():
                return
            rounds_total = int(room.settings.get("roundsPerGame") or 5)
            if finished_round >= rounds_total - 1:
                return
            if finished_round not in room.completed_rounds:
                _log.warning(
                    "duel advance: round %s not completed in room %s",
                    finished_round,
                    room_id,
                )
                return
            if finished_round + 1 != room.round_index:
                _log.warning(
                    "duel advance: round %s stale (server at %s)",
                    finished_round,
                    room.round_index,
                )
                return
            opp_id = room.opponent_of(user_id)

        await self._send_user(
            opp_id,
            {
                "type": "duel_sync_next_round",
                "roomId": room_id,
                "round": finished_round,
            },
        )

    async def _broadcast_round_complete(self, room_id: str, round_index: int) -> None:
        async with self._lock:
            room = self._rooms.get(room_id)
            if room is None:
                return
            guesses = room.round_guesses.get(round_index)
            if not guesses or len(guesses) < 2:
                return
            if round_index in room.completed_rounds:
                # 已結算過：仍重播給雙方（例如重連後）
                pass
            else:
                room.completed_rounds.add(round_index)
                for pid in room.player_ids():
                    if pid in guesses:
                        room.total_scores[pid] = room.total_scores.get(pid, 0) + int(
                            guesses[pid]["score"]
                        )

            player_payloads = []
            for pid in room.player_ids():
                if pid not in guesses:
                    continue
                g = guesses[pid]
                player_payloads.append(
                    {
                        "id": pid,
                        "displayName": room.display_name(pid),
                        "score": g["score"],
                        "distanceKm": g.get("distanceKm"),
                    }
                )

            rounds_total = int(room.settings.get("roundsPerGame") or 5)
            match_end = round_index >= rounds_total - 1
            winner_id: str | None = None
            if match_end:
                host_total = room.total_scores.get(room.host_id, 0)
                guest_total = room.total_scores.get(room.guest_id, 0)
                if host_total > guest_total:
                    winner_id = room.host_id
                elif guest_total > host_total:
                    winner_id = room.guest_id

            payload = {
                "type": "duel_round_complete",
                "roomId": room_id,
                "round": round_index,
                "players": player_payloads,
                "totals": [
                    {
                        "id": room.host_id,
                        "displayName": room.host_name,
                        "totalScore": room.total_scores.get(room.host_id, 0),
                    },
                    {
                        "id": room.guest_id,
                        "displayName": room.guest_name,
                        "totalScore": room.total_scores.get(room.guest_id, 0),
                    },
                ],
                "matchEnd": match_end,
                "winnerId": winner_id,
            }

            if match_end:
                self._rooms.pop(room_id, None)
                for pid in room.player_ids():
                    self._user_room.pop(pid, None)
            else:
                room.round_index += 1
                room.round_guesses.clear()

        for pid in room.player_ids():
            await self._send_user(pid, payload)

    async def _send_user(self, user_id: str, payload: dict[str, Any]) -> None:
        client = hub.get_client(user_id)
        if client is None:
            return
        try:
            await client.websocket.send_text(json.dumps(payload))
        except Exception:
            pass


duel_manager = DuelManager()
