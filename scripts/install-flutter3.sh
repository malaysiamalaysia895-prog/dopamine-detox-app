#!/usr/bin/env bash
# Install Flutter 3.x SDK into ~/.flutter3 and add it to PATH.
# Run once: bash scripts/install-flutter3.sh
# Then restart your shell or: source ~/.bashrc

set -euo pipefail

FLUTTER_DIR="$HOME/.flutter3"
FLUTTER_VERSION="3.22.3"
TARBALL_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ -d "$FLUTTER_DIR" ] && [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Flutter 3 already installed at $FLUTTER_DIR"
  "$FLUTTER_DIR/bin/flutter" --version
  exit 0
fi

echo "Downloading Flutter $FLUTTER_VERSION (~600 MB)..."
TMP_FILE="/tmp/flutter_linux_${FLUTTER_VERSION}.tar.xz"
curl -L "$TARBALL_URL" -o "$TMP_FILE"

echo "Extracting..."
mkdir -p "$FLUTTER_DIR"
TMP_EXTRACT="/tmp/flutter_extract_$$"
mkdir -p "$TMP_EXTRACT"
tar xf "$TMP_FILE" -C "$TMP_EXTRACT"
mv "$TMP_EXTRACT/flutter"/* "$FLUTTER_DIR/"
rm -rf "$TMP_FILE" "$TMP_EXTRACT"

# Add to PATH in .bashrc (idempotent)
MARKER='# flutter3 sdk'
if ! grep -q "$MARKER" ~/.bashrc 2>/dev/null; then
  echo "" >> ~/.bashrc
  echo "$MARKER" >> ~/.bashrc
  echo 'export PATH="$HOME/.flutter3/bin:$PATH"' >> ~/.bashrc
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Disabling analytics..."
flutter config --no-analytics 2>/dev/null || true

echo "Running flutter pub get in flutter_export/..."
cd "$(dirname "$0")/../flutter_export"
flutter pub get

echo ""
echo "Done. Flutter 3 is ready."
echo "Restart your shell or run: source ~/.bashrc"
flutter --version
