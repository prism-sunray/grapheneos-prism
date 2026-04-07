#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE="${1:-tegu}"
KEY_DIR="keys/${DEVICE}"
ARCHIVE="/tmp/keys-${DEVICE}.tar.gz"
ENCRYPTED="${ARCHIVE}.gpg"
B64_FILE="/tmp/keys-${DEVICE}.b64"

if [ ! -d "${KEY_DIR}" ]; then
  echo "Missing ${KEY_DIR}. Generate keys first with scripts/generate-keys.sh"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found. Install gh and authenticate first."
  exit 1
fi

read -s -p "Enter KEYS_PASSWORD (must match your key passphrase): " KEYS_PASSWORD
echo
if [ -z "${KEYS_PASSWORD}" ]; then
  echo "KEYS_PASSWORD cannot be empty."
  exit 1
fi

tar -czf "${ARCHIVE}" -C keys .
printf '%s\n' "${KEYS_PASSWORD}" | gpg --batch --yes --passphrase-fd 0 \
  --symmetric --cipher-algo AES256 -o "${ENCRYPTED}" "${ARCHIVE}"
base64 "${ENCRYPTED}" > "${B64_FILE}"

gh secret set SIGNING_KEYS < "${B64_FILE}"
gh secret set KEYS_PASSWORD --body "${KEYS_PASSWORD}"

echo "Secrets uploaded: SIGNING_KEYS, KEYS_PASSWORD"
echo "Temporary files: ${ARCHIVE}, ${ENCRYPTED}, ${B64_FILE}"
echo "Clean with: rm -f '${ARCHIVE}' '${ENCRYPTED}' '${B64_FILE}'"
