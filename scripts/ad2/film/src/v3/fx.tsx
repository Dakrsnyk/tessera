import { Easing, interpolate } from "remotion";
import { C, INTER } from "../lib/brand";

/** Deterministic noise in [0,1). */
export const rnd = (n: number) => {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

/** Overshoot arrival ("back out"). */
export const back = Easing.bezier(0.34, 1.56, 0.64, 1);
export const slam = Easing.bezier(0.2, 0.9, 0.1, 1);

export type KWord = { t: string; at: number; hi?: boolean };

/**
 * Kinetic line of type: each word pops in on its own frame (rise, overshoot, de-blur), the whole line
 * leaves with `out` (0 → 1: scale up, blur, fade) or collapses towards the axis with `squeeze` (0 → 1).
 */
export const KineticLine: React.FC<{
  words: KWord[];
  frame: number;
  top: number;
  size: number;
  out?: number;
  squeeze?: number;
  weight?: number;
  gap?: number;
}> = ({ words, frame, top, size, out = 0, squeeze = 0, weight = 700, gap = 0.26 }) => {
  if (out >= 1 || squeeze >= 1) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top,
        width: 1080,
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        gap: `0 ${size * gap}px`,
        flexWrap: "nowrap",
        fontFamily: INTER,
        fontWeight: weight,
        fontSize: size,
        lineHeight: 1.05,
        letterSpacing: "-0.03em",
        fontVariationSettings: "'opsz' 32",
        color: C.type1,
        whiteSpace: "nowrap",
        transform: `scale(${(1 + out * 0.18) * (1 - squeeze)}, ${1 + out * 0.18})`,
        opacity: 1 - out,
        filter: out > 0 ? `blur(${out * 16}px)` : undefined,
      }}
    >
      {words.map((w, i) => {
        const p = interpolate(frame, [w.at, w.at + 9], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: back });
        const vis = frame >= w.at;
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              opacity: vis ? Math.min(1, p * 3) : 0,
              transform: `translateY(${(1 - p) * 70}px) scale(${0.6 + 0.4 * p}) rotate(${(1 - p) * -7}deg)`,
              filter: `blur(${(1 - Math.min(1, p)) * 12}px)`,
              ...(w.hi
                ? { background: `linear-gradient(180deg, ${C.paleWarm}, ${C.sapphireBright} 70%, ${C.sapphire})`, WebkitBackgroundClip: "text", color: "transparent", textShadow: "none" }
                : { textShadow: "0 6px 40px rgba(0,0,0,0.6)" }),
            }}
          >
            {w.t}
          </span>
        );
      })}
    </div>
  );
};
