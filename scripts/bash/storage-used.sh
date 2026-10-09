#!/usr/bin/env bash

BASE_DIR="/home/casa/locations"

# Get size in GiB.
get_size() {
  local sz
  sz=$(du -sh "$1" 2>/dev/null | awk '{print $1}')
  echo "${sz:-0B}"
}

# Run for each location.
DOCS=$(get_size "$BASE_DIR/documents")
PICS=$(get_size "$BASE_DIR/pictures")
SYNC=$(get_size "$BASE_DIR/sync")
GAMES=$(get_size "$BASE_DIR/games")

# Get size of entire /home.
HOME_USED=$(df -h "$BASE_DIR" | awk 'NR==2 {print $3}')
HOME_SIZE=$(df -h "$BASE_DIR" | awk 'NR==2 {print $2}')

# Get size of entire server.
SERVER_USED=$(df -h --total -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | awk '/^total/ {print $3}')
SERVER_SIZE=$(df -h --total -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | awk '/^total/ {print $2}')

# Print outputs with a consistent spacing.
printf "%-12s %s\n" "Documents:" "$DOCS"
printf "%-12s %s\n" "Pictures:" "$PICS"
printf "%-12s %s\n" "Sync:" "$SYNC"
printf "%-12s %s\n" "Games:" "$GAMES"
echo ""
printf "%-12s %s / %s\n" "Home:" "$HOME_USED" "$HOME_SIZE"
printf "%-12s %s / %s\n" "Total:" "$SERVER_USED" "$SERVER_SIZE"
