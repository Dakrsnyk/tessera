// Visual worlds of the TikTok ads (2026-11-06): each ad gets the style of its mini-app, in the mini-app's colours
// (rule of the user: Fitness red / black / grey, Nutrition orange, Planning cyan; the video background and the iPhone
// wallpaper match). Used by the phone-framed templates (W: workout, J: nutrition journey).
import React from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { clamp, FONT, W } from "./lib";

export type SkinId = "brand" | "gym" | "kitchen";

export type Skin = {
  /** Background of every phone shot. */
  Background: React.FC;
  /** Hook title (big, top). `reveal`: the words appear one by one over that many frames, with the voice (2026-11-08). */
  Title: React.FC<{ text: string; f: number; reveal?: number }>;
  /** Answer to the hook's question (« Meet Ardane », 2026-11-08), with the app icon; `f` counts from its entrance. */
  Answer?: React.FC<{ text: string; f: number; y: number }>;
  chip: { on: string; onText: string; off: string; offText: string; radius: number; upper: boolean };
  phoneShadow: string;
  End: React.FC;
};

const t = (size: number, weight: number, color: string): React.CSSProperties => ({ fontFamily: FONT, fontWeight: weight, fontSize: size, color, textAlign: "center" });

// ------------------------------------------------------------------------------------------------ brand (navy → blue)
const BrandBg: React.FC = () => <AbsoluteFill style={{ background: "linear-gradient(180deg, #07101C 0%, #1D4E9E 100%)" }} />;
const BrandTitle: React.FC<{ text: string; f: number }> = ({ text, f }) => (
  <div style={{ position: "absolute", top: 250, left: 60, right: 60, ...t(100, 800, "#fff"), lineHeight: 1.05, fontVariationSettings: `"opsz" 32`, opacity: interpolate(f, [0, 8], [0, 1], clamp) }}>{text}</div>
);
const BrandEnd: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 14, stiffness: 150 } });
  const b = interpolate(f, [10, 20], [0, 1], clamp);
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #07101C 0%, #1D4E9E 100%)" }}>
      <Img src={staticFile("store/ardane-icon.png")} style={{ position: "absolute", top: 560, left: W / 2 - 130, width: 260, height: 260, borderRadius: 58, transform: `scale(${0.8 + 0.2 * a})`, opacity: a }} />
      <div style={{ position: "absolute", top: 880, left: 0, right: 0, ...t(84, 700, "#fff"), letterSpacing: 6, opacity: a }}>ARDANE</div>
      <div style={{ position: "absolute", top: 1000, left: 0, right: 0, ...t(52, 500, "#BED0E6"), opacity: b }}>Your whole life. One place.</div>
      <div style={{ position: "absolute", top: 1150, left: 0, right: 0, ...t(40, 600, "#fff"), opacity: b }}>Coming soon to the App Store</div>
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------------------------------------ gym poster (Fitness)
const RED = "#E5484D";
const GymBg: React.FC = () => (
  <AbsoluteFill style={{ background: "#0B0B0C", overflow: "hidden" }}>
    {/* brushed-steel stripes, a red slash, a dark vignette */}
    <AbsoluteFill style={{ background: "repeating-linear-gradient(135deg, rgba(255,255,255,0.035) 0px, rgba(255,255,255,0.035) 2px, transparent 2px, transparent 14px)" }} />
    <div style={{ position: "absolute", left: -400, top: 1180, width: 2000, height: 260, background: `linear-gradient(90deg, rgba(229,72,77,0) 0%, ${RED} 40%, #8E1D22 100%)`, transform: "rotate(-14deg)", opacity: 0.9 }} />
    <div style={{ position: "absolute", left: -400, top: 1470, width: 2000, height: 26, background: "#5A5A60", transform: "rotate(-14deg)", opacity: 0.8 }} />
    <AbsoluteFill style={{ background: "radial-gradient(ellipse 900px 1300px at 540px 900px, transparent 40%, rgba(0,0,0,0.75) 100%)" }} />
  </AbsoluteFill>
);
const GymTitle: React.FC<{ text: string; f: number; reveal?: number }> = ({ text, f, reveal }) => {
  const s = interpolate(f, [0, 8], [0, 1], clamp);
  const words = text.split(" ");
  // each word punches in when the voice reaches it (evenly over `reveal` frames); without `reveal`, the whole title at once
  const word = (i: number) => (reveal ? interpolate(f, [(i * reveal) / words.length, (i * reveal) / words.length + 4], [0, 1], clamp) : 1);
  return (
    <div style={{ position: "absolute", top: reveal ? 200 : 230, left: 50, right: 50, transform: `skewX(-10deg) translateX(${(1 - s) * -60}px)`, opacity: s }}>
      <div style={{ ...t(reveal ? 100 : 108, 900, "#fff"), lineHeight: 0.98, textTransform: "uppercase", letterSpacing: -2, fontVariationSettings: `"opsz" 32` }}>
        {reveal
          ? words.map((w, i) => (
              <span key={i} style={{ display: "inline-block", opacity: word(i), transform: `scale(${1.25 - 0.25 * word(i)})`, marginRight: i < words.length - 1 ? "0.24em" : 0 }}>
                {w}
              </span>
            ))
          : text}
      </div>
      <div style={{ margin: "26px auto 0", width: 220 * (reveal ? word(words.length - 1) : s), height: 14, background: RED }} />
    </div>
  );
};
/** « MEET ARDANE » on a red slab, the app icon on its left, punching in like a gym poster stamp. */
const GymAnswer: React.FC<{ text: string; f: number; y: number }> = ({ text, f, y }) => {
  const { fps } = useVideoConfig();
  const s = spring({ frame: f, fps, config: { damping: 12, stiffness: 190 } });
  return (
    <div style={{ position: "absolute", top: y, left: 0, right: 0, display: "flex", justifyContent: "center", opacity: interpolate(f, [0, 3], [0, 1], clamp), transform: `skewX(-10deg) scale(${1.35 - 0.35 * s})` }}>
      <div style={{ display: "flex", alignItems: "center", gap: 24, background: RED, padding: "16px 40px 16px 18px", borderRadius: 10, boxShadow: "0 24px 60px rgba(229,72,77,0.4)" }}>
        <Img src={staticFile("store/ardane-icon.png")} style={{ width: 108, height: 108, borderRadius: 25, transform: "skewX(10deg)" }} />
        <div style={{ ...t(86, 900, "#fff"), textTransform: "uppercase", letterSpacing: 1, whiteSpace: "nowrap", fontVariationSettings: `"opsz" 32` }}>{text}</div>
      </div>
    </div>
  );
};
const GymEnd: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 14, stiffness: 150 } });
  const b = interpolate(f, [10, 20], [0, 1], clamp);
  return (
    <AbsoluteFill>
      <GymBg />
      <Img src={staticFile("store/ardane-icon.png")} style={{ position: "absolute", top: 520, left: W / 2 - 130, width: 260, height: 260, borderRadius: 58, transform: `scale(${0.8 + 0.2 * a})`, opacity: a, boxShadow: `0 0 80px rgba(229,72,77,0.35)` }} />
      <div style={{ position: "absolute", top: 840, left: 0, right: 0, ...t(96, 900, "#fff"), letterSpacing: 4, transform: "skewX(-10deg)", opacity: a }}>ARDANE</div>
      <div style={{ position: "absolute", top: 970, left: 0, right: 0, ...t(52, 800, RED), textTransform: "uppercase", transform: "skewX(-10deg)", opacity: b }}>Your whole life. One place.</div>
      <div style={{ position: "absolute", top: 1120, left: 0, right: 0, ...t(40, 600, "#C9C9CE"), opacity: b }}>Coming soon to the App Store</div>
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------------------------------------ kitchen recipe card (Nutrition)
const ORANGE = "#FF9500";
const CREAM = "#FFF5E9";
const KitchenBg: React.FC = () => (
  <AbsoluteFill style={{ background: CREAM, overflow: "hidden" }}>
    {/* a gingham band at the top and bottom, like a tablecloth; faint recipe-card lines in between */}
    {[0, 1780].map((y) => (
      <div key={y} style={{ position: "absolute", left: 0, top: y, width: W, height: 140, backgroundColor: "#fff", backgroundImage: `linear-gradient(90deg, rgba(255,149,0,0.45) 50%, transparent 50%), linear-gradient(rgba(255,149,0,0.45) 50%, transparent 50%)`, backgroundSize: "56px 56px", opacity: 0.55 }} />
    ))}
    <AbsoluteFill style={{ top: 140, bottom: 140, background: "repeating-linear-gradient(180deg, transparent 0px, transparent 70px, rgba(255,149,0,0.16) 70px, rgba(255,149,0,0.16) 72px)" }} />
  </AbsoluteFill>
);
const KitchenTitle: React.FC<{ text: string; f: number }> = ({ text, f }) => {
  const s = interpolate(f, [0, 8], [0, 1], clamp);
  const u = interpolate(f, [6, 18], [0, 1], clamp);
  return (
    <div style={{ position: "absolute", top: 220, left: 60, right: 60, opacity: s }}>
      <div style={{ ...t(98, 800, "#2B1A0B"), lineHeight: 1.05, fontVariationSettings: `"opsz" 32` }}>{text}</div>
      <svg width="520" height="40" viewBox="0 0 520 40" style={{ display: "block", margin: "14px auto 0" }}>
        <path d="M6 24 C 70 4, 130 36, 200 18 S 330 6, 400 22 S 490 30, 514 14" fill="none" stroke={ORANGE} strokeWidth="11" strokeLinecap="round" pathLength={1} strokeDasharray="1" strokeDashoffset={1 - u} />
      </svg>
    </div>
  );
};
const KitchenEnd: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 14, stiffness: 150 } });
  const ring = interpolate(f, [4, 26], [0, 0.78], clamp);
  const b = interpolate(f, [10, 20], [0, 1], clamp);
  return (
    <AbsoluteFill>
      <KitchenBg />
      {/* the orange calorie ring of the app around the logo */}
      <svg width="420" height="420" viewBox="0 0 420 420" style={{ position: "absolute", left: W / 2 - 210, top: 450 }}>
        <circle cx="210" cy="210" r="190" fill="none" stroke="rgba(255,149,0,0.18)" strokeWidth="26" />
        <circle cx="210" cy="210" r="190" fill="none" stroke={ORANGE} strokeWidth="26" strokeLinecap="round" pathLength={1} strokeDasharray={`${ring} 1`} transform="rotate(-90 210 210)" />
      </svg>
      <Img src={staticFile("store/ardane-icon.png")} style={{ position: "absolute", top: 530, left: W / 2 - 130, width: 260, height: 260, borderRadius: 58, transform: `scale(${0.8 + 0.2 * a})`, opacity: a }} />
      <div style={{ position: "absolute", top: 920, left: 0, right: 0, ...t(90, 800, "#2B1A0B"), letterSpacing: 5, opacity: a }}>ARDANE</div>
      <div style={{ position: "absolute", top: 1040, left: 0, right: 0, ...t(52, 600, "#B35F00"), opacity: b }}>Your whole life. One place.</div>
      <div style={{ position: "absolute", top: 1180, left: 0, right: 0, ...t(40, 600, "#2B1A0B"), opacity: b }}>Coming soon to the App Store</div>
    </AbsoluteFill>
  );
};

export const SKINS: Record<SkinId, Skin> = {
  brand: {
    Background: BrandBg,
    Title: BrandTitle,
    chip: { on: "#fff", onText: "#07101C", off: "rgba(255,255,255,0.12)", offText: "rgba(255,255,255,0.7)", radius: 30, upper: false },
    phoneShadow: "0 50px 90px rgba(0,0,0,0.5), 0 0 0 3px rgba(255,255,255,0.12)",
    End: BrandEnd,
  },
  gym: {
    Background: GymBg,
    Title: GymTitle,
    Answer: GymAnswer,
    chip: { on: RED, onText: "#fff", off: "#1E1E21", offText: "#8E8E94", radius: 8, upper: true },
    phoneShadow: `0 50px 90px rgba(0,0,0,0.7), 0 0 0 3px rgba(229,72,77,0.55), 0 0 90px rgba(229,72,77,0.22)`,
    End: GymEnd,
  },
  kitchen: {
    Background: KitchenBg,
    Title: KitchenTitle,
    chip: { on: ORANGE, onText: "#fff", off: "#FFE6C7", offText: "#B35F00", radius: 30, upper: false },
    phoneShadow: "0 40px 70px rgba(120,60,0,0.28), 0 0 0 3px rgba(255,149,0,0.25)",
    End: KitchenEnd,
  },
};
