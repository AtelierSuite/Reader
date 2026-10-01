export type CBOR = number | string | boolean | null | Uint8Array | CBOR[] | Map<CBOR, CBOR>;

export function decodeCBOR(bytes: Uint8Array): CBOR {
  let offset = 0;

  function take(count: number): Uint8Array {
    if (offset + count > bytes.length) throw new Error("cbor truncated");
    const out = bytes.subarray(offset, offset + count);
    offset += count;
    return out;
  }

  function length(info: number): number {
    if (info < 24) return info;
    const size = info === 24 ? 1 : info === 25 ? 2 : info === 26 ? 4 : info === 27 ? 8 : 0;
    if (size === 0) throw new Error("cbor length unsupported");
    let value = 0;
    for (const byte of take(size)) value = value * 256 + byte;
    if (!Number.isSafeInteger(value)) throw new Error("cbor length too large");
    return value;
  }

  function item(): CBOR {
    const [head] = take(1);
    const major = head >> 5;
    const info = head & 31;
    switch (major) {
      case 0:
        return length(info);
      case 1:
        return -1 - length(info);
      case 2:
        return take(length(info)).slice();
      case 3:
        return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(take(length(info)));
      case 4: {
        const count = length(info);
        const out: CBOR[] = [];
        for (let i = 0; i < count; i++) out.push(item());
        return out;
      }
      case 5: {
        const count = length(info);
        const out = new Map<CBOR, CBOR>();
        for (let i = 0; i < count; i++) {
          const key = item();
          out.set(key, item());
        }
        return out;
      }
      case 7:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 22) return null;
        throw new Error("cbor simple value unsupported");
      default:
        throw new Error("cbor type unsupported");
    }
  }

  const value = item();
  if (offset !== bytes.length) throw new Error("cbor trailing bytes");
  return value;
}

export function field(value: CBOR, key: string): CBOR | undefined {
  return value instanceof Map ? value.get(key) : undefined;
}
