import { C } from "../lib/brand";

const rgb = (hex: string) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(",");

/** A horizontal Gaussian profile as a gradient: soft to the very edge of its box (no blur filter to clip). */
const gaussian = (hex: string, alpha: number) => {
  const stops = Array.from({ length: 13 }, (_, i) => {
    const x = i / 12;
    const a = alpha * Math.exp(-(((x - 0.5) / 0.17) ** 2) / 2);
    return `rgba(${rgb(hex)},${a.toFixed(4)}) ${(x * 100).toFixed(1)}%`;
  });
  return `linear-gradient(to right, ${stops.join(", ")})`;
};

/**
 * The Line: the gap of the « A » as light. 2 px white core, 24 px peach glow, coral bloom (≤ 25 %),
 * far raspberry bloom (≤ 8 %). Its ends taper so it never reads as a drawn bar.
 */
export const Seam: React.FC<{
  x: number;
  top: number;
  height: number;
  intensity?: number;
  core?: number;
}> = ({ x, top, height, intensity = 1, core = 2 }) => {
  if (intensity <= 0 || height <= 0) return null;
  const layer = (width: number, background: string, extra: number, opacity = 1): React.CSSProperties => {
    const h = height + 2 * extra;
    const edge = Math.min(30, (100 * (extra + 40)) / h);
    const taper = `linear-gradient(to bottom, transparent 0%, black ${edge}%, black ${100 - edge}%, transparent 100%)`;
    return {
      position: "absolute",
      left: x - width / 2,
      top: top - extra,
      width,
      height: h,
      background,
      opacity: opacity * intensity,
      maskImage: taper,
      WebkitMaskImage: taper,
      mixBlendMode: "screen",
    };
  };
  return (
    <>
      <div style={layer(420, gaussian(C.raspberry, 0.08), 90)} />
      <div style={layer(200, gaussian(C.coral, 0.25), 50)} />
      <div style={layer(40, gaussian(C.peach, 0.85), 14)} />
      <div style={layer(core + 2, gaussian(C.seamWarm, 1), 4)} />
      <div style={layer(core, C.seamCore, 0)} />
    </>
  );
};
