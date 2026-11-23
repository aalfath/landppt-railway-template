# LandPPT for Railway: official image pinned by version and digest.
FROM bradleylzh/landppt:0.5.1@sha256:34f605baf4530c015b0dc7d9a8c939d3ad5b47fe055e8be095a01619d53f58d2

USER root

# All state goes to one Railway volume mounted at /data. The image keeps it
# under /app, so those paths become symlinks into the volume. The baked .env
# (a copy of upstream's .env.example with s3/queue/admin123 defaults) is
# replaced by a small persisted file that the admin UI can still write to.
RUN rm -r /app/data /app/uploads /app/research_reports /app/temp /app/lib /app/.env \
 && ln -s /data/data /app/data \
 && ln -s /data/uploads /app/uploads \
 && ln -s /data/research_reports /app/research_reports \
 && ln -s /data/temp /app/temp \
 && ln -s /data/lib /app/lib \
 && ln -s /data/.env /app/.env \
 && mkdir -p /data && chown landppt:landppt /data

COPY --chmod=0755 start.sh /usr/local/bin/railway-start.sh
COPY --chmod=0644 seed.py /usr/local/lib/landppt-railway/seed.py

# Single-node defaults (no MinIO, Valkey or worker service needed).
ENV WORKERS=1 \
    RELOAD=false \
    DEBUG=false \
    PORT=8000 \
    STORAGE_BACKEND=local \
    LOCAL_STORAGE_ROOT=/app/data/artifacts \
    CACHE_BACKEND=memory \
    TASK_EXECUTION_MODE=inline \
    MALLOC_ARENA_MAX=2 \
    OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    NUMEXPR_MAX_THREADS=1

EXPOSE 8000
HEALTHCHECK NONE
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
CMD ["/opt/venv/bin/python", "run.py"]
