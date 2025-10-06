/* GdkPixbuf WASM - GObject Integration Implementation
 * Copyright © 2025 Superstruct Ltd
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include "gdk-pixbuf-wasm.h"
#include "gdk-pixbuf/gdk-pixbuf.h"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

void
gdk_pixbuf_wasm_init (void)
{
#if GDK_PIXBUF_SIDE_MODULE
  /* Set current module name for allocation tracking */
  #ifdef HAVE_G_WASM_SET_CURRENT_MODULE_NAME
  g_wasm_set_current_module_name (GDK_PIXBUF_WASM_MODULE_NAME);
  #endif

  g_message ("GdkPixbuf WASM SIDE_MODULE initialized (version %s)",
             GDK_PIXBUF_WASM_MODULE_VERSION);

  /* Force type registration through unified registry */
  gdk_pixbuf_get_type ();
  gdk_pixbuf_animation_get_type ();
  gdk_pixbuf_animation_iter_get_type ();
  gdk_pixbuf_loader_get_type ();

#else
  g_message ("GdkPixbuf WASM standalone mode initialized (version %s)",
             GDK_PIXBUF_WASM_MODULE_VERSION);
#endif
}

void
gdk_pixbuf_wasm_cleanup (void)
{
#if GDK_PIXBUF_SIDE_MODULE
  g_message ("GdkPixbuf WASM SIDE_MODULE cleanup");
#else
  g_message ("GdkPixbuf WASM standalone cleanup");
#endif
}

#ifdef __EMSCRIPTEN__

/* GModule entry points for dynamic loading */

#if GDK_PIXBUF_SIDE_MODULE

G_MODULE_EXPORT const gchar*
g_module_check_init (GTypeModule *module)
{
  gdk_pixbuf_wasm_init ();
  return NULL;  /* NULL = success */
}

G_MODULE_EXPORT void
g_module_unload (GTypeModule *module)
{
  gdk_pixbuf_wasm_cleanup ();
}

#endif /* GDK_PIXBUF_SIDE_MODULE */

/* Exported functions for validation */

EMSCRIPTEN_KEEPALIVE const char*
gdk_pixbuf_wasm_get_version (void)
{
  return GDK_PIXBUF_WASM_MODULE_VERSION;
}

EMSCRIPTEN_KEEPALIVE int
gdk_pixbuf_wasm_is_side_module (void)
{
  return GDK_PIXBUF_SIDE_MODULE;
}

EMSCRIPTEN_KEEPALIVE void
gdk_pixbuf_wasm_test_type_identity (void)
{
  /* Test that GObject type is the same as glib.wasm's */
  GType gobject_type = g_type_from_name ("GObject");
  GType pixbuf_type = gdk_pixbuf_get_type ();

  g_message ("GObject type: %lu", (unsigned long) gobject_type);
  g_message ("GdkPixbuf type: %lu", (unsigned long) pixbuf_type);
  g_message ("GdkPixbuf parent: %lu", (unsigned long) g_type_parent (pixbuf_type));

  /* Verify type identity */
  if (gobject_type == 0 || pixbuf_type == 0) {
    g_error ("Type registration failed!");
  }

  /* Verify type hierarchy */
  if (!g_type_is_a (pixbuf_type, gobject_type)) {
    g_error ("GdkPixbuf is not a GObject!");
  }

  g_message ("Type identity test passed ✓");
}

EMSCRIPTEN_KEEPALIVE void
gdk_pixbuf_wasm_test_cross_module_alloc (void)
{
  /* Create a pixbuf (allocated via glib.wasm's unified allocator) */
  GdkPixbuf *pixbuf = gdk_pixbuf_new (GDK_COLORSPACE_RGB, FALSE, 8, 64, 64);

  if (!pixbuf) {
    g_error ("Failed to create GdkPixbuf");
  }

  g_message ("Created GdkPixbuf %p (64x64)", pixbuf);

  /* Get refcount */
  guint refcount = G_OBJECT (pixbuf)->ref_count;
  g_message ("Initial refcount: %u", refcount);

  /* Ref/unref (tests cross-module memory safety) */
  g_object_ref (pixbuf);
  g_message ("After ref: %u", G_OBJECT (pixbuf)->ref_count);

  g_object_unref (pixbuf);
  g_message ("After unref: %u", G_OBJECT (pixbuf)->ref_count);

  /* Final unref (should deallocate via glib.wasm) */
  g_object_unref (pixbuf);

  g_message ("Cross-module allocation test passed ✓");
}

#endif /* __EMSCRIPTEN__ */
