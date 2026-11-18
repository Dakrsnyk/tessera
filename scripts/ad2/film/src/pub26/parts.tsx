import { AbsoluteFill, Audio, getStaticFiles, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Easing } from "remotion";
import { INTER, clamp } from "../lib/brand";
import { TimeRemap } from "../lib/time";
import { Close } from "../scenes/Close";
import P2 from "../v5/part2/timing.json";
import { CLOSE_REMAP } from "./timing26";

export const FadeIn: React.FC<{ n: number; children: React.ReactNode }> = ({ n, children }) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ opacity: interpolate(f, [0, n], [0, 1], clamp) }}>{children}</AbsoluteFill>;
};
export const FadeOut: React.FC<{ from: number; n: number; children: React.ReactNode }> = ({ from, n, children }) => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ opacity: interpolate(f, [from, from + n], [1, 0], clamp) }}>{children}</AbsoluteFill>;
};

/** The validated outro (scenes/Close.tsx, « AVAILABLE ON THE APP STORE »), exactly as FilmMainV5Part2 plays it. */
export const EndCard: React.FC = () => (
  <FadeIn n={8}>
    <TimeRemap input={CLOSE_REMAP.input} output={CLOSE_REMAP.output}>
      <Close audio={false} tagline={P2.finalCard.taglineText} cta={P2.finalCard.ctaText} ctaScale={1.35} tile />
    </TimeRemap>
  </FadeIn>
);

const out = Easing.bezier(0.16, 1, 0.3, 1);
/** The voice, as a plain bold caption (style of the « avant / après » ad), word by word. `lines` splits it over several lines. */
export const Caption: React.FC<{ lines: string[]; at: number; until: number; top?: number; size?: number }> = ({ lines, at, until, top = 8, size = 56 }) => {
  const f = useCurrentFrame();
  const fade = 1 - interpolate(f, [until - 8, until], [0, 1], clamp);
  if (f < at || fade <= 0) return null;
  let n = 0;
  return (
    <div style={{ position: "absolute", left: 40, right: 40, top, textAlign: "center", opacity: fade, color: "#F5F5F7", fontFamily: INTER, fontWeight: 700, fontSize: size, lineHeight: `${Math.round(size * 1.12)}px`, letterSpacing: -1.2, textShadow: "0 4px 24px rgba(0,0,0,0.45)" }}>
      {lines.map((line, li) => (
        <div key={li}>
          {line.split(" ").map((w, i) => {
            const e = interpolate(f, [at + n * 4, at + n * 4 + 14], [0, 1], { ...clamp, easing: out });
            n++;
            return (
              <span key={i} style={{ display: "inline-block", opacity: e, transform: `translateY(${(1 - e) * 24}px)`, filter: `blur(${(1 - e) * 8}px)`, marginRight: 14 }}>
                {w}
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
};

/** Audio mix of a film if the file exists in public/ (never required: `silent` or no file = no sound). */
export const OptionalAudio: React.FC<{ file: string; silent: boolean }> = ({ file, silent }) => {
  let has = false;
  try {
    has = !silent && getStaticFiles().some((s) => s.name === file);
  } catch {
    has = false;
  }
  return has ? <Audio src={staticFile(file)} /> : null;
};
