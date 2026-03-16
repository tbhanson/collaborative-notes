#!/usr/bin/env bash
# deploy/deploy.sh
# Run on the server by the CI pipeline (or manually).
# Assumes the repo is already cloned at /opt/family-glossary.

set -euo pipefail

APP_DIR=/opt/family-glossary
SERVICE=family-glossary

echo "==> Pulling latest code..."
cd "$APP_DIR"
git pull --ff-only

echo "==> Installing/updating Racket dependencies..."
raco pkg install --auto --batch --skip-installed \
  koyo-lib db-lib sqlite-native gregor-lib threading-lib || true

echo "==> Compiling..."
raco make main.rkt

echo "==> Restarting service..."
sudo systemctl restart "$SERVICE"

echo "==> Done. Status:"
sudo systemctl status "$SERVICE" --no-pager -l
