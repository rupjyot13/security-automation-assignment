FROM python:3.11.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN groupadd --system appuser && useradd --system --gid appuser --home-dir /app appuser && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD python -c "import socket; s=socket.create_connection(('127.0.0.1', 8000), 2); s.close()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
