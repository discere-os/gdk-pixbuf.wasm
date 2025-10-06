/* GdkPixbuf WASM - GObject Integration
 * Copyright © 2025 Superstruct Ltd
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Integration header for GdkPixbuf SIDE_MODULE to use glib.wasm's
 * unified GObject system.
 */

#ifndef GDK_PIXBUF_WASM_H
#define GDK_PIXBUF_WASM_H

#include <glib.h>
#include <glib-object.h>

/* Include GObject WASM architecture if available */
#if defined(GOBJECT_SIDE_MODULE) || defined(BUILD_SIDE_MODULE)
  #ifdef HAVE_GOBJECT_WASM_H
    #include <gobject/gobject-wasm.h>
  #endif
  #define GDK_PIXBUF_SIDE_MODULE 1
#else
  #define GDK_PIXBUF_SIDE_MODULE 0
#endif

G_BEGIN_DECLS

/* Module information for debugging */
#define GDK_PIXBUF_WASM_MODULE_NAME "gdk-pixbuf"
#define GDK_PIXBUF_WASM_MODULE_VERSION "2.43.6"

/* Initialize GdkPixbuf WASM module
 * Call this from g_module_check_init() if building as SIDE_MODULE
 */
void gdk_pixbuf_wasm_init (void);

/* Cleanup GdkPixbuf WASM module
 * Call this from g_module_unload() if building as SIDE_MODULE
 */
void gdk_pixbuf_wasm_cleanup (void);

G_END_DECLS

#endif /* GDK_PIXBUF_WASM_H */
