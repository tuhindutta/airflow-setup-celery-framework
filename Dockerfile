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
    pip install --no-cache-dir -r /requirements.txt
    
RUN pip install --no-cache-dir --no-deps \
    --index-url "${PYPI_URL}" \
    -r /custom_requirements.txt
