#!/bin/bash
# =============================================================================
# generate-keys.sh
#
# Run this ONCE on your LOCAL machine to generate GrapheneOS signing keys.
# NEVER run this in CI. Keep the keys safe - if you lose them, you'll need
# to factory reset your device to re-lock with new keys.
#
# Usage:
#   ./scripts/generate-keys.sh
#
# After running:
#   1. The keys will be in ./keys/tegu/
#   2. Follow the instructions printed at the end to upload to GitHub Secrets
#   3. Flash avb_pkmd.bin to your device ONCE before your first install
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DEVICE="${DEVICE:-tegu}"
CN="${CN:-GrapheneOS}"  # Change this to your own CN if desired
MAKE_KEY_TOOL="${REPO_ROOT}/development/tools/make_key"

echo "========================================="
echo " GrapheneOS Signing Key Generator"
echo " Device: $DEVICE (Pixel 9a)"
echo "========================================="
echo ""
echo "WARNING: These keys are CRITICAL."
echo "  - Back them up securely (encrypted USB, password manager, etc.)"
echo "  - If you lose them, you cannot update your device without a factory reset"
echo "  - Never commit them to git"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# We need the GrapheneOS source tree for make_key tool
# Check if we're in one or need to clone just the tool
if [ ! -f "${MAKE_KEY_TOOL}" ]; then
    echo ""
    echo "The make_key tool is needed from the AOSP/GrapheneOS source tree."
    echo "You have two options:"
    echo "  1. Run this script from within a synced GrapheneOS source tree"
    echo "  2. Let this script download just the tool"
    echo ""
    read -p "Download make_key tool? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "${REPO_ROOT}/development/tools"
        curl -fsSL "https://raw.githubusercontent.com/aosp-mirror/platform_development/master/tools/make_key" \
            -o "${MAKE_KEY_TOOL}"
        chmod +x "${MAKE_KEY_TOOL}"

        # Fix known trap behavior so make_key does not exit non-zero on success.
        if grep -q "trap 'rm -rf \${tmpdir}; echo; exit 1' EXIT INT QUIT" "${MAKE_KEY_TOOL}"; then
            sed -i \
                "s#trap 'rm -rf \${tmpdir}; echo; exit 1' EXIT INT QUIT#trap 'rm -rf \${tmpdir}' EXIT\\ntrap 'rm -rf \${tmpdir}; echo; exit 1' INT QUIT#" \
                "${MAKE_KEY_TOOL}"
        fi

        CLEANUP_TOOL=true
    else
        echo "Please run this script from within a GrapheneOS source tree."
        exit 1
    fi
fi

# Create key directory
mkdir -p "${REPO_ROOT}/keys/${DEVICE}"
cd "${REPO_ROOT}/keys/${DEVICE}"

echo ""
echo "Generating signing keys..."
echo "You will be prompted for a passphrase. USE THE SAME PASSPHRASE FOR ALL KEYS."
echo ""

# Generate all required signing keys
for key in releasekey platform shared media networkstack bluetooth sdk_sandbox gmscompat_lib nfc; do
    echo "--- Generating: $key ---"
    "${MAKE_KEY_TOOL}" "$key" "/CN=$CN/"
done

# Generate AVB key
echo "--- Generating: AVB key ---"
openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -out avb.pem
if [ -x "${REPO_ROOT}/external/avb/avbtool.py" ]; then
    "${REPO_ROOT}/external/avb/avbtool.py" extract_public_key --key avb.pem --output avb_pkmd.bin
elif command -v avbtool >/dev/null 2>&1; then
    avbtool extract_public_key --key avb.pem --output avb_pkmd.bin
else
    python3 -c "
# Fallback: extract public key manually if avbtool isn't available
print('WARNING: Could not extract AVB public key automatically.')
print('Install avbtool or run this from a GrapheneOS source tree:')
print('  external/avb/avbtool.py extract_public_key --key keys/${DEVICE}/avb.pem --output keys/${DEVICE}/avb_pkmd.bin')
"
fi

# Generate SSH key for factory image signing
echo "--- Generating: SSH signing key ---"
ssh-keygen -t ed25519 -f id_ed25519

echo ""
echo "========================================="
echo " Keys generated successfully!"
echo "========================================="
echo ""
echo "Key files are in: keys/${DEVICE}/"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. BACK UP YOUR KEYS to a secure location (encrypted drive, etc.)"
echo ""
echo "2. Package keys for GitHub Secrets:"
echo "   IMPORTANT: Use the SAME passphrase for GPG as you used for make_key above."
echo "   The CI uses one KEYS_PASSWORD secret for both decryption layers."
echo ""
echo "   tar -czf /tmp/keys-${DEVICE}.tar.gz -C keys ."
echo "   gpg --symmetric --cipher-algo AES256 /tmp/keys-${DEVICE}.tar.gz"
echo "   base64 /tmp/keys-${DEVICE}.tar.gz.gpg > /tmp/keys-${DEVICE}.b64"
echo ""
echo "3. Create GitHub repository secrets:"
echo "   - SIGNING_KEYS: contents of /tmp/keys-${DEVICE}.b64"
echo "   - KEYS_PASSWORD: the passphrase (same for make_key, SSH, AVB, and GPG)"
echo ""
echo "   You can set these via GitHub CLI:"
echo "   gh secret set SIGNING_KEYS < /tmp/keys-${DEVICE}.b64"
echo "   gh secret set KEYS_PASSWORD"
echo ""
echo "4. Flash AVB key to your device (ONE TIME ONLY):"
echo "   fastboot erase avb_custom_key"
echo "   fastboot flash avb_custom_key keys/${DEVICE}/avb_pkmd.bin"
echo "   fastboot reboot bootloader"
echo "   fastboot flashing lock"
echo ""
echo "5. Clean up temporary files:"
echo "   rm -f /tmp/keys-${DEVICE}.tar.gz /tmp/keys-${DEVICE}.tar.gz.gpg /tmp/keys-${DEVICE}.b64"
echo ""
echo "IMPORTANT: The key passphrase used for make_key must also be stored"
echo "as the KEYS_PASSWORD secret, as it's used during the signing process."
echo ""

# Cleanup downloaded tool if we fetched it
if [ "${CLEANUP_TOOL:-false}" = "true" ]; then
    rm -rf "${REPO_ROOT}/development"
fi
