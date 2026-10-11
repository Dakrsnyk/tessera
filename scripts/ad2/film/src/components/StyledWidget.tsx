import { Easing, Img, interpolate, staticFile } from "remotion";
import type { Rect } from "../lib/kit";
import { Seam } from "./Seam";

/**
 * A lifted widget that changes style on the beats: the same widget, same data, in other real renders,
 * each change a blade (10 frames, landing on `at`). `styles` [{at, file}] in scene frames.
 */
export const StyledWidget: React.FC<{ base: string; styles: { at: number; file: string }[]; frame: number; rect: Rect; lift: number }> = ({
  base,
  styles,
  frame,
  rect,
  lift,
}) => {
  let cur = base;
  let nxt: string | null = null;
  let wipe = 0;
  for (const st of styles) {
    if (frame >= st.at) cur = st.file;
    else if (frame >= st.at - 10) {
      nxt = st.file;
      wipe = interpolate(frame, [st.at - 10, st.at], [0, 1], { easing: Easing.bezier(0.45, 0, 0.55, 1) });
    }
  }
  const [x, y, w, h] = rect;
  const full: React.CSSProperties = { position: "absolute", inset: 0, width: "100%", height: "100%" };
  return (
    <>
      <div style={{ position: "absolute", left: x, top: y, width: w, height: h, filter: `drop-shadow(0 ${30 * lift}px ${70 * lift}px rgba(0,0,0,0.6))` }}>
        <Img src={staticFile(cur)} style={full} />
        {nxt && <Img src={staticFile(nxt)} style={{ ...full, clipPath: `inset(0 ${(1 - wipe) * 100}% 0 0)` }} />}
      </div>
      {nxt && <Seam x={x + w * wipe} top={y} height={h} spread={0.45} intensity={Math.sin(Math.PI * wipe)} />}
    </>
  );
};
