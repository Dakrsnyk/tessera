import { interpolate, useCurrentFrame } from "remotion";
import { C, clamp, ease, type } from "../lib/brand";

/**
 * Eyebrow callout (§2.6): English caps label hanging off a 1.5 px hairline at 40 % that ends in a 7 px dot
 * on a real UI point. The hairline draws from the dot in 10 frames, the label settles in (opacity and a
 * 6 px blur), exit is a 12-frame fade. Never free-floating, never over UI data.
 */
export const Callout: React.FC<{
  label: string;
  /** The UI point (dot). */
  at: [number, number];
  /** Where the label's centre sits (the hairline runs between the two, vertically). */
  labelY: number;
  from: number;
  to: number;
}> = ({ label, at, labelY, from, to }) => {
  const frame = useCurrentFrame();
  if (frame < from || frame > to + 12) return null;
  const draw = interpolate(frame, [from, from + 10], [0, 1], { ...clamp, easing: ease.split });
  const text = interpolate(frame, [from + 4, from + 16], [0, 1], { ...clamp, easing: ease.split });
  const out = interpolate(frame, [to, to + 12], [1, 0], clamp);
  const [x, y] = at;
  const above = labelY < y;
  const lineEnd = above ? labelY + 22 : labelY - 22;
  const y0 = y;
  const y1 = y + (lineEnd - y) * draw;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: out }}>
      <div
        style={{
          position: "absolute",
          left: x - 0.75,
          top: Math.min(y0, y1),
          width: 1.5,
          height: Math.abs(y1 - y0),
          background: "rgba(255,255,255,0.4)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: x - 3.5,
          top: y - 3.5,
          width: 7,
          height: 7,
          borderRadius: 4,
          background: C.type1,
          opacity: Math.min(1, draw * 3),
        }}
      />
      <div
        style={{
          ...type.eyebrow,
          position: "absolute",
          left: x - 300,
          width: 600,
          top: labelY - 16,
          textAlign: "center",
          opacity: text,
          filter: `blur(${(1 - text) * 6}px)`,
        }}
      >
        {label}
      </div>
    </div>
  );
};
