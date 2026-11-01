import { AbsoluteFill, useCurrentFrame } from "remotion";
import { ArdaneLogo } from "../components/ArdaneLogo";
import { Seam } from "../components/Seam";
import { C, clamp, ease, INTER } from "../lib/brand";
import { useT } from "../lib/i18n";
import { Cap, Caps, K, Stage, Tone, pr, useL } from "./ctx";
import { Cam, Phone, camMix, lerp, usePhoneScale } from "./Phone";

export type Screens = { node: (f: number) => React.ReactNode; at?: number; fade?: number }[];
/** A full-screen capture. */
export const S: React.FC<{ name: string; y?: number }> = ({ name, y = 0 }) => <K name={name} style={{ position: "absolute", left: 0, top: y }} />;
export const scr = (name: string) => () => <S name={name} />;

/* ---------------------------------------------------------------- line opening */
export const LineShot: React.FC<{ caps: Cap[]; seamAt?: number }> = ({ caps, seamAt = 0 }) => {
  const f = useCurrentFrame();
  const L = useL();
  const a = pr(f, seamAt, seamAt + 20);
  const h = (L.wide ? 560 : 520) * lerp(f, seamAt, seamAt + 34, 0.05, 1, ease.split);
  const fade = 1 - pr(f, seamAt + 48, seamAt + 90);
  return (
    <Stage>
      <Seam x={L.W / 2} top={L.H / 2 - h / 2} height={h} intensity={a * (0.35 + 0.65 * fade)} />
      <Caps caps={caps} />
    </Stage>
  );
};

/* ---------------------------------------------------------------- a phone and its camera */
export const PhoneShot: React.FC<{
  screens: Screens;
  tone?: Tone;
  bg?: string;
  cam0?: Partial<Cam>;
  cam1?: Partial<Cam>;
  camFrom?: number;
  camTo: number;
  ease?: (t: number) => number;
  caps?: Cap[];
  over?: (f: number) => React.ReactNode;
  dim?: number;
  enter?: number;
  back?: (f: number) => React.ReactNode;
  extra?: React.ReactNode;
}> = ({ screens, tone = "dark", bg, cam0, cam1, camFrom = 0, camTo, ease: e = ease.transfer, caps = [], over, dim, enter = 0, back, extra }) => {
  const f = useCurrentFrame();
  const p = pr(f, camFrom, camTo, e);
  const cam = camMix(cam0 ?? {}, cam1 ?? cam0 ?? {}, p);
  if (enter) {
    const q = pr(f, 0, enter, ease.arrival);
    cam.o *= Math.min(1, q * 2);
    cam.y += (1 - q) * 160;
  }
  return (
    <Stage tone={tone} bg={bg}>
      {back?.(f)}
      <Phone cam={cam} dim={dim} over={over?.(f)}>
        {screens.map((s, i) => {
          const at = s.at ?? 0;
          const o = i === 0 ? 1 : pr(f, at, at + (s.fade ?? 10));
          return o > 0 ? (
            <div key={i} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, opacity: o }}>
              {s.node(f - at)}
            </div>
          ) : null;
        })}
      </Phone>
      {extra}
      <Caps caps={caps} />
    </Stage>
  );
};

/* ---------------------------------------------------------------- widgets coming out of the phone */
export type Out = { name: string; x: number; y: number; w?: number; at: number; label?: string; rot?: number; z?: number };
const Chip: React.FC<{ k: string; color?: string }> = ({ k, color = C.sapphireBright }) => {
  const t = useT();
  const L = useL();
  const ps = usePhoneScale();
  const fs = (30 * Math.max(0.8, L.sc)) / ps;
  return (
    <div style={{ display: "inline-flex", alignItems: "center", gap: fs * 0.35, padding: `${fs * 0.28}px ${fs * 0.7}px`, borderRadius: 999, background: "rgba(8,20,34,0.78)", border: `${fs * 0.04}px solid rgba(104,181,245,0.45)`, fontFamily: INTER, fontWeight: 600, fontSize: fs, color: "#EAF4FF", whiteSpace: "nowrap" }}>
      <span style={{ width: fs * 0.5, height: fs * 0.5, borderRadius: "50%", background: color }} />
      {t(k)}
    </div>
  );
};

/** Items: (x, y) is the centre of the widget relative to the screen centre (phone-space px). They rise out of the glass one by one. */
export const OutLayer: React.FC<{ items: Out[]; f: number; collapse?: number }> = ({ items, f, collapse = 0 }) => (
  <>
    {items.map((it, i) => {
      const p = pr(f, it.at, it.at + 40, ease.lift) * (1 - collapse);
      const bob = Math.sin((f + i * 17) / 38) * 9 * p;
      const w = it.w ?? (/-m-/.test(it.name) ? 1000 : 520);
      const hh = /-m-/.test(it.name) ? (w * 510) / 1092 : /-l-/.test(it.name) ? (w * 1146) / 1092 : w;
      const cx = 603 + it.x * p;
      const cy = 1311 + it.y * p + bob;
      const sc = 0.3 + 0.7 * p;
      return (
        <div key={i} style={{ position: "absolute", left: cx - w / 2, top: cy - hh / 2, width: w, opacity: Math.min(1, p * 3), transform: `scale(${sc}) rotate(${(it.rot ?? 0) * p}deg) translateZ(${(it.z ?? 0) * p}px)`, filter: "drop-shadow(0 30px 40px rgba(0,0,0,0.55))" }}>
          <K name={it.name} w={w} style={{ borderRadius: w * 0.05 }} />
          {it.label && (
            <div style={{ position: "absolute", left: 0, top: -hh * 0.0 - 30 / 1, transform: "translateY(-125%)", opacity: pr(f, it.at + 24, it.at + 40) }}>
              <Chip k={it.label} />
            </div>
          )}
        </div>
      );
    })}
  </>
);

/* ---------------------------------------------------------------- the same widget in several styles, over changing wallpapers */
export type StyleStep = { name: string; wall: string; premium?: boolean; at: number };
export const StyleCycle: React.FC<{ steps: StyleStep[]; caps: Cap[]; width?: number }> = ({ steps, caps, width }) => {
  const f = useCurrentFrame();
  const L = useL();
  const idx = steps.reduce((acc, s, i) => (f >= s.at ? i : acc), 0);
  const step = steps[idx];
  const w = width ?? (L.wide ? 780 : Math.min(L.W * 0.86, 900));
  const cx = L.wide ? 1400 : L.W / 2;
  const cy = L.wide ? 540 : L.f === "9x16" ? 1000 : L.f === "4x5" ? 800 : 640;
  const wallW = Math.max(L.W, (L.H * 1206) / 2622);
  const pop = pr(f, step.at, step.at + 22, ease.lift);
  const prev = idx > 0 ? steps[idx - 1] : null;
  return (
    <Stage bg="#000">
      {steps.map((s, i) => {
        const o = i === 0 ? 1 : pr(f, s.at - 4, s.at + 14);
        return o > 0 ? (
          <div key={i} style={{ position: "absolute", inset: 0, opacity: o, overflow: "hidden" }}>
            <K name={s.wall} w={wallW} style={{ position: "absolute", left: (L.W - wallW) / 2, top: (L.H - (wallW * 2622) / 1206) / 2, filter: "brightness(0.62) saturate(1.1)" }} />
          </div>
        ) : null;
      })}
      <div style={{ position: "absolute", left: cx - w / 2, top: cy - (w * 510) / 1092 / 2, width: w, transform: `scale(${0.9 + 0.1 * pop}) rotate(${(1 - pop) * -2}deg)`, filter: "drop-shadow(0 40px 60px rgba(0,0,0,0.55))" }}>
        {prev && pop < 1 && <K name={prev.name} w={w} style={{ position: "absolute", left: 0, top: 0, opacity: 1 - pop }} />}
        <K name={step.name} w={w} style={{ opacity: prev ? pop : 1, borderRadius: w * 0.05 }} />
      </div>
      <Caps caps={caps} />
    </Stage>
  );
};

/* ---------------------------------------------------------------- gather: widgets converge onto a complete home */
export type Land = { name: string; x: number; y: number; w: number; at: number; fx: number; fy: number; rot: number };
export const GatherShot: React.FC<{ land: Land[]; home: React.ReactNode; base: React.ReactNode; landAt: number; caps: Cap[]; turn?: number; turnDur?: number; bg?: string; push?: number }> = ({ land, home, base, landAt, caps, turn = 0, turnDur = 1, bg, push = 0 }) => {
  const f = useCurrentFrame();
  const done = pr(f, landAt, landAt + 20);
  const ry = turn ? lerp(f, 0, turnDur, 0, turn, ease.transfer) : 0;
  return (
    <Stage bg={bg}>
      <Phone
        cam={{ ry, s: 1 + push * pr(f, 0, turnDur) }}
        over={land.map((w, i) => {
          const q = 1 - pr(f, w.at, w.at + 44, ease.arrival);
          return (
            <div key={i} style={{ position: "absolute", left: w.x + w.fx * q, top: w.y + w.fy * q, opacity: Math.min(1, (1 - q) * 3) * (1 - done), transform: `rotate(${w.rot * q}deg) scale(${1 + q * 0.3})`, filter: `drop-shadow(0 30px 40px rgba(0,0,0,${0.5 * q}))` }}>
              <K name={w.name} w={w.w} />
            </div>
          );
        })}
      >
        {base}
        <div style={{ position: "absolute", inset: 0, opacity: done }}>{home}</div>
      </Phone>
      <Caps caps={caps} />
    </Stage>
  );
};

/* ---------------------------------------------------------------- end card */
export const EndCard: React.FC<{ lines: string[]; pill?: string }> = ({ lines, pill = "common.comingSoon" }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = useL();
  const S0 = L.f === "9x16" ? 300 : L.f === "1x1" ? 190 : L.f === "4x5" ? 250 : 260;
  const icon = 1 - pr(f, 36, 72, ease.transfer);
  const grow = pr(f, 30, 84, ease.arrival);
  const halves = pr(f, 4, 40, ease.split);
  const reveal = (a: number) => pr(f, a, a + 26, ease.split);
  const wm = reveal(70);
  const fs = S0 * 0.42;
  return (
    <Stage>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", display: "flex", flexDirection: "column", gap: S0 * 0.12 }}>
        <div style={{ position: "relative", width: S0, height: S0, transform: `scale(${0.82 + 0.18 * grow})` }}>
          <div style={{ position: "absolute", inset: -S0 * 0.12, borderRadius: S0 * 0.3, background: "linear-gradient(160deg,#4E9BE0,#1B4A7A)", opacity: icon, boxShadow: `0 ${S0 * 0.1}px ${S0 * 0.3}px rgba(36,91,143,0.5)` }} />
          <ArdaneLogo size={S0} cx={S0 / 2} cy={S0 / 2} left={halves} right={halves} glow={Math.max(0.5, grow)} />
        </div>
        <div style={{ fontFamily: INTER, fontWeight: 650, fontSize: fs, letterSpacing: "0.1em", color: C.type1, opacity: wm, transform: `translateY(${(1 - wm) * 20}px)`, clipPath: `inset(0 ${(1 - wm) * 50}% 0 ${(1 - wm) * 50}%)` }}>{t("common.wordmark")}</div>
        {lines.map((k, i) => {
          const r = reveal(96 + i * 26);
          return (
            <div key={k} style={{ fontFamily: INTER, fontWeight: i === 0 ? 560 : 420, fontSize: fs * (i === 0 ? 0.55 : 0.5), color: i === 0 ? C.type1 : C.sapphireBright, opacity: r, transform: `translateY(${(1 - r) * 16}px)`, textAlign: "center", padding: "0 60px", textWrap: "balance" as React.CSSProperties["textWrap"] }}>
              {t(k)}
            </div>
          );
        })}
        <div style={{ marginTop: S0 * 0.08, fontFamily: INTER, fontWeight: 500, fontSize: fs * 0.42, color: C.type1, padding: `${fs * 0.2}px ${fs * 0.55}px`, borderRadius: 999, border: "1.5px solid rgba(255,255,255,0.55)", opacity: reveal(96 + lines.length * 26 + 14) }}>{t(pill)}</div>
      </AbsoluteFill>
    </Stage>
  );
};

/** A flash of sapphire across the whole shot (a scan that locks, a cut that lands). */
export const Flash: React.FC<{ at: number }> = ({ at }) => {
  const f = useCurrentFrame();
  const o = lerp(f, at, at + 4, 0, 1) * (1 - pr(f, at + 4, at + 16));
  return o > 0 ? <AbsoluteFill style={{ background: "radial-gradient(circle at 50% 50%, rgba(104,181,245,0.9), rgba(36,91,143,0.0) 70%)", opacity: o * 0.8, zIndex: 40 }} /> : null;
};

export { clamp };
