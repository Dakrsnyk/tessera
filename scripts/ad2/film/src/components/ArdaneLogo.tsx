import { C } from "../lib/brand";

// The app's mark (ArdaneHalf in App/Screens/Launch/LaunchView.swift), on its 100 × 100 grid.
const LEFT = "47.5,19.3 47.5,55.4 34,86 16,86";
const RIGHT = "52.5,19.3 84,86 66,86 52.5,55.4";
/** The gap and the space between the legs: where the sapphire (#4E9BE0 → #1B4A7A) light lives. */
const GAP = "47.5,19.3 52.5,19.3 52.5,55.4 66,86 34,86 47.5,55.4";

/** Gap of the « A » in the grid: slot from y 19.3 to 55.4, x 47.5 to 52.5. */
export const LOGO_GAP = { top: 0.193, bottom: 0.554, left: 0.475, right: 0.525 };

/**
 * The « A » on the void: white left half, pale-blue right half, the gradient only inside and behind the gap.
 * `left` / `right` (0…1) grow each half out of the seam (scale from its inner edge).
 */
export const ArdaneLogo: React.FC<{
  size: number;
  cx: number;
  cy: number;
  left?: number;
  right?: number;
  glow?: number;
}> = ({ size, cx, cy, left = 1, right = 1, glow = 1 }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 100 100"
    style={{ position: "absolute", left: cx - size / 2, top: cy - size / 2, overflow: "visible" }}
  >
    <defs>
      <linearGradient id="gap" x1="0" y1="0.15" x2="0" y2="0.9">
        <stop offset="0" stopColor={C.sapphire} />
        <stop offset="1" stopColor={C.sapphireDeep} />
      </linearGradient>
      <filter id="gapSoft" x="-100%" y="-50%" width="300%" height="200%">
        <feGaussianBlur stdDeviation="1.6" />
      </filter>
      <filter id="gapBloom" x="-200%" y="-100%" width="500%" height="300%">
        <feGaussianBlur stdDeviation="9" />
      </filter>
    </defs>
    {glow > 0 && (
      <>
        <polygon points={GAP} fill="url(#gap)" filter="url(#gapBloom)" opacity={0.32 * glow} />
        <polygon points={GAP} fill="url(#gap)" filter="url(#gapSoft)" opacity={0.95 * glow} />
      </>
    )}
    {left > 0 && (
      <polygon
        points={LEFT}
        fill="#FFFFFF"
        opacity={Math.min(1, left * 3)}
        transform={`translate(47.5 0) scale(${left} 1) translate(-47.5 0)`}
      />
    )}
    {right > 0 && (
      <polygon
        points={RIGHT}
        fill={C.pale}
        opacity={Math.min(1, right * 3)}
        transform={`translate(52.5 0) scale(${right} 1) translate(-52.5 0)`}
      />
    )}
  </svg>
);
