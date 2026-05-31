import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
from jose import JWTError, jwt

from app.config import JWT_ALGORITHM, JWT_EXPIRE_DAYS, JWT_SECRET

SESSION_SUPERSEDED_MESSAGE = "帳號已在其他裝置登入，請重新登入"


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(user_id: str, session_version: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRE_DAYS)
    payload = {"sub": user_id, "exp": expire, "sv": int(session_version)}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def generate_reset_token() -> str:
    """8 位英數重設碼，方便在 App 手動輸入。"""
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "".join(secrets.choice(alphabet) for _ in range(8))


def hash_reset_token(token: str) -> str:
    return hashlib.sha256(token.strip().upper().encode("utf-8")).hexdigest()


def verify_reset_token(plain: str, hashed: str) -> bool:
    return hash_reset_token(plain) == hashed


def decode_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        sub = payload.get("sub")
        if not isinstance(sub, str) or not sub:
            return None
        sv = payload.get("sv")
        return {"sub": sub, "sv": int(sv) if sv is not None else 0}
    except JWTError:
        return None


def decode_user_id(token: str) -> str | None:
    claims = decode_access_token(token)
    return claims["sub"] if claims else None
