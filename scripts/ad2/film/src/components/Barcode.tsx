// The scan's only prop: a printed EAN-13 on a plain white label (no product, no brand: people know what
// a barcode is). Fictional code, prefix 200 (in-store numbers, no real product). Units: millimetres.
import { useMemo } from "react";
import * as THREE from "three";
import { INTER } from "../lib/brand";

/** Fictional code: 200 (restricted circulation) + 9 digits, then the real EAN-13 check digit. */
export const EAN = (() => {
  const body = "200418273650";
  const sum = body.split("").reduce((s, d, i) => s + Number(d) * (i % 2 === 0 ? 1 : 3), 0);
  return body + String((10 - (sum % 10)) % 10);
})();

const L = ["0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"];
const G = ["0100111", "0110011", "0011011", "0100001", "0011101", "0111001", "0000101", "0010001", "0001001", "0010111"];
const R = ["1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100"];
const PARITY = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"];

/** The 95 modules of an EAN-13 (1 = bar). */
export const eanModules = (code: string) => {
  const d = code.split("").map(Number);
  let bits = "101";
  const parity = PARITY[d[0]];
  for (let i = 1; i <= 6; i++) bits += (parity[i - 1] === "L" ? L : G)[d[i]];
  bits += "01010";
  for (let i = 7; i <= 12; i++) bits += R[d[i]];
  return bits + "101";
};

/** Draws the barcode with its human-readable digits, in a box (x, y, w, h). */
export const drawEan = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number) => {
  const bits = eanModules(EAN);
  const quiet = 9;
  const m = w / (95 + 2 * quiet);
  ctx.fillStyle = "#FFFFFF";
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = "#111114";
  const barH = h * 0.78;
  for (let i = 0; i < 95; i++) {
    if (bits[i] !== "1") continue;
    const guard = i < 3 || (i >= 45 && i < 50) || i >= 92;
    ctx.fillRect(x + (quiet + i) * m, y + h * 0.04, m + 0.3, guard ? barH + h * 0.08 : barH);
  }
  ctx.font = `500 ${h * 0.15}px "${INTER}"`;
  ctx.textAlign = "center";
  ctx.textBaseline = "alphabetic";
  const ty = y + h * 0.98;
  ctx.fillText(EAN[0], x + quiet * m * 0.45, ty);
  ctx.fillText(EAN.slice(1, 7), x + (quiet + 3 + 21) * m, ty);
  ctx.fillText(EAN.slice(7), x + (quiet + 50 + 21) * m, ty);
};

/** The label: 64 × 40 mm, 0.6 mm thick, rounded 3 mm, the barcode printed on its face. */
export const LABEL = { w: 64, h: 40, d: 0.6, r: 3 };

const labelTexture = () => {
  const c = document.createElement("canvas");
  c.width = 1600;
  c.height = 1000;
  const ctx = c.getContext("2d")!;
  ctx.fillStyle = "#F6F5F2";
  ctx.fillRect(0, 0, c.width, c.height);
  drawEan(ctx, 230, 170, 1140, 660);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
};

const rounded = (w: number, h: number, r: number) => {
  const s = new THREE.Shape();
  s.moveTo(-w / 2 + r, -h / 2);
  s.lineTo(w / 2 - r, -h / 2);
  s.quadraticCurveTo(w / 2, -h / 2, w / 2, -h / 2 + r);
  s.lineTo(w / 2, h / 2 - r);
  s.quadraticCurveTo(w / 2, h / 2, w / 2 - r, h / 2);
  s.lineTo(-w / 2 + r, h / 2);
  s.quadraticCurveTo(-w / 2, h / 2, -w / 2, h / 2 - r);
  s.lineTo(-w / 2, -h / 2 + r);
  s.quadraticCurveTo(-w / 2, -h / 2, -w / 2 + r, -h / 2);
  return s;
};

/** The label standing on its long edge, face to +z before `rotationY`. Its texture needs Inter (the digits). */
export const BarcodeLabel: React.FC<{ rotationY: number; position?: [number, number, number]; scale?: number }> = ({
  rotationY,
  position = [0, 0, 0],
  scale = 1,
}) => {
  const parts = useMemo(() => {
    const shape = rounded(LABEL.w, LABEL.h, LABEL.r);
    const body = new THREE.ExtrudeGeometry(shape, { depth: LABEL.d, bevelEnabled: false, curveSegments: 12 });
    body.translate(0, 0, -LABEL.d / 2);
    const face = new THREE.ShapeGeometry(shape, 12);
    const pos = face.attributes.position;
    const uv = face.attributes.uv;
    for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / LABEL.w + 0.5, pos.getY(i) / LABEL.h + 0.5);
    uv.needsUpdate = true;
    return { body, face };
  }, []);
  const mats = useMemo(
    () => ({
      paper: new THREE.MeshPhysicalMaterial({ color: "#F2F1EE", roughness: 0.7, metalness: 0 }),
      print: new THREE.MeshPhysicalMaterial({ map: labelTexture(), roughness: 0.6, metalness: 0 }),
    }),
    [],
  );
  return (
    <group position={position} rotation={[0, rotationY, 0]} scale={scale}>
      <mesh geometry={parts.body} material={mats.paper} />
      <mesh geometry={parts.face} material={mats.print} position={[0, 0, LABEL.d / 2 + 0.02]} />
    </group>
  );
};
