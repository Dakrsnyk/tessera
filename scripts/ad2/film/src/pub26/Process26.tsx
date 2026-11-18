import { AbsoluteFill, Easing, Img, interpolate, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, INTER, W } from "../lib/brand";
import { kitUrl } from "../lib/kit";
import { FADES, PILLS, SHOTS } from "./shots";
import { PROCESS } from "./timing26";

/**
 * Widget ad, sequence 2: customising a widget IN the current app (copy of the choreography of v4/Process.tsx, 2026-11-18):
 * Create (« What size for your widget? ») -> pick a widget -> Studio (styles, colours, background). One whole screen at a time, never cropped,
 * ghosts of its neighbours in depth, a Sapphire blade between two captures of the same screen. No Store / My widgets / Home compose here:
 * the cut to the Home Screen is the card being drawn into the Sapphire line (the last `PROCESS.squeeze` frames), then HomeBuilder opens from it.
 * Captures are asked by kit name (SHOTS in shots.ts); the fades that hide scrolling edges are in shots.ts too (FADES).
 */
const CARD_W = 640;
const CARD_H = (CARD_W * 2622) / 1206;
const CY = 1010;
const TR = PROCESS.sceneTransition;
const BLADE = PROCESS.blade;
const blade = Easing.bezier(0.45, 0, 0.2, 1);

const Layer: React.FC<{ name: string; style?: React.CSSProperties }> = ({ name, style }) => {
  const SCL = CARD_W / 1206;
  const src = kitUrl(name);
  const pieces: React.ReactNode[] = [];
  (FADES[name] ?? []).forEach((fd, i) => {
    const add = (key: string, x0: number, y0: number, w: number, h: number, mask: string) =>
      pieces.push(
        <div key={key} style={{ position: "absolute", left: x0 * SCL, top: y0 * SCL, width: w * SCL, height: h * SCL, overflow: "hidden", maskImage: mask, WebkitMaskImage: mask }}>
          {fd.c0 ? (
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(180deg, ${fd.c0}, ${fd.c1 ?? fd.c0})` }} />
          ) : (
            <div style={{ position: "absolute", left: 0, top: -y0 * SCL, width: 6 * SCL, height: CARD_H, overflow: "hidden", transformOrigin: "0 0", transform: `scaleX(${w / 6})` }}>
              <Img src={src} style={{ position: "absolute", left: 0, top: 0, width: CARD_W, height: CARD_H }} />
            </div>
          )}
        </div>,
      );
    if (fd.r) add(`r${i}`, 1206 - fd.r, fd.y0, fd.r, fd.y1 - fd.y0, `linear-gradient(to right, transparent 0%, black ${fd.h ? 12 : 55}%)`);
    if (fd.l) add(`l${i}`, 0, fd.y0, fd.l, fd.y1 - fd.y0, `linear-gradient(to left, transparent 0%, black ${fd.h ? 12 : 55}%)`);
    if (fd.t) add(`t${i}`, 0, fd.y0, 1206, fd.t, "linear-gradient(to bottom, black 45%, transparent 100%)");
    if (fd.b) add(`b${i}`, 0, fd.y1 - fd.b, 1206, fd.b, "linear-gradient(to bottom, transparent 0%, black 55%)");
  });
  return (
    <div style={{ position: "absolute", inset: 0, ...style }}>
      <Img src={src} style={{ position: "absolute", inset: 0, width: CARD_W, height: CARD_H }} />
      {pieces}
    </div>
  );
};

const SceneCard: React.FC<{ index: number; f: number }> = ({ index, f }) => {
  const scenes = PROCESS.scenes;
  const scene = scenes[index];
  const nextStart = index < scenes.length - 1 ? scenes[index + 1].start : PROCESS.len + 99999;
  const lo = scene.start;
  if (f < lo - 1 || f > nextStart + TR) return null;
  const shots = PROCESS.steps.filter((s) => s.scene === index);
  const prevShots = PROCESS.steps.filter((s) => s.scene === index - 1);
  const nextShots = PROCESS.steps.filter((s) => s.scene === index + 1);
  const ghostL = prevShots.length ? SHOTS[prevShots[prevShots.length - 1].id] : null;
  const ghostR = nextShots.length ? SHOTS[nextShots[0].id] : null;

  const pin = interpolate(f, [lo, lo + TR + 6], [0, 1], { ...clamp, easing: ease.arrival });
  const pout = interpolate(f, [nextStart, nextStart + TR], [0, 1], { ...clamp, easing: Easing.bezier(0.5, 0, 0.75, 0.4) });
  const dir = 1 - pin;
  const x = dir * 190 - pout * 190;
  const ry = -dir * 20 + pout * 22;
  const sc = 0.88 + 0.12 * pin - pout * 0.1;
  const z = -pout * 160 + interpolate(f, [lo, nextStart], [0, 46], clamp);
  const opacity = Math.min(1, pin * 1.8) * (1 - pout);
  const blur = (1 - pin) * 14 + pout * 12;

  let baseIdx = 0;
  shots.forEach((sh, i) => {
    if (i === 0 || f >= sh.at + BLADE) baseIdx = i;
  });
  const base = shots[baseIdx];
  const nxt = shots[baseIdx + 1];
  const wp = nxt ? interpolate(f, [nxt.at, nxt.at + BLADE], [0, 1], { ...clamp, easing: blade }) : 0;

  const ghost = (name: string | null, side: -1 | 1) =>
    name ? (
      <Img
        src={kitUrl(name)}
        style={{ position: "absolute", left: CARD_W / 2 + side * 330 - 150, top: CARD_H / 2 - 325, width: 300, height: 650, borderRadius: 34, opacity: 0.3 * opacity, filter: `blur(${5 + blur}px) brightness(0.8)`, transform: `translateZ(-260px) rotateY(${-side * 24}deg)` }}
      />
    ) : null;

  return (
    <div style={{ position: "absolute", left: AXIS - CARD_W / 2, top: CY - CARD_H / 2, width: CARD_W, height: CARD_H, transformStyle: "preserve-3d", transform: `translate3d(${x}px, 0, ${z}px) rotateY(${ry}deg) scale(${sc})` }}>
      {ghost(ghostL, -1)}
      {ghost(ghostR, 1)}
      <div style={{ position: "absolute", inset: 0, borderRadius: 165 * (CARD_W / 1206), overflow: "hidden", opacity, filter: blur > 0.2 ? `blur(${blur}px)` : undefined, boxShadow: "0 40px 120px rgba(0,0,0,0.55), 0 0 0 3px rgba(255,255,255,0.10)", background: "#000" }}>
        <Layer name={SHOTS[base.id]} />
        {nxt && wp > 0 && (
          <>
            <Layer name={SHOTS[nxt.id]} style={{ clipPath: `inset(0 ${(1 - wp) * 100}% 0 0)` }} />
            <Seam x={CARD_W * wp} top={0} height={CARD_H} spread={0.45} intensity={Math.sin(Math.PI * wp)} />
          </>
        )}
      </div>
    </div>
  );
};

export const Process26: React.FC = () => {
  const f = useCurrentFrame();
  const scenes = PROCESS.scenes;
  const sceneIdx = scenes.reduce((a, s, i) => (f >= s.start ? i : a), 0);
  const stepIdx = PROCESS.steps.reduce((a, s, i) => (f >= s.at ? i : a), 0);
  const step = PROCESS.steps[stepIdx];
  const stepEnd = stepIdx < PROCESS.steps.length - 1 ? PROCESS.steps[stepIdx + 1].at : PROCESS.len - PROCESS.squeeze;
  const camYaw = 2.2 * Math.sin(f / 150);
  const camTilt = 1.2 * Math.sin(f / 190 + 1);
  const seam = scenes.slice(1).reduce((a, s) => Math.max(a, interpolate(f, [s.start, s.start + 12, s.start + TR + 10], [0, 1, 0], clamp)), 0);
  // the cut to the Home Screen: the whole card is drawn into the Sapphire line
  const sq = interpolate(f, [PROCESS.len - PROCESS.squeeze, PROCESS.len], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.5) });
  const premium = interpolate(f, [PROCESS.premium.from, PROCESS.premium.from + 14, PROCESS.premium.to - 10, PROCESS.premium.to], [0, 1, 1, 0], clamp);
  const pillIn = interpolate(f, [step.at + PROCESS.pillFrom, step.at + PROCESS.pillFrom + 14, stepEnd - 4, stepEnd + 4], [0, 1, 1, 0], clamp);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 1000px at ${AXIS}px ${CY}px, ${C.lifted}, ${C.void} 72%)` }} />
      <Seam x={AXIS} top={140} height={H - 280} intensity={0.2 + seam * 0.7 + Math.sin(Math.PI * Math.min(1, sq)) * 0.6} />
      <AbsoluteFill style={{ opacity: 1 - sq * sq * sq, transform: `scaleX(${1 - 0.985 * sq})`, transformOrigin: `${AXIS}px ${CY}px` }}>
        <div style={{ position: "absolute", inset: 0, perspective: 1900, perspectiveOrigin: `${AXIS}px ${CY}px` }}>
          <div style={{ position: "absolute", inset: 0, transformStyle: "preserve-3d", transform: `rotateY(${camYaw}deg) rotateX(${camTilt}deg)`, transformOrigin: `${AXIS}px ${CY}px` }}>
            {scenes.map((_, i) => (
              <SceneCard key={i} index={i} f={f} />
            ))}
          </div>
        </div>
        {scenes.map((s, i) => {
          const to = i < scenes.length - 1 ? scenes[i + 1].start : PROCESS.len - PROCESS.squeeze;
          const inP = interpolate(f, [s.start + 4, s.start + 26], [0, 1], { ...clamp, easing: ease.split });
          const outP = interpolate(f, [to - 4, to + 14], [0, 1], clamp);
          if (f < s.start || outP >= 1 || sceneIdx < 0) return null;
          return (
            <div
              key={i}
              style={{ position: "absolute", left: 0, top: 110, width: W, textAlign: "center", fontFamily: INTER, fontWeight: 700, fontSize: 118, lineHeight: 1, letterSpacing: "-0.03em", fontVariationSettings: "'opsz' 32", opacity: Math.min(1, inP * 2) * (1 - outP), transform: `translateY(${(1 - inP) * 50 - outP * 30}px)`, filter: `blur(${(1 - inP) * 10 + outP * 8}px)`, background: `linear-gradient(180deg, ${C.paleWarm}, ${C.type1} 55%, ${C.pale})`, WebkitBackgroundClip: "text", color: "transparent" }}
            >
              {s.word}
            </div>
          );
        })}
        {pillIn > 0 && (
          <div style={{ position: "absolute", left: 0, top: 1722, width: W, display: "flex", justifyContent: "center", opacity: pillIn, transform: `translateY(${(1 - pillIn) * 18}px)` }}>
            <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 42, letterSpacing: "-0.01em", color: C.type1, padding: "0 40px", height: 88, borderRadius: 44, display: "flex", alignItems: "center", gap: 16, background: "rgba(14,16,20,0.72)", border: `2px solid ${C.sapphire}66`, boxShadow: "0 10px 30px rgba(0,0,0,0.35)", whiteSpace: "nowrap" }}>
              <span style={{ width: 14, height: 14, borderRadius: 7, background: C.sapphire }} />
              {PILLS[step.id]}
            </div>
          </div>
        )}
        {premium > 0 && (
          <div style={{ position: "absolute", right: 36, top: 250, opacity: premium, transform: `translateY(${(1 - premium) * -12}px)` }}>
            <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 30, letterSpacing: "0.02em", color: C.pale, padding: "10px 26px", borderRadius: 999, border: "1.5px solid rgba(214,233,250,0.45)", background: "rgba(14,16,20,0.72)", whiteSpace: "nowrap" }}>With Premium</div>
          </div>
        )}
      </AbsoluteFill>
      <Grain />
    </AbsoluteFill>
  );
};
