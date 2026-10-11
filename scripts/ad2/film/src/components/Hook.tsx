import { AbsoluteFill, interpolate } from "remotion";
import { AXIS, C, clamp, ease, H, type } from "../lib/brand";
import { useFilmFrame } from "../lib/time";
import { Grain } from "./Grain";
import { Seam } from "./Seam";
import { SplitText } from "./SplitText";

/**
 * The hook (the first seconds of every film): a line of type opens from the seam, line by line, while the
 * seam stops above and below the block (as if the words were inside the gap of the « A »); the last line —
 * the brand — in white, the others too; they close back into the seam at `to`.
 */
export const HOOK_LINE = 96;

export const hookBlock = (lines: number) => {
  const height = lines * HOOK_LINE;
  const top = H / 2 - height / 2 - 40;
  return { top, height };
};

/** Mask for a full-height seam: transparent across the text block while the hook is on screen. */
export const hookSeamMask = (lines: number, on: number) => {
  const { top, height } = hookBlock(lines);
  const a = top - 40;
  const b = top + height + 40;
  const fade = 50;
  const hole = `rgba(0,0,0,${1 - on})`;
  return `linear-gradient(to bottom, black 0px, black ${a - fade}px, ${hole} ${a}px, ${hole} ${b}px, black ${b + fade}px, black ${H}px)`;
};

export const HookText: React.FC<{ lines: string[]; from: number; to: number; raw?: boolean }> = ({ lines, from, to, raw }) => {
  const { top } = hookBlock(lines.length);
  return (
    <>
      {lines.map((line, i) => (
        <SplitText key={i} raw={raw} from={from + 6 * i} exitAt={to + 3 * i} top={top + i * HOOK_LINE} height={HOOK_LINE}>
          <span style={{ ...type.super, fontSize: 92, color: i === lines.length - 1 ? C.type1 : C.type1 }}>{line}</span>
        </SplitText>
      ))}
    </>
  );
};

/**
 * A film's opening card when its first scene has no seam of its own: the line ignites (15 % on the first
 * frame, full on f4), the hook opens from it, closes back at `to`, and the line holds for the next scene.
 */
export const HookCard: React.FC<{ audio?: boolean; lines?: string[]; to?: number }> = ({ lines = ["Organize", "your life", "with Ardane."], to = 96 }) => {
  const frame = useFilmFrame();
  const ignite = interpolate(frame, [0, 4, 10], [0.15, 0.6, 1], { ...clamp, easing: ease.split });
  const on = interpolate(frame, [6, 14, to + 6, to + 26], [0, 1, 1, 0], clamp);
  const mask = hookSeamMask(lines.length, on);
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      <AbsoluteFill style={{ maskImage: mask, WebkitMaskImage: mask }}>
        <Seam x={AXIS} top={230} height={H - 460} intensity={ignite} />
      </AbsoluteFill>
      <HookText lines={lines} from={8} to={to} />
      <Grain />
    </AbsoluteFill>
  );
};
