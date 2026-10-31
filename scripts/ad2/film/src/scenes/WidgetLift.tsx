import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, Easing, interpolate } from "remotion";
import * as THREE from "three";
import { Callout } from "../components/Callout";
import { Grain } from "../components/Grain";
import { StyledWidget } from "../components/StyledWidget";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { AXIS, C, clamp, ease, H, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, heroWidget, type Rect } from "../lib/kit";
import { useFilmFrame } from "../lib/time";
import { roundRectPath, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";

/**
 * A widget of a hero Home lifts to 940 px and is read (with a callout), then docks back: the quick-add
 * widget of the Nutrition film (« log your usuals straight from your Home Screen »). No tap: there is no
 * after-state capture. Ends frontal at the Close's framing (50 mm, 63 %).
 */
export const WidgetLift: React.FC<{ audio?: boolean; home?: string; index?: number; label?: string; light?: boolean; styles?: { at: number; file: string }[] }> = ({
  home = "light",
  index = 1,
  label = "Quick add",
  light = true,
  styles = [],
}) => {
  const frame = useFilmFrame();
  const files = [heroHome(home), heroWidget(home, index)];
  const images = useImages(files);
  const screen = useCanvasTexture();
  const slotRect = HERO_WIDGETS[index].rect;
  const lifted = frame >= 20 && frame < 240;
  if (images) {
    const ctx = screen.ctx;
    ctx.drawImage(images[files[0]], 0, 0);
    if (lifted) {
      ctx.save();
      roundRectPath(ctx, slotRect, 66);
      ctx.fillStyle = light ? "rgba(255,255,255,0.35)" : "rgba(10,6,12,0.5)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(214,233,250,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 36;
      ctx.strokeStyle = "rgba(150,200,240,0.25)";
      ctx.stroke();
      ctx.restore();
    }
    screen.texture.needsUpdate = true;
  }
  const lift =
    frame < 210
      ? interpolate(frame, [20, 56], [0, 1], { ...clamp, easing: ease.lift }) + interpolate(frame, [56, 210], [0, 0.015], clamp)
      : interpolate(frame, [210, 240], [1.015, 0], { ...clamp, easing: Easing.bezier(0.5, 0, 0.2, 1) });
  const fraction = interpolate(frame, [0, 60, 210, 240], [0.7, 0.62, 0.62, 0.632], clamp);
  const S = ((H * fraction) / PHONE.h) * (SCREEN.w / 1206);
  const [x, y, w, h] = slotRect;
  const slot: Rect = [AXIS + (x - 603) * S, H / 2 + (y - 1311) * S, w * S, h * S];
  const ratio = h / w;
  const target: Rect = [AXIS - 470, 760 - (940 * ratio) / 2, 940, 940 * ratio];
  const r = slot.map((v, j) => v + (target[j] - v) * lift) as Rect;
  r[1] -= Math.sin(Math.PI * Math.min(1, lift)) * 40;
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      {images && (
        <AbsoluteFill style={{ filter: `blur(${8 * Math.min(1, lift)}px) brightness(${1 - 0.45 * Math.min(1, lift)})` }}>
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={50} position={new THREE.Vector3(0, 0, PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(50)) / 2) * fraction))} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={0} screen={screen.texture} screenOn={1} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}
      {lifted && <StyledWidget base={files[1]} styles={styles} frame={frame} rect={r} lift={Math.min(1, lift)} />}
      <Callout label={label} at={[target[0] + 80, target[1] - 10]} labelY={target[1] - 110} from={60} to={200} />
      <Grain />
    </AbsoluteFill>
  );
};
