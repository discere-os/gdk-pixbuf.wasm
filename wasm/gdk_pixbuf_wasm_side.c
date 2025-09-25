#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gdk-pixbuf/gdk-pixbuf-features.h>

const char* gdk_pixbuf_wasm_version(void) {
  return GDK_PIXBUF_VERSION;
}

