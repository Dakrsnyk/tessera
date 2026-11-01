import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { lensFov, PHONE } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, INTER, W } from "../lib/brand";
import { useT } from "../lib/i18n";
import { Glyph, Kind, TileIcon } from "./Glyphs";
import { back, KineticLine, rnd } from "./fx";
import T from "./timing.json";

/**
 * The hook (0 – 7.4 s): « the chaos of apps ». Moments of a day as bold 3D-ish glyphs on a fast cut, then each
 * becomes a loud generic app tile (no real brand), the swarm grows past ten while the camera pulls back and
 * shakes; 5.6 – 6.4 s silence and glitch; 6.4 s every tile is sucked into the Seam, flash, and the line opens
 * onto the edge-on phone of the Opening (same geometry, so the cut is invisible).
 */
const SHOTS = T.hook.momentShots as { f: number; word: string; kind: Kind; len: number }[];
const ACCENT = ["#FFB347", "#FF7A3D", "#E6EDF5", "#68B5F5", "#FF6B6B", "#7CE0A0", "#68B5F5", "#B9A8FF"];
const START = SHOTS[0].f;
const H2 = T.hook.tilesStart;
const FREEZE = T.hook.silence.from;
const IMPACT = T.hook.impact;
const GLITCH = T.hook.glitch;

/** The Seam's geometry at the Opening's first frame (85 mm, 455 mm away): the hand-off must match it. */
const phoneHeightPx = () => (PHONE.h * H) / (2 * 455 * Math.tan(((lensFov(85) / 2) * Math.PI) / 180));

/** Loud, deliberately clashing tile colours (fake apps only). */
const TILE_COLORS = [
  ["#FF2D75", "#FF9F0A"],
  ["#FFD60A", "#32D74B"],
  ["#00E5FF", "#BF5AF2"],
  ["#FF453A", "#FFD60A"],
  ["#32D74B", "#00B8D4"],
  ["#BF5AF2", "#FF2D75"],
  ["#0A84FF", "#64D2FF"],
  ["#FF9F0A", "#FF2D75"],
  ["#30D158", "#FFE66D"],
  ["#FF6EC7", "#7C4DFF"],
  ["#FFE66D", "#FF453A"],
  ["#64D2FF", "#FF2D75"],
];

type TileDef = { x: number; y: number; z: number; rot: number; sp: number; c: number; icon: number; rate: number; delay: number };
const N_TILES = 110;
const TILES: TileDef[] = (() => {
  // Slots of a loose grid, nearest to the centre first: the swarm spreads outwards as the count grows.
  const slots: { x: number; y: number; d: number }[] = [];
  for (let r = -8; r <= 8; r++)
    for (let c = -4; c <= 4; c++) {
      const x = c * 236 + (r % 2 ? 118 : 0) + (rnd(r * 9 + c) - 0.5) * 70;
      const y = r * 268 + (rnd(r * 5 + c * 3 + 1) - 0.5) * 70;
      slots.push({ x, y, d: Math.hypot(x * 1.0, y * 0.62) + rnd(r + c * 7) * 160 });
    }
  slots.sort((a, b) => a.d - b.d);
  return slots.slice(0, N_TILES).map((s, i) => ({
    x: s.x,
    y: s.y,
    z: (rnd(i * 3 + 2) - 0.5) * 520,
    rot: (rnd(i * 7 + 5) - 0.5) * 30,
    sp: i < 10 ? H2 + 2 + 70 * Math.pow(i / 9, 1.1) : 246 + 90 * Math.pow((i - 10) / (N_TILES - 11), 0.8),
    c: Math.floor(rnd(i * 11 + 3) * TILE_COLORS.length),
    icon: Math.floor(rnd(i * 13 + 1) * 10),
    rate: 0.12 + rnd(i * 17) * 0.5,
    delay: rnd(i * 19) * 5,
  }));
})();

const Tile: React.FC<{ d: TileDef; i: number; fe: number; f: number }> = ({ d, i, fe, f }) => {
  if (fe < d.sp) return null;
  const pop = interpolate(fe, [d.sp, d.sp + 11], [0, 1], { ...clamp, easing: back });
  const travel = interpolate(fe, [d.sp, d.sp + 14], [0, 1], { ...clamp, easing: ease.split });
  const suck = f >= IMPACT ? interpolate(f, [IMPACT + d.delay, IMPACT + d.delay + 14], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) }) : 0;
  if (suck >= 1) return null;
  const x = d.x * travel * (1 - suck);
  const y = d.y * travel * (1 - suck);
  const z = d.z * (1 - suck);
  const wob = Math.sin(fe * 0.08 + i * 1.7) * 3;
  const spin = suck * 540 * (rnd(i) - 0.5);
  const [c1, c2] = TILE_COLORS[d.c];
  const badge = Math.min(99, 1 + Math.floor((fe - d.sp) * d.rate * 1.4));
  const bump = 1 + 0.18 * Math.max(0, 1 - ((fe - d.sp) * d.rate * 1.4) % 1 * 4);
  return (
    <div
      style={{
        position: "absolute",
        left: -95,
        top: -95,
        width: 190,
        height: 190,
        transform: `translate3d(${x}px, ${y}px, ${z}px) rotateZ(${d.rot + wob + spin}deg) scale(${pop * (1 - suck * 0.92)})`,
        opacity: pop,
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 46,
          background: `linear-gradient(145deg, ${c1}, ${c2})`,
          boxShadow: "0 24px 50px rgba(0,0,0,0.55), inset 0 3px 0 rgba(255,255,255,0.45)",
        }}
      />
      <svg viewBox="0 0 100 100" width="110" height="110" style={{ position: "absolute", left: 40, top: 30 }}>
        <TileIcon n={d.icon} />
      </svg>
      <div style={{ position: "absolute", left: 52, top: 142, width: 86, height: 12, borderRadius: 6, background: "rgba(255,255,255,0.55)" }} />
      <div
        style={{
          position: "absolute",
          right: -22,
          top: -22,
          minWidth: 62,
          height: 62,
          padding: "0 12px",
          boxSizing: "border-box",
          borderRadius: 31,
          background: "#FF3B30",
          border: "5px solid #fff",
          boxShadow: "0 6px 16px rgba(0,0,0,0.5)",
          color: "#fff",
          fontFamily: INTER,
          fontWeight: 800,
          fontSize: 32,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${bump})`,
        }}
      >
        {badge}
      </div>
    </div>
  );
};

/** A fake notification banner (generic: a colour dot and two grey bars, no text). */
const Banner: React.FC<{ i: number; f: number; fe: number }> = ({ i, f, fe }) => {
  const at = T.hook.bannersStart + i * 15;
  if (fe < at) return null;
  const p = interpolate(fe, [at, at + 9], [0, 1], { ...clamp, easing: back });
  const suck = f >= IMPACT ? interpolate(f, [IMPACT, IMPACT + 12], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) }) : 0;
  if (suck >= 1) return null;
  const [c1, c2] = TILE_COLORS[(i * 5 + 2) % TILE_COLORS.length];
  const y = 64 + i * 46;
  const toCenter = (H / 2 - y - 56) * suck;
  return (
    <div
      style={{
        position: "absolute",
        left: 70 + (i % 3) * 16,
        top: y,
        width: 940 - (i % 3) * 32,
        height: 112,
        borderRadius: 34,
        background: "rgba(34,34,38,0.92)",
        border: "2px solid rgba(255,255,255,0.14)",
        boxShadow: "0 18px 40px rgba(0,0,0,0.5)",
        transform: `translateY(${(1 - p) * -220 + toCenter}px) scale(${1 - suck * 0.9}) rotate(${(i % 2 ? 1 : -1) * 1.2 * (1 - suck)}deg)`,
        opacity: Math.min(1, p * 3),
        display: "flex",
        alignItems: "center",
        gap: 24,
        paddingLeft: 24,
      }}
    >
      <div style={{ width: 66, height: 66, borderRadius: 18, background: `linear-gradient(145deg, ${c1}, ${c2})` }} />
      <div>
        <div style={{ width: 300 - (i % 4) * 30, height: 16, borderRadius: 8, background: "rgba(255,255,255,0.85)" }} />
        <div style={{ width: 520 - (i % 3) * 60, height: 12, borderRadius: 6, background: "rgba(255,255,255,0.35)", marginTop: 14 }} />
      </div>
      <div style={{ marginLeft: "auto", marginRight: 30, width: 20, height: 20, borderRadius: 10, background: "#FF3B30" }} />
    </div>
  );
};

/** One moment: glyph in 3D with extrusion, ghost depth layers, parallax outline word, slammed keyword. */
const Moment: React.FC<{ shot: (typeof SHOTS)[number]; idx: number; f: number }> = ({ shot, idx, f }) => {
  const t = f - shot.f;
  const p = t / shot.len;
  const acc = ACCENT[idx];
  const dir = idx % 2 ? -1 : 1;
  const enter = interpolate(t, [0, 7], [0, 1], { ...clamp, easing: back });
  const push = 0.86 + 0.4 * p + 0.2 * Math.pow(Math.max(0, p - 0.7) / 0.3, 2);
  const ry = dir * (-30 + 52 * p);
  const rx = 14 - 20 * p;
  const exit = interpolate(t, [shot.len - 2, shot.len], [0, 1], clamp);
  const layers = 7;
  return (
    <AbsoluteFill style={{ opacity: 1 - exit * 0.0 }}>
      {/* the colour of the moment, bleeding into the dark */}
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 760px 700px at ${540 + dir * 60}px 640px, ${acc}55, transparent 70%)`, opacity: enter }} />
      {/* parallax outline word, huge, moving against the camera */}
      <div
        style={{
          position: "absolute",
          left: 540 - dir * 140 * p - 700,
          top: 330,
          width: 1400,
          textAlign: "center",
          fontFamily: INTER,
          fontWeight: 900,
          fontSize: 560,
          letterSpacing: "-0.04em",
          color: "transparent",
          WebkitTextStroke: `3px ${acc}`,
          opacity: 0.32 * enter,
          transform: `scale(${1.1 + 0.15 * p})`,
          whiteSpace: "nowrap",
        }}
      >
        {shot.word}
      </div>
      <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, perspective: 1500 }}>
        <div
          style={{
            position: "absolute",
            left: 540 - 380,
            top: 640 - 380,
            width: 760,
            height: 760,
            transformStyle: "preserve-3d",
            transform: `scale(${push * (0.45 + 0.55 * enter)}) rotateY(${ry}deg) rotateX(${rx}deg) rotateZ(${dir * (-6 + 8 * p)}deg)`,
            filter: `blur(${(1 - Math.min(1, enter)) * 14}px)`,
          }}
        >
          {/* ghosts: depth */}
          {[-1, 1].map((s) => (
            <div key={s} style={{ position: "absolute", inset: 0, transform: `translateZ(${s * 170}px) translateX(${s * 70 * dir}px) scale(1.15)`, opacity: 0.1, filter: "blur(6px)" }}>
              <Glyph kind={shot.kind} size={760} />
            </div>
          ))}
          {/* extrusion: stacked darker copies behind the face */}
          {Array.from({ length: layers }, (_, i) => (
            <div key={i} style={{ position: "absolute", inset: 0, transform: `translateZ(${-(layers - i) * 9}px)` }}>
              <Glyph kind={shot.kind} size={760} dim={0.22 + 0.08 * i} />
            </div>
          ))}
          <div style={{ position: "absolute", inset: 0, filter: `drop-shadow(0 40px 60px rgba(0,0,0,0.55)) drop-shadow(0 0 60px ${acc}66)` }}>
            <Glyph kind={shot.kind} size={760} />
          </div>
        </div>
      </div>
      {/* keyword that slams */}
      <div style={{ position: "absolute", left: 0, top: 960, width: W, display: "flex", justifyContent: "center" }}>
        <span
          style={{
            fontFamily: INTER,
            fontWeight: 800,
            fontSize: 190,
            letterSpacing: "0.02em",
            color: C.type1,
            lineHeight: 1,
            transform: `scale(${interpolate(t, [0, 5], [1.9, 1], { ...clamp, easing: Easing.out(Easing.cubic) })})`,
            opacity: interpolate(t, [0, 2], [0, 1], clamp),
            textShadow: `0 0 50px ${acc}aa, 0 10px 40px rgba(0,0,0,0.7)`,
          }}
        >
          {shot.word}
        </span>
      </div>
      <div style={{ position: "absolute", left: 540 - 220, top: 1170, width: 440 * interpolate(t, [2, 9], [0, 1], { ...clamp, easing: ease.split }), height: 8, borderRadius: 4, background: acc, boxShadow: `0 0 24px ${acc}` }} />
    </AbsoluteFill>
  );
};

export const Hook: React.FC<{ audio?: boolean }> = () => {
  const f = useCurrentFrame();
  const t = useT();
  const fe = Math.min(f, FREEZE);
  const inMoments = f >= START && f < H2 + 4;

  // Seam: ticks before the first word, a pulse on every cut, absent while the tiles swarm.
  const ticks = T.hook.tick;
  let seamI = 0.15;
  for (const k of ticks) seamI = Math.max(seamI, interpolate(f, [k - 1, k, k + 8], [0, 1, 0.15], clamp));
  const cutF = SHOTS.map((s) => s.f);
  for (const k of cutF) seamI = Math.max(seamI, interpolate(f, [k, k + 12], [1, 0.3], clamp) * (f >= k ? 1 : 0));
  const preSeam = f < H2 ? (f >= START ? Math.max(0.22, seamI * 0.7) : seamI) : 0;
  const preFade = interpolate(f, [H2 - 8, H2], [1, 0], clamp);

  // Camera over the swarm.
  const tilesOn = f >= H2;
  const zoom = interpolate(fe, [H2, FREEZE], [1.45, 0.7], { ...clamp, easing: Easing.bezier(0.3, 0, 0.2, 1) }) + (f > FREEZE ? (f - FREEZE) * 0.0006 : 0);
  const tilt = interpolate(fe, [H2, FREEZE], [0, 12], { ...clamp, easing: Easing.bezier(0.3, 0, 0.2, 1) });
  const shakeA = interpolate(fe, T.hook.shakeRamp, [0, 20], clamp);
  const shaking = f < FREEZE;
  const sx = shaking ? (rnd(f * 3.1) - 0.5) * 2 * shakeA : 0;
  const sy = shaking ? (rnd(f * 5.7 + 2) - 0.5) * 2 * shakeA : 0;
  const roll = shaking ? Math.sin(fe * 0.21) * shakeA * 0.08 : 0;
  const glitchNow = GLITCH.indexOf(f) >= 0;
  const gx = glitchNow ? (rnd(f * 1.7) - 0.5) * 70 : 0;

  // Texts.
  const h1Out = interpolate(f, [H2 - 12, H2 - 2], [0, 1], clamp);
  const h1 = T.hook.h1Words.map((w, i) => ({ t: t(i < 2 ? "v3.h1.a" : "v3.h1.b").split(" ")[i < 2 ? i : i - 2], at: w.f, hi: i === 4 }));
  const h1a = h1.slice(0, 2);
  const h1b = h1.slice(2);
  const h2w = T.hook.h2Words;
  const squeeze = interpolate(f, [IMPACT, IMPACT + 9], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) });
  const cnt = interpolate(fe, [T.hook.tenCounter.from, T.hook.tenCounter.to], [1, 10], { ...clamp, easing: Easing.bezier(0.5, 0, 0.9, 0.6) });
  const counterNum = Math.round(cnt);
  const slamT = f - T.hook.tenCounter.slam;
  const showWord = f >= T.hook.tenCounter.slam;
  const counterOn = f >= T.hook.tenCounter.from - 8;
  const counterPop = interpolate(f, [T.hook.tenCounter.from - 8, T.hook.tenCounter.from + 2], [0, 1], { ...clamp, easing: back });

  // Impact.
  const flash = interpolate(f, [IMPACT + 12, IMPACT + 14, IMPACT + 28], [0, 1, 0], clamp);
  const pointGlow = interpolate(f, [IMPACT, IMPACT + 14], [0, 1], clamp);
  const lineH = interpolate(f, T.hook.lineOpen, [0, phoneHeightPx() * 0.96], { ...clamp, easing: ease.split });
  const lineI = interpolate(f, [IMPACT + 12, IMPACT + 16], [0, 1], clamp);
  const ring = interpolate(f, [IMPACT + 13, IMPACT + 36], [0, 1], { ...clamp, easing: Easing.out(Easing.cubic) });

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />

      {/* before the swarm: the Seam, and the moments */}
      {f < H2 && (
        <AbsoluteFill style={{ opacity: preFade }}>
          <Seam x={AXIS} top={230} height={H - 460} intensity={preSeam} />
        </AbsoluteFill>
      )}
      {inMoments && SHOTS.map((s, i) => (f >= s.f && f < s.f + s.len + (i === SHOTS.length - 1 ? 4 : 0) ? <Moment key={i} shot={s} idx={i} f={f} /> : null))}
      {/* white micro-flash on every cut */}
      {SHOTS.map((s, i) => {
        const o = interpolate(f, [s.f, s.f + 3], [0.1, 0], clamp);
        return o > 0 && f >= s.f ? <AbsoluteFill key={i} style={{ background: "#fff", opacity: o }} /> : null;
      })}

      {/* H1 */}
      <KineticLine words={h1a} frame={f} top={1270} size={150} out={h1Out} />
      <KineticLine words={h1b} frame={f} top={1430} size={150} out={h1Out} />

      {/* the swarm */}
      {tilesOn && f < IMPACT + 16 && (
        <AbsoluteFill style={{ perspective: 1800, filter: glitchNow ? "drop-shadow(8px 0 0 rgba(0,255,255,0.7)) drop-shadow(-8px 0 0 rgba(255,0,110,0.7))" : undefined }}>
          <div
            style={{
              position: "absolute",
              left: 540 + gx,
              top: H / 2,
              width: 0,
              height: 0,
              transformStyle: "preserve-3d",
              transform: `translate(${sx}px, ${sy}px) scale(${zoom}) rotateX(${tilt}deg) rotateZ(${roll}deg)`,
            }}
          >
            {TILES.map((d, i) => (
              <Tile key={i} d={d} i={i} fe={fe} f={f} />
            ))}
          </div>
          <AbsoluteFill style={{ transform: `translate(${sx + gx}px, ${sy}px)` }}>
            {Array.from({ length: 9 }, (_, i) => (
              <Banner key={i} i={i} f={f} fe={fe} />
            ))}
          </AbsoluteFill>
        </AbsoluteFill>
      )}

      {/* H2 over a scrim */}
      {tilesOn && f < IMPACT + 10 && (
        <>
          <AbsoluteFill style={{ background: "linear-gradient(to bottom, transparent 56%, rgba(0,0,0,0.88) 70%, rgba(0,0,0,0.92) 100%)", opacity: Math.min(1, (f - H2) / 10) * (1 - squeeze) }} />
          <div style={{ transform: glitchNow ? `translateX(${gx * 0.4}px)` : undefined }}>
            <KineticLine
              words={[{ t: t("v3.h2.a"), at: h2w[0].f }]}
              frame={f}
              top={1330}
              size={78}
              squeeze={squeeze}
              weight={600}
            />
            <div style={{ position: "absolute", left: 0, top: 1410, width: W, height: 290, display: "flex", justifyContent: "center", alignItems: "center", transform: `scale(${(0.5 + 0.5 * counterPop) * (1 - squeeze)}, ${0.5 + 0.5 * counterPop})`, opacity: counterOn ? 1 : 0 }}>
              <span
                style={{
                  fontFamily: INTER,
                  fontWeight: 800,
                  fontSize: showWord ? 270 : 300,
                  letterSpacing: "-0.04em",
                  lineHeight: 1,
                  background: `linear-gradient(180deg, ${C.paleWarm}, ${C.sapphireBright} 65%, ${C.sapphire})`,
                  WebkitBackgroundClip: "text",
                  color: "transparent",
                  transform: showWord ? `scale(${interpolate(slamT, [0, 6], [1.5, 1], { ...clamp, easing: Easing.out(Easing.cubic) })})` : undefined,
                  filter: `drop-shadow(0 0 ${showWord ? 50 : 20}px rgba(78,155,224,0.65))`,
                }}
              >
                {showWord ? t("v3.ten") : counterNum}
              </span>
            </div>
            <KineticLine words={[{ t: t("v3.h2.c"), at: h2w[5].f }]} frame={f} top={1710} size={78} squeeze={squeeze} weight={600} />
          </div>
        </>
      )}

      {/* silence: scanlines and glitch strips */}
      {f >= FREEZE && f < IMPACT && (
        <>
          <AbsoluteFill style={{ background: "repeating-linear-gradient(0deg, rgba(0,0,0,0.22) 0px, rgba(0,0,0,0.22) 2px, transparent 2px, transparent 6px)", opacity: 0.8 }} />
          {glitchNow &&
            Array.from({ length: 6 }, (_, i) => {
              const y = rnd(f * 7 + i) * 1800;
              const h = 20 + rnd(f * 3 + i * 5) * 120;
              const dx = (rnd(f * 11 + i * 2) - 0.5) * 140;
              return <div key={i} style={{ position: "absolute", left: dx, top: y, width: W, height: h, background: i % 2 ? "rgba(0,255,255,0.22)" : "rgba(255,0,110,0.22)", mixBlendMode: "screen" }} />;
            })}
          {glitchNow && <AbsoluteFill style={{ background: "#fff", opacity: 0.07 }} />}
        </>
      )}

      {/* impact: the point, the ring, the line */}
      {f >= IMPACT && f < IMPACT + 16 && (
        <AbsoluteFill style={{ background: `radial-gradient(circle ${40 + 260 * pointGlow}px at ${AXIS}px ${H / 2}px, rgba(255,255,255,${0.95 * pointGlow}), rgba(104,181,245,${0.5 * pointGlow}) 35%, transparent 72%)` }} />
      )}
      {ring > 0 && ring < 1 && (
        <div
          style={{
            position: "absolute",
            left: AXIS - 700 * ring,
            top: H / 2 - 700 * ring,
            width: 1400 * ring,
            height: 1400 * ring,
            borderRadius: "50%",
            border: `${10 * (1 - ring) + 1}px solid ${C.pale}`,
            opacity: 1 - ring,
            boxShadow: `0 0 80px ${C.sapphire}`,
          }}
        />
      )}
      {f >= IMPACT + 12 && (
        <>
          <Seam x={AXIS} top={H / 2 - lineH / 2} height={lineH} intensity={lineI} />
          {Array.from({ length: 30 }, (_, i) => {
            const tt = f - (IMPACT + 14);
            if (tt < 0) return null;
            const side = i % 2 ? 1 : -1;
            const dist = (160 + rnd(i * 3) * 700) * Math.pow(tt / 30, 0.6);
            const y = H / 2 + (rnd(i * 5 + 1) - 0.5) * lineH * 0.9;
            const len = 30 + rnd(i * 7) * 150;
            return <div key={i} style={{ position: "absolute", left: AXIS + side * dist - (side > 0 ? 0 : len), top: y, width: len, height: 3, background: `linear-gradient(to ${side > 0 ? "right" : "left"}, ${C.pale}, transparent)`, opacity: Math.max(0, 1 - tt / 34) }} />;
          })}
        </>
      )}
      <AbsoluteFill style={{ background: "#fff", opacity: flash }} />
      <Grain />
    </AbsoluteFill>
  );
};
