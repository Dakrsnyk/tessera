// Template W « séance de musculation » (2026-11-06), framing of proposal 2 (phone on the Ardane gradient, numbered steps):
// build the workout from the library, log a set, create the medium workout widget and place it on the Home Screen,
// then the Live Activity on the Lock Screen (rest timer, « Set done » without unlocking).
import React from "react";
import { AbsoluteFill, Audio, Img, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { clamp, FONT, FPS, H, PremiumTag, W } from "./lib";
import { CH, CW } from "./journey/Screens";
import { BuildScreen, FitnessHome, LockScreen, TrainScreen, WidgetScreen } from "./journey/Workout";

export type PartW = "hook" | "build" | "train" | "widget" | "lock" | "end";
export type SpecW = {
  id: string;
  template: "W";
  music?: string;
  hook: string;
  steps: Record<"build" | "train" | "widget" | "lock", string>;
  vo: Record<PartW, string>;
  voLen: Record<string, number>;
};

const LEAD = 0.25;
const ORDER: PartW[] = ["hook", "build", "train", "widget", "lock", "end"];
const MIN: Record<PartW, number> = { hook: 2.4, build: 4.9, train: 2.4, widget: 4.6, lock: 3.6, end: 2.8 };
const TAIL: Record<PartW, number> = { hook: 0.3, build: 0.3, train: 0.3, widget: 0.4, lock: 0.5, end: 0.6 };
/** Plans that show Premium: the full exercise library (and its demos), the Premium widget styles. */
const PREMIUM: PartW[] = ["build", "widget"];

export const timelineW = (s: SpecW) => {
  let from = 0;
  return ORDER.map((key) => {
    const d = Math.round(Math.max(MIN[key], (s.voLen[s.vo[key]] ?? 0) + LEAD + TAIL[key]) * FPS);
    const r = { key, from, frames: d };
    from += d;
    return r;
  });
};
export const lengthW = (s: SpecW) => timelineW(s).reduce((a, p) => a + p.frames, 0);

const PH = 1400;
const PS = PH / CH;
const PW = CW * PS;

const Phone: React.FC<{ children: React.ReactNode; y?: number }> = ({ children, y = 300 }) => (
  <div style={{ position: "absolute", left: (W - PW) / 2 - 12, top: y - 12, width: PW + 24, height: PH + 24, borderRadius: 96, background: "#0E0F12", boxShadow: "0 50px 90px rgba(0,0,0,0.5), 0 0 0 3px rgba(255,255,255,0.12)" }}>
    <div style={{ position: "absolute", left: 12, top: 12, width: PW, height: PH, borderRadius: 84, overflow: "hidden", background: "#000" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, transformOrigin: "0 0", transform: `scale(${PS})` }}>{children}</div>
    </div>
  </div>
);

const Steps: React.FC<{ spec: SpecW; part: PartW }> = ({ spec, part }) => {
  const keys = ["build", "train", "widget", "lock"] as const;
  return (
    <div style={{ position: "absolute", top: 150, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 12 }}>
      {keys.map((k, i) => (
        <div
          key={k}
          style={{
            fontFamily: FONT,
            fontWeight: 700,
            fontSize: 32,
            padding: "12px 20px",
            borderRadius: 30,
            whiteSpace: "nowrap",
            color: k === part ? "#07101C" : "rgba(255,255,255,0.7)",
            background: k === part ? "#fff" : "rgba(255,255,255,0.12)",
          }}
        >
          {i + 1} {spec.steps[k]}
        </div>
      ))}
    </div>
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

const PartView: React.FC<{ part: PartW; spec: SpecW }> = ({ part, spec }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  if (part === "end") return <End />;
  // red gradient behind the phone (asked on 2026-11-06), from the Fitness red of the app (#E5484D, « Set done »)
  const bg = <AbsoluteFill style={{ background: "linear-gradient(180deg, #1A0406 0%, #6E1116 55%, #C2333A 100%)" }} />;
  if (part === "hook") {
    const rise = spring({ frame: f - 10, fps, config: { damping: 16, stiffness: 90 } });
    return (
      <AbsoluteFill>
        {bg}
        <div style={{ position: "absolute", top: 250, left: 60, right: 60, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 100, lineHeight: 1.05, color: "#fff", fontVariationSettings: `"opsz" 32`, opacity: interpolate(f, [0, 8], [0, 1], clamp) }}>
          {spec.hook}
        </div>
        <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, transform: `translateY(${(1 - rise) * 1200 + 300}px)` }}>
          <Phone>
            <FitnessHome />
          </Phone>
        </div>
      </AbsoluteFill>
    );
  }
  return (
    <AbsoluteFill>
      {bg}
      <Steps spec={spec} part={part} />
      <Phone>
        {part === "build" && <BuildScreen f={f} />}
        {part === "train" && <TrainScreen f={f} />}
        {part === "widget" && <WidgetScreen f={f} fps={fps} />}
        {/* « Tap Set done » comes at about 58 % of the lock line */}
        {part === "lock" && <LockScreen f={f} done={Math.round((LEAD + 0.58 * (spec.voLen[spec.vo.lock] ?? 1.5)) * FPS)} />}
      </Phone>
      {PREMIUM.includes(part) && <PremiumTag y={1748} />}
    </AbsoluteFill>
  );
};

export const TemplateW: React.FC<{ spec: SpecW }> = ({ spec }) => {
  const { durationInFrames } = useVideoConfig();
  const tl = timelineW(spec);
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
