// The Nutrition prop (§2.3): a matte white tub, label « GREEK YOGURT 0% » in Inter with a fictional
// EAN-13 (prefix 200: in-store numbers, no real product). No real brand. Units: millimetres.
import { useMemo } from "react";
import * as THREE from "three";
import { INTER, useFontsReady } from "../lib/brand";

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

const PROFILE = {
  bottomR: 40,
  topR: 47.5,
  height: 82,
  lidR: 49.5,
  lidH: 7,
};

/** Label texture: front panel (title, fat-free badge, weight) and, on the side, the barcode. */
const labelTexture = () => {
  const c = document.createElement("canvas");
  c.width = 2048;
  c.height = 640;
  const ctx = c.getContext("2d")!;
  ctx.fillStyle = "#F4F3F0";
  ctx.fillRect(0, 0, c.width, c.height);
  // Front panel (centred at u = 0.25, the side the camera sees first).
  const cx = c.width * 0.25;
  ctx.fillStyle = "#1A1A1E";
  ctx.textAlign = "center";
  ctx.textBaseline = "alphabetic";
  ctx.font = `600 34px "${INTER}"`;
  ctx.letterSpacing = "8px";
  ctx.fillText("PLAIN · NATURE", cx, 150);
  ctx.letterSpacing = "-2px";
  ctx.font = `700 132px "${INTER}"`;
  ctx.fillText("GREEK", cx, 300);
  ctx.fillText("YOGURT", cx, 430);
  ctx.letterSpacing = "0px";
  ctx.fillStyle = "#FF7A59";
  ctx.font = `700 92px "${INTER}"`;
  ctx.fillText("0%", cx, 545);
  ctx.fillStyle = "#6E6E73";
  ctx.font = `500 30px "${INTER}"`;
  ctx.fillText("750 g", cx, 600);
  // Barcode panel, a quarter turn away (u = 0.75), upright.
  drawEan(ctx, c.width * 0.75 - 170, 220, 340, 220);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  t.wrapS = THREE.RepeatWrapping;
  return t;
};

export const YogurtTub: React.FC<{ rotationY: number; position?: [number, number, number]; scale?: number }> = ({
  rotationY,
  position = [0, 0, 0],
  scale = 1,
}) => {
  const fonts = useFontsReady();
  const parts = useMemo(() => {
    const { bottomR, topR, height, lidR, lidH } = PROFILE;
    // Body: a tapered wall with a rolled rim, closed at the bottom.
    const pts = [
      new THREE.Vector2(0, 0),
      new THREE.Vector2(bottomR - 3, 0),
      new THREE.Vector2(bottomR, 2.5),
      new THREE.Vector2(topR, height),
      new THREE.Vector2(topR + 1.2, height + 0.6),
    ];
    const body = new THREE.LatheGeometry(pts, 96);
    // Label: the side of the wall (a slightly larger frustum, open ended), UVs around × up.
    // Radius of the wall at a height (linear from the foot to the rim), the label 0.35 mm proud of it.
    const wall = (y: number) => bottomR + ((topR - bottomR) * (y - 2.5)) / (height - 2.5) + 0.35;
    const y0 = 9;
    const y1 = height - 7;
    const label = new THREE.CylinderGeometry(wall(y1), wall(y0), y1 - y0, 128, 1, true);
    label.translate(0, (y0 + y1) / 2, 0);
    const lid = new THREE.CylinderGeometry(lidR, lidR, lidH, 96);
    lid.translate(0, height + lidH / 2 + 0.4, 0);
    const lidTop = new THREE.CylinderGeometry(lidR - 2, lidR - 0.5, 1.2, 96);
    lidTop.translate(0, height + lidH + 0.9, 0);
    return { body, label, lid, lidTop };
  }, []);
  const mats = useMemo(
    () => ({
      plastic: new THREE.MeshPhysicalMaterial({ color: "#F2F1EE", roughness: 0.55, metalness: 0, sheen: 0.2 }),
      lid: new THREE.MeshPhysicalMaterial({ color: "#EDEBE6", roughness: 0.45, metalness: 0, clearcoat: 0.3 }),
      // Drawn once Inter is decoded (a canvas would otherwise fall back to another font).
      label: new THREE.MeshPhysicalMaterial({ map: fonts ? labelTexture() : null, roughness: 0.5, metalness: 0 }),
    }),
    [fonts],
  );
  return (
    <group position={position} rotation={[0, rotationY, 0]} scale={scale}>
      <mesh geometry={parts.body} material={mats.plastic} />
      <mesh geometry={parts.label} material={mats.label} />
      <mesh geometry={parts.lid} material={mats.lid} />
      <mesh geometry={parts.lidTop} material={mats.lid} />
    </group>
  );
};
