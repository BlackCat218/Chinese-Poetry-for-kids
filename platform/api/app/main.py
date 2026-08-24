from contextlib import asynccontextmanager
import json
from os import getenv

from fastapi import Depends, FastAPI, Header, HTTPException, status
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from psycopg_pool import ConnectionPool


DATABASE_URL = getenv("DATABASE_URL", "")
ADMIN_API_TOKEN = getenv("ADMIN_API_TOKEN", "change-me-before-sharing")
pool: ConnectionPool | None = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global pool
    pool = ConnectionPool(conninfo=DATABASE_URL, open=True)
    yield
    if pool is not None:
        pool.close()


app = FastAPI(title="Chinese Poetry Content API", version="0.1.0", lifespan=lifespan)


def require_admin(x_admin_token: str | None = Header(default=None)) -> None:
    if x_admin_token != ADMIN_API_TOKEN:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin token")


@app.get("/health")
def health() -> dict[str, str]:
    if pool is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database pool unavailable")
    with pool.connection() as connection, connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        cursor.fetchone()
    return {"status": "ok"}


@app.get("/admin/content-summary", dependencies=[Depends(require_admin)])
def content_summary() -> dict[str, int]:
    if pool is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database pool unavailable")
    with pool.connection() as connection, connection.cursor() as cursor:
        cursor.execute("SELECT COUNT(*) FROM poems")
        poem_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM poems WHERE status = 'published'")
        published_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM quiz_questions WHERE status = 'published'")
        question_count = cursor.fetchone()[0]
    return {"poems": poem_count, "published_poems": published_count, "published_questions": question_count}


class PoemDraft(BaseModel):
    slug: str = Field(pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    title: str = Field(min_length=1, max_length=100)
    author_name: str = Field(min_length=1, max_length=100)
    dynasty_name: str = Field(min_length=1, max_length=50)
    body: str = Field(min_length=1)
    pinyin_lines: list[str] = []
    brief_analysis: str | None = None
    detailed_analysis: str | None = None
    creation_background: str | None = None
    source_reference: str | None = None


@app.get("/admin/poems", dependencies=[Depends(require_admin)])
def list_poems(status_filter: str | None = None) -> list[dict[str, str]]:
    if pool is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database pool unavailable")
    sql = """
        SELECT poems.id::text, poems.slug, poems.title, poems.status::text, authors.name, dynasties.name
        FROM poems
        LEFT JOIN authors ON authors.id = poems.author_id
        LEFT JOIN dynasties ON dynasties.id = poems.dynasty_id
    """
    params: tuple[str, ...] = ()
    if status_filter:
        sql += " WHERE poems.status = %s"
        params = (status_filter,)
    sql += " ORDER BY poems.updated_at DESC LIMIT 100"
    with pool.connection() as connection, connection.cursor() as cursor:
        cursor.execute(sql, params)
        return [
            {"id": row[0], "slug": row[1], "title": row[2], "status": row[3], "author": row[4] or "", "dynasty": row[5] or ""}
            for row in cursor.fetchall()
        ]


@app.post("/admin/poems", status_code=status.HTTP_201_CREATED, dependencies=[Depends(require_admin)])
def create_poem(draft: PoemDraft) -> dict[str, str]:
    if len(draft.pinyin_lines) not in (0, len(draft.body.splitlines())):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="pinyin_lines must match poem body line count")
    if pool is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database pool unavailable")
    with pool.connection() as connection, connection.cursor() as cursor:
        cursor.execute("INSERT INTO dynasties (name) VALUES (%s) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id", (draft.dynasty_name,))
        dynasty_id = cursor.fetchone()[0]
        cursor.execute(
            "INSERT INTO authors (name, dynasty_id) VALUES (%s, %s) ON CONFLICT (name, dynasty_id) DO UPDATE SET name = EXCLUDED.name RETURNING id",
            (draft.author_name, dynasty_id),
        )
        author_id = cursor.fetchone()[0]
        cursor.execute(
            """
            INSERT INTO poems (slug, title, author_id, dynasty_id, body, pinyin_lines, brief_analysis, detailed_analysis, creation_background, source_reference, status)
            VALUES (%s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s, %s, 'draft')
            RETURNING id::text
            """,
            (draft.slug, draft.title, author_id, dynasty_id, draft.body, json.dumps(draft.pinyin_lines, ensure_ascii=False), draft.brief_analysis, draft.detailed_analysis, draft.creation_background, draft.source_reference),
        )
        poem_id = cursor.fetchone()[0]
    return {"id": poem_id, "status": "draft"}


@app.patch("/admin/poems/{poem_id}/publish", dependencies=[Depends(require_admin)])
def publish_poem(poem_id: str) -> dict[str, str]:
    if pool is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database pool unavailable")
    with pool.connection() as connection, connection.cursor() as cursor:
        cursor.execute("UPDATE poems SET status = 'published', updated_at = now() WHERE id = %s RETURNING id::text", (poem_id,))
        row = cursor.fetchone()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Poem not found")
    return {"id": row[0], "status": "published"}


app.mount("/admin", StaticFiles(directory="app/admin", html=True), name="admin-ui")