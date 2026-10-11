import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, interpolate } from "remotion";
import * as THREE from "three";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, W } from "../lib/brand";
import { k } from "../lib/kit";
import { useFilmFrame } from "../lib/time";
import { useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";

/**
 * The 15 s film « One Screen » (Concept §6.2), before the Close: My Day in one continuous 60 fps virtual
 * scroll of the stitched page (scripts/ad2/stitch.py), driven by three real flicks released on downbeats
 * (2.0 / 5.0 / 8.0 s) with UIScrollView deceleration (0.998 per ms). Macro: the cards about 980 px wide.
 * The scroll ends exactly on a captured slice (s10), shown as is before the pull-out.
 */
const TALL = k("myday-tall.png");
const LAST = k("home-s10.png");
const TAB = k("home-s00.png");
const FILES = [TALL, LAST, TAB];
const START = 470;
const END = 2897; // offset of slice s10
const FLICKS = [
  { at: 120, distance: 700 },
  { at: 300, distance: 1100 },
  { at: 480, distance: END - START - 1800 },
];
/** UIScrollView deceleration: 0.998 per millisecond → e^(−2.002 t). */
const DECAY = -Math.log(0.998) * 1000;

const scrollAt = (f: number) => {
  let y = START;
  for (const fl of FLICKS) {
    if (f > fl.at) y += fl.distance * (1 - Math.exp((-DECAY * (f - fl.at)) / 60));
  }
  return y;
};

export const MyDay: React.FC<{ audio?: boolean }> = () => {
  const frame = useFilmFrame();
  const images = useImages(FILES);
  const screen = useCanvasTexture();
  const settle = interpolate(frame, [612, 624], [0, 1], clamp);
  if (images) {
    const ctx = screen.ctx;
    const y = Math.min(scrollAt(frame), END);
    ctx.drawImage(images[TALL], 0, y, 1206, 2622, 0, 0, 1206, 2622);
    // Status bar on top and the floating tab bar at the bottom stay put while the page scrolls.
    ctx.drawImage(images[TAB], 0, 0, 1206, 140, 0, 0, 1206, 140);
    ctx.drawImage(images[TAB], 0, 2370, 1206, 252, 0, 2370, 1206, 252);
    if (settle > 0) {
      ctx.globalAlpha = settle;
      ctx.drawImage(images[LAST], 0, 0);
      ctx.globalAlpha = 1;
    }
    screen.texture.needsUpdate = true;
  }
  // Macro at 135 mm (the phone wider than the frame), then the pull-out to the Close's framing (50 mm).
  const out = interpolate(frame, [624, 660], [0, 1], { ...clamp, easing: ease.transfer });
  const lens = 135 - 85 * out;
  const fraction = 1.255 + (0.632 - 1.255) * out;
  const drift = interpolate(frame, [0, 624], [0, 1], clamp);
  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(lens)) / 2) * fraction * (1 + 0.03 * drift));
  // The line ignites across the lit phone (f0–30), then stays on the glass as a still vertical specular line.
  const ignite = interpolate(frame, [0, 6, 30], [0.2, 1, 0], clamp);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      {images && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment />
          <CameraLook lens={lens} position={new THREE.Vector3(0, -6 * (1 - out), distance)} target={new THREE.Vector3(0, -6 * (1 - out), 0)} />
          <Phone3D yaw={0} screen={screen.texture} screenOn={1} sweep={0.5} />
        </ThreeCanvas>
      )}
      <Seam x={AXIS} top={0} height={H} intensity={ignite} />
      <Grain />
    </AbsoluteFill>
  );
};
