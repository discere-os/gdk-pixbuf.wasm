# GdkPixbuf WASM Build Configuration
# Part of the unified Meson build system for Discere OS
# Copyright 2025 Superstruct Ltd, New Zealand
# Licensed under LGPL-2.1-or-later

# Get build options from meson_options.txt
wasm_build_type = get_option('wasm_build_type')
wasm_simd = get_option('wasm_simd')
wasm_threading = get_option('wasm_threading')
wasm_optimize = get_option('wasm_optimize')

# Common compilation flags for all WASM builds
gdkp_wasm_cargs = [
  '-DGDKPIXBUF_WASM=1',
  '-flto',
]

# Add SIMD support (mandatory for Chrome/Edge 113+)
if wasm_simd
  gdkp_wasm_cargs += ['-msimd128']
endif

# Add threading support
if wasm_threading
  gdkp_wasm_cargs += ['-pthread']
endif

# Optimization strategy
if wasm_optimize == 'size'
  gdkp_wasm_cargs += ['-Os']
elif wasm_optimize == 'speed'
  gdkp_wasm_cargs += ['-O3']
else  # balanced
  gdkp_wasm_cargs += ['-O3']
endif

# Common link flags
common_link_args = [
  '-flto',
  '-sWASM_BIGINT=1',
  '-sENVIRONMENT=web,webview,worker',
]

# Add threading to link args
if wasm_threading
  common_link_args += ['-pthread', '-sPROXY_TO_PTHREAD']
endif

# Build type specific memory configuration
memory_args = []
if wasm_build_type == 'minimal'
  memory_args = [
    '-sINITIAL_MEMORY=64MB',
    '-sALLOW_MEMORY_GROWTH=1',
  ]
elif wasm_build_type == 'standard'
  memory_args = [
    '-sINITIAL_MEMORY=128MB',
    '-sMAXIMUM_MEMORY=1GB',
    '-sALLOW_MEMORY_GROWTH=1',
  ]
elif wasm_build_type == 'webgpu'
  memory_args = [
    '-sUSE_WEBGPU=1',
    '-sASYNCIFY=1',
    '-sINITIAL_MEMORY=256MB',
    '-sMAXIMUM_MEMORY=2GB',
    '-sALLOW_MEMORY_GROWTH=1',
  ]
endif

# MAIN_MODULE build (self-contained for testing/NPM)
# Includes all dependencies statically linked
gdkp_main_link_args = common_link_args + memory_args + [
  '-sWASM=1',
  '-sMODULARIZE=1',
  '-sEXPORT_ES6=1',
  '-sEXPORT_NAME=GdkPixbufModule',
  '-sNO_FILESYSTEM=1',
  '-sEXPORTED_RUNTIME_METHODS=["cwrap","ccall","UTF8ToString","FS","HEAPU8"]',
  '-sSINGLE_FILE=1',
]

executable(
  'gdk-pixbuf-main',
  files('gdk_pixbuf_wasm_module.c'),
  dependencies: [gdkpixbuf_dep],
  c_args: gdkp_wasm_cargs,
  link_args: gdkp_main_link_args,
  install: true,
  install_dir: get_option('bindir'),
)

# SIDE_MODULE build (production - dynamic loading by discere-concha.wasm)
# Minimal size, host provides dependencies via dlopen()
gdkp_side_link_args = common_link_args + [
  '-sSIDE_MODULE=2',
  '-fPIC',
  '-sERROR_ON_UNDEFINED_SYMBOLS=0',  # Host provides dependencies (glib, png, jpeg, tiff, webp, etc.)
  '-sEXPORTED_FUNCTIONS=["_gdk_pixbuf_wasm_version"]',
]

# SIDE_MODULE builds should be size-optimized
if wasm_optimize != 'size'
  gdkp_side_link_args += ['-O3']
endif

shared_module(
  'gdk-pixbuf-side',
  files('gdk_pixbuf_wasm_side.c'),
  dependencies: [gdkpixbuf_dep],
  name_prefix: '',
  name_suffix: 'wasm',
  c_args: gdkp_wasm_cargs + ['-DGOBJECT_SIDE_MODULE=1'],
  link_args: gdkp_side_link_args,
  install: true,
  install_dir: get_option('libdir'),
)
