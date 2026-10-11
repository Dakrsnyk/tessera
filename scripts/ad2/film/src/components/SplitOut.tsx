import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { AXIS, clamp, ease, H, W } from "../lib/brand";
import { Seam } from "./Seam";

/**
 * Split (§2.8, chapter change): the frame splits at x = 540 and its two halves slide apart like the halves
 * of the « A », falling back (scale) and blurring 0 → 12 px, the next scene revealed in the widening gap.
 * 30 frames on (0.7, 0, 0.2, 1), seam glow on both inner edges. `children` is the outgoing scene, still
 * playing (rendered twice: one per half).
 */
export const SplitOut: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame, [0, 30], [0, 1], { ...clamp, easing: ease.chapter });
  const half = (side: "left" | "right") => (
    <AbsoluteFill
      style={{
        clipPath: side === "left" ? `inset(0 ${W - AXIS}px 0 0)` : `inset(0 0 0 ${AXIS}px)`,
        translate: `${(side === "left" ? -1 : 1) * (AXIS + 40) * p}px 0px`,
        scale: `${1 - 0.1 * p}`,
        filter: `blur(${12 * p}px)`,
      }}
    >
      {children}
    </AbsoluteFill>
  );
  const edge = (AXIS + 40) * p * (1 - 0.1 * p);
  return (
    <AbsoluteFill>
      {half("left")}
      {half("right")}
      <Seam x={AXIS - edge} top={0} height={H} intensity={1 - p * 0.6} spread={0.6} />
      <Seam x={AXIS + edge} top={0} height={H} intensity={1 - p * 0.6} spread={0.6} />
    </AbsoluteFill>
  );
};
