#!/usr/bin/env bash

# As the script takes 10 seconds to run, cache the result.
CACHE_FILE="/tmp/ente_status.cache"
LOCK_FILE="/tmp/ente_status.lock"
CACHE_TTL=15

# Convert time to relative (just now, 1 hour ago, etc).
get_relative_time() {
  local epoch="$1"
  if [ -z "$epoch" ] || [ "$epoch" -eq 0 ]; then
    echo "No files found"
    return
  fi

  local now
  now=$(date +%s)
  local diff=$((now - epoch))

  # If synced less than 60 seconds ago.
  if [ "$diff" -lt 60 ]; then
    echo "Just now"
  # If synced less than 60 minutes ago.
  elif [ "$diff" -lt 3600 ]; then
    local mins=$((diff / 60))
    [ "$mins" -eq 1 ] && echo "1 minute ago" || echo "$mins minutes ago"
  # If synced less than 1 day ago.
  elif [ "$diff" -lt 86400 ]; then
    local hours=$((diff / 3600))
    [ "$hours" -eq 1 ] && echo "1 hour ago" || echo "$hours hours ago"
  # If synced yesterday.
  elif [ "$diff" -lt 172800 ]; then
    echo "Yesterday ($(date -d "@$epoch" "+%H:%M"))"
  # If synced 2+ days ago.
  else
    local days=$((diff / 86400))
    echo "$days days ago"
  fi
}

# Main function for the script.
update_cache() {

  exec 200>"$LOCK_FILE"
  flock -n 200 || return 0

  # Reset cache age because it is actively running.
  touch "$CACHE_FILE"

  # Ente directories.
  local ente_dir="/home/software/mounts/Ente-Photos"
  local b2_dir="$ente_dir/minio/b2-eu-cen"
  local henry_dir="$b2_dir/1580559962386438"
  local poppy_dir="$b2_dir/1580559962386439"
  local container="my-ente-museum-1"

  # Check when directories last changed.
  local henry_epoch henry_sync poppy_epoch poppy_sync
  henry_epoch=$(find "$henry_dir" -type f -not -path '*/.minio.sys/*' -printf '%T@\n' 2>/dev/null | sort -n | tail -n 1 | cut -d. -f1)
  henry_sync=$(get_relative_time "$henry_epoch")

  poppy_epoch=$(find "$poppy_dir" -type f -not -path '*/.minio.sys/*' -printf '%T@\n' 2>/dev/null | sort -n | tail -n 1 | cut -d. -f1)
  poppy_sync=$(get_relative_time "$poppy_epoch")

  # Record size of directories.
  local henry_storage poppy_storage total_storage
  henry_storage=$(du -sh "$henry_dir" 2>/dev/null | awk '{print $1}')
  henry_storage=${henry_storage:-"N/A"}

  poppy_storage=$(du -sh "$poppy_dir" 2>/dev/null | awk '{print $1}')
  poppy_storage=${poppy_storage:-"N/A"}

  total_storage=$(du -sh "$ente_dir" 2>/dev/null | awk '{print $1}')
  total_storage=${total_storage:-"N/A"}

  # Check the status of the Ente containers.
  local status
  status=$(docker ps --filter "name=^/${container}$" --format "{{.Status}}")
  status=${status:-"Offline"}

  # Record outputs to temporary file.
  {
    printf "%-20s %s\n" "Henry last sync:" "$henry_sync"
    printf "%-20s %s\n" "Poppy last sync:" "$poppy_sync"
    echo ""
    printf "%-20s %s\n" "Henry storage used:" "$henry_storage"
    printf "%-20s %s\n" "Poppy storage used:" "$poppy_storage"
    # printf "%-20s %s\n" "Total storage used:" "$total_storage"
    echo ""
    printf "%-20s %s\n" "Status:" "$status"
  } >"${CACHE_FILE}.tmp"

  # Copy temporary file to cache file.
  mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
}

# Build cache file on first run.
if [ ! -f "$CACHE_FILE" ]; then
  echo "Loading Ente status..."
  update_cache
fi

# Print cached data.
cat "$CACHE_FILE"

# If the cache is old, rerun and update the cache file in the background.
CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
if [ "$CACHE_AGE" -gt "$CACHE_TTL" ]; then
  (update_cache) &>/dev/null &
fi
