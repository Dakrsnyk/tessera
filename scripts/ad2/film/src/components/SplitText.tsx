import { interpolate, useCurrentFrame } from "remotion";
import { AXIS, C, clamp, ease, W } from "../lib/brand";

/**
 * « Split from the seam » (§2.6): a 2 px line flashes at x = 540 for 8 frames, then the line of type
 * opens from the centre: the left half slides +40 → 0 px, the right half −40 → 0 px, behind a mask
 * widening from the axis, 24 frames on (0.16, 1, 0.3, 1), opacity 0 → 1 over the first 10 frames.
 * Exit (optional, at `exitAt`): the halves close back into the seam in 18 frames, ease-in.
 */
export const SplitText: React.FC<{
  from: number;
  top: number;
  height: number;
  exitAt?: number;
  children: React.ReactNode;
}> = ({ from, top, height, exitAt, children }) => {
  const frame = useCurrentFrame();
  const local = frame - from;
  if (local < 0) return null;

  const open = interpolate(local, [8, 32], [0, 1], { ...clamp, easing: ease.split });
  const close = exitAt === undefined ? 0 : interpolate(frame, [exitAt, exitAt + 18], [0, 1], { ...clamp, easing: ease.easeIn });
  const p = open * (1 - close);
  const opacity = interpolate(local, [8, 18], [0, 1], clamp) * (close < 1 ? 1 : 0);
  const flash = interpolate(local, [0, 2, 8, 14], [0, 1, 1, 0], clamp);
  const reach = p * AXIS;

  const half = (side: "left" | "right"): React.CSSProperties => ({
    position: "absolute",
    left: 0,
    top: top - 30,
    width: W,
    height: height + 60,
    clipPath:
      side === "left"
        ? `inset(0px ${W - AXIS}px 0px ${AXIS - reach}px)`
        : `inset(0px ${W - AXIS - reach}px 0px ${AXIS}px)`,
    opacity,
  });
  const content = (dx: number): React.CSSProperties => ({
    position: "absolute",
    left: 0,
    top: 30,
    width: W,
    height,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    color: C.type1,
    translate: `${dx}px 0px`,
    whiteSpace: "nowrap",
  });

  return (
    <>
      {flash > 0 && (
        <div
          style={{
            position: "absolute",
            left: AXIS - 1,
            top,
            width: 2,
            height,
            background: C.seamCore,
            opacity: flash,
            boxShadow: `0 0 12px 2px ${C.peach}, 0 0 40px 6px rgba(255,122,89,0.25)`,
          }}
        />
      )}
      <div style={half("left")}>
        <div style={content(40 * (1 - p))}>{children}</div>
      </div>
      <div style={half("right")}>
        <div style={content(-40 * (1 - p))}>{children}</div>
      </div>
    </>
  );
};
