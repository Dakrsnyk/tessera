import { AbsoluteFill, interpolate, staticFile } from "remotion";
import { AXIS, clamp, ease, H, W } from "../lib/brand";
import { k } from "../lib/kit";
import { useFilmFrame } from "../lib/time";

/** Tall slats of real wallpapers (drawn by the app), on 3 depth rows sliding vertically (§2.8 Strata). */
const ROWS = [
  {
    blur: 10,
    opacity: 0.4,
    speed: 60,
    width: 220,
    walls: ["wall-dunes.png", "wall-ocean.png", "wall-nebula.png", "wall-topography.png", "wall-midnight.png"],
    xs: [70, 330, 760, 1010, 520],
  },
  {
    blur: 4,
    opacity: 0.58,
    speed: -110,
    width: 260,
    walls: ["wall-paper.png", "wall-synthwave.png", "wall-graphite.png", "wall-sunset.png"],
    xs: [150, 410, 690, 940],
  },
  {
    blur: 1.5,
    opacity: 0.75,
    speed: 180,
    width: 300,
    walls: ["wall-aurora.png", "wall-midnight.png", "wall-sunset.png"],
    xs: [-20, 560, 1100],
  },
];

const Slat: React.FC<{ file: string; x: number; width: number; y: number; blur: number; opacity: number; fold: number }> = ({
  file,
  x,
  width,
  y,
  blur,
  opacity,
  fold,
}) => (
  <div
    style={{
      position: "absolute",
      left: x - width / 2 + (AXIS - x) * fold,
      top: 0,
      width: width * (1 - fold * 0.85),
      height: H,
      backgroundImage: `url(${staticFile(k(file))})`,
      backgroundSize: `${width * 2.2}px auto`,
      backgroundPosition: `${-width * 0.6}px ${y}px`,
      backgroundRepeat: "repeat-y",
      filter: `blur(${blur}px)`,
      opacity,
      borderRadius: 6,
    }}
  />
);

/**
 * The void fills with slats from `from`; they fold behind the phone like a closing blind from `foldAt`
 * (50 frames) and fade to the void. `register`: at each universe change a slat of the incoming wallpaper
 * glides into register behind the phone (arriving exactly on the change).
 */
export const Strata: React.FC<{ from: number; foldAt: number; register: { at: number; file: string }[] }> = ({
  from,
  foldAt,
  register,
}) => {
  const frame = useFilmFrame();
  if (frame < from || frame > foldAt + 60) return null;
  const t = (frame - from) / 60;
  const appear = interpolate(frame, [from, from + 30], [0, 1], { ...clamp, easing: ease.arrival });
  const fold = interpolate(frame, [foldAt, foldAt + 50], [0, 1], { ...clamp, easing: ease.transfer });
  const fade = interpolate(frame, [foldAt + 20, foldAt + 60], [1, 0], clamp);
  return (
    <AbsoluteFill style={{ opacity: appear * fade }}>
      {ROWS.map((row, r) =>
        row.xs.map((x, i) => (
          <Slat
            key={`${r}-${i}`}
            file={row.walls[i % row.walls.length]}
            x={x}
            width={row.width}
            y={t * row.speed + i * 377}
            blur={row.blur}
            opacity={row.opacity}
            fold={fold}
          />
        )),
      )}
      {register.map(({ at, file }) => {
        const p = interpolate(frame, [at - 40, at], [0, 1], { ...clamp, easing: ease.arrival });
        const out = interpolate(frame, [at, at + 24], [1, 0], clamp);
        if (frame < at - 40 || frame > at + 24) return null;
        const x = W + 200 - (W + 200 - AXIS) * p;
        return <Slat key={at} file={file} x={x} width={340} y={-t * 40} blur={0} opacity={0.95 * out} fold={0} />;
      })}
    </AbsoluteFill>
  );
};
