import { AbsoluteFill, Easing, Img, interpolate, staticFile } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, H } from "../lib/brand";
import { k } from "../lib/kit";
import { useFilmFrame } from "../lib/time";

/**
 * Cold open of the Fitness film « Every Second Counts » (Concept §6.4, 0–4 s): the real Live Activity, lifted
 * at 1000 px, counts down one real second per beat (1:00 → 0:57); between the ticks a blade brings the next
 * demonstration figure, huge on its lit plinth, played at 1× (bench press, back squat, deadlift, pull-up).
 */
const REST = [0, 1, 2, 3].map((i) => k(`live-rest-real-${String(i).padStart(3, "0")}.png`));
const FIGURES = [
  { name: "bench-press", count: 240 },
  { name: "back-squat", count: 234 },
  { name: "deadlift", count: 264 },
  { name: "pull-up", count: 258 },
];
const fig = (i: number, f: number) => {
  const { name, count } = FIGURES[i];
  return k(`demo-${name}-dark-${String(Math.max(0, f) % count).padStart(4, "0")}.png`);
};
const LA = { x: AXIS - 500, y: 250, w: 1000, h: (1000 * 465) / 1116 };
/** Figures change half-way between the ticks (30, 90, 150 …), each with a 10-frame blade. */
const CHANGE = [30, 90, 150, 210];

export const FitnessCold: React.FC<{ audio?: boolean }> = () => {
  const frame = useFilmFrame();
  const second = Math.min(3, Math.max(0, Math.floor(frame / 60)));
  let current = 0;
  for (let i = 0; i < CHANGE.length; i++) if (frame >= CHANGE[i] + 10) current = Math.min(3, i + 1);
  const changing = CHANGE.findIndex((c) => frame >= c && frame < c + 10);
  const wipe = changing >= 0 ? interpolate(frame, [CHANGE[changing], CHANGE[changing] + 10], [0, 1], { easing: Easing.bezier(0.45, 0, 0.55, 1) }) : 0;
  const next = changing >= 0 ? Math.min(3, changing + 1) : current;
  const appear = interpolate(frame, [0, 14], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const figBox = { x: AXIS - 640, y: 760, w: 1280 };
  const figure = (i: number, startAt: number, extra?: React.CSSProperties) => (
    <Img src={staticFile(fig(i, frame - startAt))} style={{ position: "absolute", left: figBox.x, top: figBox.y, width: figBox.w, ...extra }} />
  );
  const startOf = (i: number) => (i === 0 ? 0 : CHANGE[i - 1]);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 700px 900px at ${AXIS}px ${H / 2}px, #E5484D, transparent 75%)`, opacity: 0.06 }} />
      {/* Plinth under the figures. */}
      <div style={{ position: "absolute", left: AXIS - 520, top: 1430, width: 1040, height: 150, borderRadius: "50%", background: "radial-gradient(ellipse at 50% 40%, #3A3A3F, #1C1C1F 65%, transparent 72%)", opacity: appear }} />
      <div style={{ opacity: appear }}>
        {figure(current, startOf(current))}
        {changing >= 0 && figure(next, CHANGE[changing], { clipPath: `inset(0 ${(1 - wipe) * 100}% 0 0)` })}
      </div>
      {changing >= 0 && <Seam x={figBox.x + figBox.w * wipe} top={figBox.y} height={760} spread={0.5} intensity={Math.sin(Math.PI * wipe)} />}
      <Img
        src={staticFile(REST[second])}
        style={{ position: "absolute", left: LA.x, top: LA.y, width: LA.w, height: LA.h, opacity: appear, filter: "drop-shadow(0 30px 60px rgba(0,0,0,0.6))" }}
      />
      <Grain />
    </AbsoluteFill>
  );
};
