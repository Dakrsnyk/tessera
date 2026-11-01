import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, getStaticFiles, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, INTER, W } from "../lib/brand";
import { FormatFrame } from "../films/FormatFrame";
import { FormatProps } from "../films/Formatted";
import { useT } from "../lib/i18n";
import { TimeRemap } from "../lib/time";
import { Close, LOGO } from "../scenes/Close";
import { LOGO_GAP } from "../components/ArdaneLogo";
import { Essentials } from "../scenes/Essentials";
import { Fitness } from "../scenes/Fitness";
import { LockScreen } from "../scenes/LockScreen";
import { Nutrition } from "../scenes/Nutrition";
import { Opening } from "../scenes/Opening";
import { Studio } from "../scenes/Studio";
import { Universes } from "../scenes/Universes";
import { Burst } from "./Burst";
import { KineticLine } from "./fx";
import { Hook } from "./Hook";
import T from "./timing.json";

export const V3_LENGTH = T.length;
const AUDIO = "audio/en/mix-v3main.wav";

type Seg = {
  from: number;
  length: number;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  El: React.FC<any>;
  input?: number[];
  output?: number[];
  props?: Record<string, unknown>;
  punch?: boolean;
  end?: boolean;
};

const SEGS: Seg[] = [
  { from: 0, length: 444, El: Hook },
  // Reveal: the phone turns edge-on → frontal (fast), then the layers come apart.
  { from: 444, length: 138, El: Opening, input: [0, 138], output: [0, 359], props: { lit: true, words: false, wake: 30 } },
  { from: 582, length: 258, El: Universes, input: [0, 258], output: [0, 170], props: { words: false } },
  // Personalise: universes change on the beat, then the Studio.
  { from: 840, length: 360, El: Universes, input: [0, 270, 300, 360], output: [170, 420, 480, 560], props: { words: false } },
  { from: 1200, length: 360, El: Studio, props: { words: false, counts: false } },
  // Universes of the app.
  { from: 1560, length: 156, El: Burst },
  { from: 1716, length: 270, El: Nutrition, input: [0, 36, 44, 100, 190, 212, 226, 250, 270], output: [0, 90, 110, 180, 300, 330, 366, 420, 520], punch: true },
  { from: 1986, length: 90, El: Fitness, input: [0, 90], output: [0, 90], punch: true },
  { from: 2076, length: 70, El: LockScreen, input: [0, 70], output: [100, 170], punch: true },
  { from: 2146, length: 66, El: Essentials, input: [0, 66], output: [16, 82], punch: true },
  { from: 2212, length: 68, El: Essentials, input: [0, 68], output: [240, 308], punch: true },
  // End card.
  { from: 2280, length: 420, El: Close, input: [0, 84, 120, 420], output: [0, 60, 96, 299], props: { tagline: "Your whole life. One place." }, end: true },
];

const Punch: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const f = useCurrentFrame();
  const s = interpolate(f, [0, 14], [1.07, 1], { ...clamp, easing: ease.split });
  return <AbsoluteFill style={{ transform: `scale(${s})`, transformOrigin: "50% 50%" }}>{children}</AbsoluteFill>;
};

/** A cut carried by the seam: a line flashes at the axis, a soft white flash, across the change. */
const CutFx: React.FC = () => {
  const f = useCurrentFrame() - 2;
  const i = interpolate(f, [-2, 0, 18], [0, 1, 0], clamp);
  const w = interpolate(f, [0, 5], [0.26, 0], clamp);
  return (
    <>
      {f >= 0 && <AbsoluteFill style={{ background: "#fff", opacity: w }} />}
      <Seam x={AXIS} top={150} height={H - 300} intensity={i} />
    </>
  );
};

/** The end card breathes: a slow push, the gap of the A shimmering, calm for the last 0.3 s. */
const Breathe: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const f = useCurrentFrame();
  const calm = interpolate(f, [384, 402], [1, 0], clamp);
  const push = 1 + 0.06 * interpolate(f, [60, 402], [0, 1], { ...clamp, easing: Easing.bezier(0.25, 0.1, 0.25, 1) });
  const top = LOGO.cy - LOGO.size / 2 + LOGO_GAP.top * LOGO.size;
  const h = (LOGO_GAP.bottom - LOGO_GAP.top) * LOGO.size;
  const shimmer = (0.18 + 0.16 * Math.sin(f * 0.11) + 0.1 * Math.sin(f * 0.37)) * calm * interpolate(f, [120, 170], [0, 1], clamp);
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: `${LOGO.cx}px ${LOGO.cy + 200}px` }}>{children}</AbsoluteFill>
      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: `${LOGO.cx}px ${LOGO.cy + 200}px` }}>
        <Seam x={AXIS} top={top - 10} height={h + 20} intensity={Math.max(0, shimmer)} spread={0.7} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const PremiumPill: React.FC<{ f: number }> = ({ f }) => {
  const t = useT();
  const [a, b] = T.personalise.premiumPill;
  const p = interpolate(f, [a, a + 12, b - 10, b], [0, 1, 1, 0], { ...clamp, easing: ease.split });
  return (
    <div style={{ position: "absolute", left: 0, top: 84, width: W, display: "flex", justifyContent: "center", opacity: p, transform: `translateY(${(1 - p) * 30}px) scale(${0.9 + 0.1 * p})` }}>
      <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 40, color: C.type1, padding: "0 44px", height: 96, borderRadius: 48, display: "flex", alignItems: "center", border: "2px solid rgba(214,233,250,0.7)", background: "rgba(7,16,28,0.8)", boxShadow: "0 0 50px rgba(78,155,224,0.5)" }}>
        {t("common.withPremium")}
      </div>
    </div>
  );
};

const Texts: React.FC = () => {
  const f = useCurrentFrame();
  const t = useT();
  const V = T.voice;
  const veil = interpolate(f, [448, 468, 740, 760], [0, 1, 1, 0], clamp);
  const meetOut = interpolate(f, [V.everything - 18, V.everything - 4], [0, 1], clamp);
  const evOut = interpolate(f, [740, 760], [0, 1], clamp);
  const wOut = interpolate(f, [1010, 1032], [0, 1], clamp);
  const demo = interpolate(f, [460, 480, 2250, 2270], [0, 1, 1, 0], clamp);
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: "linear-gradient(to bottom, transparent 54%, rgba(0,0,0,0.78) 70%, rgba(0,0,0,0.9) 100%)", opacity: veil * 0.9 }} />
      {f >= V.meet && f < V.everything && <KineticLine words={[{ t: t("v3.meet"), at: V.meet }]} frame={f} top={1560} size={128} out={meetOut} />}
      {f >= V.everything - 4 && f < 770 && (
        <>
          <KineticLine words={[{ t: t("v3.every"), at: V.everything }]} frame={f} top={1500} size={84} out={evOut} weight={600} />
          <KineticLine words={[{ t: t("v3.one"), at: V.everything + 24, hi: true }]} frame={f} top={1610} size={126} out={evOut} />
        </>
      )}
      {f >= V.widgets && f < 1040 && (
        <>
          <KineticLine words={[{ t: t("v3.widgets"), at: V.widgets }]} frame={f} top={1630} size={110} out={wOut} />
          <KineticLine words={[{ t: t("v3.way"), at: 900, hi: true }]} frame={f} top={1750} size={110} out={wOut} />
        </>
      )}
      {f >= T.personalise.premiumPill[0] && f < T.personalise.premiumPill[1] && <PremiumPill f={f} />}
      <div style={{ position: "absolute", left: 0, top: 1862, width: W, textAlign: "center", fontFamily: INTER, fontWeight: 600, fontSize: 22, letterSpacing: "0.16em", textTransform: "uppercase", color: C.type3, opacity: demo }}>
        {t("v3.demo")}
      </div>
    </AbsoluteFill>
  );
};

export const FilmMainV3: React.FC = () => {
  let hasAudio = false;
  try {
    hasAudio = getStaticFiles().some((s) => s.name === AUDIO);
  } catch {
    hasAudio = false;
  }
  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      {SEGS.map(({ from, length, El, input, output, props, punch, end }) => {
        const inner = <El audio={false} {...(props ?? {})} />;
        const timed = input && output ? <TimeRemap input={input} output={output}>{inner}</TimeRemap> : inner;
        return (
          <Sequence key={from} from={from} durationInFrames={length} layout="absolute-fill">
            {punch ? <Punch>{timed}</Punch> : end ? <Breathe>{timed}</Breathe> : timed}
          </Sequence>
        );
      })}
      {T.cuts.map((c) => (
        <Sequence key={`c${c}`} from={Math.max(0, c - 2)} durationInFrames={24} layout="absolute-fill">
          <CutFx />
        </Sequence>
      ))}
      <Texts />
      <Grain amount={0.012} />
      {hasAudio && <Audio src={staticFile(AUDIO)} />}
    </AbsoluteFill>
  );
};

/** Output in the chosen format and language (9:16 passes through). */
export const FilmMainV3Format: React.FC<FormatProps> = ({ format, lang }) => (
  <FormatFrame format={format} lang={lang} text={{ headline: "frame.main", sub: "frame.main.sub", show: 480, hide: 2250 }}>
    <FilmMainV3 />
  </FormatFrame>
);
