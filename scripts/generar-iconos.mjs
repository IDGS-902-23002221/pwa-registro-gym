import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function makePng(size, pixel) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const raw = Buffer.alloc(size * (size * 3 + 1));
  let o = 0;
  for (let y = 0; y < size; y++) {
    raw[o++] = 0;
    for (let x = 0; x < size; x++) {
      const [r, g, b] = pixel(x, y, size);
      raw[o++] = r;
      raw[o++] = g;
      raw[o++] = b;
    }
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const NEGRO = [13, 13, 13];
const MORADO = [156, 39, 176];
const MORADO_CLARO = [206, 147, 216];

// dumbbell: barra horizontal al centro y cuatro placas
function pixel(x, y, s) {
  const u = (x / s) * 100;
  const v = (y / s) * 100;
  const dentro = (x0, y0, x1, y1) => u >= x0 && u < x1 && v >= y0 && v < y1;

  const barra = dentro(28, 45, 72, 55);
  const placaIExt = dentro(14, 28, 24, 72);
  const placaIInt = dentro(24, 36, 32, 64);
  const placaEExt = dentro(76, 28, 86, 72);
  const placaEInt = dentro(68, 36, 76, 64);

  if (barra || placaIExt || placaEExt) return MORADO_CLARO;
  if (placaIInt || placaEInt) return MORADO;
  return NEGRO;
}

writeFileSync('public/pwa-192x192.png', makePng(192, pixel));
writeFileSync('public/pwa-512x512.png', makePng(512, pixel));
console.log('iconos generados');