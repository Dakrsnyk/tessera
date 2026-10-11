import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, Easing, Img, interpolate, random, staticFile } from "remotion";
import * as THREE from "three";
import { FilmAudio } from "../components/FilmAudio";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { AXIS, C, clamp, ease, H, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, heroWidget, k, type Rect, wall } from "../lib/kit";
import { drawBlade, roundRectPath, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { useFilmFrame } from "../lib/time";

/** Local frame 0 = f2880 of the main film (48.0 s). The merge peak is f3120 = local 240. */
const U = "crepuscule";
/** Each hero widget arrives in a different style: one interface, many looks (§5.2 shot 22). */
const FLOATERS = [
  { index: 0, from: "aurore", at: [-70, -330] as [number, number] },
  { index: 1, from: "neon", at: [110, -40] as [number, number] },
  { index: 2, from: "etudes", at: [-150, 300] as [number, number] },
  { index: 3, from: "espace", at: [150, 330] as [number, number] },
];
const CONSTELLATION = [
  "budgetLeft-s-luxury",
  "calories-m-aurora",
  "habitStreak-s-neon",
  "habits-m-aurora",
  "hydration-s-ocean",
  "moneyDashboard-m-aurora",
  "nextSet-s-luxury",
  "priorities-s-paper",
  "restTimer-s-neon",
  "spendingByCategory-m-glass",
  "timetable-l-editorial",
  "todaysWorkout-m-aurora",
  "trainingStreak-s-sport",
  "upNext-s-elegant",
  "weekView-m-editorial",
  "weeklyVolume-m-neon",
  "yearDots-l-space",
  "calories-s-blossom",
  "calories-s-synthwave",
  "calories-s-liquidGlass",
  "macros-m-luxury",
  "macros-m-synthwave",
  "macros-m-editorial",
  "macros-m-ocean",
  "hydration-s-glass",
  "habits-m-neon",
  "moneyDashboard-m-dark",
  "restTimer-s-light",
  "trainingStreak-s-aurora",
  "upNext-s-light",
  "weekView-m-aurora",
  "yearDots-l-dark",
  "todaysWorkout-m-light",
  "calories-s-preset-cyber",
  "macros-m-matteBlack",
  "habitStreak-s-light",
  "calories-s-ocean",
  "timetable-l-aurora",
  "weeklyVolume-m-light",
  "calories-s-matteBlack",
].map((n) => k(`${n}.png`));
const FILES = [heroHome(U), wall(U), ...HERO_WIDGETS.map((w) => heroWidget(U, w.index))];
const DOCK_AT = (i: number) => 240 + 4 * i;

/** Frontal at the end: 50 mm, the phone at 62 % of the frame height. */
const FRACTION = 0.62;
const LENS = 50;
const S = ((H * FRACTION) / PHONE.h) * (SCREEN.w / 1206);
const toFrame = ([x, y, w, h]: Rect): Rect => [AXIS + (x - 603) * S, H / 2 + (y - 1311) * S, w * S, h * S];

export const Gather: React.FC<{ audio?: boolean }> = ({ audio = true }) => {
  const frame = useFilmFrame();
  const images = useImages(FILES);
  const screen = useCanvasTexture();
  const docked = (i: number) => frame >= DOCK_AT(i) + 30;

  if (images) {
    const ctx = screen.ctx;
    ctx.drawImage(images[heroHome(U)], 0, 0);
    HERO_WIDGETS.forEach((w, i) => {
      if (docked(i)) return;
      // An empty slot: the wallpaper, glowing as a socket.
      const [x, y, ww, hh] = w.rect;
      ctx.drawImage(images[wall(U)], x - 30, y - 30, ww + 60, hh + 66, x - 30, y - 30, ww + 60, hh + 66);
      ctx.save();
      roundRectPath(ctx, w.rect, 60);
      ctx.fillStyle = "rgba(10,6,12,0.35)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(255,224,204,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 36;
      ctx.strokeStyle = `rgba(255,224,204,${0.18 + 0.12 * Math.sin(frame / 12 + i)})`;
      ctx.stroke();
      ctx.restore();
      // On contact the socket flashes 30 % for 4 frames.
      const flash = interpolate(frame, [DOCK_AT(i) + 30, DOCK_AT(i) + 34], [0.3, 0], clamp);
      if (frame >= DOCK_AT(i) + 26 && flash > 0) {
        ctx.fillStyle = `rgba(255,224,204,${flash})`;
        ctx.fill();
      }
    });
    screen.texture.needsUpdate = true;
  }

  const yaw = interpolate(frame, [0, 230], [10, 0], { ...clamp, easing: ease.transfer });
  const fraction = interpolate(frame, [0, 230, 299], [0.56, FRACTION, FRACTION * 1.02], {
    ...clamp,
    easing: [ease.transfer, Easing.linear],
  });
  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(LENS)) / 2) * fraction);
  const sweep = frame >= 272 && frame <= 298 ? interpolate(frame, [272, 298], [0, 1]) : -1;
  const streak = interpolate(frame, [228, 262], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 1) });

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      {/* The constellation: about 40 real widget renders far behind, blurred, drifting; it streaks in at the merge. */}
      <AbsoluteFill style={{ opacity: 0.25 * (1 - streak) + 0.0 }}>
        {CONSTELLATION.map((src, i) => {
          const x = random(`x${i}`) * W;
          const y = random(`y${i}`) * H;
          const w = 130 + random(`w${i}`) * 150;
          const dx = (random(`dx${i}`) - 0.5) * 0.4 * frame;
          const dy = (random(`dy${i}`) - 0.5) * 0.3 * frame;
          const px = x + dx + (AXIS - x - dx) * streak;
          const py = y + dy + (H / 2 - y - dy) * streak;
          return (
            <Img
              key={src}
              src={staticFile(src)}
              style={{
                position: "absolute",
                left: px - w / 2,
                top: py - w / 2,
                width: w * (1 - 0.7 * streak),
                filter: `blur(${14 + 10 * streak}px)`,
              }}
            />
          );
        })}
      </AbsoluteFill>
      {images && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment />
          <CameraLook lens={LENS} position={new THREE.Vector3(0, 0, distance)} target={new THREE.Vector3(0, 0, 0)} />
          <Phone3D yaw={yaw} screen={screen.texture} screenOn={1} sweep={sweep} />
        </ThreeCanvas>
      )}
      {/* The four hero widgets, each in another style, glide to their places and dock into one design. */}
      {FLOATERS.map((fl, i) => {
        if (docked(i)) return null;
        const slot = toFrame(HERO_WIDGETS[fl.index].rect);
        const arrive = interpolate(frame, [10 + 14 * i, 180 + 10 * i], [0, 1], { ...clamp, easing: ease.arrival });
        const dock = interpolate(frame, [DOCK_AT(i), DOCK_AT(i) + 30], [0, 1], { ...clamp, easing: Easing.bezier(0.5, 0, 0.2, 1) });
        const hover: Rect = [slot[0] + fl.at[0], slot[1] + fl.at[1], slot[2] * 1.12, slot[3] * 1.12];
        const far: Rect = [AXIS + (hover[0] - AXIS) * 1.9, H / 2 + (hover[1] - H / 2) * 1.9, hover[2] * 0.7, hover[3] * 0.7];
        const mix = (a: Rect, b: Rect, p: number) => a.map((v, j) => v + (b[j] - v) * p) as Rect;
        const bob = Math.sin(frame / 25 + i * 1.7) * 8 * (1 - dock);
        const r = mix(mix(far, hover, arrive), slot, dock);
        const blade = interpolate(frame, [DOCK_AT(i) + 18, DOCK_AT(i) + 30], [0, 1], clamp);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: r[0],
              top: r[1] + bob,
              width: r[2],
              height: r[3],
              opacity: arrive,
              filter: `drop-shadow(0 ${24 * (1 - dock)}px ${50 * (1 - dock)}px rgba(0,0,0,0.6))`,
            }}
          >
            <Img
              src={staticFile(heroWidget(fl.from, fl.index))}
              style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
            />
            {/* As it docks, it blades into the Sunset design. */}
            <Img
              src={staticFile(heroWidget(U, fl.index))}
              style={{ position: "absolute", inset: 0, width: "100%", height: "100%", clipPath: `inset(0 ${(1 - blade) * 100}% 0 0)` }}
            />
            {blade > 0 && blade < 1 && (
              <div
                style={{
                  position: "absolute",
                  left: `${blade * 100}%`,
                  top: 0,
                  width: 2,
                  height: "100%",
                  background: "#FFF",
                  boxShadow: "0 0 14px 3px rgba(255,224,204,0.8)",
                }}
              />
            )}
          </div>
        );
      })}
      <Grain />
      {audio && <FilmAudio from={2880} />}
    </AbsoluteFill>
  );
};

void drawBlade;
