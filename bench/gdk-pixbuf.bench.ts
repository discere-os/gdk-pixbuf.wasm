/**
 * GdkPixbuf WASM Benchmarks
 */

import GdkPixbufWASM from "../src/lib/index.ts"

Deno.bench("gdk-pixbuf initialization", {
  baseline: true
}, async () => {
  const lib = new GdkPixbufWASM()
  await lib.initialize()
})
