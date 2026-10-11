import { AbsoluteFill, useCurrentFrame } from "remotion";
import { H, W } from "../lib/brand";

/** 1.2 % monochrome grain on every frame (prevents banding in the void and the glows). A new seed per frame. */
export const Grain: React.FC<{ amount?: number }> = ({ amount = 0.024 }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ pointerEvents: "none", opacity: amount }}>
      <svg width={W} height={H}>
        <filter id={`grain-${frame}`} x="0" y="0" width="100%" height="100%">
          <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves={1} seed={frame} stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width={W} height={H} filter={`url(#grain-${frame})`} />
      </svg>
    </AbsoluteFill>
  );
};
