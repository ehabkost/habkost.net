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

SITE_DIR="${SITE_DIR:-_site/}"

mkdir -p ~/.ssh
echo "$UPLOAD_SSH_KEY" > ~/.ssh/id_for_upload
chmod 600 ~/.ssh/id_for_upload
echo "$SSH_KNOWN_HOSTS" >> ~/.ssh/known_hosts

RSYNC_OPTS=(-avz -e "ssh -i ~/.ssh/id_for_upload")
if [ "${DELETE:-0}" = "1" ]; then
    RSYNC_OPTS+=(--delete)
fi
if [ "${DRY_RUN:-0}" = "1" ]; then
    RSYNC_OPTS+=(--dry-run)
fi

rsync "${RSYNC_OPTS[@]}" "$SITE_DIR" "$UPLOAD_USERNAME@$UPLOAD_HOST:$UPLOAD_PATH/"
