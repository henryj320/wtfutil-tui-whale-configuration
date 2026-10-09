#!/usr/bin/env bash

# Cache results as the script takes a while to run.
# Most of this is a copy of ente-status.sh but pointed at a different directory.
CACHE_FILE="/tmp/system_info.cache"
LOCK_FILE="/tmp/system_info.lock"
CACHE_TTL=15

get_relative_time() {
  local epoch="$1"
  if [ -z "$epoch" ] || [ "$epoch" -eq 0 ]; then
    echo "Never"
    return
  fi

  local now
  now=$(date +%s)
  local diff=$((now - epoch))

  if [ "$diff" -lt 60 ]; then
    echo "Just now"
  elif [ "$diff" -lt 3600 ]; then
    local mins=$((diff / 60))
    [ "$mins" -eq 1 ] && echo "1 minute ago" || echo "$mins minutes ago"
  elif [ "$diff" -lt 86400 ]; then
    local hours=$((diff / 3600))
    [ "$hours" -eq 1 ] && echo "1 hour ago" || echo "$hours hours ago"
  elif [ "$diff" -lt 172800 ]; then
    echo "Yesterday ($(date -d "@$epoch" "+%H:%M"))"
  else
    local days=$((diff / 86400))
    echo "$days days ago"
  fi
}

update_cache() {
  exec 200>"$LOCK_FILE"
  flock -n 200 || return 0
  touch "$CACHE_FILE"

  # Output relative uptime.
  local up_seconds up_days up_hours up_mins uptime_str
  up_seconds=$(cut -d. -f1 /proc/uptime)
  up_days=$((up_seconds / 86400))
  up_hours=$(((up_seconds % 86400) / 3600))
  up_mins=$(((up_seconds % 3600) / 60))
  if [ "$up_days" -gt 0 ]; then
    uptime_str="${up_days}d ${up_hours}h ${up_mins}m"
  else
    uptime_str="${up_hours}h ${up_mins}m"
  fi

  # Output Debian and Kernel version.
  local debian_ver kernel_ver
  debian_ver=$(cat /etc/debian_version 2>/dev/null || echo "Unknown")
  kernel_ver=$(uname -r)

  # Output number of apt updates pending.
  local updates
  updates=$(apt-get -s upgrade 2>/dev/null | awk '/upgraded, / {print $1; exit}')
  updates=${updates:-0}
  if [ "$updates" -gt 0 ]; then
    updates="${updates} pending"
  else
    updates="Up to date"
  fi

  # Check ClamAV log for last run time.
  local clam_log="/home/casa/locations/logs/ClamAV/removed_files.log"
  local clam_epoch clam_time
  clam_epoch=$(stat -c %Y "$clam_log" 2>/dev/null || echo 0)
  clam_time=$(get_relative_time "$clam_epoch")

  # Save all outputs to cache file.
  {
    printf "%-18s %s\n" "Uptime:" "$uptime_str"
    echo ""
    printf "%-18s %s\n" "Debian Version:" "$debian_ver"
    printf "%-18s %s\n" "Kernel:" "$kernel_ver"
    echo ""
    printf "%-18s %s\n" "Updates:" "$updates"
    echo ""
    printf "%-18s %s\n" "Last ClamAV Scan:" "$clam_time"
  } >"${CACHE_FILE}.tmp"

  mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
}

if [ ! -f "$CACHE_FILE" ]; then
  echo "Loading System Info..."
  update_cache
fi

cat "$CACHE_FILE"

CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
if [ "$CACHE_AGE" -gt "$CACHE_TTL" ]; then
  (update_cache) &>/dev/null &
fi
