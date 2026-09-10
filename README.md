## Docker Build and Run

### 1. Build the Docker image

From the repository root:

```bash
docker build -t vulntracker-app:task4 .
```

### 2. Run the container

The application uses SQLite by default, so no external database configuration is required for a local Docker run.

```bash
docker run --rm -p 8000:8000 vulntracker-app:task4
```

The application will be available at:

```text
http://localhost:8000
```

### 3. Health check

Verify that the application is running:

```text
http://localhost:8000/health
```

The expected response is:

```json
{
  "status": "ok"
}
```
