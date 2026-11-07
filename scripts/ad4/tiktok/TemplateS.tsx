// Template S « étudiant » (2026-11-06), school-notebook style: a student photographs the paper class schedule, Ardane reads
// it on the iPhone (Planning › Import my schedule), every class lands in the week, then the Home Screen pages of a student
// (weekly schedule; next class, next exam, apps). Lined paper, tape, highlighter titles, blue-pen doodles.
import React from "react";
import { AbsoluteFill, Audio, Img, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { cap, clamp, FONT, FPS, PremiumTag, W } from "./lib";
import { CH, CW, Tap } from "./journey/Screens";
import { Doodle, ImportFlow, Marker, Notebook, PaperSchedule, Tape } from "./journey/School";
import { BuilderFlow, builderEnd, BuilderPlan, PushIn, StudioChoice, StudioStep } from "./journey/Create";
import { HomeBase, Landing, OCEAN } from "./journey/Screens";

export type PartS = "hook" | "snap" | "import" | "week" | "create" | "home" | "end";
export type SpecS = {
  id: string;
  template: "S";
  music?: string;
  captions: Record<Exclude<PartS, "end">, string[]>;
  vo: Record<PartS, string>;
  voLen: Record<string, number>;
};

const LEAD = 0.25;
const ORDER: PartS[] = ["hook", "snap", "import", "week", "create", "home", "end"];

/** The mechanic of every ad (2026-11-06): Create tab → Planning · studies → Next class + Next exam (Medium) → the Studio
 * themes (the real builder preview of that widget; its Midnight and Ocean versions are drawn with the colours of those
 * themes, taken from the real exports macros-m-preset-*) → the widget lands on an ocean-blue Home Screen. */
const STU_BUILDER: BuilderPlan = { space: "student", tapTile: [594, 2145], medium: [600, 726], tapCustomize: [603, 2394] };
const STU_END = builderEnd(STU_BUILDER);
const STU_THEMES: StudioChoice[] = [
  { at: 0, w: "x-student-combo", name: "Light", tag: "Free" },
  { at: 18, w: "x-student-combo-midnight", name: "Midnight", tag: "Premium" },
  { at: 36, w: "x-student-combo-ocean", name: "Ocean", tag: "Premium" },
];
const STU_SAVE = 56;
const STU_FINAL = "x-student-combo-ocean";
const MIN: Record<PartS, number> = { hook: 2.6, snap: 2.0, import: 5.6, week: 2.6, create: (STU_END + STU_SAVE + 10) / FPS, home: 3.4, end: 2.8 };
const TAIL: Record<PartS, number> = { hook: 0.3, snap: 0.3, import: 0.3, week: 0.4, create: 0.3, home: 0.5, end: 0.6 };

export const timelineS = (s: SpecS) => {
  let from = 0;
  return ORDER.map((key) => {
    const d = Math.round(Math.max(MIN[key], (s.voLen[s.vo[key]] ?? 0) + LEAD + TAIL[key]) * FPS);
    const r = { key, from, frames: d };
    from += d;
    return r;
  });
};
export const lengthS = (s: SpecS) => timelineS(s).reduce((a, p) => a + p.frames, 0);

const PH = 1300;
const PS = PH / CH;
const PW = CW * PS;
const PX = (W - PW) / 2;
const PY = 400;

/** The phone lying on the notebook page, held by two pieces of tape. */
const Phone: React.FC<{ children: React.ReactNode; f: number; enter?: boolean }> = ({ children, f, enter }) => {
  const { fps } = useVideoConfig();
  const s = enter ? spring({ frame: f, fps, config: { damping: 15, stiffness: 120 } }) : 1;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: 1920, transform: `translateY(${(1 - s) * 1400}px) rotate(-2deg)`, transformOrigin: "540px 1050px" }}>
      <div style={{ position: "absolute", left: PX - 12, top: PY - 12, width: PW + 24, height: PH + 24, borderRadius: 92, background: "#111214", boxShadow: "0 30px 60px rgba(40,30,10,0.35)" }}>
        <div style={{ position: "absolute", left: 12, top: 12, width: PW, height: PH, borderRadius: 80, overflow: "hidden", background: "#000" }}>
          <div style={{ position: "absolute", width: CW, height: CH, transformOrigin: "0 0", transform: `scale(${PS})` }}>{children}</div>
        </div>
      </div>
      <Tape x={PX - 70} y={PY + 40} rot={-38} />
      <Tape x={PX + PW - 120} y={PY + 40} rot={36} />
    </div>
  );
};

const Corners: React.FC<{ f: number }> = ({ f }) => {
  const o = interpolate(f, [0, 14], [160, 0], { ...clamp, easing: (t) => 1 - Math.pow(1 - t, 3) });
  const box = { x: 110, y: 470, w: 860, h: 1000 };
  const c = (dx: number, dy: number) => ({
    position: "absolute" as const,
    left: dx < 0 ? box.x - o : box.x + box.w - 110 + o,
    top: dy < 0 ? box.y - o : box.y + box.h - 110 + o,
    width: 110,
    height: 110,
    borderColor: "#111",
    borderStyle: "solid",
    borderWidth: 0,
    [dx < 0 ? "borderLeftWidth" : "borderRightWidth"]: 14,
    [dy < 0 ? "borderTopWidth" : "borderBottomWidth"]: 14,
    borderRadius: 30,
  });
  return (
    <>
      <div style={c(-1, -1)} />
      <div style={c(1, -1)} />
      <div style={c(-1, 1)} />
      <div style={c(1, 1)} />
    </>
  );
};

const Sheet: React.FC<{ z?: number }> = ({ z = 1 }) => (
  <div style={{ position: "absolute", left: 110, top: 520, transform: `rotate(1.6deg) scale(${z})`, transformOrigin: "430px 480px" }}>
    <PaperSchedule w={860} />
    <Tape x={330} y={-34} rot={-3} w={200} />
  </div>
);

const Titles: React.FC<{ lines: string[]; f: number }> = ({ lines, f }) => (
  <>
    {lines.map((l, i) => (
      <Marker key={l} text={l} f={f} at={3 + i * 7} y={130 + i * 118} size={84} rot={i % 2 ? 1.5 : -2} />
    ))}
  </>
);

const PartView: React.FC<{ part: PartS; spec: SpecS }> = ({ part, spec }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  if (part === "end") {
    const a = spring({ frame: f, fps, config: { damping: 14, stiffness: 150 } });
    return (
      <AbsoluteFill>
        <Notebook />
        <div style={{ position: "absolute", left: W / 2 - 140, top: 470, transform: `rotate(-4deg) scale(${0.8 + 0.2 * a})`, opacity: a }}>
          <Img src={staticFile("store/ardane-icon.png")} style={{ width: 280, height: 280, borderRadius: 62, boxShadow: "0 20px 40px rgba(0,0,0,0.25)" }} />
          <Tape x={40} y={-26} rot={-6} w={200} />
        </div>
        <div style={{ position: "absolute", top: 830, left: 0, right: 0, textAlign: "center", fontFamily: FONT, fontWeight: 900, fontSize: 96, letterSpacing: 6, color: "#10151C", opacity: a }}>ARDANE</div>
        <Marker text="Your whole life. One place." f={f} at={8} y={980} size={64} rot={-1.5} />
        <div style={{ position: "absolute", top: 1140, left: 0, right: 0, textAlign: "center", fontFamily: FONT, fontWeight: 700, fontSize: 44, color: "#2747A8", opacity: interpolate(f, [14, 22], [0, 1], clamp) }}>Coming soon to the App Store</div>
      </AbsoluteFill>
    );
  }
  return (
    <AbsoluteFill>
      <Notebook />
      {part === "hook" && <Sheet />}
      {part === "snap" && (
        <>
          <Sheet z={interpolate(f, [0, 20], [1, 1.04], clamp)} />
          <Corners f={f} />
          <AbsoluteFill style={{ background: "#fff", opacity: interpolate(f, [16, 19, 30], [0, 0.9, 0], clamp) }} />
        </>
      )}
      {part === "import" && (
        <Phone f={f} enter>
          {f < 22 ? (
            <>
              <Img src={cap("app-planning-s04")} style={{ position: "absolute", width: CW, height: CH }} />
              <Tap f={f} at={14} x={450} y={1755} />
            </>
          ) : (
            <ImportFlow f={f - 22} fps={fps} />
          )}
        </Phone>
      )}
      {part === "week" && (
        <>
          <Phone f={f}>
            <Img src={cap("app-planning-week")} style={{ position: "absolute", width: CW, height: CH }} />
          </Phone>
          <Doodle f={f} at={14} d="M 880 1380 l 40 50 l 90 -120" width={14} />
        </>
      )}
      {part === "create" && (
        <Phone f={f}>
          {f < STU_END ? (
            <BuilderFlow f={f} plan={STU_BUILDER} />
          ) : (
            <PushIn f={f - STU_END} under={<BuilderFlow f={STU_END - 1} plan={STU_BUILDER} />}>
              <StudioStep f={f - STU_END} base="studio-theme" choices={STU_THEMES} saveAt={STU_SAVE} />
            </PushIn>
          )}
        </Phone>
      )}
      {part === "home" && (
        <>
          <Phone f={f}>
            <HomeBase theme={OCEAN} filled={<Landing f={f} fps={fps} widget={STU_FINAL} glow="64,214,232" />} />
          </Phone>
          {/* circles the Next exam half of the widget, in cyan (Planning) so it reads on the ocean wallpaper */}
          <Doodle f={f} at={44} dur={14} d="M 730 455 C 930 455 935 800 705 800 C 420 800 400 465 750 462" width={12} color="#2BD4EA" />
        </>
      )}
      <Titles lines={spec.captions[part]} f={f} />
      {(part === "import" || part === "create") && <PremiumTag y={1760} />}
    </AbsoluteFill>
  );
};

export const TemplateS: React.FC<{ spec: SpecS }> = ({ spec }) => {
  const { durationInFrames } = useVideoConfig();
  const tl = timelineS(spec);
  const voAt = tl.map((p) => {
    const start = p.from + Math.round(LEAD * FPS);
    return { start, end: start + Math.round((spec.voLen[spec.vo[p.key]] ?? 0) * FPS) };
  });
  const duck = (fr: number) => Math.max(0, ...voAt.map((v) => interpolate(fr, [v.start - 8, v.start - 2, v.end + 2, v.end + 10], [0, 1, 1, 0], clamp)));
  return (
    <AbsoluteFill style={{ background: "#FBF8F0" }}>
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
