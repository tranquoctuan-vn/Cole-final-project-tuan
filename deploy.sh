#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

log() {
  printf "\033[0;32m[INFO]\033[0m %s\n" "$1"
}

warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "Docker Compose is not installed." >&2
    exit 1
  fi
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local retries="${3:-60}"
  local delay="${4:-5}"

  log "Waiting for $name ($url) ..."
  for _ in $(seq 1 "$retries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      log "$name is ready."
      return 0
    fi
    sleep "$delay"
  done

  echo "$name did not become ready in time." >&2
  return 1
}

main() {
  require_cmd docker
  require_cmd curl

  log "Downloading Spark/Iceberg jars"
  ./download-spark-jars.sh

  log "Starting services"
  compose_cmd up -d --build

  wait_for_http "Kafka Connect" "http://localhost:8083/connectors"
  wait_for_http "Airflow" "http://localhost:8080/health"
  wait_for_http "Analytics API" "http://localhost:8000/health"

  log "Configuring Kafka topics + Debezium connector"
  ./kafka-scripts.sh setup-all

  log "Deployment completed successfully."
  cat <<MSG

Useful URLs:
- Airflow: http://localhost:8080
- Control Center: http://localhost:9021
- MinIO Console: http://localhost:9001
- Analytics API docs: http://localhost:8000/docs
- Dashboard: http://localhost:8501

MSG
}

main "$@"
