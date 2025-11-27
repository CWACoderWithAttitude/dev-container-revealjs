#!/bin/zsh
#!/usr/bin/env zsh
# Watch p.adoc and run ./run.sh when it changes using fswatch (macOS).
# Usage: chmod +x watch-p.adoc.fswatch.zsh; ./watch-p.adoc.fswatch.zsh
# Requires: fswatch (brew install fswatch)

file="mcp-servers2.adoc"
cmd="make"  # convert"
debounce=1   # seconds to ignore further events after running

# ensure fswatch is available
if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch not found. Install it with: brew install fswatch" >&2
  exit 2
fi

# wait for file to exist before starting
while [[ ! -e "$file" ]]; do
  echo "Waiting for $file to appear..."
  sleep 1
done

last_run=0

# Use null-separated output to handle arbitrary filenames safely.
# Watch common events: Updated, Created, Removed, Renamed
fswatch -0 --event=Updated --event=Created --event=Removed --event=Renamed "$file" | while IFS= read -r -d '' event; do
  now=$(date +%s)

  # debounce: skip if last run was within debounce seconds
  if (( now - last_run < debounce )); then
    continue
  fi
  last_run=$now

  # If file was removed, wait for it to reappear before running
  if [[ ! -e "$file" ]]; then
    echo "$(date +'%F %T') - $file removed; waiting for it to reappear..."
    while [[ ! -e "$file" ]]; do sleep 1; done
    echo "$(date +'%F %T') - $file reappeared"
  fi

  echo "$(date +'%F %T') - Change detected ($event); running: $cmd"
  "$cmd"
done
