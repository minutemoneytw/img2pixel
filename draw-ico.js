/* draw-ico.js — 手刻 16x16 像素龍頭 → 多尺寸 img2pixel.ico
 * 色板跟工具 UI 一致：金＝#e8b23a / 亮金＝#f7d270 / 描邊＝#5d3f10
 * 相容性策略：<=64px 用 BMP frame（任何程式都吃），128/256 用 PNG frame（Explorer OK）
 */
const fs = require('fs'), zlib = require('zlib');

// '.'=透明  o=描邊  g=金  h=亮金  w=眼白  p=瞳  n=鼻孔  d=暗金陰影
const PAL = {
  'o': [93, 63, 16, 255],
  'g': [232, 178, 58, 255],
  'h': [247, 210, 112, 255],
  'w': [251, 251, 242, 255],
  'p': [35, 24, 8, 255],
  'n': [138, 92, 20, 255],
  'd': [156, 106, 25, 255],
  '.': [0, 0, 0, 0]
};
const GRID = [
  '.....o....o.....',
  '....ogo..ogo....',
  '....ogoooogo....',
  '...oggggggggo...',
  '..ogghggggghgo..',
  '..ogwwpggpwwgo..',
  '..ogghggggghgo..',
  '..oggnggggnggo..',
  '.oggggggggggggo.',
  '.oggggggggggggo.',
  '.oggggddddggggo.',
  '..oddddddddddo..',
  '....oddddddo....',
  '.....oddddo.....',
  '......oddo......',
  '.......oo.......'
];
const G = 16;
const grid = { w: G, h: G, px: Buffer.alloc(G * G * 4) };
GRID.forEach((row, y) => {
  if (row.length !== G) throw new Error('row ' + y + ' width=' + row.length);
  [...row].forEach((c, x) => {
    const p = PAL[c]; if (!p) throw new Error('bad char ' + c + ' @' + x + ',' + y);
    const i = (y * G + x) * 4;
    grid.px[i] = p[0]; grid.px[i + 1] = p[1]; grid.px[i + 2] = p[2]; grid.px[i + 3] = p[3];
  });
});

function nearest(src, size) {
  const out = { w: size, h: size, px: Buffer.alloc(size * size * 4) };
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const sx = Math.min(src.w - 1, (x * src.w / size) | 0);
    const sy = Math.min(src.h - 1, (y * src.h / size) | 0);
    const si = (sy * src.w + sx) * 4, di = (y * size + x) * 4;
    out.px[di] = src.px[si]; out.px[di + 1] = src.px[si + 1]; out.px[di + 2] = src.px[si + 2]; out.px[di + 3] = src.px[si + 3];
  }
  return out;
}

// BMP frame（ICO 內嵌版 BITMAPINFOHEADER + 32bpp BGRA bottom-up + 1bpp AND mask）
function bmpFrame(img) {
  const s = img.w;
  const head = Buffer.alloc(40);
  head.writeUInt32LE(40, 0);
  head.writeInt32LE(s, 4);
  head.writeInt32LE(s * 2, 8);      // XOR+AND 兩段
  head.writeUInt16LE(1, 12);
  head.writeUInt16LE(32, 14);
  head.writeUInt32LE(s * s * 4 + (((s + 31) >> 5) << 2) * s, 20);
  const px = Buffer.alloc(s * s * 4), mask = Buffer.alloc((((s + 31) >> 5) << 2) * s);
  for (let y = 0; y < s; y++) {
    const srcY = s - 1 - y;                               // bottom-up
    for (let x = 0; x < s; x++) {
      const si = (srcY * s + x) * 4, di = (y * s + x) * 4;
      px[di] = img.px[si + 2]; px[di + 1] = img.px[si + 1]; px[di + 2] = img.px[si]; px[di + 3] = img.px[si + 3];
      if (img.px[si + 3] === 0) mask[y * (((s + 31) >> 5) << 2) + (x >> 3)] |= (0x80 >> (x & 7));
    }
  }
  return Buffer.concat([head, px, mask]);
}

let CRC_T = null;
function crc32(buf) {
  if (!CRC_T) { CRC_T = new Int32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); CRC_T[n] = c; } }
  let c = -1; for (let i = 0; i < buf.length; i++) c = CRC_T[(c ^ buf[i]) & 255] ^ (c >>> 8);
  return ~c;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])) >>> 0);
  return Buffer.concat([len, t, data, crc]);
}
function pngEncode(rgba, size) {
  const stride = size * 4, raw = Buffer.alloc((stride + 1) * size);
  for (let y = 0; y < size; y++) { raw[y * (stride + 1)] = 0; rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))
  ]);
}
const SIZES = [16, 32, 48, 64, 128, 256];
const entries = SIZES.map(s => {
  const px = nearest(grid, s).px;
  return { s, bits: 32, data: bmpFrame({ w: s, h: s, px }) };   // 全 BMP frame：相容性最好（任何程式都吃）
});
const header = Buffer.alloc(6); header.writeUInt16LE(1, 2); header.writeUInt16LE(entries.length, 4);
let offset = 6 + entries.length * 16;
const dir = Buffer.alloc(entries.length * 16), blobs = [];
entries.forEach((e, i) => {
  const d = dir.subarray(i * 16, i * 16 + 16);
  d[0] = e.s === 256 ? 0 : e.s;
  d.writeUInt16LE(1, 4); d.writeUInt16LE(e.bits, 6);
  d.writeUInt32LE(e.data.length, 8); d.writeUInt32LE(offset, 12);
  offset += e.data.length; blobs.push(e.data);
});
const out = process.argv[2] || 'C:/Users/一/Documents/img2pixel/img2pixel.ico';
fs.writeFileSync(out, Buffer.concat([header, dir, ...blobs]));
fs.writeFileSync(process.env.TEMP + '/i2p_icon_preview.png', pngEncode(nearest(grid, 256).px, 256));
console.log('ICO OK:', out, '(preview: %TEMP%/i2p_icon_preview.png)');
