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
├─ Jenkinsfile         # Jenkins CI/CD pipeline definition
```

---

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


---

## CI/CD Flow Summary

| Stage                | Description                               | Key Output                                       |
| -------------------- | ----------------------------------------- | ------------------------------------------------ |
| Checkout             | Clean workspace and fetch repo            | SCM contents                                     |
| Prepare              | Fetch dependencies, inject creds          | Staged directory with Docker assets              |
| Build up services    | Build & deploy custom Airflow image       | Image with private deps installed and deployed   |

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

## Future Enhancements

* Parameterize Airflow version and executor via Jenkins.
* Support for remote Docker hosts (Swarm/Kubernetes).
* Add Makefile for local dev lifecycle management.
* Integration with GitHub Actions for lightweight CI.

---


**Maintainer:** [@tuhindutta](https://github.com/tuhindutta)
[**GitHub repo:**](https://github.com/tuhindutta/airflow-setup-celery-framework)
