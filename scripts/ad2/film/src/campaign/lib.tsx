import { AbsoluteFill, Easing, Img, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame } from "remotion";
import { clamp, INTER } from "../lib/brand";
import { asset } from "../lib/kit";

/**
 * Shared pieces of the 2026-11 campaign (one ad per mini-app + general films), taken from the validated IRL Fitness ad
 * (src/irl/IrlFitness.tsx): real footage, one small lowercase word per shot, bare app screens (rounded corners, shadow, never a
 * drawn case), cuts on the beat. 1080 x 1920, 60 fps. Captures: public/kit2026/en (asset("kit/<name>.png")), recordings of
 * the app: public/campaign/rec/<name>.mp4. Footage of each film: public/campaign/<film>/<clip>.mp4.
 */
export const FPS = 60;
export type Span = readonly [number, number]; // [from, duration] in frames

export type Grade = "natural" | "bw" | "warm" | "cool" | "dark";
const FILTERS: Record<Grade, string> = {
  natural: "contrast(1.06) saturate(1.05)",
  bw: "grayscale(1) contrast(1.28)",
  warm: "contrast(1.08) saturate(1.12) sepia(0.12)",
  cool: "contrast(1.08) saturate(0.95) hue-rotate(-6deg)",
  dark: "contrast(1.18) saturate(0.85) brightness(0.82)",
};

/** Real footage: graded, vignette, slow push-in. `bg`: blurred and dimmed, behind a screen. */
export const Footage: React.FC<{ src: string; dur: number; from?: number; rate?: number; bg?: boolean; grade?: Grade; zoom?: [number, number] }> = ({
  src,
  dur,
  from = 0,
  rate = 1,
  bg = false,
  grade = "natural",
  zoom = [1.03, 1.1],
}) => {
  const f = useCurrentFrame();
  const z = interpolate(f, [0, dur], zoom);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#000" }}>
      <OffthreadVideo
        src={staticFile(src)}
        muted
        playbackRate={rate}
        startFrom={from}
        style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${bg ? 1.15 : z})`, filter: `${FILTERS[grade]}${bg ? " blur(22px) brightness(0.5)" : ""}` }}
      />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 75% 60% at 50% 48%, rgba(0,0,0,0) 45%, rgba(0,0,0,0.5) 100%)" }} />
    </AbsoluteFill>
  );
};

/** One small lowercase word (or short line) in the middle, like the reference reels. `dark`: dark ink for light scenes. */
export const Word: React.FC<{ text: string; at?: number; until: number; y?: number; size?: number; dark?: boolean }> = ({ text, at = 4, until, y = 900, size = 46, dark = false }) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [at, at + 6, until - 5, until], [0, 1, 1, 0], clamp);
  return (
    <div
      style={{
        position: "absolute",
        left: 60,
        right: 60,
        top: y,
        textAlign: "center",
        opacity: o,
        color: dark ? "#111" : "#fff",
        fontFamily: INTER,
        fontWeight: 500,
        fontSize: size,
        lineHeight: 1.15,
        letterSpacing: -0.5,
        textShadow: dark ? "none" : "0 2px 18px rgba(0,0,0,0.7)",
      }}
    >
      {text}
    </div>
  );
};

export const PW = 780;
export const SCL = PW / 1206;
export const PH = 2622 * SCL;
/** A real app screen as a bare screen (rounded corners + shadow, no drawn case), arriving with a small lift, slow push-in. */
export const Screen: React.FC<{ dur: number; children: React.ReactNode; top?: number; width?: number; light?: boolean }> = ({ dur, children, top = 150, width = PW, light = false }) => {
  const f = useCurrentFrame();
  const s = width / 1206;
  const a = interpolate(f, [0, 12], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const z = interpolate(f, [0, dur], [1, 1.05]);
  return (
    <div
      style={{
        position: "absolute",
        left: (1080 - width) / 2,
        top,
        width,
        height: 2622 * s,
        borderRadius: 165 * s,
        overflow: "hidden",
        opacity: a,
        transform: `translateY(${(1 - a) * 80}px) scale(${(0.94 + 0.06 * a) * z})`,
        boxShadow: light ? "0 40px 110px rgba(0,0,0,0.28), 0 0 0 2px rgba(0,0,0,0.06)" : "0 50px 140px rgba(0,0,0,0.7), 0 0 0 2px rgba(255,255,255,0.10)",
        background: "#000",
      }}
    >
      <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, transform: `scale(${s})`, transformOrigin: "0 0" }}>{children}</div>
    </div>
  );
};

/** A capture of the kit (1206 x 2622). */
export const Cap: React.FC<{ name: string }> = ({ name }) => <Img src={asset(`kit/${name}.png`)} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />;

/** A capture of the campaign kit (run 44465910005 of 2026-11-19 and later, public/campaign/kit/<name>.png): the freshest. */
export const CapC: React.FC<{ name: string }> = ({ name }) => <Img src={staticFile(`campaign/kit/${name}.png`)} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />;

/** A widget export of the campaign kit (true transparency), floating, popping in. */
export const WidgetC: React.FC<{ name: string; width: number; ratio: number; y?: number; at?: number }> = ({ name, width, ratio, y = 960, at = 0 }) => {
  const f = useCurrentFrame();
  const a = interpolate(f, [at, at + 8], [0, 1], clamp);
  const pop = interpolate(f, [at, at + 16], [0.86, 1], { ...clamp, easing: Easing.bezier(0.2, 1.4, 0.4, 1) });
  const h = width * ratio;
  return <Img src={staticFile(`campaign/kit/${name}.png`)} style={{ position: "absolute", left: 540 - width / 2, top: y - h / 2, width, height: h, opacity: a, transform: `scale(${pop})`, filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.45))" }} />;
};

/** A recording of the app (a played scene of the kit, 1206 x 2622 or close), inside a Screen. `from`: seconds into the clip. */
export const Rec: React.FC<{ src: string; from?: number; rate?: number }> = ({ src, from = 0, rate = 1 }) => (
  <OffthreadVideo src={staticFile(src)} muted startFrom={Math.round(from * FPS)} playbackRate={rate} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, objectFit: "cover" }} />
);

/** A widget export (true transparency) floating in the middle, popping in. */
export const Widget: React.FC<{ name: string; width: number; ratio: number; y?: number; at?: number }> = ({ name, width, ratio, y = 960, at = 0 }) => {
  const f = useCurrentFrame();
  const a = interpolate(f, [at, at + 8], [0, 1], clamp);
  const pop = interpolate(f, [at, at + 16], [0.86, 1], { ...clamp, easing: Easing.bezier(0.2, 1.4, 0.4, 1) });
  const h = width * ratio;
  return <Img src={asset(`kit/${name}.png`)} style={{ position: "absolute", left: 540 - width / 2, top: y - h / 2, width, height: h, opacity: a, transform: `scale(${pop})`, filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.45))" }} />;
};

export const Seq: React.FC<{ t: Span; children: React.ReactNode }> = ({ t, children }) => (
  <Sequence from={t[0]} durationInFrames={t[1]} layout="absolute-fill">
    {children}
  </Sequence>
);

/** A footage shot with an optional word. */
export const Roll: React.FC<{ t: Span; src: string; word?: string; grade?: Grade; from?: number; y?: number }> = ({ t, src, word, grade, from, y }) => (
  <Seq t={t}>
    <Footage src={src} dur={t[1]} grade={grade} from={from} />
    {word && <Word text={word} until={t[1]} y={y} />}
  </Seq>
);

/** Cross-fade helper: children fade in over n frames. */
export const FadeIn: React.FC<{ n: number; children: React.ReactNode }> = ({ n, children }) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ opacity: interpolate(f, [0, n], [0, 1], clamp) }}>{children}</AbsoluteFill>;
};
