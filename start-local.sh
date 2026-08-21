#!/bin/bash
# =============================================================================
# start-local.sh — Entry point for local development Docker container.
# Launches all three services: PaddleOCR, Pipeline, and Next.js.
# No Caddy reverse proxy needed for localhost development.
# =============================================================================

set -e

# Graceful shutdown: kill all child processes when the container stops.
cleanup() {
    echo "[start-local] Shutting down services..."
    kill "$OCR_PID" "$PIPELINE_PID" "$NEXT_PID" 2>/dev/null || true
    wait 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

cd /app

# ---- 1. Initialize database (creates tables if they don't exist) -----------
echo "[start-local] Initializing database..."
bun run db:push 2>&1 || echo "[start-local] db:push warning (tables may already exist)"

# ---- 2. Start PaddleOCR service (port 3002, PP-OCRv5) --------------------
echo "[start-local] Starting PaddleOCR service on port 3002..."
(cd mini-services/paddleocr-service && python3 main.py) &
OCR_PID=$!

# ---- 3. Start pipeline-service (port 3001, Bun + socket.io) ---------------
echo "[start-local] Starting pipeline-service on port 3001..."
(cd mini-services/pipeline-service && bun run start) &
PIPELINE_PID=$!

# ---- 4. Start Next.js production server (port 3000) ------------------------
echo "[start-local] Starting Next.js on port 3000..."
bun .next/standalone/server.js &
NEXT_PID=$!

# ---- 5. Wait for services to be ready --------------------------------------
echo "[start-local] Waiting for services to initialize..."
sleep 5

# Quick health check
if curl -s -o /dev/null -w "" "http://localhost:3000/" 2>/dev/null; then
    echo "[start-local] Next.js is responding on port 3000 ✓"
else
    echo "[start-local] WARNING: Next.js not yet responding (may still be starting)"
fi

# ---- 6. Keep the container alive -------------------------------------------
echo "[start-local] All services started successfully!"
echo ""
echo "==================================================================="
echo "Manhwa Recap Studio is running"
echo "==================================================================="
echo "  - PaddleOCR service:   PID $OCR_PID (port 3002)"
echo "  - Pipeline service:    PID $PIPELINE_PID (port 3001)"
echo "  - Next.js app:         PID $NEXT_PID (port 3000)"
echo ""
echo "Access the app at: http://localhost:3000"
echo "==================================================================="

# Keep container alive
wait
