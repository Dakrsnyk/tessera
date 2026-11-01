import { createContext, useContext } from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { C, clamp, ease, INTER, type } from "../lib/brand";
import { Format } from "../lib/formats";
import { useLang, useT } from "../lib/i18n";
import { kitSrc26 } from "./kit26";

/**
 * Campaign 2026 toolkit: format-native layout (each format has its own composition, not a crop), tone, captions,
 * capture images with a drawn placeholder when a capture does not exist yet.
 */
export type Tone = "dark" | "light";
export type Size = "xl" | "l" | "m" | "s";
type Zone = "cap" | "mid" | "low";
export type Box = { x: number; y: number; w: number; center: boolean; align: "center" | "left" };
export type Lay = {
  W: number;
  H: number;
  f: Format;
  wide: boolean;
  sc: number;
  phone: { cx: number; cy: number; h: number };
  k: number;
  cap: Box;
  mid: Box;
  low: Box;
  fs: Record<Size, number>;
};

const DIM: Record<Format, { W: number; H: number }> = { "9x16": { W: 1080, H: 1920 }, "1x1": { W: 1080, H: 1080 }, "4x5": { W: 1080, H: 1350 }, "16x9": { W: 1920, H: 1080 } };

export const layoutOf = (f: Format): Lay => {
  const { W, H } = DIM[f];
  const mk = (phone: Lay["phone"], sc: number, cap: Box, low: Box, fs: Lay["fs"]): Lay => ({
    W,
    H,
    f,
    wide: f === "16x9",
    sc,
    phone,
    k: (phone.h * 0.974) / 2622,
    cap,
    mid: { x: f === "16x9" ? 210 : 70, y: H / 2, w: f === "16x9" ? 1500 : 940, center: true, align: "center" },
    low,
    fs,
  });
  const c = (x: number, y: number, w: number, center = false, align: Box["align"] = "center"): Box => ({ x, y, w, center, align });
  if (f === "9x16") return mk({ cx: 540, cy: 1010, h: 1240 }, 1, c(70, 120, 940), c(70, 1672, 940), { xl: 100, l: 80, m: 54, s: 38 });
  if (f === "1x1") return mk({ cx: 540, cy: 660, h: 800 }, 0.62, c(60, 40, 960), c(60, 990, 960), { xl: 66, l: 54, m: 38, s: 28 });
  if (f === "4x5") return mk({ cx: 540, cy: 810, h: 980 }, 0.78, c(70, 64, 940), c(70, 1262, 940), { xl: 80, l: 64, m: 44, s: 32 });
  return mk({ cx: 1400, cy: 540, h: 980 }, 0.95, c(110, 470, 820, true, "left"), c(110, 860, 820, false, "left"), { xl: 96, l: 78, m: 54, s: 38 });
};

export const FormatContext = createContext<Format>("9x16");
export const useL = () => layoutOf(useContext(FormatContext));
export const ToneContext = createContext<Tone>("dark");
export const useTone = () => useContext(ToneContext);

export const ink = (tone: Tone) => (tone === "dark" ? C.type1 : "#14263A");
export const ink2 = (tone: Tone) => (tone === "dark" ? C.type2 : "#5A6B80");
export const accent = (tone: Tone) => (tone === "dark" ? C.sapphireBright : "#245B8F");

/** The nutrient colours of the app: calories orange, protein red, carbs yellow, fat blue. */
export const MACRO = { kcal: "#FF9500", protein: "#E5484D", carbs: "#F5A524", fat: "#3366FF" };

export const pr = (f: number, a: number, b: number, e?: (t: number) => number) => interpolate(f, [a, b], [0, 1], { ...clamp, easing: e });
export const sec = (s: number) => Math.round(s * 60);

/* ---------------------------------------------------------------- stage */
export const Stage: React.FC<{ tone?: Tone; bg?: string; children?: React.ReactNode }> = ({ tone = "dark", bg, children }) => {
  const background = bg ?? (tone === "dark" ? "radial-gradient(ellipse 90% 55% at 50% 40%, #0B2038 0%, #04080F 55%, #000 100%)" : "linear-gradient(180deg,#F8F5EE 0%,#E8EEF6 100%)");
  return (
    <ToneContext.Provider value={tone}>
      <AbsoluteFill style={{ background, fontFamily: INTER }}>
        {children}
        {tone === "dark" && <Grain />}
      </AbsoluteFill>
    </ToneContext.Provider>
  );
};

/* ---------------------------------------------------------------- captions */
export type Cap = { k: string; at: number; out?: number; size?: Size; slot?: number; accent?: boolean; premium?: boolean; split?: boolean; zone?: Zone; mono?: boolean };

const Star: React.FC<{ s: number; color: string }> = ({ s, color }) => (
  <svg width={s} height={s} viewBox="0 0 24 24" style={{ flex: "none" }}>
    <path d="M12 2l2.9 6.6 7.1.7-5.3 4.8 1.5 7-6.2-3.6-6.2 3.6 1.5-7L2 9.3l7.1-.7z" fill={color} />
  </svg>
);

const CapText: React.FC<{ c: Cap }> = ({ c }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = useL();
  const tone = useTone();
  const lang = useLang();
  const size = c.size ?? "l";
  const text = t(c.k);
  const fs = L.fs[size] * (lang === "fr" && size !== "s" ? 0.94 : 1);
  const out = c.out === undefined ? 1 : 1 - pr(f, c.out, c.out + 12);
  const color = c.accent ? accent(tone) : ink(tone);
  const zone = c.zone ?? "cap";
  if (c.premium) {
    const a = accent(tone);
    const o = pr(f, c.at, c.at + 14, ease.split) * out;
    return (
      <div style={{ opacity: o, transform: `translateY(${(1 - o) * 14}px)`, display: "flex", alignItems: "center", gap: fs * 0.3, padding: `${fs * 0.22}px ${fs * 0.55}px`, borderRadius: 999, border: `${Math.max(1.5, fs * 0.05)}px solid ${a}`, background: tone === "dark" ? "rgba(36,91,143,0.32)" : "rgba(36,91,143,0.1)", color: tone === "dark" ? "#EAF4FF" : "#245B8F", fontFamily: INTER, fontWeight: 600, fontSize: fs * 0.82, letterSpacing: "0.01em", whiteSpace: "nowrap" }}>
        <Star s={fs * 0.8} color={a} />
        {text}
      </div>
    );
  }
  const chip: React.CSSProperties =
    zone === "low"
      ? { padding: `${fs * 0.28}px ${fs * 0.7}px`, borderRadius: 999, background: tone === "dark" ? "rgba(10,24,40,0.72)" : "rgba(255,255,255,0.8)", border: `1px solid ${tone === "dark" ? "rgba(104,181,245,0.35)" : "rgba(36,91,143,0.25)"}`, backdropFilter: "blur(12px)" }
      : {};
  const base: React.CSSProperties = { fontFamily: INTER, fontWeight: size === "xl" ? 700 : size === "l" ? 650 : 560, fontSize: fs, lineHeight: 1.08, letterSpacing: size === "xl" || size === "l" ? "-0.02em" : "-0.005em", color, fontVariationSettings: "'opsz' 32", textWrap: "balance" as React.CSSProperties["textWrap"], textAlign: L.mid.align === "left" && zone !== "mid" && L.wide ? "left" : "center", ...chip };
  if (c.split) {
    const p = pr(f, c.at, c.at + 34, ease.split);
    const o = pr(f, c.at, c.at + 12) * out;
    const r = (1 - p) * 50;
    return <div style={{ ...base, opacity: o, clipPath: `inset(-20% ${r}% -20% ${r}%)` }}>{text}</div>;
  }
  const words = text.split(" ");
  return (
    <div style={{ ...base, opacity: out }}>
      {words.map((w, i) => {
        const p = pr(f, c.at + i * 3, c.at + i * 3 + 22, ease.split);
        return (
          <span key={i} style={{ display: "inline-block", opacity: Math.min(1, p * 1.5), transform: `translateY(${(1 - p) * 0.35 * fs}px)`, whiteSpace: "pre" }}>
            {w}
            {i < words.length - 1 ? " " : ""}
          </span>
        );
      })}
    </div>
  );
};

export const Caps: React.FC<{ caps: Cap[] }> = ({ caps }) => {
  const L = useL();
  return (
    <>
      {(["cap", "mid", "low"] as const).map((z) => {
        const items = caps.filter((c) => (c.zone ?? "cap") === z);
        if (!items.length) return null;
        const b = L[z];
        const slots = Array.from(new Set(items.map((c) => c.slot ?? 0))).sort((a, c) => a - c);
        return (
          <div key={z} style={{ position: "absolute", left: b.x, top: b.y, width: b.w, transform: b.center ? "translateY(-50%)" : undefined, display: "flex", flexDirection: "column", alignItems: b.align === "center" ? "center" : "flex-start", gap: 16 * L.sc, zIndex: 20 }}>
            {slots.map((s) => (
              <div key={s} style={{ display: "grid", justifyItems: b.align === "center" ? "center" : "start" }}>
                {items
                  .filter((c) => (c.slot ?? 0) === s)
                  .map((c, i) => (
                    <div key={i} style={{ gridArea: "1 / 1" }}>
                      <CapText c={c} />
                    </div>
                  ))}
              </div>
            ))}
          </div>
        );
      })}
    </>
  );
};

/** The permanent legal line (bottom left), except on the end card. */
export const DemoLine: React.FC = () => {
  const t = useT();
  const L = useL();
  return <div style={{ position: "absolute", left: 36 * L.sc + 14, bottom: 30 * L.sc + 8, fontFamily: INTER, fontSize: Math.max(18, 24 * L.sc), color: "rgba(255,255,255,0.62)", mixBlendMode: "difference", zIndex: 30 }}>{t("common.demoData")}</div>;
};

/* ---------------------------------------------------------------- captures */
/** Natural size of a capture from its name (kit conventions). */
export const natural = (name: string): [number, number] => {
  if (/^live-/.test(name)) return [1116, 465];
  if (/^lock-.*-rect/.test(name)) return [688, 304];
  if (/^lock-.*-(circular|inline)/.test(name)) return [304, 304];
  if (/-m-/.test(name)) return [1092, 510];
  if (/-s-/.test(name)) return [680, 680];
  if (/-l-/.test(name)) return [1092, 1146];
  if (/-tall/.test(name)) return [1206, 5519];
  return [1206, 2622];
};

/** A capture of the kit at width `w` (px of its parent's space), or a drawn placeholder when it does not exist. */
export const K: React.FC<{ name: string; w?: number; style?: React.CSSProperties }> = ({ name, w, style }) => {
  const lang = useLang();
  const src = kitSrc26(name, lang);
  const [nw, nh] = natural(name);
  const width = w ?? nw;
  const height = (width * nh) / nw;
  if (!src) {
    return (
      <div style={{ width, height, boxSizing: "border-box", borderRadius: width * 0.06, border: `${Math.max(3, width * 0.004)}px dashed rgba(104,181,245,0.7)`, background: "linear-gradient(160deg,#16314F,#0B1B2E)", color: "#CFE6FB", fontFamily: INTER, display: "flex", alignItems: "center", justifyContent: "center", textAlign: "center", fontSize: width * 0.045, padding: width * 0.06, ...style }}>
        {name}
        <br />
        (capture to come)
      </div>
    );
  }
  return <Img src={staticFile(src)} style={{ width, height, display: "block", ...style }} />;
};

/** Wordmark text style helper. */
export const wordmark = { ...type.wordmark };
export { C };
