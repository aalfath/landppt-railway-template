"""First-boot and every-boot setup for LandPPT on Railway.

1. Waits for the database (a sibling's private DNS name can take a minute).
2. Under a Postgres advisory lock (polled, so overlapping deploys never run it
   twice), creates tables, applies migrations, imports default templates and
   creates the admin from LANDPPT_BOOTSTRAP_ADMIN_* when no user exists yet.
3. Writes the OpenAI-compatible provider (OPENAI_API_KEY, OPENAI_BASE_URL,
   OPENAI_MODEL) into LandPPT's system settings. A value is written only when
   the Railway variable changed since the last boot, so edits made later in the
   admin UI survive restarts.
Any failure exits non-zero so Railway restarts the service.
"""
import asyncio, hashlib, json, os, sys, time

DB = os.environ.get("DATABASE_URL", "")
STATE = "/data/.railway-seed.json"
LOCK_ID = 7243015


def log(msg):
    print(f"[railway-setup] {msg}", flush=True)


def wait_for_postgres():
    import psycopg2
    url = DB.replace("postgresql+asyncpg://", "postgresql://")
    deadline = time.time() + 300
    while True:
        try:
            conn = psycopg2.connect(url, connect_timeout=5)
            conn.autocommit = True
            return conn
        except Exception as exc:  # DNS or Postgres not ready yet
            if time.time() > deadline:
                log(f"database not reachable after 300 s: {exc}")
                sys.exit(1)
            log(f"waiting for database: {str(exc).strip().splitlines()[0][:120]}")
            time.sleep(3)


def take_lock(conn):
    cur = conn.cursor()
    deadline = time.time() + 600
    while True:
        cur.execute("SELECT pg_try_advisory_lock(%s)", (LOCK_ID,))
        if cur.fetchone()[0]:
            return
        if time.time() > deadline:
            log("timed out waiting for the setup lock")
            sys.exit(1)
        log("another deploy is running setup, waiting")
        time.sleep(2)


def main():
    lock_conn = None
    if DB.startswith(("postgres://", "postgresql://")):
        lock_conn = wait_for_postgres()
        take_lock(lock_conn)

    sys.path.insert(0, "/app/src")
    from landppt import cli as lcli
    from landppt.database.database import AsyncSessionLocal, close_db
    from landppt.database.repositories import UserConfigRepository

    log("migrating database")
    asyncio.run(lcli._run_with_db_close(lcli._migrate())) or sys.exit("migration failed")
    n = asyncio.run(lcli._run_with_db_close(lcli._bootstrap_default_templates()))
    log(f"default templates available: {n}")
    lcli._bootstrap_admin()

    try:
        state = json.load(open(STATE))
    except Exception:
        state = {}
    wanted = {
        "landppt_api_key": ("OPENAI_API_KEY", "password"),
        "landppt_base_url": ("OPENAI_BASE_URL", "url"),
        "landppt_model": ("OPENAI_MODEL", "text"),
        "default_ai_provider": ("LANDPPT_DEFAULT_AI_PROVIDER", "select"),
    }
    defaults = {"LANDPPT_DEFAULT_AI_PROVIDER": "landppt"}

    async def seed():
        changed = []
        try:
            async with AsyncSessionLocal() as session:
                repo = UserConfigRepository(session)
                existing = await repo.get_all_configs(user_id=None) or {}
                for key, (env, ctype) in wanted.items():
                    value = (os.environ.get(env) or defaults.get(env, "")).strip()
                    if not value:
                        continue
                    digest = hashlib.sha256(value.encode()).hexdigest()
                    if state.get(key) == digest and key in existing:
                        continue
                    if not await repo.set_config(user_id=None, key=key, value=value,
                                                 config_type=ctype, category="ai_providers"):
                        raise RuntimeError(f"could not store {key}")
                    state[key] = digest
                    changed.append(key)
                await session.commit()
        finally:
            await close_db()
        return changed

    changed = asyncio.run(seed())
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE)
    log("AI provider settings updated: " + (", ".join(changed) if changed else "none (unchanged)"))
    if not os.environ.get("OPENAI_API_KEY", "").strip():
        log("OPENAI_API_KEY is empty: set it in Railway or in Settings > AI providers before generating slides")
    if lock_conn is not None:
        lock_conn.close()


if __name__ == "__main__":
    main()
