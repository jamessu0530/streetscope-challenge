from contextlib import asynccontextmanager

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pymongo.errors import ServerSelectionTimeoutError

from app.config import PORT
from app.database import ensure_indexes, get_client
from app.routes import ai, auth, leaderboard, memes, realtime


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        get_client().admin.command("ping")
        ensure_indexes()
    except ServerSelectionTimeoutError as e:
        raise RuntimeError(
            "Cannot reach MongoDB Atlas. Check MONGODB_URI and Network Access (IP whitelist)."
        ) from e
    yield


app = FastAPI(
    title="GeoGuesser Auth API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(ai.router)
app.include_router(leaderboard.router)
app.include_router(memes.router)
app.include_router(realtime.router)


@app.get("/health")
async def health():
    get_client().admin.command("ping")
    return {"ok": True, "mongodb": "connected"}


# API 路由須在 static mount 之前註冊，否則 /health 可能被 StaticFiles 吃掉
_public_dir = Path(__file__).resolve().parents[2] / "public"
if _public_dir.is_dir():
    app.mount("/", StaticFiles(directory=str(_public_dir), html=True), name="public")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload=True)
