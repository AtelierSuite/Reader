export interface Node {
  tag: number;
  whole: Uint8Array;
  value: Uint8Array;
  children: Node[];
}

export function parseDER(bytes: Uint8Array): Node {
  const [node, used] = read(bytes, 0);
  if (used !== bytes.length) throw new Error("der trailing bytes");
  return node;
}

function read(bytes: Uint8Array, start: number): [Node, number] {
  if (start + 2 > bytes.length) throw new Error("der truncated");
  const tag = bytes[start];
  let length = bytes[start + 1];
  let header = 2;
  if (length & 0x80) {
    const size = length & 0x7f;
    if (size === 0 || size > 4 || start + 2 + size > bytes.length) throw new Error("der length unsupported");
    length = 0;
    for (let i = 0; i < size; i++) length = length * 256 + bytes[start + 2 + i];
    header += size;
  }
  const end = start + header + length;
  if (end > bytes.length) throw new Error("der truncated");
  const value = bytes.subarray(start + header, end);
  const children: Node[] = [];
  if (tag & 0x20) {
    let offset = 0;
    while (offset < value.length) {
      const [child, used] = read(value, offset);
      children.push(child);
      offset = used;
    }
  }
  return [{ tag, whole: bytes.subarray(start, end), value, children }, end];
}

export function oid(node: Node): string {
  if (node.tag !== 0x06) throw new Error("der expected oid");
  const parts = [Math.floor(node.value[0] / 40), node.value[0] % 40];
  let current = 0;
  for (const byte of node.value.subarray(1)) {
    current = current * 128 + (byte & 0x7f);
    if (!(byte & 0x80)) {
      parts.push(current);
      current = 0;
    }
  }
  return parts.join(".");
}

export function child(node: Node, index: number, tag?: number): Node {
  const found = node.children[index];
  if (!found || (tag !== undefined && found.tag !== tag)) throw new Error("der unexpected structure");
  return found;
}

function time(node: Node): Date {
  const text = new TextDecoder().decode(node.value);
  const match = node.tag === 0x17
    ? /^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text)
    : /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(text);
  if (!match) throw new Error("der bad time");
  let year = Number(match[1]);
  if (node.tag === 0x17) year += year < 50 ? 2000 : 1900;
  return new Date(Date.UTC(year, Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6])));
}

const CURVES: { [oid: string]: { name: string; size: number } } = {
  "1.2.840.10045.3.1.7": { name: "P-256", size: 32 },
  "1.3.132.0.34": { name: "P-384", size: 48 },
};

const HASHES: { [oid: string]: string } = {
  "1.2.840.10045.4.3.2": "SHA-256",
  "1.2.840.10045.4.3.3": "SHA-384",
};

export interface Certificate {
  tbs: Uint8Array;
  signatureHash: string;
  signature: Uint8Array;
  spki: Uint8Array;
  curve: { name: string; size: number };
  point: Uint8Array;
  notBefore: Date;
  notAfter: Date;
  extensions: Map<string, Uint8Array>;
}

export function parseCertificate(der: Uint8Array): Certificate {
  const cert = parseDER(der);
  const tbs = child(cert, 0, 0x30);
  const signatureHash = HASHES[oid(child(child(cert, 1, 0x30), 0))];
  const signatureBits = child(cert, 2, 0x03);
  if (!signatureHash) throw new Error("unsupported signature algorithm");
  const offset = tbs.children[0]?.tag === 0xa0 ? 1 : 0;
  const validity = child(tbs, offset + 3, 0x30);
  const spki = child(tbs, offset + 5, 0x30);
  const curve = CURVES[oid(child(child(spki, 0, 0x30), 1))];
  if (!curve) throw new Error("unsupported curve");
  const extensions = new Map<string, Uint8Array>();
  const wrapper = tbs.children.find((node) => node.tag === 0xa3);
  for (const extension of wrapper ? child(wrapper, 0, 0x30).children : []) {
    const value = extension.children[extension.children.length - 1];
    extensions.set(oid(child(extension, 0)), value.value);
  }
  return {
    tbs: tbs.whole,
    signatureHash,
    signature: signatureBits.value.subarray(1),
    spki: spki.whole,
    curve,
    point: child(spki, 1, 0x03).value.subarray(1),
    notBefore: time(child(validity, 0)),
    notAfter: time(child(validity, 1)),
    extensions,
  };
}

export function rawSignature(der: Uint8Array, size: number): Uint8Array {
  const sequence = parseDER(der);
  const out = new Uint8Array(size * 2);
  [child(sequence, 0, 0x02), child(sequence, 1, 0x02)].forEach((integer, index) => {
    let bytes = integer.value;
    while (bytes.length > size && bytes[0] === 0) bytes = bytes.subarray(1);
    if (bytes.length > size) throw new Error("signature integer too large");
    out.set(bytes, index * size + (size - bytes.length));
  });
  return out;
}

export async function verifySignedBy(certificate: Certificate, issuer: Certificate): Promise<boolean> {
  const key = await crypto.subtle.importKey("spki", issuer.spki, { name: "ECDSA", namedCurve: issuer.curve.name }, false, ["verify"]);
  return crypto.subtle.verify(
    { name: "ECDSA", hash: certificate.signatureHash },
    key,
    rawSignature(certificate.signature, issuer.curve.size),
    certificate.tbs,
  );
}
