import { AbsoluteFill, Easing, Img, interpolate, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, H, INTER, W } from "../lib/brand";
import { kitUrl } from "../lib/kit";
import { useT } from "../lib/i18n";
import { back } from "./fx";

/**
 * « Nutrition. Fitness. Money. Habits. » on the beat: four 30-frame shots, one real widget each flying through
 * a 3D stack (the previous one racing away), the word slammed over it, the seam flashing at every cut.
 * Local frame 0 = f1560; the first word lands at local 36 (the voice, 26.6 s).
 */
const ITEMS = [
  { key: "v3.nutrition", img: "calories-s-dark", back: "macros-m-dark", glow: "#FF9500", w: 640 },
  { key: "v3.fitness", img: "setup-hero-aurore-1", glow: "#FF5D5D", w: 940 },
  { key: "v3.money", img: "setup-hero-aurore-2", glow: "#68B5F5", w: 640 },
  { key: "v3.habits", img: "kit/habitStreak-s-aurora", glow: "#7CE0A0", w: 640 },
] as { key: string; img: string; back?: string; glow: string; w: number }[];
const BASE = 36;

export const Burst: React.FC = () => {
  const f = useCurrentFrame();
  const t = useT();
  // the first plate arrives early (anticipation), the others just before their word
  const starts = ITEMS.map((_, i) => (i === 0 ? 0 : BASE + 30 * i - 10));
  const idx = Math.min(3, Math.max(0, Math.floor((f - BASE + 8) / 30)));
  let seamI = interpolate(f, [0, 30], [0.2, 0.9], clamp);
  for (let i = 0; i < 4; i++) {
    const c = BASE + 30 * i;
    if (f >= c) seamI = Math.max(seamI, interpolate(f, [c, c + 14], [1, 0.2], clamp));
  }
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 800px 900px at 540px 760px, ${ITEMS[idx].glow}44, transparent 70%)` }} />
      <Seam x={AXIS} top={200} height={H - 400} intensity={seamI * 0.6} />
      <div style={{ position: "absolute", inset: 0, perspective: 1400 }}>
        {ITEMS.map((it, i) => {
          const s0 = starts[i];
          const word = BASE + 30 * i;
          const local = f - s0;
          if (local < -2) return null;
          const dur = i === 0 ? 66 : 40;
          if (local > dur + 12) return null;
          const enter = interpolate(local, [0, 12], [0, 1], { ...clamp, easing: back });
          const leave = interpolate(f, [word + 26, word + 40], [0, 1], { ...clamp, easing: Easing.bezier(0.5, 0, 0.9, 0.3) });
          const dir = i % 2 ? -1 : 1;
          const p = Math.min(1, local / dur);
          const rx = 10 - 14 * p;
          const ry = dir * (-34 + 50 * p);
          const scale = (0.55 + 0.45 * enter) * (1 + 0.28 * p);
          const x = dir * (1 - enter) * 520 + dir * leave * 900;
          const y = 700 + leave * -120;
          return (
            <div key={i} style={{ position: "absolute", left: 540 - it.w / 2, top: y - it.w * 0.25, width: it.w, transformStyle: "preserve-3d", transform: `translateX(${x}px) rotateX(${rx}deg) rotateY(${ry + leave * dir * 40}deg) scale(${scale})`, opacity: 1 - leave * 0.8 }}>
              {it.back && (
                <Img src={kitUrl(it.back)} style={{ position: "absolute", left: -250, top: -170, width: 940, borderRadius: 52, transform: "translateZ(-200px)", filter: "drop-shadow(0 40px 60px rgba(0,0,0,0.6))" }} />
              )}
              {[1, 2].map((g) => (
                <Img key={g} src={kitUrl(it.img)} style={{ position: "absolute", left: dir * g * 70, top: -g * 40, width: it.w, opacity: 0.16, filter: "blur(5px)", transform: `translateZ(${-g * 160}px)` }} />
              ))}
              <Img src={kitUrl(it.img)} style={{ width: it.w, display: "block", borderRadius: 60, filter: `drop-shadow(0 50px 80px rgba(0,0,0,0.65)) drop-shadow(0 0 70px ${it.glow}55)` }} />
            </div>
          );
        })}
      </div>
      {ITEMS.map((it, i) => {
        const word = BASE + 30 * i;
        const local = f - word;
        if (local < 0 || local > 38) return null;
        const sc = interpolate(local, [0, 5], [2.1, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
        const out = interpolate(local, [28, 38], [1, 0], clamp);
        return (
          <div key={i} style={{ position: "absolute", left: 0, top: 1210, width: W, display: "flex", justifyContent: "center", opacity: out }}>
            <span style={{ fontFamily: INTER, fontWeight: 800, fontSize: 190, letterSpacing: "-0.035em", color: C.type1, lineHeight: 1, transform: `scale(${sc})`, textShadow: `0 0 60px ${it.glow}bb, 0 14px 40px rgba(0,0,0,0.7)` }}>
              {t(it.key)}
            </span>
          </div>
        );
      })}
      {ITEMS.map((_, i) => {
        const c = BASE + 30 * i;
        const o = interpolate(f, [c, c + 3], [0.2, 0], clamp);
        return f >= c && o > 0 ? <AbsoluteFill key={i} style={{ background: "#fff", opacity: o }} /> : null;
      })}
      <Grain />
    </AbsoluteFill>
  );
};
