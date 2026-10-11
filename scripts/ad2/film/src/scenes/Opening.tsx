import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { FilmAudio } from "../components/FilmAudio";
import { hookSeamMask, HookText } from "../components/Hook";
import { Grain } from "../components/Grain";
import { CameraRig, lensFov, PHONE, Phone3D, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, heroWidget } from "../lib/kit";
import { drawLifted, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { useFilmFrame } from "../lib/time";

const FILES = [heroHome("aurore"), ...HERO_WIDGETS.map((w) => heroWidget("aurore", w.index))];

/** Ambient tint of the hero Home (average colour of the capture, desaturated 40 %), at most 6 % spill. */
const TINT = "#43576A";

/**
 * Shots 1–3 of the main film (f0–359, 0–6 s): S1 « Hook ».
 * 1 · f0–119: the phone seen edge-on is a vertical line of light (15 % on f0, ignites on f6), it turns
 *     toward the camera (yaw 90° → 35°) while the camera dollies back 6 %. VO V1.
 * 2 · f120–239: the turn ends frontal (35° → 0°), push-in 4 %/s; the screen wakes on the hero Home
 *     (Aurora); a light sweep crosses the glass at f180. V2 starts at f234.
 * 3 · f240–359: push-in to 1.10×, rising 30 px; « Designed around you. » splits from the seam.
 */
/** `hook`: the opening line of type, timed in the film's own frames (the opening's turn may be held under it). */
export const Opening: React.FC<{ audio?: boolean; hook?: { lines: string[]; to: number } }> = ({ audio = true, hook }) => {
  const outFrame = useCurrentFrame();
  const hookOn = hook ? interpolate(outFrame, [6, 14, hook.to + 6, hook.to + 26], [0, 1, 1, 0], clamp) : 0;
  const frame = useFilmFrame();
  const images = useImages(FILES);
  const { ctx, texture: screen } = useCanvasTexture();
  if (images) {
    // The hero Home (Aurora). « Breath » (f150–): each widget lifts 40 px in z and settles, 12 frames apart.
    ctx.drawImage(images[FILES[0]], 0, 0);
    HERO_WIDGETS.forEach((w, i) => {
      const start = 150 + 12 * i;
      const b = interpolate(frame, [start, start + 12, start + 30], [0, 1, 0], { ...clamp, easing: Easing.bezier(0.45, 0, 0.55, 1) });
      if (b > 0) drawLifted(ctx, images[heroWidget("aurore", w.index)], w.rect, b);
    });
    screen.needsUpdate = true;
  }

  // One continuous orbit from edge-on to frontal: no stop at the shot change.
  const yaw = interpolate(frame, [6, 236], [90, 0], { ...clamp, easing: Easing.bezier(0.45, 0, 0.18, 1) });
  // Dolly back 6 % (shot 1), push-in 4 %/s (shot 2), then to 1.10× (shot 3). Long tails, no dead stops.
  const distance = interpolate(frame, [0, 110, 240, 359], [455, 482, 446, 404], {
    ...clamp,
    // The last push keeps some speed into the next shot (the orbit into the exploded view continues).
    easing: [ease.arrival, Easing.bezier(0.42, 0, 0.58, 1), Easing.bezier(0.42, 0, 0.75, 0.88)],
  });
  const rise = interpolate(frame, [240, 359], [0, 2.8], { ...clamp, easing: Easing.bezier(0.42, 0, 0.3, 1) });

  // The line: 15 % on the first frame (the thumbnail is never black), ignites on f6, and gives way to the
  // phone as it turns face-on.
  const ignite = interpolate(frame, [0, 6, 12], [0.15, 0.15, 1], { ...clamp, easing: ease.split });
  const edgeOn = interpolate(yaw, [62, 86], [0, 1], { ...clamp, easing: Easing.bezier(0.4, 0, 0.6, 1) });
  const pxPerMm = H / (2 * distance * Math.tan(((lensFov(85) / 2) * Math.PI) / 180));
  const phoneHeightPx = PHONE.h * pxPerMm;

  const screenOn = interpolate(frame, [120, 148], [0, 1], { ...clamp, easing: Easing.bezier(0.2, 0, 0.2, 1) });
  const sweep = frame >= 180 && frame <= 210 ? interpolate(frame, [180, 210], [0, 1], { easing: Easing.bezier(0.45, 0, 0.55, 1) }) : -1;
  // While the super is read, the lower third of the phone falls back (type never sits on UI data).
  const typeVeil = interpolate(frame, [256, 280, 336, 356], [0, 1, 1, 0], clamp);

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse 700px 1100px at ${AXIS}px ${H / 2}px, ${TINT}, transparent 75%)`,
          opacity: 0.06 * screenOn,
        }}
      />
      {/* Mounted once the capture is decoded: the canvas only redraws when the frame changes. */}
      {images && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment />
          <CameraRig lens={85} distance={distance} height={12 + rise} lookY={rise} />
          <Phone3D yaw={yaw} screen={screen} screenOn={screenOn} sweep={sweep} />
        </ThreeCanvas>
      )}
      <AbsoluteFill style={hook ? { maskImage: hookSeamMask(hook.lines.length, hookOn), WebkitMaskImage: hookSeamMask(hook.lines.length, hookOn) } : undefined}>
        <Seam x={AXIS} top={H / 2 - phoneHeightPx * 0.48} height={phoneHeightPx * 0.96} intensity={ignite * edgeOn} />
      </AbsoluteFill>
      {hook && <HookText raw lines={hook.lines} from={8} to={hook.to} />}
      <AbsoluteFill
        style={{
          background: "linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.72) 72%, rgba(0,0,0,0.85) 100%)",
          opacity: typeVeil,
        }}
      />
      <SplitText from={262} exitAt={340} top={1468} height={110}>
        <span style={type.super}>Designed around you.</span>
      </SplitText>
      <Grain />

      {audio && <FilmAudio from={0} />}
    </AbsoluteFill>
  );
};
