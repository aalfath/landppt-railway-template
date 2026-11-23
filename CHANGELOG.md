# Changelog

## 0.5.1-railway.1 (2026-11-23)

First release of the Railway template.

- LandPPT `0.5.1` (`bradleylzh/landppt:0.5.1@sha256:34f605baf4530c015b0dc7d9a8c939d3ad5b47fe055e8be095a01619d53f58d2`).
- Single-node mode: Postgres, local storage on the `/data` volume, in-memory cache, inline tasks, 1 worker.
- The admin is created on first boot from a generated password, and self-registration is off.
- The OpenAI-compatible provider is seeded from `OPENAI_API_KEY`, `OPENAI_BASE_URL` and `OPENAI_MODEL`.
- Uploads, generated files, the image cache and the runtime `.env` are persisted on the volume.
