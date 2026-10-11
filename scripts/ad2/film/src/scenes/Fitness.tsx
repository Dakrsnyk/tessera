import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, Easing, Img, interpolate, staticFile } from "remotion";
import * as THREE from "three";
import { Callout } from "../components/Callout";
import { FilmAudio } from "../components/FilmAudio";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { StyledWidget } from "../components/StyledWidget";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, heroWidget, k, type Rect } from "../lib/kit";
import { drawBlade, roundRectPath, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { useFilmFrame } from "../lib/time";

/** Local frame 0 = f960 of the main film (16.0 s, the downbeat where the drums come in). */
const U = "crepuscule";
const NEXT = HERO_WIDGETS[1];
const SESSION = k("session-0-dark.png");
/** After « Série faite »: set 4 of 4, the rest restarted (1:58). */
const SESSION_AFTER = k("session-1-dark.png");
/** « Série faite » on the session capture (px). */
const SET_DONE = { x0: 108, x1: 1098, y0: 1386, y1: 1524 };
const LIBRARY = k("lib-0-dark.png");
const DETAIL = k("ex-0-dark.png");
const demo = (name: string, i: number, count: number) => k(`demo-${name}-dark-${String(Math.round(i) % count).padStart(4, "0")}.png`);
const BENCH = { name: "bench-press", count: 240 };
const SQUAT = { name: "back-squat", count: 234 };
const DEAD = { name: "deadlift", count: 264 };
const FILES = [heroHome(U), heroWidget(U, NEXT.index), SESSION, LIBRARY, DETAIL];
/** Red ambient of Fitness (§2.1), at most 6 %. */
const TINT = "#E5484D";

/** The phone (frontal, 85 mm): its apparent height falls back as the widget comes forward. */
const phoneFraction = (f: number) =>
  interpolate(f, [0, 12, 60, 330], [0.81, 0.81, 0.62, 0.55], { ...clamp, easing: [Easing.linear, ease.lift, Easing.linear] });
const screenToFrame = (fraction: number) => {
  const pxPerMm = (H * fraction) / PHONE.h;
  const s = (pxPerMm * SCREEN.w) / 1206;
  return (px: number, py: number) => [AXIS + (px - 603) * s, H / 2 + (py - 1311) * s] as [number, number];
};

/** The lifted next-set widget: 960 px wide, centred at y 900 (§2.5: a medium widget at least 940 px). */
const LIFTED: Rect = [60, 900 - (960 * 510) / 1092 / 2, 960, (960 * 510) / 1092];
/** The floating pane: the real screen at 900 px wide (≈ 2.24 px/pt). */
/** Where the breathing hold leaves it (the morph into the pane starts from there). */
const LIFTED_END: Rect = [LIFTED[0] - 6, LIFTED[1] - 8, LIFTED[2] + 12, LIFTED[3] + (12 * 510) / 1092];
const PANE_S = 900 / 1206;
const PANE_X = (W - 900) / 2;

/** `tapAt` (the Fitness film): « Série faite » is tapped in the app on that frame, the blade reveals the after-state. */
export const Fitness: React.FC<{ audio?: boolean; tapAt?: number; styles?: { at: number; file: string }[] }> = ({ audio = true, tapAt, styles = [] }) => {
  const frame = useFilmFrame();
  const images = useImages(FILES);
  const screen = useCanvasTexture();

  // Lift (§2.8): blade down the left edge f0–6, across f6–18 (+8 % exposure), detaches f12–48.
  const lift = interpolate(frame, [12, 48], [0, 1], { ...clamp, easing: ease.lift });
  const breathe = interpolate(frame, [48, 150], [0, 1], clamp);
  const detached = frame >= 12;
  if (images) {
    const ctx = screen.ctx;
    ctx.drawImage(images[heroHome(U)], 0, 0);
    const [x, y, w, h] = NEXT.rect;
    if (!detached) {
      const across = interpolate(frame, [6, 18], [0, 1], clamp);
      if (across > 0) {
        ctx.save();
        ctx.beginPath();
        ctx.rect(x, y, w * across, h);
        ctx.clip();
        ctx.filter = "brightness(1.08)";
        ctx.drawImage(images[heroWidget(U, NEXT.index)], x, y, w, h);
        ctx.restore();
      }
      const down = interpolate(frame, [0, 6], [0, 1], clamp);
      drawBlade(ctx, frame < 6 ? x : x + w * across, y, frame < 6 ? h * down : h, 1);
    } else {
      // The empty slot glows as a socket (peach inner glow 18 %).
      ctx.save();
      roundRectPath(ctx, NEXT.rect, 66);
      ctx.fillStyle = "rgba(8,6,10,0.55)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(255,224,204,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 40;
      ctx.strokeStyle = "rgba(255,224,204,0.18)";
      ctx.stroke();
      ctx.restore();
    }
    screen.texture.needsUpdate = true;
  }

  const fraction = phoneFraction(frame);
  const lens = 85;
  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(lens)) / 2) * fraction);
  const toFrame = screenToFrame(fraction);
  const phoneBlur = interpolate(frame, [12, 36, 150, 180, 450, 480], [0, 8, 8, 12, 12, 16], clamp);
  const phoneDim = interpolate(frame, [12, 36, 150, 180, 450, 500], [1, 0.55, 0.55, 0.4, 0.4, 0], clamp);

  // The widget's path: from its slot on the glass to 960 px in front, rising 40 px on the way.
  const [sx, sy] = toFrame(NEXT.rect[0], NEXT.rect[1]);
  const [ex, ey] = toFrame(NEXT.rect[0] + NEXT.rect[2], NEXT.rect[1] + NEXT.rect[3]);
  const slot: Rect = [sx, sy, ex - sx, ey - sy];
  const mix = (a: Rect, b: Rect, p: number): Rect => a.map((v, i) => v + (b[i] - v) * p) as Rect;
  const liftedRect = mix(slot, LIFTED, lift);
  liftedRect[1] -= Math.sin(Math.PI * lift) * 40 + 8 * breathe;
  liftedRect[0] -= 6 * breathe;
  liftedRect[2] += 12 * breathe;
  liftedRect[3] += (12 * breathe * 510) / 1092;

  // Shot 8 (f150–): the blade turns the widget into the pane; the rounded rect grows over 24 frames.
  const morph = interpolate(frame, [150, 174], [0, 1], { ...clamp, easing: ease.transfer });
  const paneTop = interpolate(frame, [150, 174, 330, 380], [150, 150, -150, 60], {
    ...clamp,
    easing: [Easing.linear, Easing.bezier(0.45, 0, 0.2, 1), ease.transfer],
  });
  const paneRect: Rect = [PANE_X, paneTop, 900, 2622 * PANE_S];
  const container = frame < 150 ? liftedRect : mix(LIFTED_END, paneRect, morph);
  const blade150 = interpolate(frame, [150, 174], [0, 1], clamp);
  // Shot 9: blade to the library (f330–348), then an iOS push to the exercise (f400–430).
  const blade330 = interpolate(frame, [330, 348], [0, 1], clamp);
  const push = interpolate(frame, [400, 430], [0, 1], { ...clamp, easing: Easing.bezier(0.2, 0.9, 0.25, 1) });
  // Shot 10: the pane recedes, the figure steps out of its card (f450–).
  const recede = interpolate(frame, [450, 500], [0, 1], { ...clamp, easing: ease.transfer });
  const paneOut = interpolate(frame, [450, 462, 500], [1, 0.28, 0.2], clamp);
  const figIn = interpolate(frame, [450, 462], [0, 1], clamp);

  // Focus band on the pane (depth of field): the held element is sharp; the frozen rest timer never is.
  const focusY =
    tapAt === undefined
      ? interpolate(frame, [174, 200, 250, 290, 330], [699, 699, 1990, 1990, 400], clamp)
      : interpolate(frame, [174, tapAt - 24, tapAt - 6, tapAt + 30, tapAt + 54, 330], [699, 699, 1455, 1455, 699, 400], clamp);
  const tapped = tapAt !== undefined && frame >= tapAt;
  const tapRing = tapAt === undefined ? 1 : interpolate(frame, [tapAt, tapAt + 18], [0, 1], { ...clamp, easing: ease.split });
  const tapBlade = tapAt === undefined ? 0 : interpolate(frame, [tapAt, tapAt + 12], [0, 1], { ...clamp, easing: Easing.bezier(0.45, 0, 0.2, 1) });
  const sessionNow = tapped && tapBlade >= 1 ? SESSION_AFTER : SESSION;
  // The blade runs outward from the button (pane px).
  const bx = 603 * PANE_S;
  const xL = bx - tapBlade * bx;
  const xR = bx + tapBlade * (900 - bx);
  const toPane = (px: number, py: number) => [PANE_X + px * PANE_S, paneTop + py * PANE_S] as [number, number];
  const bandY = toPane(0, focusY)[1];

  const paneImage = (src: string, extra?: React.CSSProperties) => (
    <Img src={staticFile(src)} style={{ position: "absolute", left: 0, top: 0, width: 900, height: 2622 * PANE_S, ...extra }} />
  );

  const fig = (count: number, name: string) => staticFile(demo(name, Math.max(0, frame - 450), count));
  const step = interpolate(frame, [450, 500], [0, 1], { ...clamp, easing: ease.lift });
  const tri = interpolate(frame, [540, 580], [0, 1], { ...clamp, easing: ease.transfer });
  const toLine = interpolate(frame, [578, 600], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 1) });
  // The card of the detail screen (capture px) on the pane, where the figure starts.
  const card = toPane(60, 401);
  const figW = interpolate(step, [0, 1], [1080 * PANE_S, 1320]) * (1 - 0.22 * tri);
  const figX = interpolate(step, [0, 1], [card[0], AXIS - 660]) + 660 * 0.22 * tri;
  const figY = interpolate(step, [0, 1], [card[1], 360]) + 40 * tri;

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      <AbsoluteFill
        style={{ background: `radial-gradient(ellipse 700px 900px at ${AXIS}px ${H / 2}px, ${TINT}, transparent 75%)`, opacity: 0.06 }}
      />
      {images && phoneDim > 0 && (
        <AbsoluteFill style={{ filter: `blur(${phoneBlur}px) brightness(${phoneDim})` }}>
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={lens} position={new THREE.Vector3(0, 0, distance)} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={0} screen={screen.texture} screenOn={1} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}

      {/* The lifted widget, then the pane it becomes (shots 7–9). */}
      {detached && frame < 500 && (
        <div
          style={{
            position: "absolute",
            left: container[0],
            top: container[1],
            width: container[2],
            height: container[3],
            borderRadius: interpolate(morph, [0, 1], [56, 44]),
            overflow: "hidden",
            boxShadow: `0 ${30 * lift}px ${80 * lift}px rgba(0,0,0,${0.6 * lift})`,
            scale: `${1 - 0.18 * recede}`,
            filter: `blur(${12 * interpolate(frame, [450, 462], [0, 1], clamp)}px) brightness(${paneOut})`,
            opacity: 1 - interpolate(frame, [480, 500], [0, 1], clamp),
          }}
        >
          {frame < 174 && (
            <Img
              src={staticFile(heroWidget(U, NEXT.index))}
              style={{
                position: "absolute",
                left: 0,
                top: 0,
                width: LIFTED_END[2],
                height: LIFTED_END[3],
                clipPath: `inset(0 0 0 ${(blade150 * container[2] * 100) / LIFTED_END[2]}%)`,
              }}
            />
          )}
          {frame >= 150 && (
            <div
              style={{
                position: "absolute",
                left: 0,
                top: 0,
                width: 900,
                height: 2622 * PANE_S,
                translate: `${(container[0] - PANE_X) * 0}px 0px`,
                clipPath: frame < 174 ? `inset(0 ${(1 - blade150) * 100}% 0 0)` : undefined,
              }}
            >
              <div style={{ position: "absolute", inset: 0, translate: `${-260 * push}px 0px`, filter: `brightness(${1 - 0.35 * push})` }}>
                {/* Session (sharp band around the focus, the rest softly out of focus). */}
                {frame < 348 && paneImage(sessionNow, { filter: frame >= 174 && frame < 330 ? "blur(3px)" : undefined })}
                {frame >= 174 &&
                  frame < 330 &&
                  paneImage(sessionNow, {
                    maskImage: `linear-gradient(to bottom, transparent ${bandY - container[1] - 260}px, black ${bandY - container[1] - 120}px, black ${bandY - container[1] + 120}px, transparent ${bandY - container[1] + 260}px)`,
                  })}
                {tapped && tapBlade < 1 && paneImage(SESSION_AFTER, { clipPath: `inset(0 ${900 - xR}px 0 ${xL}px)` })}
                {tapped && tapRing < 1 && (
                  <div
                    style={{
                      position: "absolute",
                      left: SET_DONE.x0 * PANE_S,
                      top: SET_DONE.y0 * PANE_S,
                      width: (SET_DONE.x1 - SET_DONE.x0) * PANE_S,
                      height: (SET_DONE.y1 - SET_DONE.y0) * PANE_S,
                      borderRadius: ((SET_DONE.y1 - SET_DONE.y0) * PANE_S) / 2,
                      border: `3px solid ${C.peach}`,
                      boxShadow: "0 0 24px 4px rgba(255,224,204,0.5)",
                      scale: `${1 + 0.12 * tapRing}`,
                      opacity: 0.95 * (1 - tapRing),
                    }}
                  />
                )}
                {frame >= 330 && paneImage(LIBRARY, { clipPath: frame < 348 ? `inset(0 ${(1 - blade330) * 100}% 0 0)` : undefined })}
              </div>
              {frame >= 400 && (
                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    translate: `${900 * (1 - push)}px 0px`,
                    boxShadow: "-20px 0 40px rgba(0,0,0,0.4)",
                  }}
                >
                  {paneImage(DETAIL)}
                </div>
              )}
            </div>
          )}
        </div>
      )}
      {styles.length > 0 && frame >= 48 && frame < 150 && (
        <StyledWidget base={heroWidget(U, NEXT.index)} styles={styles} frame={frame} rect={liftedRect} lift={lift} />
      )}
      {frame >= 150 && frame < 174 && (
        <Seam x={container[0] + container[2] * blade150} top={container[1]} height={Math.min(container[3], H)} spread={0.5} />
      )}
      {frame >= 330 && frame < 348 && (
        <Seam x={PANE_X + 900 * blade330} top={Math.max(0, paneTop)} height={H - Math.max(0, paneTop)} spread={0.5} />
      )}

      {/* Shot 10: the figure steps out of its card onto a lit plinth; the triptych from f540; the line. */}
      {frame >= 450 && (
        <AbsoluteFill style={{ scale: `${1 - toLine} 1`, transformOrigin: `${AXIS}px 50%`, opacity: 1 - toLine * 0.6 }}>
          {tri > 0 && (
            <>
              <Plinth x={250} y={930} w={520} opacity={0.7 * tri} />
              <Img
                src={fig(SQUAT.count, SQUAT.name)}
                style={{ position: "absolute", left: 250 - 380, top: 930 - 470, width: 760, opacity: 0.75 * tri, filter: "blur(2.5px)" }}
              />
              <Plinth x={830} y={880} w={460} opacity={0.6 * tri} />
              <Img
                src={fig(DEAD.count, DEAD.name)}
                style={{ position: "absolute", left: 830 - 330, top: 880 - 410, width: 660, opacity: 0.6 * tri, filter: "blur(4px)" }}
              />
            </>
          )}
          <Plinth x={figX + figW / 2} y={figY + figW * 0.56} w={figW * 0.85} opacity={step} />
          <Img src={fig(BENCH.count, BENCH.name)} style={{ position: "absolute", left: figX, top: figY, width: figW, opacity: figIn }} />
        </AbsoluteFill>
      )}
      {frame >= 576 && <Seam x={AXIS} top={300} height={1320} intensity={interpolate(frame, [576, 600], [0, 1], clamp)} />}

      <Callout label="Next set" at={[liftedRect[0] + 70, liftedRect[1] - 10]} labelY={liftedRect[1] - 110} from={48} to={138} />
      {tapAt === undefined ? (
        <>
          <Callout label="Set 3 of 4" at={toPane(105, 660)} labelY={toPane(105, 660)[1] - 110} from={182} to={264} />
          <Callout label="Workout progress" at={toPane(285, 2040)} labelX={toPane(285, 2040)[0] + 240} from={252} to={324} />
        </>
      ) : (
        <>
          <Callout label="Set done" at={toPane(603, 1380)} labelY={toPane(603, 1380)[1] - 120} from={tapAt - 26} to={tapAt + 14} />
          <Callout label="Set 4 of 4" at={toPane(105, 660)} labelY={toPane(105, 660)[1] - 110} from={tapAt + 30} to={tapAt + 100} />
        </>
      )}
      <Callout label="Exercise library" at={toPane(560, 330)} labelX={toPane(560, 330)[0] + 70} from={348} to={420} />
      <SplitText from={508} exitAt={578} top={1236} height={100}>
        <span style={type.super}>163 exercises.</span>
      </SplitText>
      <SplitText from={520} exitAt={578} top={1330} height={100}>
        <span style={{ ...type.super, color: C.type2 }}>Each one animated.</span>
      </SplitText>
      <Grain />
      {audio && <FilmAudio from={960} />}
    </AbsoluteFill>
  );
};

/** A lit plinth (#1C1C1F) under a figure: its top face catches the light, its front falls to black. */
const Plinth: React.FC<{ x: number; y: number; w: number; opacity: number }> = ({ x, y, w, opacity }) => (
  <div style={{ position: "absolute", left: x - w / 2, top: y - w * 0.07, width: w, height: w * 0.42, opacity }}>
    <div
      style={{
        position: "absolute",
        inset: 0,
        top: w * 0.07,
        background: "linear-gradient(#1C1C1F, #000 85%)",
        borderRadius: `0 0 ${w * 0.05}px ${w * 0.05}px`,
      }}
    />
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width: w,
        height: w * 0.14,
        borderRadius: "50%",
        background: "radial-gradient(ellipse at 50% 40%, #3A3A3F, #1C1C1F 70%)",
        boxShadow: "0 -2px 30px rgba(255,244,236,0.08)",
      }}
    />
  </div>
);
