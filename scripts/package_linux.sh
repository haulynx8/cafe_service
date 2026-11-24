#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Error: Missing .env file. Copy .env.example to .env and configure Supabase keys." >&2
  exit 1
fi

set -a
source .env
set +a

VERSION="1.0.0"
RELEASE="1"
PKG_VERSION="${VERSION}-${RELEASE}"

echo "==> Building Flutter Linux release bundle..."
flutter build linux --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"

BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "Error: Bundle directory not found at $BUNDLE_DIR" >&2
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

BUILD_DATE="$(date +%s)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "==> Preparing package root..."
PKG_ROOT="$TEMP_DIR/root"
mkdir -p "$PKG_ROOT/opt/cafe-service"
mkdir -p "$PKG_ROOT/usr/bin"
mkdir -p "$PKG_ROOT/usr/share/applications"
mkdir -p "$PKG_ROOT/usr/share/pixmaps"

# Copy Flutter release bundle
cp -r "$BUNDLE_DIR/"* "$PKG_ROOT/opt/cafe-service/"

# Copy Icon
if [[ -f "$ROOT_DIR/assets/icons/linux/icon_512.png" ]]; then
  cp "$ROOT_DIR/assets/icons/linux/icon_512.png" "$PKG_ROOT/usr/share/pixmaps/cafe-service.png"
fi

# Launcher script
cat <<'EOF' > "$PKG_ROOT/usr/bin/cafe-service"
#!/bin/sh
exec /opt/cafe-service/cafe_service "$@"
EOF
chmod 755 "$PKG_ROOT/usr/bin/cafe-service"

# Desktop entry
cat <<'EOF' > "$PKG_ROOT/usr/share/applications/cafe-service.desktop"
[Desktop Entry]
Type=Application
Name=Cafe Service
Comment=Cafe service dashboard and order management
Exec=cafe-service
Icon=cafe-service
Terminal=false
Categories=Office;Finance;
EOF
chmod 644 "$PKG_ROOT/usr/share/applications/cafe-service.desktop"

INSTALLED_SIZE_BYTES=$(du -sb "$PKG_ROOT" | awk '{print $1}')
INSTALLED_SIZE_KB=$(( (INSTALLED_SIZE_BYTES + 1023) / 1024 ))

# -------------------------------------------------------------
# 1. ARCH LINUX PACKAGE (.pkg.tar.zst)
# -------------------------------------------------------------
echo "==> Creating Arch Linux package (.pkg.tar.zst)..."
ARCH_STAGING="$TEMP_DIR/arch"
mkdir -p "$ARCH_STAGING"
cp -r "$PKG_ROOT/opt" "$ARCH_STAGING/"
cp -r "$PKG_ROOT/usr" "$ARCH_STAGING/"

cat <<EOF > "$ARCH_STAGING/.PKGINFO"
pkgname = cafe-service
pkgbase = cafe-service
pkgver = ${PKG_VERSION}
pkgdesc = Cafe Service dashboard and online ordering application
url = https://example.invalid/cafe-service
builddate = ${BUILD_DATE}
packager = Cafe Service
size = ${INSTALLED_SIZE_BYTES}
arch = x86_64
license = proprietary
depend = gtk3
depend = util-linux-libs
depend = xz
EOF

ARCH_PKG_NAME="cafe-service-${PKG_VERSION}-x86_64.pkg.tar.zst"
(
  cd "$ARCH_STAGING"
  tar -c --zstd -f "$DIST_DIR/$ARCH_PKG_NAME" .PKGINFO opt usr
)
echo "✓ Arch Linux package created: $DIST_DIR/$ARCH_PKG_NAME"

# -------------------------------------------------------------
# 2. DEBIAN PACKAGE (.deb)
# -------------------------------------------------------------
echo "==> Creating Debian package (.deb)..."
DEB_STAGING="$TEMP_DIR/deb"
mkdir -p "$DEB_STAGING/DEBIAN"
mkdir -p "$DEB_STAGING/opt"
mkdir -p "$DEB_STAGING/usr"

cp -r "$PKG_ROOT/opt/"* "$DEB_STAGING/opt/"
cp -r "$PKG_ROOT/usr/"* "$DEB_STAGING/usr/"

echo "2.0" > "$DEB_STAGING/debian-binary"

cat <<EOF > "$DEB_STAGING/DEBIAN/control"
Package: cafe-service
Version: ${PKG_VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Cafe Service <cafe@example.invalid>
Installed-Size: ${INSTALLED_SIZE_KB}
Depends: libgtk-3-0, libblkid1, liblzma5
Description: Cafe Service dashboard and online ordering application
 Cafe service dashboard, order entry, expense tracking, and offline sync.
EOF

(
  cd "$DEB_STAGING/DEBIAN"
  tar -czf "$DEB_STAGING/control.tar.gz" control
)

(
  cd "$DEB_STAGING"
  tar -czf "$DEB_STAGING/data.tar.gz" --transform 's,^\.,./,' ./opt ./usr
)

DEB_PKG_NAME="cafe-service_${PKG_VERSION}_amd64.deb"
(
  cd "$DEB_STAGING"
  ar rcs "$DIST_DIR/$DEB_PKG_NAME" debian-binary control.tar.gz data.tar.gz
)
echo "✓ Debian package created: $DIST_DIR/$DEB_PKG_NAME"

echo ""
echo "Summary of generated Linux packages:"
ls -lh "$DIST_DIR/$ARCH_PKG_NAME" "$DIST_DIR/$DEB_PKG_NAME"
