#!/bin/bash
set -euo pipefail

# Required environment variables:
#   UPLOAD_SSH_KEY     - private SSH key content
#   SSH_KNOWN_HOSTS    - known_hosts entry for the remote host
#   UPLOAD_USERNAME    - SSH username
#   UPLOAD_HOST        - remote hostname
#   UPLOAD_PATH        - remote path to deploy to
#   SITE_DIR           - local directory to upload (default: _site/)
#   DELETE             - set to "1" to pass --delete to rsync
#   DRY_RUN            - set to "1" to pass --dry-run to rsync
#   DELETIONS_FILE     - when set (with DELETE=1), write list of deleted paths to this file

SITE_DIR="${SITE_DIR:-_site/}"

mkdir -p ~/.ssh
echo "$UPLOAD_SSH_KEY" > ~/.ssh/id_for_upload
chmod 600 ~/.ssh/id_for_upload
echo "$SSH_KNOWN_HOSTS" >> ~/.ssh/known_hosts

RSYNC_OPTS=(-avz -e "ssh -i ~/.ssh/id_for_upload")
if [ "${DELETE:-0}" = "1" ]; then
    RSYNC_OPTS+=(--delete)
    # Protect paths listed in deploy-no-delete.txt from deletion
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    NO_DELETE_FILE="$SCRIPT_DIR/../deploy-no-delete.txt"
    if [ -f "$NO_DELETE_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            # skip empty lines and comments
            case "$line" in ''|\#*) continue ;; esac
            RSYNC_OPTS+=(--filter "protect $line")
        done < "$NO_DELETE_FILE"
    fi
fi
if [ "${DRY_RUN:-0}" = "1" ]; then
    RSYNC_OPTS+=(--dry-run)
fi

if [ -n "${DELETIONS_FILE:-}" ]; then
    RSYNC_OPTS+=(--itemize-changes)
fi

rsync "${RSYNC_OPTS[@]}" "$SITE_DIR" "$UPLOAD_USERNAME@$UPLOAD_HOST:$UPLOAD_PATH/" \
  | tee /dev/stderr \
  | if [ -n "${DELETIONS_FILE:-}" ]; then
      # Extract deleted paths from rsync --itemize-changes output.
      # Deletion lines have the format: "*deleting   path/to/file"
      sed -n 's/^\*deleting[[:space:]]\+//p' > "$DELETIONS_FILE"
    else
      cat > /dev/null
    fi
