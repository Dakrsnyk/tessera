import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, Easing, interpolate } from "remotion";
import * as THREE from "three";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { StyledWidget } from "../components/StyledWidget";
import { AXIS, C, clamp, ease, H, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, heroWidget, type Rect } from "../lib/kit";
import { useFilmFrame } from "../lib/time";
import { drawBlade, roundRectPath, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";

/**
 * The 8 s film « The Line » (Concept §6.3), before the Close: the line ignites, opens into the two halves
 * of the « A »; in the widening gap the Home changes universe on each beat (Aurora → Neon → Paper → Sunset)
 * until the gap is phone-wide; the macros widget lifts (960 px), then docks back.
 */
const ORDER = [
  { at: 0, u: "aurore" },
  { at: 60, u: "neon" },
  { at: 90, u: "etudes" },
  { at: 120, u: "crepuscule" },
];
const MACROS = HERO_WIDGETS[0];
const FILES = [...ORDER.map((o) => heroHome(o.u)), heroWidget("crepuscule", MACROS.index)];
const LENS = 50;
const FRACTION = 0.632;
const S = ((H * FRACTION) / PHONE.h) * (SCREEN.w / 1206);
const toFrame = ([x, y, w, h]: Rect): Rect => [AXIS + (x - 603) * S, H / 2 + (y - 1311) * S, w * S, h * S];
const LIFTED: Rect = [60, 760 - (960 * 510) / 1092 / 2, 960, (960 * 510) / 1092];

export const LineOpen: React.FC<{ audio?: boolean; styles?: { at: number; file: string }[] }> = ({ styles = [] }) => {
  const frame = useFilmFrame();
  const images = useImages(FILES);
  const screen = useCanvasTexture();
  const lift = frame < 240 ? interpolate(frame, [150, 186], [0, 1], { ...clamp, easing: ease.lift }) : interpolate(frame, [240, 270], [1, 0], { ...clamp, easing: Easing.bezier(0.5, 0, 0.2, 1) });
  const lifted = frame >= 150 && frame < 270;

  if (images) {
    const ctx = screen.ctx;
    let i = 0;
    while (i + 1 < ORDER.length && frame >= ORDER[i + 1].at) i++;
    ctx.drawImage(images[heroHome(ORDER[i].u)], 0, 0);
    const next = ORDER[i + 1];
    // Each change is a blade across the screen, 10 frames, landing on the beat.
    if (next && frame >= next.at - 10) {
      const p = interpolate(frame, [next.at - 10, next.at], [0, 1], clamp);
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, 0, 1206 * p, 2622);
      ctx.clip();
      ctx.drawImage(images[heroHome(next.u)], 0, 0);
      ctx.restore();
      drawBlade(ctx, 1206 * p, 0, 2622, Math.sin(Math.PI * p));
    }
    if (lifted) {
      ctx.save();
      roundRectPath(ctx, MACROS.rect, 66);
      ctx.fillStyle = "rgba(10,6,12,0.5)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(214,233,250,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 36;
      ctx.strokeStyle = "rgba(214,233,250,0.18)";
      ctx.stroke();
      ctx.restore();
    }
    screen.texture.needsUpdate = true;
  }

  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(LENS)) / 2) * FRACTION);
  const phoneW = SCREEN.w * ((H * FRACTION) / PHONE.h) * 1.1;
  const gap = interpolate(frame, [24, 150], [0, phoneW + 80], { ...clamp, easing: Easing.bezier(0.5, 0, 0.25, 1) });
  const ignite = interpolate(frame, [0, 6, 14], [0.15, 1, 1], clamp);
  const edges = interpolate(frame, [140, 175], [1, 0], clamp) * ignite;
  const lineH = H * FRACTION;
  const slot = toFrame(MACROS.rect);
  const r: Rect = slot.map((v, j) => v + (LIFTED[j] - v) * lift) as Rect;
  r[1] -= Math.sin(Math.PI * lift) * 40;

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      {images && (
        <AbsoluteFill
          style={{
            clipPath: `inset(0px ${W / 2 - gap / 2}px 0px ${W / 2 - gap / 2}px)`,
            filter: lifted ? `blur(${8 * lift}px) brightness(${1 - 0.45 * lift})` : undefined,
          }}
        >
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={LENS} position={new THREE.Vector3(0, 0, distance)} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={0} screen={screen.texture} screenOn={1} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}
      <Seam x={AXIS - gap / 2} top={H / 2 - lineH / 2} height={lineH} intensity={edges} />
      {gap > 2 && <Seam x={AXIS + gap / 2} top={H / 2 - lineH / 2} height={lineH} intensity={edges} />}
      {lifted && <StyledWidget base={heroWidget("crepuscule", MACROS.index)} styles={styles} frame={frame} rect={r} lift={lift} />}
      <Grain />
    </AbsoluteFill>
  );
};
