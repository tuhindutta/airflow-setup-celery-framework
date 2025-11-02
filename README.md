# Airflow Celery Framework — Automated CI/CD Setup via Jenkins

## Overview

This repository provides a **framework to deploy Apache Airflow with CeleryExecutor** using Docker Compose, with full automation through **Jenkins CI/CD**. It extends the official Airflow image to include **custom Python dependencies from a private Nexus repository**, supporting both Linux and Windows Jenkins agents.

The goal: one-click Airflow deployment that securely integrates private dependencies and maintains environment consistency across teams.

---

## Architecture

```
Jenkins CI/CD
   │
   ├─ Clones repo → prepares workspace
   ├─ Injects Nexus credentials (via Jenkins creds or params)
   ├─ Downloads requirements → stages deployment directory
   ├─ Builds Airflow Docker image using secrets for Nexus access
   └─ Launches docker-compose to spin up full Airflow Celery stack

Airflow Stack (Docker Compose)
  ├─ airflow-scheduler
  ├─ airflow-worker(s)
  ├─ airflow-triggerer
  ├─ airflow-apiserver
  ├─ airflow-dag-processor
  ├─ postgres (metadata DB)
  ├─ redis (Celery broker)
  └─ flower (optional UI)
```

**Tech Highlights:**

* **Airflow Base Image:** apache/airflow:3.1.0 (can be adjusted)
* **Executor:** CeleryExecutor with Redis as broker and PostgreSQL as backend
* **Secrets:** Injected dynamically during build (not baked into image)
* **Build System:** Docker BuildKit (for secret mounts)
* **Deployment:** Triggered by Jenkins pipeline
* **Compatibility:** Works on both Unix and Windows Jenkins agents

---

## Repository Structure

```
<root>/
├─ docker-compose.yaml        # Defines complete Airflow + Redis + Postgres + Celery stack
├─ Dockerfile                 # Extends official Airflow image, installs dependencies from Nexus
├─ .env                       # Defines Airflow UID and base image
├─ requirements.txt            # Public Python dependencies
├─ custom_requirements.txt     # Private dependencies (via Nexus)
├─ jenkins/Jenkinsfile         # Jenkins CI/CD pipeline definition
├─ dags/                       # DAGs directory
├─ plugins/                    # Custom plugins
├─ config/                     # Airflow config mounts
└─ scripts/                    # Optional init and helper scripts
```

---

## Component Details

### `.env`

Defines base image and Airflow UID for consistent file ownership.

```bash
AIRFLOW_IMAGE_NAME=apache/airflow:3.1.0
AIRFLOW_UID=50000
```

---

### `Dockerfile`

Extends the official Airflow image and installs both public and private Python dependencies.

```dockerfile
FROM apache/airflow:3.1.0

USER root
COPY requirements.txt /requirements.txt
COPY custom_requirements.txt /custom_requirements.txt

ARG INDEX_URL=https://pypi.org/simple
ENV PYPI_URL=${INDEX_URL}

RUN --mount=type=secret,id=nexus_user \
    --mount=type=secret,id=nexus_pass \
    set -e; \
    U="$(cat /run/secrets/nexus_user)"; \
    P="$(cat /run/secrets/nexus_pass)";

USER airflow
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /requirements.txt && \
    pip install --no-cache-dir --no-deps --index-url "${PYPI_URL}" -r /custom_requirements.txt
```

**Key Points:**

* Credentials for Nexus are passed securely via Docker secrets.
* Base image can be customized using `AIRFLOW_IMAGE_NAME`.
* Uses `--no-cache-dir` for clean, reproducible builds.

---

### `docker-compose.yaml`

Defines all Airflow services with required dependencies and health checks.

**Core Components:**

* **Postgres (16):** Metadata database for Airflow.
* **Redis (7.2):** Celery broker.
* **Airflow services:** webserver/API, scheduler, worker, triggerer, dag-processor, CLI.
* **Flower:** Optional Celery monitoring UI (port 5555).
* **Init container:** Handles directory setup, permission fixes, and user creation.

**Build and Secrets:**

```yaml
build:
  context: .
  dockerfile: Dockerfile
  args:
    INDEX_URL: ${NEXUS_URL}
  secrets:
    - nexus_user
    - nexus_pass
```

**Secrets:**

```yaml
secrets:
  nexus_user:
    file: ./nexus_user
  nexus_pass:
    file: ./nexus_pass
```

**Volumes:**

```
./dags:/opt/airflow/dags
./logs:/opt/airflow/logs
./plugins:/opt/airflow/plugins
./config:/opt/airflow/config
```

**Usage:**

```bash
docker compose up -d
docker compose ps
```

---

### `jenkins/Jenkinsfile`

Declarative Jenkins pipeline that automates setup, build, and deployment.

**Parameters:**

* `NEXUS_URL`: Custom PyPI/simple index (optional)
* `DEV_DIR`: Target directory for staging the build
* `NEXUS_CREDS_ID`: Jenkins credentials ID (optional)
* `NEXUS_USER`, `NEXUS_PASS`: Fallback credentials
* `REQUIREMENTS`, `CUSTOM_REQUIREMENTS`: URLs for requirement files

**Stages:**

1. **Checkout:** Cleans workspace and checks out repository.
2. **Prepare:** Creates `DEV_DIR`, injects credentials, downloads requirement files.
3. **Build up services:** Builds Docker image and runs `docker compose up -d`, cleans secrets.

**Snippet:**

```groovy
withCredentials([usernamePassword(credentialsId: params.NEXUS_CREDS_ID, usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
  sh 'docker compose up -d'
}
```

**Cleanup:** Sensitive files like credentials, Dockerfile, and compose YAML are deleted post-deployment.

---

## CI/CD Flow Summary

| Stage    | Description                      | Key Output                          |
| -------- | -------------------------------- | ----------------------------------- |
| Checkout | Clean workspace and fetch repo   | SCM contents                        |
| Prepare  | Fetch dependencies, inject creds | Staged directory with Docker assets |
| Build    | Build custom Airflow image       | Image with private deps installed   |
| Deploy   | Run `docker compose up -d`       | Running Airflow Celery cluster      |

---

## Configuration Reference

| Variable                     | Purpose                  | Default                                            |
| ---------------------------- | ------------------------ | -------------------------------------------------- |
| `AIRFLOW_IMAGE_NAME`         | Base image name          | apache/airflow:3.1.0                               |
| `AIRFLOW_UID`                | File ownership alignment | 50000                                              |
| `NEXUS_URL`                  | Custom Python index      | [https://pypi.org/simple](https://pypi.org/simple) |
| `NEXUS_CREDS_ID`             | Jenkins credentials ID   | —                                                  |
| `DEV_DIR`                    | Target build directory   | —                                                  |
| `_AIRFLOW_WWW_USER_USERNAME` | Default Airflow user     | airflow                                            |
| `_AIRFLOW_WWW_USER_PASSWORD` | Default password         | airflow                                            |

---

## Best Practices

* Generate and set a `FERNET_KEY` for production security.
* Avoid deleting `docker-compose.yaml` post-deployment for lifecycle management.
* Keep Airflow image version pinned to a known-stable tag.
* Validate Nexus credentials via Jenkins before pipeline execution.
* Use Jenkins credentials store instead of passing plain text.

---

## Quickstart

```bash
# 1. Set environment variables or use Jenkins params
export NEXUS_URL=https://<nexus-repo>/simple
export DEV_DIR=/tmp/airflow_celery_setup

# 2. Build and run locally (manual)
docker build --secret id=nexus_user,src=./nexus_user \
             --secret id=nexus_pass,src=./nexus_pass \
             -t custom-airflow:latest .

docker compose up -d

# 3. Access Airflow UI
http://localhost:8082  (username: airflow, password: airflow)
```

---

## Future Enhancements

* Parameterize Airflow version and executor via Jenkins.
* Support for remote Docker hosts (Swarm/Kubernetes).
* Add Makefile for local dev lifecycle management.
* Integration with GitHub Actions for lightweight CI.

---

## License

Apache License 2.0 — See LICENSE file for details.

---

**Maintainer:** [@tuhindutta](https://github.com/tuhindutta)

For documentation site setup: this README can be used directly as the landing page for GitHub Pages or extended with MkDocs Material for versioned documentation.
