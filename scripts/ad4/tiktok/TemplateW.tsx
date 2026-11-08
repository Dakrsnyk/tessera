// Template W « séance de musculation » (2026-11-06), framing of proposal 2 (phone on the Ardane gradient, numbered steps):
// build the workout from the library, log a set, create the medium workout widget and place it on the Home Screen,
// then the Live Activity on the Lock Screen (rest timer, « Set done » without unlocking).
import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { clamp, FONT, FPS, H, PremiumTag, W } from "./lib";
import { CH, CW } from "./journey/Screens";
import { BuildScreen, FitnessHome, LockScreen, TrainScreen, WIDGET_FRAMES, WidgetScreen } from "./journey/Workout";
import { SKINS, SkinId } from "./skins";

export type PartW = "hook" | "build" | "train" | "widget" | "lock" | "end";
export type SpecW = {
  id: string;
  template: "W";
  music?: string;
  hook: string;
  /** The hook as a question, then its answer (« Meet Ardane. », asked on 2026-11-08): shown and said right after the question. */
  answer?: { text: string; vo: string };
  /** Visual world (skins.tsx); « gym » = Fitness red / black / grey. */
  skin?: SkinId;
  steps: Record<"build" | "train" | "widget" | "lock", string>;
  vo: Record<PartW, string>;
  voLen: Record<string, number>;
};

const LEAD = 0.25;
const ORDER: PartW[] = ["hook", "build", "train", "widget", "lock", "end"];
const MIN: Record<PartW, number> = { hook: 2.4, build: 4.9, train: 2.4, widget: WIDGET_FRAMES / FPS, lock: 3.6, end: 2.8 };
const TAIL: Record<PartW, number> = { hook: 0.3, build: 0.3, train: 0.3, widget: 0.4, lock: 0.5, end: 0.6 };
/** Plans that show Premium: the full exercise library (and its demos), the Premium widget styles. */
const PREMIUM: PartW[] = ["build", "widget"];

/** With an answer, the question starts almost at once and the answer follows a short beat later (2026-11-08). */
const HOOK_LEAD = 0.15;
const HOOK_GAP = 0.15;

/** The voice lines of a part and when each starts (s from the part's start). */
const voicesW = (s: SpecW, key: PartW) =>
  key === "hook" && s.answer
    ? [
        { vo: s.vo.hook, at: HOOK_LEAD },
        { vo: s.answer.vo, at: HOOK_LEAD + (s.voLen[s.vo.hook] ?? 0) + HOOK_GAP },
      ]
    : [{ vo: s.vo[key], at: LEAD }];

export const timelineW = (s: SpecW) => {
  let from = 0;
  return ORDER.map((key) => {
    const last = voicesW(s, key).slice(-1)[0];
    const d = Math.round(Math.max(MIN[key], last.at + (s.voLen[last.vo] ?? 0) + TAIL[key]) * FPS);
    const r = { key, from, frames: d };
    from += d;
    return r;
  });
};
export const lengthW = (s: SpecW) => timelineW(s).reduce((a, p) => a + p.frames, 0);

const PH = 1400;
const PS = PH / CH;
const PW = CW * PS;

const Phone: React.FC<{ children: React.ReactNode; y?: number; shadow?: string }> = ({ children, y = 300, shadow = "0 50px 90px rgba(0,0,0,0.5), 0 0 0 3px rgba(255,255,255,0.12)" }) => (
  <div style={{ position: "absolute", left: (W - PW) / 2 - 12, top: y - 12, width: PW + 24, height: PH + 24, borderRadius: 96, background: "#0E0F12", boxShadow: shadow }}>
    <div style={{ position: "absolute", left: 12, top: 12, width: PW, height: PH, borderRadius: 84, overflow: "hidden", background: "#000" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, transformOrigin: "0 0", transform: `scale(${PS})` }}>{children}</div>
    </div>
  </div>
);

const Steps: React.FC<{ spec: SpecW; part: PartW }> = ({ spec, part }) => {
  const c = SKINS[spec.skin ?? "brand"].chip;
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
            borderRadius: c.radius,
            textTransform: c.upper ? "uppercase" : "none",
            whiteSpace: "nowrap",
            color: k === part ? c.onText : c.offText,
            background: k === part ? c.on : c.off,
          }}
        >
          {i + 1} {spec.steps[k]}
        </div>
      ))}
    </div>
  );
};

const PartView: React.FC<{ part: PartW; spec: SpecW }> = ({ part, spec }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const skin = SKINS[spec.skin ?? "brand"];
  if (part === "end") return <skin.End />;
  const bg = <skin.Background />;
  if (part === "hook") {
    // with an answer: the question alone, word by word with the voice, then « Meet Ardane » and the phone rises under it
    const [q, a] = voicesW(spec, "hook");
    const answerAt = spec.answer && a ? Math.round(a.at * FPS) - 2 : null;
    const rise = spring({ frame: f - (answerAt ?? 10), fps, config: { damping: 16, stiffness: 90 } });
    return (
      <AbsoluteFill>
        {bg}
        <skin.Title text={spec.hook} f={f} reveal={answerAt !== null ? Math.round((q.at + 0.8 * (spec.voLen[q.vo] ?? 1)) * FPS) : undefined} />
        {answerAt !== null && skin.Answer && spec.answer && f >= answerAt && <skin.Answer text={spec.answer.text} f={f - answerAt} y={590} />}
        <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, transform: `translateY(${(1 - rise) * 1200 + (answerAt !== null ? 520 : 300)}px)` }}>
          <Phone shadow={skin.phoneShadow}>
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
      <Phone shadow={skin.phoneShadow}>
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
  const voAt = tl.flatMap((p) =>
    voicesW(spec, p.key).map((v) => {
      const start = p.from + Math.round(v.at * FPS);
      return { start, end: start + Math.round((spec.voLen[v.vo] ?? 0) * FPS) };
    }),
  );
  const duck = (fr: number) => Math.max(0, ...voAt.map((v) => interpolate(fr, [v.start - 8, v.start - 2, v.end + 2, v.end + 10], [0, 1, 1, 0], clamp)));
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {tl.map((p) => (
        <Sequence key={p.key} from={p.from} durationInFrames={p.frames}>
          <PartView part={p.key} spec={spec} />
          {voicesW(spec, p.key).map((v) => (
            <Sequence key={v.vo} from={Math.round(v.at * FPS)}>
              <Audio src={staticFile(`tiktok/vo/${spec.id}-${v.vo}.wav`)} volume={1} />
            </Sequence>
          ))}
        </Sequence>
      ))}
      <Audio
        src={staticFile(spec.music ?? "lifestyle/music.wav")}
        volume={(fr) => interpolate(fr, [0, 6, durationInFrames - 20, durationInFrames], [0, 1, 1, 0], clamp) * (0.6 - 0.38 * duck(fr))}
      />
    </AbsoluteFill>
  );
};
