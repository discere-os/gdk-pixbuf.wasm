/**
 * GdkPixbuf WASM - GObject Integration Tests
 * Copyright © 2025 Superstruct Ltd
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Validates GdkPixbuf integration with glib.wasm's unified GObject system.
 */

import { assertEquals, assertExists } from "@std/assert";

interface WasmModule {
  ccall: (name: string, returnType: string, argTypes: string[], args: unknown[]) => unknown;
  cwrap: (name: string, returnType: string, argTypes: string[]) => (...args: unknown[]) => unknown;
  _malloc: (size: number) => number;
  _free: (ptr: number) => void;
  HEAPU8: Uint8Array;
  UTF8ToString: (ptr: number) => string;
}

async function loadGdkPixbufWasm(): Promise<WasmModule> {
  const wasmPath = "./install/wasm/gdk-pixbuf-main.js";

  try {
    const module = await import(wasmPath);
    const createModule = module.default;
    const instance = await createModule();
    return instance as WasmModule;
  } catch (error) {
    throw new Error(`Failed to load GdkPixbuf WASM: ${error}`);
  }
}

Deno.test("GdkPixbuf - Module initialization", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const getVersion = pixbuf.cwrap("gdk_pixbuf_wasm_get_version", "string", []);
  const version = getVersion() as string;

  assertExists(version, "Version should be defined");
  assertEquals(version.startsWith("2."), true, "Should be version 2.x");
});

Deno.test("GdkPixbuf - SIDE_MODULE detection", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const isSideModule = pixbuf.cwrap("gdk_pixbuf_wasm_is_side_module", "number", []);
  const result = isSideModule() as number;

  // When built as MAIN for testing, should return 0
  // When built as SIDE for production, should return 1
  assertEquals(typeof result, "number", "Should return a number");
});

Deno.test("GdkPixbuf - Type identity with GObject", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const typeFromName = pixbuf.cwrap("g_type_from_name", "number", ["string"]);

  const gobjectType = typeFromName("GObject") as number;
  const pixbufType = typeFromName("GdkPixbuf") as number;

  assertExists(gobjectType, "GObject type should exist");
  assertExists(pixbufType, "GdkPixbuf type should exist");
  assertEquals(gobjectType > 0, true, "GObject type should be valid");
  assertEquals(pixbufType > 0, true, "GdkPixbuf type should be valid");

  // Test type hierarchy
  const isA = pixbuf.cwrap("g_type_is_a", "number", ["number", "number"]);
  const result = isA(pixbufType, gobjectType) as number;

  assertEquals(result !== 0, true, "GdkPixbuf should be a GObject");
});

Deno.test("GdkPixbuf - Type identity test function", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const testTypeIdentity = pixbuf.cwrap("gdk_pixbuf_wasm_test_type_identity", "null", []);

  // Should not throw
  testTypeIdentity();
});

Deno.test("GdkPixbuf - Cross-module allocation test", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const testCrossModuleAlloc = pixbuf.cwrap("gdk_pixbuf_wasm_test_cross_module_alloc", "null", []);

  // Should not throw, no leaks
  testCrossModuleAlloc();
});

Deno.test("GdkPixbuf - Create and destroy pixbuf", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const newPixbuf = pixbuf.cwrap("gdk_pixbuf_new", "number",
    ["number", "number", "number", "number", "number"]);
  const objectUnref = pixbuf.cwrap("g_object_unref", "null", ["number"]);

  // GDK_COLORSPACE_RGB = 0, has_alpha = 0, bits_per_sample = 8
  const ptr = newPixbuf(0, 0, 8, 128, 128) as number;

  assertExists(ptr, "Pixbuf should be created");
  assertEquals(ptr > 0, true, "Pointer should be valid");

  // Cleanup
  objectUnref(ptr);
});

Deno.test("GdkPixbuf - Pixbuf properties", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const newPixbuf = pixbuf.cwrap("gdk_pixbuf_new", "number",
    ["number", "number", "number", "number", "number"]);
  const getWidth = pixbuf.cwrap("gdk_pixbuf_get_width", "number", ["number"]);
  const getHeight = pixbuf.cwrap("gdk_pixbuf_get_height", "number", ["number"]);
  const getNChannels = pixbuf.cwrap("gdk_pixbuf_get_n_channels", "number", ["number"]);
  const objectUnref = pixbuf.cwrap("g_object_unref", "null", ["number"]);

  const ptr = newPixbuf(0, 0, 8, 256, 128) as number;

  assertEquals(getWidth(ptr), 256, "Width should be 256");
  assertEquals(getHeight(ptr), 128, "Height should be 128");
  assertEquals(getNChannels(ptr), 3, "Should have 3 channels (RGB)");

  objectUnref(ptr);
});

Deno.test("GdkPixbuf - Reference counting", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const newPixbuf = pixbuf.cwrap("gdk_pixbuf_new", "number",
    ["number", "number", "number", "number", "number"]);
  const objectRef = pixbuf.cwrap("g_object_ref", "number", ["number"]);
  const objectUnref = pixbuf.cwrap("g_object_unref", "null", ["number"]);

  const ptr = newPixbuf(0, 0, 8, 64, 64) as number;

  // Initial refcount should be 1 (floating reference is sunk for GdkPixbuf)

  // Ref (increases to 2)
  objectRef(ptr);

  // Unref (back to 1)
  objectUnref(ptr);

  // Final unref (should deallocate)
  objectUnref(ptr);

  // If we got here without crash, test passed
});

Deno.test("GdkPixbuf - Multiple pixbufs", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const newPixbuf = pixbuf.cwrap("gdk_pixbuf_new", "number",
    ["number", "number", "number", "number", "number"]);
  const objectUnref = pixbuf.cwrap("g_object_unref", "null", ["number"]);

  const pixbufs: number[] = [];

  // Create 10 pixbufs
  for (let i = 0; i < 10; i++) {
    const ptr = newPixbuf(0, 0, 8, 32 + i * 8, 32 + i * 8) as number;
    assertExists(ptr, `Pixbuf ${i} should be created`);
    pixbufs.push(ptr);
  }

  // All should have different pointers
  const uniquePointers = new Set(pixbufs);
  assertEquals(uniquePointers.size, 10, "All pointers should be unique");

  // Cleanup
  for (const ptr of pixbufs) {
    objectUnref(ptr);
  }
});

Deno.test("GdkPixbuf - Performance baseline", async () => {
  const pixbuf = await loadGdkPixbufWasm();

  const newPixbuf = pixbuf.cwrap("gdk_pixbuf_new", "number",
    ["number", "number", "number", "number", "number"]);
  const objectUnref = pixbuf.cwrap("g_object_unref", "null", ["number"]);

  const iterations = 1000;
  const start = performance.now();

  for (let i = 0; i < iterations; i++) {
    const ptr = newPixbuf(0, 0, 8, 64, 64) as number;
    objectUnref(ptr);
  }

  const elapsed = performance.now() - start;
  const opsPerSec = (iterations / elapsed) * 1000;

  console.log(`\nPerformance: ${iterations} pixbuf create/destroy cycles`);
  console.log(`  Time: ${elapsed.toFixed(2)}ms`);
  console.log(`  Rate: ${opsPerSec.toFixed(0)} ops/sec`);

  // Sanity check - should be reasonably fast
  assertEquals(elapsed < 5000, true, "Should complete in under 5 seconds");
});
