// The Personalisation film « Build Your World » (Concept §6.6): its own scenes around the Universes.
import { ThreeCanvas } from "@remotion/three";
import { useMemo } from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile } from "remotion";
import * as THREE from "three";
import { Callout } from "../components/Callout";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { DOCK, dockIcon, HERO_WIDGETS, heroHome, heroWidget, k, type Rect, wall } from "../lib/kit";
import { useFilmFrame } from "../lib/time";
import { roundRectPath, useCanvasTexture } from "../lib/useCanvas";
import { imageTexture, useImages } from "../lib/useImages";

const distanceFor = (lens: number, fraction: number) => PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(lens)) / 2) * fraction);
const Backdrop: React.FC = () => <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />;

/** 0–6 s: a bare wallpaper; the line crosses the glass; real widgets fall onto the grid on the beats. */
const B = "aurore";
const BUILD_FILES = [heroHome(B), wall(B), ...HERO_WIDGETS.map((w) => heroWidget(B, w.index)), ...DOCK.map((_, i) => dockIcon(B, i))];
const LANDS = [150, 180, 210, 240];

export const Build: React.FC<{ audio?: boolean }> = () => {
  const frame = useFilmFrame();
  const images = useImages(BUILD_FILES);
  const screen = useCanvasTexture();
  if (images) {
    const ctx = screen.ctx;
    ctx.drawImage(images[heroHome(B)], 0, 0);
    // The real Home without its widgets, their names and the dock icons: the wallpaper shows in their places.
    for (const [x, y, w, h] of HERO_WIDGETS.map((w) => w.rect)) {
      ctx.drawImage(images[wall(B)], x - 30, y - 30, w + 60, h + 110, x - 30, y - 30, w + 60, h + 110);
    }
    for (const [x, y, w, h] of DOCK) {
      ctx.drawImage(images[wall(B)], x - 20, y - 20, w + 40, h + 40, x - 20, y - 20, w + 40, h + 40);
    }
    HERO_WIDGETS.forEach((w, i) => {
      const p = interpolate(frame, [LANDS[i] - 18, LANDS[i]], [0, 1], { ...clamp, easing: Easing.bezier(0.55, 0, 0.9, 0.6) });
      if (p <= 0) return;
      const settle = interpolate(frame, [LANDS[i], LANDS[i] + 10], [1.03, 1], { ...clamp, easing: Easing.bezier(0.2, 0, 0.2, 1) });
      const s = (1.25 - 0.25 * p) * (p >= 1 ? settle : 1);
      const [x, y, ww, hh] = w.rect;
      ctx.save();
      ctx.globalAlpha = Math.min(1, p * 2);
      ctx.shadowColor = `rgba(0,0,0,${0.5 * (1 - p) + 0.15})`;
      ctx.shadowBlur = 50 * (1 - p) + 10;
      ctx.shadowOffsetY = 30 * (1 - p);
      ctx.drawImage(images[heroWidget(B, w.index)], x + (ww - ww * s) / 2, y + (hh - hh * s) / 2 - 160 * (1 - p), ww * s, hh * s);
      ctx.restore();
      // Its name under it (from the real Home), once it has landed.
      if (p >= 1) ctx.drawImage(images[heroHome(B)], x - 30, y + hh + 4, ww + 60, 76, x - 30, y + hh + 4, ww + 60, 76);
    });
    DOCK.forEach((r, i) => {
      const a = interpolate(frame, [250 + 6 * i, 268 + 6 * i], [0, 1], { ...clamp, easing: ease.arrival });
      if (a <= 0) return;
      ctx.globalAlpha = a;
      const s = 0.8 + 0.2 * a;
      ctx.drawImage(images[dockIcon(B, i)], r[0] + (r[2] * (1 - s)) / 2, r[1] + (r[3] * (1 - s)) / 2, r[2] * s, r[3] * s);
      ctx.globalAlpha = 1;
    });
    screen.texture.needsUpdate = true;
  }
  const fraction = interpolate(frame, [0, 359], [0.74, 0.875], { ...clamp, easing: Easing.bezier(0.3, 0, 0.7, 1) });
  const phoneH = H * fraction;
  const line = interpolate(frame, [20, 28, 60], [0, 1, 0], clamp);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <Backdrop />
      {images && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment />
          <CameraLook lens={85} position={new THREE.Vector3(0, 0, distanceFor(85, fraction))} target={new THREE.Vector3(0, 0, 0)} />
          <Phone3D yaw={0} screen={screen.texture} screenOn={interpolate(frame, [0, 12], [0.4, 1], clamp)} />
        </ThreeCanvas>
      )}
      <Seam x={AXIS} top={H / 2 - phoneH / 2} height={phoneH} intensity={line} />
      <Grain />
    </AbsoluteFill>
  );
};

/** 11–15 s: the macros widget lifts and changes style on each beat (same data), then docks back. */
const U = "crepuscule";
const STYLES = [
  { at: 60, file: k("macros-m-glass.png") },
  { at: 90, file: k("macros-m-neon.png") },
  { at: 120, file: k("macros-m-paper.png") },
  { at: 150, file: k("macros-m-luxury.png") },
  { at: 180, file: k("macros-m-liquidGlass.png") },
  { at: 210, file: heroWidget(U, 0) },
];
const STYLE_FILES = [heroHome(U), heroWidget(U, 0)];
const SC_LIFTED: Rect = [60, 760 - (960 * 510) / 1092 / 2, 960, (960 * 510) / 1092];

export const StyleCycle: React.FC<{ audio?: boolean }> = () => {
  const frame = useFilmFrame();
  const images = useImages(STYLE_FILES);
  const screen = useCanvasTexture();
  const macros = HERO_WIDGETS[0];
  const lifted = frame >= 0 && frame < 240;
  if (images) {
    const ctx = screen.ctx;
    ctx.drawImage(images[heroHome(U)], 0, 0);
    if (lifted) {
      ctx.save();
      roundRectPath(ctx, macros.rect, 66);
      ctx.fillStyle = "rgba(10,6,12,0.5)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(255,224,204,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 36;
      ctx.strokeStyle = "rgba(255,224,204,0.18)";
      ctx.stroke();
      ctx.restore();
    }
    screen.texture.needsUpdate = true;
  }
  const lift = frame < 214 ? interpolate(frame, [0, 36], [0, 1], { ...clamp, easing: ease.lift }) : interpolate(frame, [214, 240], [1, 0], { ...clamp, easing: Easing.bezier(0.5, 0, 0.2, 1) });
  const fraction = interpolate(frame, [0, 40, 214, 240], [0.78, 0.68, 0.68, 0.632], clamp);
  const S = ((H * fraction) / PHONE.h) * (SCREEN.w / 1206);
  const [x, y, w, h] = macros.rect;
  const slot: Rect = [AXIS + (x - 603) * S, H / 2 + (y - 1311) * S, w * S, h * S];
  const r = slot.map((v, j) => v + (SC_LIFTED[j] - v) * lift) as Rect;
  r[1] -= Math.sin(Math.PI * lift) * 40;
  let cur = heroWidget(U, 0);
  let nxt: string | null = null;
  let wipe = 0;
  for (const st of STYLES) {
    if (frame >= st.at) cur = st.file;
    else if (frame >= st.at - 10) {
      nxt = st.file;
      wipe = interpolate(frame, [st.at - 10, st.at], [0, 1], { easing: Easing.bezier(0.45, 0, 0.55, 1) });
    }
  }
  const blur = interpolate(lift, [0, 1], [0, 8]);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <Backdrop />
      {images && (
        <AbsoluteFill style={{ filter: `blur(${blur}px) brightness(${1 - 0.45 * lift})` }}>
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={85} position={new THREE.Vector3(0, 0, distanceFor(85, fraction))} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={0} screen={screen.texture} screenOn={1} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}
      <div style={{ position: "absolute", left: r[0], top: r[1], width: r[2], height: r[3], filter: `drop-shadow(0 ${30 * lift}px ${70 * lift}px rgba(0,0,0,0.6))` }}>
        <Img src={staticFile(cur)} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
        {nxt && <Img src={staticFile(nxt)} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", clipPath: `inset(0 ${(1 - wipe) * 100}% 0 0)` }} />}
      </div>
      {nxt && <Seam x={r[0] + r[2] * wipe} top={r[1]} height={r[3]} spread={0.45} intensity={Math.sin(Math.PI * wipe)} />}
      <SplitText from={62} exitAt={186} top={1250} height={100}>
        <span style={type.super}>57 styles</span>
      </SplitText>
      <Grain />
    </AbsoluteFill>
  );
};

/** 15–18 s: the matching real Lock Screen slides in beside the Home; the app icon changes through blades. */
const ICONS = ["icon-Default", "icon-Classic", "icon-GlassBlack", "icon-RedGlass"].map((n) => k(`icons/${n}.png`));
const ICON_AT = [0, 70, 100, 130];

export const LockIcon: React.FC<{ audio?: boolean }> = () => {
  const frame = useFilmFrame();
  const sw = 430;
  const sh = (sw * 2622) / 1206;
  const homeX = interpolate(frame, [0, 34], [AXIS - sw / 2, AXIS - sw - 24], { ...clamp, easing: ease.transfer });
  const lockX = interpolate(frame, [8, 40], [W + 40, AXIS + 24], { ...clamp, easing: ease.arrival });
  const top = 250;
  const screenStyle = (x: number): React.CSSProperties => ({
    position: "absolute",
    left: x,
    top,
    width: sw,
    height: sh,
    borderRadius: 60,
    overflow: "hidden",
    boxShadow: "0 0 0 6px #2B2A28, 0 0 0 7.5px #8A8781, 0 40px 90px rgba(0,0,0,0.6)",
  });
  let cur = 0;
  for (let i = 0; i < ICON_AT.length; i++) if (frame >= ICON_AT[i]) cur = i;
  const nextI = ICON_AT.findIndex((at) => frame >= at - 10 && frame < at);
  const wipe = nextI > 0 ? interpolate(frame, [ICON_AT[nextI] - 10, ICON_AT[nextI]], [0, 1]) : 0;
  const icon = 230;
  const iconX = AXIS - icon / 2;
  const iconY = top + sh + 70;
  const iconIn = interpolate(frame, [40, 60], [0, 1], { ...clamp, easing: ease.arrival });
  const iconStyle: React.CSSProperties = { position: "absolute", left: 0, top: 0, width: icon, height: icon, borderRadius: icon * 0.2237 };
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <Backdrop />
      <div style={screenStyle(homeX)}>
        <Img src={staticFile(heroHome(U))} style={{ width: sw, height: sh }} />
      </div>
      <div style={screenStyle(lockX)}>
        <Img src={staticFile(k(`lock-${U}.png`))} style={{ width: sw, height: sh }} />
      </div>
      <div style={{ position: "absolute", left: iconX, top: iconY + 30 * (1 - iconIn), width: icon, height: icon, opacity: iconIn, filter: "drop-shadow(0 24px 40px rgba(0,0,0,0.6))" }}>
        <Img src={staticFile(ICONS[cur])} style={iconStyle} />
        {nextI > 0 && <Img src={staticFile(ICONS[nextI])} style={{ ...iconStyle, clipPath: `inset(0 ${(1 - wipe) * 100}% 0 0)` }} />}
      </div>
      {nextI > 0 && <Seam x={iconX + icon * wipe} top={iconY} height={icon} spread={0.35} intensity={Math.sin(Math.PI * wipe)} />}
      <Callout label="Lock Screen" at={[lockX + sw / 2, top - 8]} labelY={top - 70} from={44} to={170} />
      <Callout label="App icon" at={[iconX + icon + 8, iconY + icon / 2]} labelX={iconX + icon + 60} from={64} to={170} />
      <Grain />
    </AbsoluteFill>
  );
};

/** 18–21 s: five real Store Homes in a row at different depths slide together through the seam into one. */
const FIVE = ["aurore", "neon", "etudes", "espace", "crepuscule"];
const FIVE_FILES = FIVE.map(heroHome);

export const FivePhones: React.FC<{ audio?: boolean }> = () => {
  const frame = useFilmFrame();
  const images = useImages(FIVE_FILES);
  const textures = useMemo(() => (images ? FIVE_FILES.map((f) => imageTexture(images[f])) : null), [images]);
  const merge = interpolate(frame, [100, 165], [0, 1], { ...clamp, easing: ease.transfer });
  const fraction = interpolate(frame, [0, 60, 100, 170], [0.5, 0.42, 0.42, 0.632], { ...clamp, easing: [ease.arrival, Easing.linear, ease.transfer] });
  const slots = [-2, -1, 1, 2, 0];
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <Backdrop />
      {textures && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment />
          <CameraLook lens={50} position={new THREE.Vector3(0, 0, distanceFor(50, fraction))} target={new THREE.Vector3(0, 0, 0)} />
          {textures.map((t, i) => {
            const s = slots[i];
            const x = s * 92 * (1 - merge);
            const z = -Math.abs(s) * 70 * (1 - merge) - (s === 0 ? 0 : 40 * merge);
            return <Phone3D key={i} yaw={-s * 8 * (1 - merge)} position={[x, 0, z]} screen={t} screenOn={s === 0 ? 1 : 1 - merge * 0.9} />;
          })}
        </ThreeCanvas>
      )}
      {merge > 0 && merge < 1 && <Seam x={AXIS} top={H / 2 - (H * fraction) / 2} height={H * fraction} intensity={Math.sin(Math.PI * merge)} />}
      <SplitText from={0} exitAt={90} top={1500} height={100}>
        <span style={type.super}>23 ready-made</span>
      </SplitText>
      <SplitText from={8} exitAt={90} top={1596} height={100}>
        <span style={{ ...type.super, color: C.type2 }}>Home Screens</span>
      </SplitText>
      <Grain />
    </AbsoluteFill>
  );
};
