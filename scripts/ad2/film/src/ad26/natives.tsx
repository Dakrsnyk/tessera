import { AbsoluteFill, useCurrentFrame } from "remotion";
import { EAN, eanModules } from "../components/Barcode";
import { C, ease, INTER } from "../lib/brand";
import { useLang, useT } from "../lib/i18n";
import { Cap, Caps, K, MACRO, Stage, accent, ink, ink2, pr, useL } from "./ctx";
import { lerp } from "./Phone";

/* ---------------------------------------------------------------- barcode that slides into the real scan square (1206 space) */
export const ScanLayer: React.FC<{ f: number }> = ({ f }) => {
  const p = pr(f, 14, 78, ease.arrival);
  const lock = pr(f, 78, 92);
  const bits = eanModules(EAN);
  const w = 620;
  const h = 400;
  const m = 560 / (95 + 18);
  return (
    <>
      <div style={{ position: "absolute", left: 603 - w / 2 + (1 - p) * 1000, top: 1258 - h / 2 - (1 - p) * 260, width: w, height: h, borderRadius: 26, background: "#F6F5F2", boxShadow: "0 30px 60px rgba(0,0,0,0.35)", transform: `rotate(${(1 - p) * 14}deg) scale(${0.85 + 0.15 * p})` }}>
        <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
          {bits.split("").map((b, i) => {
            const guard = i < 3 || (i >= 45 && i < 50) || i >= 92;
            return b === "1" ? <rect key={i} x={30 + (9 + i) * m * 0.95 - 4} y={34} width={m * 0.95 + 0.4} height={guard ? 300 : 276} fill="#111114" /> : null;
          })}
          <text x={w / 2} y={h - 30} textAnchor="middle" fontFamily={INTER} fontSize={34} fill="#111114" letterSpacing={7}>{EAN}</text>
        </svg>
      </div>
      {lock > 0 && <div style={{ position: "absolute", left: 603 - 390, top: 1258 - 390, width: 780, height: 780, borderRadius: 120, border: "14px solid rgba(104,181,245,0.95)", boxShadow: "0 0 80px rgba(104,181,245,0.8), inset 0 0 80px rgba(104,181,245,0.4)", opacity: lock * (1 - pr(f, 100, 120) * 0.3) }} />}
    </>
  );
};

/* ---------------------------------------------------------------- the calorie ring (orange) and the 3 macro bars (red, yellow, blue) */
export const RingBars: React.FC<{ caps?: Cap[]; tone?: "light" | "dark" }> = ({ caps = [], tone = "light" }) => {
  const f = useCurrentFrame();
  const t = useT();
  const lang = useLang();
  const L = useL();
  const cw = L.wide ? 860 : Math.min(L.W * 0.88, 940);
  const scale = cw / 900;
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 540 : L.f === "9x16" ? 1040 : L.f === "4x5" ? 800 : 650;
  const sweep = pr(f, 4, 70, ease.transfer);
  const remaining = 1 - sweep * 0.49;
  const R = 150;
  const circ = 2 * Math.PI * R;
  const num = (n: number) => (lang === "fr" ? n.toLocaleString("fr-FR").replace(/ /g, " ") : n.toLocaleString("en-US"));
  const bars = [
    { k: "nutrition.protein", v: "89 / 130 g", p: 89 / 130, c: MACRO.protein },
    { k: "nutrition.carbs", v: "144 / 250 g", p: 144 / 250, c: MACRO.carbs },
    { k: "nutrition.fat", v: "16 / 70 g", p: 16 / 70, c: MACRO.fat },
  ];
  const dark = tone === "dark";
  return (
    <Stage tone={tone}>
      <div style={{ position: "absolute", left: cx - cw / 2, top: cy - (scale * 700) / 2, width: 900, height: 700, transform: `scale(${scale})`, transformOrigin: "0 0", borderRadius: 64, background: dark ? "#14181F" : "#FFFFFF", boxShadow: "0 40px 90px rgba(20,38,58,0.18)", fontFamily: INTER, color: ink(tone) }}>
        <svg width={900} height={420} style={{ position: "absolute", left: 0, top: 0 }}>
          <circle cx={260} cy={230} r={R} fill="none" stroke="rgba(255,149,0,0.17)" strokeWidth={40} />
          <circle cx={260} cy={230} r={R} fill="none" stroke={MACRO.kcal} strokeWidth={40} strokeLinecap="round" strokeDasharray={`${circ * remaining} ${circ}`} transform="rotate(-90 260 230)" />
        </svg>
        <div style={{ position: "absolute", left: 110, top: 160, width: 300, textAlign: "center" }}>
          <div style={{ fontSize: 88, fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 1 }}>{num(Math.round(2200 - sweep * 1078))}</div>
          <div style={{ fontSize: 30, color: ink2(tone), marginTop: 6 }}>{t("nutrition.kcalLeft")}</div>
        </div>
        <div style={{ position: "absolute", left: 500, top: 150, width: 360 }}>
          <div style={{ fontSize: 34, fontWeight: 600, color: MACRO.kcal }}>{t("nutrition.calories")}</div>
          <div style={{ fontSize: 60, fontWeight: 650, marginTop: 8 }}>
            {num(Math.round(sweep * 1078))} <span style={{ fontSize: 30, color: ink2(tone) }}>/ {num(2200)} kcal</span>
          </div>
        </div>
        {bars.map((b, i) => {
          const q = pr(f, 70 + i * 24, 70 + i * 24 + 30, ease.lift);
          return (
            <div key={b.k} style={{ position: "absolute", left: 56, top: 450 + i * 76, width: 788, opacity: Math.min(1, q * 3) }}>
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: 34, fontWeight: 560 }}>
                <span style={{ display: "flex", alignItems: "center", gap: 14 }}>
                  <span style={{ width: 22, height: 22, borderRadius: 11, background: b.c }} />
                  {t(b.k)}
                </span>
                <span style={{ color: ink2(tone), fontWeight: 500 }}>{b.v}</span>
              </div>
              <div style={{ height: 14, borderRadius: 7, background: dark ? "rgba(255,255,255,0.12)" : "rgba(20,38,58,0.1)", marginTop: 10 }}>
                <div style={{ height: 14, borderRadius: 7, background: b.c, width: `${b.p * 100 * q}%` }} />
              </div>
            </div>
          );
        })}
      </div>
      <Caps caps={caps} />
    </Stage>
  );
};

/* ---------------------------------------------------------------- Finance */
const money = (n: number, lang: string) => (lang === "fr" ? `${Math.round(n).toLocaleString("fr-FR").replace(/ /g, " ")} $` : `$${Math.round(n).toLocaleString("en-US")}`);
export const INCOME = 4280;
export const EXPENSES = 2649;
export const BALANCE = INCOME - EXPENSES;

export const BalanceCounter: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const f = useCurrentFrame();
  const lang = useLang();
  const t = useT();
  const L = useL();
  const p = pr(f, 8, 100, ease.arrival);
  const fs = L.fs.xl * (L.wide ? 2.4 : 2.2);
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 540 : L.H / 2 + (L.f === "9x16" ? 60 : 40);
  const line = pr(f, 90, 150, ease.transfer);
  return (
    <Stage>
      <div style={{ position: "absolute", left: cx - 520, width: 1040, top: cy - fs * 0.6, textAlign: "center", fontFamily: INTER, fontWeight: 700, fontSize: fs, letterSpacing: "-0.04em", color: C.type1, fontVariantNumeric: "tabular-nums", fontVariationSettings: "'opsz' 32" }}>{money(BALANCE * p, lang)}</div>
      <div style={{ position: "absolute", left: cx - 300, width: 600, top: cy + fs * 0.55, textAlign: "center", fontFamily: INTER, fontSize: fs * 0.2, color: C.sapphireBright, opacity: pr(f, 50, 80) }}>{t("finance.balance")}</div>
      <div style={{ position: "absolute", left: cx - 520 * line, width: 1040 * line, top: cy + fs * 0.8, height: 4, background: `linear-gradient(90deg, transparent, ${C.sapphireBright}, transparent)`, opacity: line }} />
      <Caps caps={caps} />
    </Stage>
  );
};

export const Pills: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const f = useCurrentFrame();
  const lang = useLang();
  const t = useT();
  const L = useL();
  const rows = [
    { k: "finance.income", v: INCOME, c: C.sapphireBright, at: 12 },
    { k: "finance.expenses", v: EXPENSES, c: "#FF8A65", at: 72 },
    { k: "finance.balance", v: BALANCE, c: "#FFFFFF", at: 132 },
  ];
  const pw = L.wide ? 760 : Math.min(L.W * 0.86, 900);
  const ph = L.f === "1x1" ? 150 : 200;
  const gap = L.f === "1x1" ? 26 : 40;
  const cx = L.wide ? 1380 : L.W / 2;
  const top = L.wide ? 540 - (3 * ph + 2 * gap) / 2 : L.f === "9x16" ? 620 : L.f === "1x1" ? 300 : 400;
  const stretch = pr(f, 176, 190, ease.chapter);
  return (
    <Stage>
      {rows.map((r, i) => {
        const p = pr(f, r.at, r.at + 24, ease.lift);
        const cnt = pr(f, r.at + 6, r.at + 50, ease.arrival);
        const hide = i < 2 ? 1 - stretch : 1;
        return (
          <div key={r.k} style={{ position: "absolute", left: cx - pw / 2, top: top + i * (ph + gap), width: pw, height: ph, borderRadius: ph / 2, background: "rgba(36,91,143,0.28)", border: `2px solid ${r.c}55`, display: "flex", alignItems: "center", justifyContent: "space-between", padding: `0 ${ph * 0.4}px`, fontFamily: INTER, color: C.type1, opacity: Math.min(1, p * 2) * hide, transform: `translateY(${(1 - p) * 40}px) scaleX(${1 + (i === 2 ? stretch * 0.08 : 0)})` }}>
            <span style={{ fontSize: ph * 0.26, fontWeight: 560, color: r.c }}>{t(r.k)}</span>
            <span style={{ fontSize: ph * 0.38, fontWeight: 700, letterSpacing: "-0.02em", fontVariantNumeric: "tabular-nums" }}>{money(r.v * cnt, lang)}</span>
          </div>
        );
      })}
      <Caps caps={caps} />
    </Stage>
  );
};

const DATA = [0.34, 0.37, 0.3, 0.33, 0.4, 0.46, 0.43, 0.5, 0.47, 0.42, 0.45, 0.52, 0.58, 0.55, 0.6, 0.57, 0.52, 0.55, 0.62, 0.66, 0.63, 0.7, 0.74, 0.7, 0.72, 0.78, 0.8, 0.77, 0.82, 0.86];

export const CurveCard: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = useL();
  const cw = L.wide ? 860 : Math.min(L.W * 0.9, 940);
  const scale = cw / 900;
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 540 : L.f === "9x16" ? 980 : L.f === "4x5" ? 780 : 640;
  const W = 820;
  const H = 360;
  const pts = DATA.map((v, i) => [40 + (i / (DATA.length - 1)) * W, 40 + (1 - v) * H] as const);
  const d = pts.map(([x, y], i) => (i ? `L${x},${y}` : `M${x},${y}`)).join(" ");
  const p = pr(f, 14, 110, ease.transfer);
  const n = Math.min(pts.length - 1, Math.floor(p * (pts.length - 1)));
  const [dx, dy] = pts[n];
  const prem = pr(f, 120, 140);
  const seg = ["finance.month", "finance.threeMonths", "finance.year"];
  return (
    <Stage>
      <div style={{ position: "absolute", left: cx - cw / 2, top: cy - (scale * 640) / 2, width: 900, height: 640, transform: `scale(${scale})`, transformOrigin: "0 0", borderRadius: 60, background: "linear-gradient(180deg,#0F2640,#0A1828)", border: "1.5px solid rgba(104,181,245,0.3)", boxShadow: "0 40px 90px rgba(0,0,0,0.5)", fontFamily: INTER }}>
        <div style={{ position: "absolute", left: 40, top: 36, display: "flex", gap: 8, padding: 8, borderRadius: 40, background: "rgba(255,255,255,0.07)" }}>
          {seg.map((k, i) => (
            <div key={k} style={{ padding: "12px 28px", borderRadius: 32, fontSize: 30, fontWeight: 600, background: i === 0 ? "#245B8F" : "transparent", color: i === 0 ? "#fff" : C.type2, boxShadow: i > 0 && prem > 0 ? `0 0 0 2px rgba(104,181,245,${0.6 * prem})` : undefined }}>{t(k)}</div>
          ))}
        </div>
        <svg width={900} height={500} style={{ position: "absolute", left: 0, top: 130 }} viewBox="0 0 900 460">
          <defs>
            <linearGradient id="curveFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#68B5F5" stopOpacity="0.45" />
              <stop offset="1" stopColor="#245B8F" stopOpacity="0" />
            </linearGradient>
            <clipPath id="curveClip"><rect x="0" y="0" width={40 + p * W} height="460" /></clipPath>
          </defs>
          <g clipPath="url(#curveClip)">
            <path d={`${d} L${40 + W},440 L40,440 Z`} fill="url(#curveFill)" />
            <path d={d} fill="none" stroke="#68B5F5" strokeWidth={7} strokeLinejoin="round" strokeLinecap="round" />
          </g>
          <circle cx={dx} cy={dy} r={14} fill="#fff" stroke="#68B5F5" strokeWidth={6} />
        </svg>
      </div>
      <Caps caps={caps} />
    </Stage>
  );
};

/** Three captures that stack in depth: categories, bills, savings. */
export const StackCards: React.FC<{ items: { name: string; k: string }[]; at: number[]; caps: Cap[] }> = ({ items, at, caps }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = useL();
  const D = { "9x16": { w: 820, h: 640, dy: 140 }, "1x1": { w: 540, h: 400, dy: 78 }, "4x5": { w: 700, h: 520, dy: 110 }, "16x9": { w: 720, h: 560, dy: 120 } }[L.f];
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 540 : L.f === "9x16" ? 1010 : L.f === "4x5" ? 800 : 640;
  return (
    <Stage>
      {items.map((it, i) => {
        const p = pr(f, at[i], at[i] + 30, ease.lift);
        // How many cards came after this one: it recedes up and back.
        const after = items.reduce((n, _, j) => n + (j > i ? pr(f, at[j], at[j] + 30, ease.lift) : 0), 0);
        const y = cy + (1 - p) * 700 - after * D.dy;
        const s = 1 - after * 0.07;
        return (
          <div key={it.name} style={{ position: "absolute", left: cx - D.w / 2, top: y - D.h / 2, width: D.w, height: D.h, borderRadius: 48, overflow: "hidden", opacity: Math.min(1, p * 2.4), transform: `scale(${s})`, zIndex: i, filter: `brightness(${1 - after * 0.18})`, boxShadow: "0 40px 80px rgba(0,0,0,0.55)", border: "1.5px solid rgba(104,181,245,0.35)" }}>
            <div style={{ width: D.w, height: D.h, overflow: "hidden" }}>
              <K name={it.name} w={D.w * 1.0} style={{ objectFit: "cover" }} />
            </div>
            <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: D.h * 0.26, background: "linear-gradient(to top, rgba(4,10,18,0.92), transparent)" }} />
            <div style={{ position: "absolute", left: 30, bottom: 22, fontFamily: INTER, fontWeight: 650, fontSize: Math.max(30, D.w * 0.05), color: "#F5F5F7" }}>{t(it.k)}</div>
          </div>
        );
      })}
      <Caps caps={caps} />
    </Stage>
  );
};

/* ---------------------------------------------------------------- Organisation */
const Glyph: React.FC<{ kind: "habits" | "planning" | "goals"; s: number; c: string }> = ({ kind, s, c }) => (
  <svg width={s} height={s} viewBox="0 0 48 48" fill="none" stroke={c} strokeWidth={3.4} strokeLinecap="round" strokeLinejoin="round">
    {kind === "habits" && (
      <>
        <circle cx="24" cy="24" r="17" />
        <path d="M15 24.5l6 6 12-13" />
      </>
    )}
    {kind === "planning" && (
      <>
        <rect x="6" y="9" width="36" height="32" rx="7" />
        <path d="M6 19h36M16 5v8M32 5v8M15 27h6M27 27h6M15 34h6" />
      </>
    )}
    {kind === "goals" && (
      <>
        <circle cx="24" cy="24" r="17" />
        <circle cx="24" cy="24" r="9" />
        <circle cx="24" cy="24" r="2.5" fill={c} />
      </>
    )}
  </svg>
);

export const ThreeCards: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = useL();
  const items: { k: string; g: "habits" | "planning" | "goals"; col: string }[] = [
    { k: "common.hlHabits", g: "habits", col: "#245B8F" },
    { k: "common.hlPlanning", g: "planning", col: "#3C7DB8" },
    { k: "common.hlGoals", g: "goals", col: "#68B5F5" },
  ];
  const cw = L.wide ? 330 : L.f === "1x1" ? 250 : L.f === "4x5" ? 300 : 330;
  const ch = cw * 1.25;
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 560 : L.f === "9x16" ? 1000 : L.f === "4x5" ? 800 : 640;
  const zoom = pr(f, 190, 236, ease.chapter);
  return (
    <Stage tone="light">
      {items.map((it, i) => {
        const p = pr(f, 6 + i * 14, 40 + i * 14, ease.lift);
        const dx = (i - 1) * (cw * (L.wide ? 1.12 : 1.14));
        const dy = (i - 1) * (L.wide ? 0 : cw * 0.1) * 0 + Math.sin((f + i * 40) / 50) * 14;
        const rot = (i - 1) * 4;
        const isHab = i === 0;
        const sc = isHab ? 1 + zoom * 2.2 : 1 - zoom * 0.2;
        return (
          <div key={it.k} style={{ position: "absolute", left: cx + dx - cw / 2, top: cy + dy - ch / 2 + (1 - p) * 120 + (i % 2 ? 40 : 0), width: cw, height: ch, borderRadius: cw * 0.14, background: "#FFFFFF", boxShadow: "0 30px 70px rgba(20,38,58,0.2)", opacity: Math.min(1, p * 2) * (isHab ? 1 : 1 - zoom), transform: `rotate(${rot * (1 - zoom)}deg) scale(${sc})`, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: cw * 0.1, fontFamily: INTER, zIndex: isHab ? 5 : 1 }}>
            <div style={{ width: cw * 0.42, height: cw * 0.42, borderRadius: cw * 0.13, background: `${it.col}22`, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Glyph kind={it.g} s={cw * 0.26} c={it.col} />
            </div>
            <div style={{ fontSize: cw * 0.11, fontWeight: 650, color: "#14263A" }}>{t(it.k)}</div>
          </div>
        );
      })}
      <Caps caps={caps} />
    </Stage>
  );
};

export const HabitCard: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = useL();
  const cw = L.wide ? 860 : Math.min(L.W * 0.88, 940);
  const scale = cw / 900;
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 540 : L.f === "9x16" ? 1000 : L.f === "4x5" ? 800 : 640;
  const tick = pr(f, 50, 84, ease.transfer);
  const fill = (i: number) => pr(f, 96 + i * 12, 96 + i * 12 + 14);
  const streak = Math.round(lerp(f, 150, 180, 11, 12));
  return (
    <Stage tone="light">
      <div style={{ position: "absolute", left: cx - cw / 2, top: cy - (scale * 700) / 2, width: 900, height: 700, transform: `scale(${scale})`, transformOrigin: "0 0", borderRadius: 64, background: "#fff", boxShadow: "0 40px 90px rgba(20,38,58,0.18)", fontFamily: INTER }}>
        <svg width={900} height={300} style={{ position: "absolute", left: 0, top: 40 }}>
          <circle cx={450} cy={150} r={110} fill={`rgba(36,91,143,${0.08 + 0.1 * tick})`} stroke="#245B8F" strokeWidth={10} />
          <path d="M395 152 l42 44 l78 -90" fill="none" stroke="#245B8F" strokeWidth={20} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={240} strokeDashoffset={240 * (1 - tick)} />
        </svg>
        <div style={{ position: "absolute", left: 90, top: 380, display: "flex", gap: 18 }}>
          {[0, 1, 2, 3, 4, 5, 6].map((i) => (
            <div key={i} style={{ width: 86, height: 86, borderRadius: 24, background: `rgba(36,91,143,${0.1 + 0.9 * fill(i)})`, transform: `scale(${1 + 0.15 * Math.sin(Math.PI * fill(i))})` }} />
          ))}
        </div>
        <div style={{ position: "absolute", left: 0, width: 900, top: 520, textAlign: "center", color: "#14263A" }}>
          <span style={{ fontSize: 120, fontWeight: 700, letterSpacing: "-0.03em" }}>{streak}</span>
          <span style={{ fontSize: 40, fontWeight: 560, color: "#5A6B80", marginLeft: 18 }}>{t("organisation.streak")}</span>
        </div>
      </div>
      <Caps caps={caps} />
    </Stage>
  );
};

export const WeekBlocks: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const f = useCurrentFrame();
  const L = useL();
  const cw = L.wide ? 860 : Math.min(L.W * 0.9, 940);
  const scale = cw / 900;
  const cx = L.wide ? 1380 : L.W / 2;
  const cy = L.wide ? 540 : L.f === "9x16" ? 1000 : L.f === "4x5" ? 800 : 640;
  const blocks: [number, number, number, string][] = [
    [0, 0, 2, "#245B8F"], [0, 3, 1, "#68B5F5"], [1, 1, 2, "#3C7DB8"], [1, 4, 1, "#245B8F"], [2, 0, 1, "#68B5F5"], [2, 2, 3, "#245B8F"],
    [3, 1, 1, "#3C7DB8"], [3, 3, 2, "#68B5F5"], [4, 0, 2, "#3C7DB8"], [4, 3, 1, "#245B8F"], [5, 2, 2, "#68B5F5"], [6, 1, 1, "#245B8F"],
  ];
  const today = lerp(f, 20, 200, 0.2, 2.8);
  return (
    <Stage tone="light">
      <div style={{ position: "absolute", left: cx - cw / 2, top: cy - (scale * 720) / 2, width: 900, height: 720, transform: `scale(${scale})`, transformOrigin: "0 0", borderRadius: 60, background: "#fff", boxShadow: "0 40px 90px rgba(20,38,58,0.18)", fontFamily: INTER, overflow: "hidden" }}>
        {[0, 1, 2, 3, 4, 5, 6].map((d) => (
          <div key={d} style={{ position: "absolute", left: 40 + d * 117, top: 36, width: 100, textAlign: "center", fontSize: 28, fontWeight: 600, color: d === 2 ? "#245B8F" : "#8A97A8" }}>{["M", "T", "W", "T", "F", "S", "S"][d]}</div>
        ))}
        {[0, 1, 2, 3, 4, 5].map((r) => (
          <div key={r} style={{ position: "absolute", left: 40, right: 40, top: 110 + r * 100, height: 1, background: "rgba(20,38,58,0.07)" }} />
        ))}
        {blocks.map(([d, r, h, c], i) => {
          const p = pr(f, 10 + i * 12, 10 + i * 12 + 18, ease.lift);
          return <div key={i} style={{ position: "absolute", left: 44 + d * 117, top: 116 + r * 100 - (1 - p) * 60, width: 92, height: h * 100 - 10, borderRadius: 20, background: c, opacity: p }} />;
        })}
        <div style={{ position: "absolute", left: 30, right: 30, top: 110 + today * 100, height: 4, background: "#E5484D", borderRadius: 2 }} />
      </div>
      <Caps caps={caps} />
    </Stage>
  );
};

export { AbsoluteFill, accent };
