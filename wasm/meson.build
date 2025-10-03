gdkp_wasm_cargs = ['-msimd128', '-DGDKPIXBUF_WASM=1']

gdkp_main_link_args = [
  '-sWASM=1',
  '-sMODULARIZE=1',
  '-sEXPORT_ES6=1',
  '-sEXPORT_NAME=GdkPixbufModule',
  '-sALLOW_MEMORY_GROWTH=1',
  '-sENVIRONMENT=web,webview,worker',
  '-sNO_FILESYSTEM=1',
  '-sEXPORTED_RUNTIME_METHODS=["cwrap","ccall","UTF8ToString"]',
  '-O3',
  '-flto',
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

gdkp_side_link_args = [
  '-sSIDE_MODULE=2',
  '-fPIC',
  '-O3',
  '-flto',
  '-sERROR_ON_UNDEFINED_SYMBOLS=0',  # Host provides dependencies (glib, png, jpeg, tiff, webp, etc.)
  '-sEXPORTED_FUNCTIONS=["_gdk_pixbuf_wasm_version"]',
]

shared_module(
  'gdk-pixbuf-side',
  files('gdk_pixbuf_wasm_side.c'),
  dependencies: [gdkpixbuf_dep],
  name_prefix: '',
  name_suffix: 'wasm',
  c_args: gdkp_wasm_cargs,
  link_args: gdkp_side_link_args,
  install: true,
  install_dir: get_option('libdir'),
)

