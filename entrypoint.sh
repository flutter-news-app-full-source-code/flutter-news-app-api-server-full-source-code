#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# The first argument determines which process to run.
PROCESS_TYPE="$1"

case "$PROCESS_TYPE" in
  server)
    echo "Starting Dart Frog server..."
    exec /app/dart_frog_server
    ;;
  finalize-worker)
    echo "Starting local media finalization worker..."
    exec /app/local_media_finalization_worker
    ;;
  cleanup-worker)
    echo "Starting media cleanup worker..."
    exec /app/media_cleanup_worker
    ;;
  analytics-worker)
    echo "Starting analytics sync worker..."
    exec /app/analytics_sync_worker
    ;;
  *)
    echo "Error: Unknown process type '$PROCESS_TYPE'" >&2
    echo "Usage: [server|finalize-worker|cleanup-worker|analytics-worker]" >&2
    exit 1
    ;;
esac