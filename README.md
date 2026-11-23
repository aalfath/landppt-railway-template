[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/landppt?utm_medium=integration&utm_source=button&utm_campaign=landppt)

# LandPPT on Railway

One-click Railway template for [LandPPT](https://github.com/sligter/LandPPT), an open-source web app that turns a topic or a document (PDF, Word, Markdown, web pages) into a slide deck with an LLM. It comes with 25 built-in slide templates and styles, an online editor, and export to PDF, HTML and image-based PPTX.

**Version:** LandPPT `0.5.1`, from the official image `bradleylzh/landppt:0.5.1@sha256:34f605baf4530c015b0dc7d9a8c939d3ad5b47fe055e8be095a01619d53f58d2`. The image is pinned by version and digest in this repo's `Dockerfile`.

## What gets deployed

| Service | What it does |
|---|---|
| **LandPPT** | The web app and API (FastAPI and Uvicorn on port 8000, health check `/health`). It is built from this repo, with a volume at `/data` for uploads, generated decks, the image cache and runtime settings. |
| **Postgres** | Railway's PostgreSQL. It stores users, projects, slides, templates and settings. |

Upstream's full Compose stack also runs Valkey, MinIO, a separate worker and a PPTX renderer for multi-node setups. For a single service they aren't needed, so this template runs LandPPT in single-node mode: local file storage on the volume, an in-memory cache and inline background tasks.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `OPENAI_API_KEY` | *(you enter it)* | The API key for any OpenAI-compatible LLM endpoint (OpenAI, OpenRouter, DeepSeek, Groq, a self-hosted vLLM or Ollama, and so on). |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | The base URL of that OpenAI-compatible API. |
| `OPENAI_MODEL` | `gpt-4.1-mini` | The model name to use. |
| `LANDPPT_BOOTSTRAP_ADMIN_USERNAME` | `admin` | The admin account created on first boot. |
| `LANDPPT_BOOTSTRAP_ADMIN_PASSWORD` | generated (`secret(24)`) | The admin password. Find it in the LandPPT service's **Variables** tab. |
| `SECRET_KEY` | generated (`secret(64)`) | Signs sessions. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Points at the Postgres service. |
| `PORT` | `8000` | The port the app listens on. |

On every boot, the start script writes `OPENAI_API_KEY`, `OPENAI_BASE_URL` and `OPENAI_MODEL` into LandPPT's system AI provider settings, but only when the Railway variable has changed since the last boot. Changes you make later in **Settings → AI providers** are kept. Anthropic, Gemini, Ollama, image providers and web research (Tavily or SearXNG) can be set up in the admin UI afterwards.

## After deploying

1. Open the public URL and sign in as `admin` with the generated `LANDPPT_BOOTSTRAP_ADMIN_PASSWORD`.
2. Create a project: enter a topic or upload a document. LandPPT drafts an outline and then the slides.
3. Export to PDF, HTML or image-based PPTX. Editable PPTX export uses the commercial Apryse SDK and needs your own `APRYSE_LICENSE_KEY`. It is optional and not set.

Self-registration is turned off (`ENABLE_USER_REGISTRATION=false`), because every user would spend your LLM key. To let others sign up, set it to `true` and consider `INVITE_CODE_REQUIRED_FOR_REGISTRATION=true`.

## Resources

The app idles at about 300 MB of RAM with one Uvicorn worker. A Chromium PDF or image export peaks at about 420 MB, so it fits Railway's 0.5 GB per-service limit on the Free and Trial plans. For long decks, narration or video export, give the service 1 GB or more (Hobby plan). Set `WORKERS` to more than 1 only when the service has at least 1 GB per worker.

## How updates reach you

This template builds from this repo's `main` branch. When we bump LandPPT here, Railway shows an **update available** notice on your project, and you choose when to apply it. Read [`CHANGELOG.md`](CHANGELOG.md) first, because breaking changes are listed at the top of each entry. Database migrations run automatically on start, under a lock.

## Files

- `Dockerfile`: the pinned upstream image. It moves `/app` state onto the `/data` volume and sets single-node defaults.
- `start.sh`: prepares the volume, drops to the unprivileged `landppt` user, applies safe defaults and starts the upstream entrypoint.
- `seed.py`: waits for Postgres, migrates under an advisory lock, creates the admin and default templates, and seeds the AI provider.

LandPPT is © its authors under the Apache-2.0 licence. This wrapper is not affiliated with the LandPPT project.
