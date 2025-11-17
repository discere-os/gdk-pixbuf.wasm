#!/bin/bash
# Unified Meson Build Script for gdk-pixbuf.wasm
# Part of the Discere OS WASM Ecosystem
# Copyright 2025 Superstruct Ltd, New Zealand
# Licensed under LGPL-2.1-or-later

set -euo pipefail

# Configuration
BUILD_TYPE="${1:-standard}"
CLEAN="${CLEAN:-false}"
OPTIMIZE="${OPTIMIZE:-balanced}"
BUILD_DIR="build"
INSTALL_DIR="$PWD/install"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[Build]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[Build]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[Build]${NC} $1"
}

log_error() {
    echo -e "${RED}[Build]${NC} $1"
}

# Banner
echo ""
log_info "╔════════════════════════════════════════════════════════╗"
log_info "║  Unified Meson Build for gdk-pixbuf.wasm             ║"
log_info "║  Discere OS WASM Ecosystem                            ║"
log_info "╚════════════════════════════════════════════════════════╝"
echo ""
log_info "Build Type: $BUILD_TYPE"
log_info "Optimize:   $OPTIMIZE"
log_info "Clean:      $CLEAN"
echo ""

# Validate required tools
log_info "Validating build tools..."
if ! command -v emcc >/dev/null 2>&1; then
    log_error "emcc not found. Please install Emscripten SDK."
    log_error "Visit: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi

if ! command -v meson >/dev/null 2>&1; then
    log_error "meson not found. Please install Meson build system."
    log_error "Run: pip install meson"
    exit 1
fi

if ! command -v ninja >/dev/null 2>&1; then
    log_error "ninja not found. Please install Ninja build tool."
    log_error "Run: pip install ninja"
    exit 1
fi

# Display versions
EMCC_VERSION=$(emcc --version | head -n1)
MESON_VERSION=$(meson --version)
NINJA_VERSION=$(ninja --version)
log_success "✓ emcc:  $EMCC_VERSION"
log_success "✓ meson: $MESON_VERSION"
log_success "✓ ninja: $NINJA_VERSION"
echo ""

# Validate build type
case "$BUILD_TYPE" in
    minimal|standard|webgpu)
        log_info "Build type validated: $BUILD_TYPE"
        ;;
    *)
        log_error "Invalid build type: $BUILD_TYPE"
        log_error "Valid options: minimal, standard, webgpu"
        exit 1
        ;;
esac

# Clean if requested
if [[ "$CLEAN" == "true" ]]; then
    log_warning "Cleaning previous builds..."
    rm -rf "$BUILD_DIR" build-* "$INSTALL_DIR"
    log_success "✓ Clean complete"
    echo ""
fi

# Setup environment for cross-compilation
export EMCC_CFLAGS="-pthread -sPROXY_TO_PTHREAD"
export LDFLAGS="-lwebsocket.js -sPROXY_POSIX_SOCKETS -pthread -sPROXY_TO_PTHREAD"

log_info "Configuring Meson build system..."
log_info "Cross-file:      emscripten-cross.ini"
log_info "Build directory: $BUILD_DIR"
log_info "Install prefix:  $INSTALL_DIR"

# Configure Meson
meson setup "$BUILD_DIR" \
    --cross-file=emscripten-cross.ini \
    --prefix="$INSTALL_DIR" \
    --libdir=wasm \
    --bindir=wasm \
    --buildtype=release \
    -Dwasm_build_type="$BUILD_TYPE" \
    -Dwasm_simd=true \
    -Dwasm_threading=true \
    -Dwasm_optimize="$OPTIMIZE" \
    --force-fallback-for=glib,libffi,zlib \
    -Dglib:xattr=false \
    -Dglib:tests=false \
    -Dtests=false \
    -Dintrospection=disabled \
    -Dman=false \
    -Ddocumentation=false \
    -Dthumbnailer=disabled

log_success "✓ Configuration complete"
echo ""

# Compile
log_info "Compiling gdk-pixbuf.wasm..."
meson compile -C "$BUILD_DIR" -v

log_success "✓ Compilation complete"
echo ""

# Install
log_info "Installing to $INSTALL_DIR/wasm/..."
meson install -C "$BUILD_DIR"

log_success "✓ Installation complete"
echo ""

# Post-process with wasm-opt (if available)
if command -v wasm-opt >/dev/null 2>&1; then
    log_info "Optimizing WASM with wasm-opt..."

    SIDE_WASM="$INSTALL_DIR/wasm/gdk-pixbuf-side.wasm"
    if [[ -f "$SIDE_WASM" ]]; then
        ORIGINAL_SIZE=$(stat -f%z "$SIDE_WASM" 2>/dev/null || stat -c%s "$SIDE_WASM" 2>/dev/null)
        wasm-opt -O3 -c "$SIDE_WASM" -o "$SIDE_WASM.tmp"
        mv "$SIDE_WASM.tmp" "$SIDE_WASM"
        OPTIMIZED_SIZE=$(stat -f%z "$SIDE_WASM" 2>/dev/null || stat -c%s "$SIDE_WASM" 2>/dev/null)
        REDUCTION=$((ORIGINAL_SIZE - OPTIMIZED_SIZE))
        log_success "✓ Optimized SIDE_MODULE: $ORIGINAL_SIZE → $OPTIMIZED_SIZE bytes (-$REDUCTION bytes)"
    fi
else
    log_warning "wasm-opt not found, skipping post-optimization"
    log_info "Install from: https://github.com/WebAssembly/binaryen"
fi
echo ""

# Generate build manifest
log_info "Generating build manifest..."
GIT_VERSION=$(git describe --tags --always 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$INSTALL_DIR/wasm/manifest.json" <<EOF
{
  "name": "@discere-os/gdk-pixbuf.wasm",
  "version": "$GIT_VERSION",
  "build_type": "$BUILD_TYPE",
  "build_date": "$BUILD_DATE",
  "optimization": "$OPTIMIZE",
  "features": {
    "simd": true,
    "threading": true,
    "webgpu": $([ "$BUILD_TYPE" = "webgpu" ] && echo "true" || echo "false")
  },
  "outputs": {
    "side_module": "gdk-pixbuf-side.wasm",
    "main_module": "gdk-pixbuf-main.js"
  }
}
EOF

log_success "✓ Manifest generated"
echo ""

# Run post-install script if it exists
if [[ -f "scripts/postinstall.py" ]]; then
    log_info "Running post-install script..."
    python3 scripts/postinstall.py "$INSTALL_DIR"
    log_success "✓ Post-install complete"
    echo ""
fi

# Display build summary
echo ""
log_success "╔════════════════════════════════════════════════════════╗"
log_success "║  Build Complete!                                      ║"
log_success "╚════════════════════════════════════════════════════════╝"
echo ""
log_info "Output Directory: $INSTALL_DIR/wasm/"
echo ""

if [[ -f "$INSTALL_DIR/wasm/gdk-pixbuf-side.wasm" ]]; then
    SIDE_SIZE=$(stat -f%z "$INSTALL_DIR/wasm/gdk-pixbuf-side.wasm" 2>/dev/null || stat -c%s "$INSTALL_DIR/wasm/gdk-pixbuf-side.wasm" 2>/dev/null)
    SIDE_SIZE_KB=$((SIDE_SIZE / 1024))
    log_success "✓ gdk-pixbuf-side.wasm  (${SIDE_SIZE_KB}KB) - SIDE_MODULE"
fi

if [[ -f "$INSTALL_DIR/wasm/gdk-pixbuf-main.js" ]]; then
    MAIN_SIZE=$(stat -f%z "$INSTALL_DIR/wasm/gdk-pixbuf-main.js" 2>/dev/null || stat -c%s "$INSTALL_DIR/wasm/gdk-pixbuf-main.js" 2>/dev/null)
    MAIN_SIZE_KB=$((MAIN_SIZE / 1024))
    log_success "✓ gdk-pixbuf-main.js    (${MAIN_SIZE_KB}KB) - MAIN_MODULE"
fi

if [[ -f "$INSTALL_DIR/wasm/manifest.json" ]]; then
    log_success "✓ manifest.json"
fi

echo ""
log_info "Next Steps:"
log_info "  • Test MAIN_MODULE: deno task demo"
log_info "  • Run tests:        deno task test"
log_info "  • Deploy SIDE_MODULE to CDN"
echo ""
