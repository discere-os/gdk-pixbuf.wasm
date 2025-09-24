#!/bin/bash
# GdkPixbuf WASM Production Build Script
# Copyright 2025 Superstruct Ltd, New Zealand
# Licensed under LGPL-2.1-or-later

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_DIR="${SCRIPT_DIR}/_build_wasm"
readonly DIST_DIR="${SCRIPT_DIR}/dist"
readonly WASM_PREFIX="/usr/local/wasm"

# Build options
BUILD_TYPE="${1:-release}"
TARGET="${2:-web}"
FEATURES="${3:-core}"
OPTIMIZATION="${4:-size}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1" >&2
}

# Check dependencies
check_dependencies() {
    local deps=("emcc" "meson" "ninja" "pkg-config")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is not installed or not in PATH"
            exit 1
        fi
    done
    
    log "All dependencies found"
}

# Setup environment
setup_environment() {
    export CC="emcc"
    export CXX="em++"
    export AR="emar"
    export RANLIB="emranlib"
    export PKG_CONFIG_PATH="${WASM_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    
    # Emscripten optimization flags
    case "$OPTIMIZATION" in
        "size")
            export CFLAGS="-Os -DNDEBUG -flto -fno-exceptions"
            export LDFLAGS="-Os --closure=1"
            ;;
        "speed")
            export CFLAGS="-O3 -DNDEBUG -ffast-math -flto"
            export LDFLAGS="-O3 --closure=1"
            ;;
        "debug")
            export CFLAGS="-O1 -g -DDEBUG -fsanitize=address"
            export LDFLAGS="-O1 -g -fsanitize=address"
            ;;
    esac
    
    # Add SIMD support if available
    if [[ "$FEATURES" == *"simd"* ]]; then
        export CFLAGS="$CFLAGS -msimd128 -DGDK_PIXBUF_ENABLE_SIMD=1"
        export LDFLAGS="$LDFLAGS -msimd128"
        log "SIMD acceleration enabled"
    fi
    
    # WebGPU support
    if [[ "$FEATURES" == *"webgpu"* ]]; then
        export CFLAGS="$CFLAGS -DGDK_PIXBUF_ENABLE_WEBGPU=1"
        warn "WebGPU support requires additional implementation"
    fi
    
    log "Environment configured for $BUILD_TYPE build with $OPTIMIZATION optimization"
}

# Configure build
configure_build() {
    log "Configuring Meson build..."

    # Set up PKG_CONFIG paths for WASM dependencies
    local GLIB_ROOT="$(cd ../glib.wasm && pwd)/install"
    local CAIRO_ROOT="$(cd ../cairo.wasm && pwd)/install"
    local FONTCONFIG_ROOT="$(cd ../fontconfig.wasm && pwd)/install"
    local FREETYPE_ROOT="$(cd ../freetype.wasm && pwd)/install"
    local LIBPNG_ROOT="$(cd ../libpng.wasm && pwd)/install"
    local ZLIB_ROOT="$(cd ../zlib.wasm && pwd)/install"

    # Set PKG_CONFIG_LIBDIR to find WASM libraries instead of system libraries
    export PKG_CONFIG_LIBDIR="${GLIB_ROOT}/lib/pkgconfig:${CAIRO_ROOT}/lib/pkgconfig:${FONTCONFIG_ROOT}/lib/pkgconfig:${FREETYPE_ROOT}/lib/pkgconfig:${LIBPNG_ROOT}/lib/pkgconfig:${ZLIB_ROOT}/lib/pkgconfig"
    unset PKG_CONFIG_PATH

    log "PKG_CONFIG_LIBDIR set to use WASM dependencies"

    # Remove existing build directory
    rm -rf "$BUILD_DIR"
    
    # Determine builtin loaders based on features
    local builtin_loaders="none"
    case "$FEATURES" in
        "core")
            builtin_loaders="gif,bmp,ico,pnm,xpm,xbm,tga"
            ;;
        "standard")
            builtin_loaders="gif,bmp,ico,pnm,xpm,xbm,tga,png"
            ;;
        "extended")
            builtin_loaders="gif,bmp,ico,pnm,xpm,xbm,tga,png,jpeg"
            ;;
        "all")
            builtin_loaders="all"
            ;;
    esac
    
    # Meson configuration
    meson setup "$BUILD_DIR" \
        --cross-file=wasm-cross.txt \
        --default-library=static \
        --buildtype="$BUILD_TYPE" \
        -Dbuiltin_loaders="$builtin_loaders" \
        -Dpng=auto \
        -Djpeg=auto \
        -Dtiff=disabled \
        -Dgif=enabled \
        -Dothers=enabled \
        -Dtests=false \
        -Dintrospection=disabled \
        -Ddocumentation=false \
        -Dman=false \
        -Dthumbnailer=disabled \
        -Drelocatable=false \
        -Dgio_sniffing=false \
        -Dinstalled_tests=false
    
    log "Build configured successfully"
}

# Build the library
build_library() {
    log "Building GdkPixbuf WASM library..."
    
    ninja -C "$BUILD_DIR"
    
    log "Build completed successfully"
}

# Create WASM bindings
create_wasm_bindings() {
    log "Creating WASM JavaScript bindings..."
    
    mkdir -p "$DIST_DIR"
    
    # Emscripten linker settings
    local emcc_flags=(
        "-s" "MODULARIZE=1"
        "-s" "EXPORT_NAME=GdkPixbuf"
        "-s" "EXPORTED_RUNTIME_METHODS=['ccall','cwrap','setValue','getValue','UTF8ToString','stringToUTF8']"
        "-s" "ALLOW_MEMORY_GROWTH=1"
        "-s" "INITIAL_MEMORY=67108864"  # 64MB
        "-s" "MAXIMUM_MEMORY=268435456" # 256MB
        "-s" "STACK_SIZE=1048576"       # 1MB
        "-s" "NO_EXIT_RUNTIME=1"
        "-s" "ASSERTIONS=0"
        "--bind"
    )
    
    # Target-specific settings
    case "$TARGET" in
        "web")
            emcc_flags+=("-s" "ENVIRONMENT=web")
            ;;
        "node")
            emcc_flags+=("-s" "ENVIRONMENT=node")
            ;;
        "worker")
            emcc_flags+=("-s" "ENVIRONMENT=worker")
            ;;
        "all")
            emcc_flags+=("-s" "ENVIRONMENT=web,worker,node")
            ;;
    esac
    
    # Link all static libraries
    local static_libs=(
        "$BUILD_DIR/gdk-pixbuf/libgdk_pixbuf-2.0.a"
    )
    
    # Add system libraries
    emcc_flags+=("-lglib-2.0" "-lgobject-2.0" "-lgio-2.0")
    
    # Add image format libraries based on features
    if [[ "$FEATURES" == *"png"* ]] || [[ "$FEATURES" == "standard" ]] || [[ "$FEATURES" == "extended" ]] || [[ "$FEATURES" == "all" ]]; then
        emcc_flags+=("-lpng" "-lz")
    fi
    
    if [[ "$FEATURES" == *"jpeg"* ]] || [[ "$FEATURES" == "extended" ]] || [[ "$FEATURES" == "all" ]]; then
        emcc_flags+=("-ljpeg")
    fi
    
    # Create the final WASM module
    emcc "${static_libs[@]}" "${emcc_flags[@]}" \
        -o "$DIST_DIR/gdk-pixbuf.js" \
        $LDFLAGS
    
    log "WASM bindings created successfully"
}

# Create TypeScript definitions
create_typescript_definitions() {
    log "Creating TypeScript definitions..."
    
    cat > "$DIST_DIR/gdk-pixbuf.d.ts" << 'EOF'
/**
 * GdkPixbuf WASM - TypeScript Definitions
 * Copyright 2025 Superstruct Ltd, New Zealand
 * Licensed under LGPL-2.1-or-later
 */

export interface GdkPixbufOptions {
    width: number;
    height: number;
    hasAlpha?: boolean;
    channels?: number;
}

export interface ScaleOptions {
    width: number;
    height: number;
    interpolation?: 'NEAREST' | 'TILES' | 'BILINEAR' | 'HYPER';
}

export interface FormatOptions {
    png?: {
        compression?: number; // 0-9
    };
    jpeg?: {
        quality?: number; // 0-100
        progressive?: boolean;
    };
}

export declare class GdkPixbuf {
    constructor(width: number, height: number, hasAlpha?: boolean);
    
    static newFromData(data: Uint8Array, format?: string): Promise<GdkPixbuf>;
    static newFromFile(filename: string): Promise<GdkPixbuf>;
    static newFromBuffer(buffer: ArrayBuffer): Promise<GdkPixbuf>;
    
    get width(): number;
    get height(): number;
    get channels(): number;
    get hasAlpha(): boolean;
    get rowstride(): number;
    get pixels(): Uint8ClampedArray;
    
    scale(options: ScaleOptions): GdkPixbuf;
    scaleSimple(width: number, height: number, interpolation?: string): GdkPixbuf;
    
    rotate(angle: number): GdkPixbuf;
    flip(horizontal: boolean): GdkPixbuf;
    
    composite(
        source: GdkPixbuf,
        destX: number, destY: number,
        destWidth: number, destHeight: number,
        offsetX: number, offsetY: number,
        scaleX: number, scaleY: number,
        interpolation?: string,
        alpha?: number
    ): void;
    
    toCanvas(canvas: HTMLCanvasElement): void;
    toImageData(): ImageData;
    toBuffer(format?: string, options?: FormatOptions): Uint8Array;
    
    dispose(): void;
}

export declare class GdkPixbufAnimation {
    constructor(data: Uint8Array);
    
    get width(): number;
    get height(): number;
    get isStaticImage(): boolean;
    
    getStaticImage(): GdkPixbuf;
    getIter(): GdkPixbufAnimationIter;
}

export declare class GdkPixbufAnimationIter {
    getPixbuf(): GdkPixbuf;
    advance(currentTime?: number): boolean;
    getDelayTime(): number;
}

export declare class GdkPixbufLoader {
    constructor();
    
    write(data: Uint8Array): void;
    close(): void;
    getPixbuf(): GdkPixbuf | null;
    getAnimation(): GdkPixbufAnimation | null;
    
    setSize(width: number, height: number): void;
}

export interface GdkPixbufModule {
    GdkPixbuf: typeof GdkPixbuf;
    GdkPixbufAnimation: typeof GdkPixbufAnimation;
    GdkPixbufLoader: typeof GdkPixbufLoader;
}

declare function GdkPixbuf(): Promise<GdkPixbufModule>;
export default GdkPixbuf;
EOF
    
    log "TypeScript definitions created"
}

# Create package.json
create_package_json() {
    log "Creating package.json..."
    
    cat > "$DIST_DIR/package.json" << EOF
{
  "name": "@superstruct/gdk-pixbuf-wasm",
  "version": "2.43.6-wasm.1",
  "description": "High-performance image processing library compiled to WebAssembly",
  "main": "gdk-pixbuf.js",
  "types": "gdk-pixbuf.d.ts",
  "files": [
    "gdk-pixbuf.js",
    "gdk-pixbuf.wasm",
    "gdk-pixbuf.d.ts"
  ],
  "keywords": [
    "image",
    "graphics",
    "webassembly",
    "wasm",
    "gdk-pixbuf",
    "png",
    "jpeg",
    "gif"
  ],
  "author": "Superstruct Ltd",
  "license": "LGPL-2.1-or-later",
  "homepage": "https://github.com/superstruct/gdk-pixbuf.wasm",
  "repository": {
    "type": "git",
    "url": "https://github.com/superstruct/gdk-pixbuf.wasm.git"
  },
  "engines": {
    "node": ">=14.0.0"
  },
  "browser": {
    "fs": false,
    "path": false,
    "os": false
  },
  "scripts": {
    "test": "echo 'Run tests with: npm run test:browser'",
    "test:browser": "echo 'Browser testing not yet implemented'",
    "serve": "python3 -m http.server 8080"
  },
  "peerDependencies": {},
  "devDependencies": {},
  "sideEffects": false
}
EOF
    
    log "Package.json created"
}

# Optimize WASM binary
optimize_wasm() {
    log "Optimizing WASM binary..."
    
    # Use wasm-opt if available
    if command -v wasm-opt &> /dev/null; then
        wasm-opt -O3 --enable-simd --dce --vacuum \
            "$DIST_DIR/gdk-pixbuf.wasm" \
            -o "$DIST_DIR/gdk-pixbuf.wasm"
        log "WASM binary optimized with wasm-opt"
    else
        warn "wasm-opt not found, skipping binary optimization"
    fi
    
    # Create size-optimized variant
    if [[ "$OPTIMIZATION" == "size" ]]; then
        if command -v wasm-opt &> /dev/null; then
            wasm-opt -Os --enable-simd --dce --vacuum \
                "$DIST_DIR/gdk-pixbuf.wasm" \
                -o "$DIST_DIR/gdk-pixbuf-min.wasm"
            log "Size-optimized variant created"
        fi
    fi
}

# Generate build report
generate_report() {
    log "Generating build report..."
    
    local report_file="$DIST_DIR/build-report.txt"
    
    cat > "$report_file" << EOF
GdkPixbuf WASM Build Report
==========================
Generated: $(date)
Build Type: $BUILD_TYPE
Target: $TARGET
Features: $FEATURES
Optimization: $OPTIMIZATION

File Sizes:
-----------
EOF
    
    if [[ -f "$DIST_DIR/gdk-pixbuf.js" ]]; then
        echo "JavaScript: $(du -h "$DIST_DIR/gdk-pixbuf.js" | cut -f1)" >> "$report_file"
    fi
    
    if [[ -f "$DIST_DIR/gdk-pixbuf.wasm" ]]; then
        echo "WASM Binary: $(du -h "$DIST_DIR/gdk-pixbuf.wasm" | cut -f1)" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Build Configuration:" >> "$report_file"
    echo "CC: $CC" >> "$report_file"
    echo "CFLAGS: $CFLAGS" >> "$report_file"
    echo "LDFLAGS: $LDFLAGS" >> "$report_file"
    
    log "Build report saved to $report_file"
}

# Cleanup build artifacts
cleanup() {
    if [[ "${KEEP_BUILD:-false}" != "true" ]]; then
        log "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    else
        log "Build directory preserved at $BUILD_DIR"
    fi
}

# Main build process
main() {
    log "Starting GdkPixbuf WASM build..."
    log "Configuration: $BUILD_TYPE/$TARGET/$FEATURES/$OPTIMIZATION"
    
    check_dependencies
    setup_environment
    configure_build
    build_library
    create_wasm_bindings
    create_typescript_definitions
    create_package_json
    optimize_wasm
    generate_report
    cleanup
    
    log "Build completed successfully!"
    log "Output directory: $DIST_DIR"
    
    # Display final file sizes
    echo ""
    echo -e "${BLUE}Final Build Artifacts:${NC}"
    ls -lh "$DIST_DIR"/*.{js,wasm,d.ts} 2>/dev/null || true
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [BUILD_TYPE] [TARGET] [FEATURES] [OPTIMIZATION]

BUILD_TYPE:
  release (default) - Optimized production build
  debug            - Development build with debug symbols
  debugoptimized   - Optimized build with debug info

TARGET:
  web (default)    - Browser environment only
  node            - Node.js environment only
  worker          - Web Worker environment only
  all             - All environments

FEATURES:
  core (default)   - Basic formats (GIF, BMP, ICO, PNM, XPM, XBM, TGA)
  standard        - Core + PNG support
  extended        - Standard + JPEG support
  all             - All supported formats
  simd            - Add SIMD acceleration (can combine with others)
  webgpu          - Add WebGPU support (experimental)

OPTIMIZATION:
  size (default)   - Optimize for binary size
  speed           - Optimize for execution speed
  debug           - Minimal optimization, debug friendly

Examples:
  $0                              # Default: release/web/core/size
  $0 release web standard size    # Standard build with PNG support
  $0 release web "extended,simd"  # Extended build with SIMD acceleration
  $0 debug web core debug         # Debug build for development

Environment Variables:
  KEEP_BUILD=true                 # Preserve build directory
  WASM_PREFIX=/custom/path        # Custom WASM dependencies path

EOF
}

# Handle command line arguments
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Run main build process
main "$@"