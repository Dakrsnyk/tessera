// Template J « parcours » (2026-11-06): the user opens Ardane, goes to Nutrition, scans a dish, customizes the Macros widget
// in the Studio and places it on a Home Screen that already has apps and a Fitness widget (M). One app journey, three framings:
//   "full"  : the app in full screen, TikTok captions (looks like a screen recording);
//   "phone" : the phone on the Ardane gradient, numbered steps at the top;
//   "photo" : opens on the real dish photo, then the phone over the blurred photo / wallpaper, TikTok captions.
import React from "react";
import { AbsoluteFill, Audio, Img, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption, cap, clamp, FONT, FPS, H, out, PremiumTag, W } from "./lib";
import { CH, CW, HomeBase, ICON, Landing, PHOTO, PhotoScan, PhotoSummary, Tap } from "./journey/Screens";

export type PartKey = "hook" | "open" | "scan" | "custom" | "place" | "end";
export type SpecJ = {
  id: string;
  template: "J";
  framing: "full" | "phone" | "photo";
  music?: string;
  /** Voice line per part (keys of vo_lines.json) and on-screen caption per part. */
  vo: Record<PartKey, string>;
  captions: Partial<Record<PartKey, string>>;
  /** The widget style the user ends on (Studio capture + the matching widget export). */
  final: { studio: string; widget: string };
  voLen: Record<string, number>;
};

const LEAD = 0.25;
/** Shortest length of each part (s): what its own animation needs. */
const MIN: Record<PartKey, number> = { hook: 2.0, open: 3.0, scan: 4.9, custom: 3.7, place: 3.2, end: 2.8 };
const TAIL: Record<PartKey, number> = { hook: 0.3, open: 0.4, scan: 0.4, custom: 0.4, place: 0.8, end: 0.6 };
const ORDER: PartKey[] = ["hook", "open", "scan", "custom", "place", "end"];

export const timelineJ = (s: SpecJ) => {
  let from = 0;
  return ORDER.map((key) => {
    const d = Math.round(Math.max(MIN[key], (s.voLen[s.vo[key]] ?? 0) + LEAD + TAIL[key]) * FPS);
    const r = { key, from, frames: d };
    from += d;
    return r;
  });
};
export const lengthJ = (s: SpecJ) => timelineJ(s).reduce((a, p) => a + p.frames, 0);

/** Which Studio capture shows at frame f of the customize part, and the taps. */
const STUDIO = (final: string) => [
  { at: 0, src: "studio-style" },
  { at: 20, src: "studio-style-aurora" },
  { at: 38, src: "studio-style-neon" },
  { at: 56, src: final },
];

/** The app screen of a part at its local frame f (capture px). Also where the camera should look (0–1 of the height). */
const AppScreen: React.FC<{ part: PartKey; f: number; spec: SpecJ }> = ({ part, f, spec }) => {
  const { fps } = useVideoConfig();
  if (part === "hook") return <HomeBase />;
  if (part === "open") {
    // tap the Ardane icon, the app grows out of it, My Day, tap the Nutrition card, Nutrition, tap « Add a food »
    const grow = interpolate(f, [8, 20], [0, 1], { ...clamp, easing: out });
    const inApp = f >= 8;
    const nutrition = f >= 40;
    return (
      <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden", background: "#000" }}>
        <HomeBase />
        <Tap f={f} at={4} x={ICON.x + ICON.s / 2} y={ICON.y + ICON.s / 2} />
        {inApp && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              transformOrigin: `${ICON.x + ICON.s / 2}px ${ICON.y + ICON.s / 2}px`,
              transform: `scale(${0.12 + 0.88 * grow})`,
              borderRadius: 120 * (1 - grow) + 10,
              overflow: "hidden",
              opacity: Math.min(1, grow * 3),
            }}
          >
            <Img src={cap(nutrition ? "app-nutrition-s00" : "home-s00")} style={{ position: "absolute", width: CW, height: CH }} />
            <Tap f={f} at={32} x={700} y={640} />
            <Tap f={f} at={60} x={603} y={1272} />
          </div>
        )}
      </div>
    );
  }
  if (part === "scan") {
    const SUM = 84; // summary from frame 84 (2.8 s)
    return (
      <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
        {f < SUM ? <PhotoScan t={f * 2} /> : <PhotoSummary t={(f - SUM) * 2} />}
        <Tap f={f} at={11} x={603} y={2030} />
        <Tap f={f} at={SUM + 46} x={603} y={2330} />
      </div>
    );
  }
  if (part === "custom") {
    const steps = STUDIO(spec.final.studio);
    let k = 0;
    steps.forEach((s, i) => {
      if (f >= s.at) k = i;
    });
    const fade = k > 0 ? interpolate(f, [steps[k].at, steps[k].at + 5], [0, 1], clamp) : 1;
    return (
      <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden" }}>
        {k > 0 && <Img src={cap(steps[k - 1].src)} style={{ position: "absolute", width: CW, height: CH }} />}
        <Img src={cap(steps[k].src)} style={{ position: "absolute", width: CW, height: CH, opacity: fade }} />
        <Tap f={f} at={16} x={880} y={1700} />
        <Tap f={f} at={34} x={330} y={1900} />
        <Tap f={f} at={52} x={603} y={1139} />
        <Tap f={f} at={84} x={603} y={2393} />
      </div>
    );
  }
  if (part === "place") return <HomeBase filled={<Landing f={f} fps={fps} widget={spec.final.widget} />} />;
  return null;
};

/** Vertical focus of the full-screen framing per part (0 = top of the capture). */
const FOCUS: Record<PartKey, number> = { hook: 0.42, open: 0.42, scan: 0.5, custom: 0.56, place: 0.42, end: 0.5 };

const FullFrame: React.FC<{ part: PartKey; f: number; spec: SpecJ }> = ({ part, f, spec }) => {
  const s = W / CW;
  const sh = CH * s;
  const top = Math.min(0, Math.max(H - sh, H / 2 - sh * FOCUS[part]));
  const punch = interpolate(f, [0, 6], [1.05, 1], { ...clamp, easing: out });
  return (
    <AbsoluteFill style={{ background: "#000", overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, top, width: CW, height: CH, transformOrigin: "0 0", transform: `scale(${s * punch})` }}>
        <AppScreen part={part} f={f} spec={spec} />
      </div>
    </AbsoluteFill>
  );
};

const PH = 1400;
const PS = PH / CH;
const PW = CW * PS;
const Phone: React.FC<{ part: PartKey; f: number; spec: SpecJ; y?: number }> = ({ part, f, spec, y = 300 }) => (
  <div
    style={{
      position: "absolute",
      left: (W - PW) / 2 - 12,
      top: y - 12,
      width: PW + 24,
      height: PH + 24,
      borderRadius: 96,
      background: "#0E0F12",
      boxShadow: "0 50px 90px rgba(0,0,0,0.5), 0 0 0 3px rgba(255,255,255,0.12)",
    }}
  >
    <div style={{ position: "absolute", left: 12, top: 12, width: PW, height: PH, borderRadius: 84, overflow: "hidden", background: "#000" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, transformOrigin: "0 0", transform: `scale(${PS})` }}>
        <AppScreen part={part} f={f} spec={spec} />
      </div>
    </div>
  </div>
);

const STEPS: { key: PartKey; label: string }[] = [
  { key: "open", label: "Open" },
  { key: "scan", label: "Scan" },
  { key: "custom", label: "Customize" },
  { key: "place", label: "Place" },
];

const Steps: React.FC<{ part: PartKey }> = ({ part }) => {
  const idx = STEPS.findIndex((s) => s.key === part);
  return (
    <div style={{ position: "absolute", top: 150, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 14 }}>
      {STEPS.map((s, i) => (
        <div
          key={s.key}
          style={{
            fontFamily: FONT,
            fontWeight: 700,
            fontSize: 34,
            padding: "12px 22px",
            borderRadius: 30,
            color: i === idx ? "#07101C" : "rgba(255,255,255,0.7)",
            background: i === idx ? "#fff" : "rgba(255,255,255,0.12)",
          }}
        >
          {i + 1} {s.label}
        </div>
      ))}
    </div>
  );
};

const PhoneFrame: React.FC<{ part: PartKey; f: number; spec: SpecJ }> = ({ part, f, spec }) => {
  const { fps } = useVideoConfig();
  const rise = part === "hook" ? spring({ frame: f - 10, fps, config: { damping: 16, stiffness: 90 } }) : 1;
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #07101C 0%, #1D4E9E 100%)" }}>
      {part === "hook" ? (
        <>
          <div style={{ position: "absolute", top: 260 - (1 - rise) * 0, left: 60, right: 60, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 100, lineHeight: 1.05, color: "#fff", fontVariationSettings: `"opsz" 32`, opacity: interpolate(f, [0, 8], [0, 1], clamp) }}>
            {spec.captions.hook}
          </div>
          <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, transform: `translateY(${(1 - rise) * 1200 + 260}px)` }}>
            <Phone part="hook" f={f} spec={spec} />
          </div>
        </>
      ) : (
        <>
          <Steps part={part} />
          <Phone part={part} f={f} spec={spec} />
        </>
      )}
    </AbsoluteFill>
  );
};

const PhotoFrame: React.FC<{ part: PartKey; f: number; spec: SpecJ }> = ({ part, f, spec }) => {
  const { fps } = useVideoConfig();
  const onPlate = part === "hook" || part === "open" || part === "scan";
  if (part === "hook") {
    const z = interpolate(f, [0, 60], [1.12, 1.0], clamp);
    return (
      <AbsoluteFill style={{ background: "#000", overflow: "hidden" }}>
        <Img src={staticFile(PHOTO)} style={{ position: "absolute", left: -420, top: 0, width: 1920, height: H, objectFit: "cover", transform: `scale(${z})` }} />
      </AbsoluteFill>
    );
  }
  const rise = part === "open" ? spring({ frame: f, fps, config: { damping: 15, stiffness: 110 } }) : 1;
  return (
    <AbsoluteFill style={{ background: "#000", overflow: "hidden" }}>
      {onPlate ? (
        <Img src={staticFile(PHOTO)} style={{ position: "absolute", left: -420, top: 0, width: 1920, height: H, objectFit: "cover", filter: "blur(30px) brightness(0.6)" }} />
      ) : (
        <Img src={staticFile("kit/wall-jade.png")} style={{ position: "absolute", left: -60, top: -60, width: W + 120, height: H + 120, objectFit: "cover", filter: "blur(30px) brightness(0.8)" }} />
      )}
      <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, transform: `translateY(${(1 - rise) * 1500}px)` }}>
        <Phone part={part} f={f} spec={spec} y={330} />
      </div>
    </AbsoluteFill>
  );
};

const End: React.FC = () => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 14, stiffness: 150 } });
  const b = interpolate(f, [10, 20], [0, 1], clamp);
  const t = (size: number, weight: number, color: string): React.CSSProperties => ({ fontFamily: FONT, fontWeight: weight, fontSize: size, color, textAlign: "center" });
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #07101C 0%, #1D4E9E 100%)" }}>
      <Img src={staticFile("store/ardane-icon.png")} style={{ position: "absolute", top: 560, left: W / 2 - 130, width: 260, height: 260, borderRadius: 58, transform: `scale(${0.8 + 0.2 * a})`, opacity: a, boxShadow: "0 30px 60px rgba(0,0,0,0.4)" }} />
      <div style={{ position: "absolute", top: 880, left: 0, right: 0, ...t(84, 700, "#fff"), letterSpacing: 6, opacity: a }}>ARDANE</div>
      <div style={{ position: "absolute", top: 1000, left: 0, right: 0, ...t(52, 500, "#BED0E6"), opacity: b }}>Your whole life. One place.</div>
      <div style={{ position: "absolute", top: 1150, left: 0, right: 0, ...t(40, 600, "#fff"), opacity: b }}>Coming soon to the App Store</div>
    </AbsoluteFill>
  );
};

const PartView: React.FC<{ part: PartKey; spec: SpecJ }> = ({ part, spec }) => {
  const f = useCurrentFrame();
  if (part === "end") return <End />;
  const line = spec.captions[part];
  const premium = part === "custom" || part === "place";
  return (
    <AbsoluteFill>
      {spec.framing === "full" && <FullFrame part={part} f={f} spec={spec} />}
      {spec.framing === "phone" && <PhoneFrame part={part} f={f} spec={spec} />}
      {spec.framing === "photo" && <PhotoFrame part={part} f={f} spec={spec} />}
      {line && spec.framing !== "phone" && <Caption text={line} y={part === "hook" && spec.framing === "photo" ? 700 : 120} at={3} size={part === "hook" ? 68 : 58} />}
      {premium && <PremiumTag y={spec.framing === "full" ? 1500 : 1748} />}
    </AbsoluteFill>
  );
};

export const TemplateJ: React.FC<{ spec: SpecJ }> = ({ spec }) => {
  const { durationInFrames } = useVideoConfig();
  const tl = timelineJ(spec);
  const voAt = tl.map((p) => {
    const start = p.from + Math.round(LEAD * FPS);
    return { start, end: start + Math.round((spec.voLen[spec.vo[p.key]] ?? 0) * FPS) };
  });
  const duck = (fr: number) => Math.max(0, ...voAt.map((v) => interpolate(fr, [v.start - 8, v.start - 2, v.end + 2, v.end + 10], [0, 1, 1, 0], clamp)));
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {tl.map((p) => (
        <Sequence key={p.key} from={p.from} durationInFrames={p.frames}>
          <PartView part={p.key} spec={spec} />
          <Sequence from={Math.round(LEAD * FPS)}>
            <Audio src={staticFile(`tiktok/vo/${spec.id}-${spec.vo[p.key]}.wav`)} volume={1} />
          </Sequence>
        </Sequence>
      ))}
      <Audio
        src={staticFile(spec.music ?? "lifestyle/music.wav")}
        volume={(fr) => interpolate(fr, [0, 6, durationInFrames - 20, durationInFrames], [0, 1, 1, 0], clamp) * (0.6 - 0.38 * duck(fr))}
      />
    </AbsoluteFill>
  );
};
