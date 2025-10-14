/**
 * Type definitions for GdkPixbuf WASM
 */

export interface GDK_PIXBUFModule {
  _malloc: (size: number) => number
  _free: (ptr: number) => void
  HEAPU8: Uint8Array
  setValue: (ptr: number, value: number, type: string) => void
  getValue: (ptr: number, type: string) => number
}

export class GDK_PIXBUFError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'GDK_PIXBUFError'
  }
}
