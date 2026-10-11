import { ThreeCanvas } from "@remotion/three";
import { useMemo } from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile } from "remotion";
import * as THREE from "three";
import { drawEan, BarcodeLabel, LABEL } from "../components/Barcode";
import { Callout } from "../components/Callout";
import { FilmAudio } from "../components/FilmAudio";
import { Grain } from "../components/Grain";
import { CameraLook, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, useFontsReady, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, k, project, type Rect } from "../lib/kit";
import { useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { useFilmFrame } from "../lib/time";

/** Local frame 0 = f1920 of the main film (32.0 s): the light snaps on. */
const U = "crepuscule";
const LOCK = k("lock-crepuscule.png");
const SEARCH = k("nut-1-dark.png");
const CHROME = k("scan-chrome-dark.png");
const SHEET = k("nut-2-dark.png");
const BEFORE = k("nut-0-dark.png");
const AFTER = k("nut-3-dark.png");
const FILES = [heroHome(U), LOCK, SEARCH, CHROME, SHEET, BEFORE, AFTER];
const MACROS = HERO_WIDGETS[0].rect;
/** Points of the captures (px): the « Scanner » pill, the aiming square, « Enregistrer ». */
const PILL = { x: 983, y: 288, w: 234, h: 71 };
const SQUARE = { x: 604, y: 1250, size: 735 };
const SAVE = { x: 982, y: 330, w: 356, h: 128 };
/** The quantity sheet starts below the status bar of its capture. */
const SHEET_TOP = 190;

const SCALE = 1.6;
const PHONE_AT = new THREE.Vector3(0, 82, 210);

const poolTexture = () => {
  const c = document.createElement("canvas");
  c.width = c.height = 1024;
  const ctx = c.getContext("2d")!;
  const g = ctx.createRadialGradient(512, 512, 0, 512, 512, 512);
  g.addColorStop(0, "#F2F2F4");
  g.addColorStop(0.28, "#E6E6EA");
  g.addColorStop(0.55, "#6A6A70");
  g.addColorStop(0.8, "#121214");
  g.addColorStop(1, "#000000");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 1024, 1024);
  ctx.save();
  ctx.translate(512, 512);
  ctx.scale(1, 0.2);
  const s = ctx.createRadialGradient(0, 0, 0, 0, 0, 52);
  s.addColorStop(0, "rgba(0,0,0,0.5)");
  s.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = s;
  ctx.fillRect(-60, -60, 120, 120);
  ctx.restore();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
};

/** The label as the phone's camera sees it (drawn once, Inter needed for the digits). */
const useLabelPicture = (ready: boolean) =>
  useMemo(() => {
    if (!ready) return null;
    const c = document.createElement("canvas");
    c.width = 640;
    c.height = 400;
    const ctx = c.getContext("2d")!;
    ctx.fillStyle = "#F4F3F0";
    ctx.beginPath();
    ctx.roundRect(0, 0, 640, 400, 30);
    ctx.fill();
    drawEan(ctx, 92, 68, 456, 264);
    return c;
  }, [ready]);

/** Camera of the 3D part: the label (shot 14), the phone sliding in, the macro on the pill, the app. */
const cameraAt = (f: number) => {
  const pill = new THREE.Vector3((PILL.x / 1206 - 0.5) * SCREEN.w, (0.5 - PILL.y / 2622) * SCREEN.h, PHONE.d / 2).add(PHONE_AT);
  const labelTarget = new THREE.Vector3(0, (LABEL.h * SCALE) / 2, 0);
  const label = {
    lens: 85,
    target: labelTarget,
    position: new THREE.Vector3(0, labelTarget.y + 940 * 0.24, interpolate(f, [0, 89], [980, 900], { ...clamp, easing: ease.arrival })),
  };
  const phoneDist = (fraction: number, lens: number) => PHONE.h / (2 * Math.tan(Math.atan(18 / lens)) * fraction);
  const front = (fraction: number, lens: number, target: THREE.Vector3) => ({
    lens,
    target,
    position: target.clone().add(new THREE.Vector3(0, 6, phoneDist(fraction, lens))),
  });
  if (f < 90) return label;
  // 90–130: onto the phone · 130–180: macro on the pill (135 mm) · 180–222: back to the whole screen.
  const a = interpolate(f, [90, 130], [0, 1], { ...clamp, easing: ease.transfer });
  const b = interpolate(f, [130, 176], [0, 1], { ...clamp, easing: Easing.bezier(0.45, 0, 0.2, 1) });
  const c = interpolate(f, [180, 222], [0, 1], { ...clamp, easing: ease.transfer });
  const lens = 85 + 50 * b - 50 * c;
  const fraction = interpolate(a, [0, 1], [0.55, 0.78]) * (1 + 1.4 * b) * (1 - (1.4 * c) / (1 + 1.4)) + 0.14 * c;
  const target = labelTarget.clone().lerp(PHONE_AT, a).lerp(pill, b).lerp(PHONE_AT, c);
  const push = interpolate(f, [222, 330], [1, 1.04], clamp);
  const cam = front(fraction * push, lens, target);
  // Coming from the label's camera position, blend for the first frames of the move.
  cam.position.lerp(label.position, 1 - a);
  return cam;
};

export const Nutrition: React.FC<{ audio?: boolean }> = ({ audio = true }) => {
  const frame = useFilmFrame();
  const fonts = useFontsReady();
  const images = useImages(FILES);
  const labelPicture = useLabelPicture(fonts);
  const screen = useCanvasTexture();
  const pool = useMemo(poolTexture, []);
  const ready = fonts && images && labelPicture;

  // Phone: slides in from the right (90–130), screen on the Lock Screen, unlock slide-up (110–137).
  const enter = interpolate(frame, [90, 130], [1, 0], { ...clamp, easing: ease.arrival });
  const phoneAt = PHONE_AT.clone().add(new THREE.Vector3(260 * enter, 0, 0));
  if (ready) {
    const ctx = screen.ctx;
    const unlock = interpolate(frame, [110, 137], [0, 1], { ...clamp, easing: Easing.bezier(0.3, 0, 0.1, 1) });
    // Home (zooming in slightly as the Lock Screen leaves), then the app opening from the widget (180–207).
    const open = interpolate(frame, [180, 207], [0, 1], { ...clamp, easing: Easing.bezier(0.3, 0, 0.1, 1) });
    if (open < 1) {
      const z = 0.94 + 0.06 * unlock;
      ctx.fillStyle = "#000";
      ctx.fillRect(0, 0, 1206, 2622);
      ctx.drawImage(images[heroHome(U)], 603 - 603 * z, 1311 - 1311 * z, 1206 * z, 2622 * z);
      if (unlock < 1) ctx.drawImage(images[LOCK], 0, -2622 * unlock);
      // Tap pulse on « Scanner » (f2070 = local 150).
      const ring = interpolate(frame, [150, 168], [0, 1], { ...clamp, easing: ease.split });
      if (frame >= 150 && ring < 1) {
        ctx.save();
        ctx.strokeStyle = `rgba(255,224,204,${0.95 * (1 - ring)})`;
        ctx.lineWidth = 8;
        ctx.shadowColor = "rgba(255,224,204,0.8)";
        ctx.shadowBlur = 24;
        const g = 1 + 0.25 * ring;
        ctx.beginPath();
        ctx.roundRect(PILL.x - (PILL.w * g) / 2, PILL.y - (PILL.h * g) / 2, PILL.w * g, PILL.h * g, (PILL.h * g) / 2);
        ctx.stroke();
        ctx.restore();
      }
    }
    if (open > 0) {
      // The flow opens from the widget's rect: « Ajouter un aliment », then the camera sheet slides over it.
      const [mx, my, mw, mh] = MACROS;
      const r: Rect = [mx * (1 - open), my * (1 - open), mw + (1206 - mw) * open, mh + (2622 - mh) * open];
      ctx.save();
      ctx.beginPath();
      ctx.roundRect(...r, 60 * (1 - open) + 10);
      ctx.clip();
      ctx.drawImage(images[SEARCH], ...r);
      ctx.restore();
      const slide = interpolate(frame, [207, 235], [1, 0], { ...clamp, easing: Easing.bezier(0.2, 0.9, 0.25, 1) });
      if (frame >= 207) {
        const top = 2622 * slide;
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, top, 1206, 2622);
        ctx.clip();
        // The camera view: the label in daylight, drifting as a hand would, settling in the square on f270.
        const bg = ctx.createRadialGradient(SQUARE.x, SQUARE.y + top, 100, SQUARE.x, SQUARE.y + top, 1500);
        bg.addColorStop(0, "#DCDCDF");
        bg.addColorStop(1, "#56565B");
        ctx.fillStyle = bg;
        ctx.fillRect(0, top, 1206, 2622);
        const settle = interpolate(frame, [215, 270], [0, 1], { ...clamp, easing: Easing.bezier(0.25, 0.1, 0, 1) });
        const drift = 1 - settle;
        const lw = 560 + 60 * settle;
        const lx = SQUARE.x + 210 * drift + 18 * Math.sin(frame / 9) * drift;
        const ly = SQUARE.y + top + 330 * drift + 14 * Math.cos(frame / 11) * drift;
        ctx.translate(lx, ly);
        ctx.rotate(0.22 * drift);
        ctx.shadowColor = "rgba(0,0,0,0.25)";
        ctx.shadowBlur = 30;
        ctx.drawImage(labelPicture, -lw / 2, (-lw * 400) / 640 / 2, lw, (lw * 400) / 640);
        ctx.restore();
        ctx.drawImage(images[CHROME], 0, top);
      }
      // The quantity sheet rises over the scanner (iOS spring, 300–330).
      const rise = interpolate(frame, [300, 330], [1, 0], { ...clamp, easing: Easing.bezier(0.2, 0.9, 0.25, 1) });
      if (frame >= 300) {
        ctx.fillStyle = `rgba(0,0,0,${0.35 * (1 - rise)})`;
        ctx.fillRect(0, 0, 1206, 2622);
        ctx.drawImage(images[SHEET], 0, SHEET_TOP, 1206, 2622 - SHEET_TOP, 0, SHEET_TOP + 2432 * rise, 1206, 2622 - SHEET_TOP);
      }
    }
    screen.texture.needsUpdate = true;
  }

  const cam = cameraAt(frame);
  const light = interpolate(frame, [0, 4], [0.82, 1], clamp);
  const turn = interpolate(frame, [0, 89, 300], [-0.35, 0.35, 0.6], { ...clamp, easing: [Easing.bezier(0.3, 0, 0.6, 1), Easing.linear] });
  const labelBlur = interpolate(frame, [90, 130], [0, 10], clamp);
  const pillAt = project(
    new THREE.Vector3((PILL.x / 1206 - 0.5) * SCREEN.w, (0.5 - PILL.y / 2622) * SCREEN.h, PHONE.d / 2).add(phoneAt),
    cam.position,
    cam.target,
    cam.lens,
  );

  // Shot 17: the sheet lifts off the glass to a 940 px pane (330–366); « Enregistrer » tapped on f390.
  const sheetPane = (() => {
    const s = 940 / 1206;
    return { x: (W - 940) / 2, y: 40, s };
  })();
  const lift = interpolate(frame, [330, 366], [0, 1], { ...clamp, easing: ease.lift });
  // Frontal phone centred on the target: capture px → frame px is a plain scale.
  const glassS = (H / (2 * cam.position.distanceTo(cam.target) * (18 / cam.lens))) * (SCREEN.w / 1206);
  const glassRect = { x: AXIS - 603 * glassS, y: H / 2 - (1311 - SHEET_TOP) * glassS, s: glassS };
  const pane = {
    x: glassRect.x + (sheetPane.x - glassRect.x) * lift,
    y: glassRect.y + (sheetPane.y - glassRect.y) * lift - Math.sin(Math.PI * lift) * 40,
    s: glassRect.s + (sheetPane.s - glassRect.s) * lift,
  };
  const phoneOut = interpolate(frame, [330, 354, 400, 420], [1, 0.55, 0.55, 0], clamp);
  const phoneBlur = interpolate(frame, [330, 354], [0, 8], clamp);
  const tap = interpolate(frame, [390, 408], [0, 1], { ...clamp, easing: ease.split });

  // Shot 18 (420–): the Split opens the frame on the numbers; the blade of 450 turns them before → after.
  const split = interpolate(frame, [420, 450], [0, 1], { ...clamp, easing: ease.chapter });
  const blade = interpolate(frame, [450, 470], [0, 1], { ...clamp, easing: Easing.bezier(0.45, 0, 0.55, 1) });
  const fan = interpolate(frame, [420, 452], [0, 1], { ...clamp, easing: ease.lift });

  const sheetLayer = (half?: "left" | "right") => (
    <div
      style={{
        position: "absolute",
        left: pane.x,
        top: pane.y,
        width: 1206 * pane.s,
        height: (2622 - SHEET_TOP) * pane.s,
        borderRadius: 44,
        overflow: "hidden",
        boxShadow: `0 ${30 * lift}px ${80 * lift}px rgba(0,0,0,${0.6 * lift})`,
        clipPath:
          half === "left"
            ? `inset(0 ${AXIS - pane.x < 0 ? 0 : 1206 * pane.s - (AXIS - pane.x)}px 0 0)`
            : half === "right"
              ? `inset(0 0 0 ${AXIS - pane.x}px)`
              : undefined,
        translate: half === "left" ? `${-600 * split}px 0px` : half === "right" ? `${600 * split}px 0px` : undefined,
        scale: half ? `${1 - 0.12 * split}` : undefined,
        filter: half ? `blur(${12 * split}px)` : undefined,
      }}
    >
      <Img src={staticFile(SHEET)} style={{ position: "absolute", left: 0, top: -SHEET_TOP * pane.s, width: 1206 * pane.s }} />
      {frame >= 390 && tap < 1 && (
        <div
          style={{
            position: "absolute",
            left: (SAVE.x - SAVE.w / 2) * pane.s,
            top: (SAVE.y - SAVE.h / 2 - SHEET_TOP) * pane.s,
            width: SAVE.w * pane.s,
            height: SAVE.h * pane.s,
            borderRadius: (SAVE.h * pane.s) / 2,
            border: `3px solid ${C.peach}`,
            boxShadow: "0 0 24px 4px rgba(255,224,204,0.5)",
            scale: `${1 + 0.2 * tap}`,
            opacity: 0.95 * (1 - tap),
          }}
        />
      )}
    </div>
  );

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      {ready && frame < 420 && (
        <>
          <AbsoluteFill style={{ filter: `blur(${labelBlur}px)`, opacity: frame < 330 ? 1 : phoneOut }}>
            <ThreeCanvas width={W} height={H}>
              <StudioEnvironment variant="daylight" />
              <directionalLight position={[60, 600, 160]} intensity={2.2 * light} />
              <ambientLight intensity={0.25 * light} />
              <CameraLook lens={cam.lens} position={cam.position} target={cam.target} />
              <mesh rotation={[-Math.PI / 2, 0, 0]}>
                <planeGeometry args={[1400, 1400]} />
                <meshBasicMaterial map={pool} toneMapped={false} color={new THREE.Color(light, light, light)} />
              </mesh>
              <BarcodeLabel rotationY={turn} position={[0, (LABEL.h * SCALE) / 2, 0]} scale={SCALE} />
            </ThreeCanvas>
          </AbsoluteFill>
          <AbsoluteFill
            style={{
              background: `radial-gradient(ellipse 760px 1150px at ${AXIS}px ${H * 0.52}px, transparent 55%, rgba(0,0,0,0.85) 100%)`,
            }}
          />
          {frame >= 90 && (
            <AbsoluteFill style={{ filter: `blur(${phoneBlur}px) brightness(${frame < 330 ? 1 : phoneOut})` }}>
              <ThreeCanvas width={W} height={H}>
                <StudioEnvironment />
                <CameraLook lens={cam.lens} position={cam.position} target={cam.target} />
                <Phone3D yaw={0} position={[phoneAt.x, phoneAt.y, phoneAt.z]} screen={screen.texture} screenOn={1} />
              </ThreeCanvas>
            </AbsoluteFill>
          )}
        </>
      )}
      <Callout label="Scanner" at={[pillAt[0], pillAt[1] - 70]} labelY={pillAt[1] - 190} from={120} to={174} />

      {/* Shot 18: the numbers, before → after. */}
      {frame >= 420 && <Numbers fan={fan} blade={blade} frame={frame} />}
      {frame >= 450 && frame < 470 && <Seam x={W * blade} top={420} height={1100} spread={0.6} />}

      {frame >= 330 && frame < 420 && sheetLayer()}
      {frame >= 420 && frame < 452 && (
        <>
          {sheetLayer("left")}
          {sheetLayer("right")}
          <Seam x={AXIS - 600 * split} top={0} height={H} intensity={1 - split} spread={0.5} />
          <Seam x={AXIS + 600 * split} top={0} height={H} intensity={1 - split} spread={0.5} />
        </>
      )}
      <Grain />
      {audio && <FilmAudio from={1920} />}
    </AbsoluteFill>
  );
};

/** Four real crops of the Nutrition home in a staggered depth stack (§5.2 shot 18). */
const CROPS: { name: string; src: Rect; at: [number, number]; scale: number; depth: number }[] = [
  { name: "Calories left", src: [90, 730, 480, 470], at: [70, 620], scale: 1.08, depth: 0 },
  { name: "Protein", src: [100, 1228, 330, 184], at: [600, 560], scale: 1.12, depth: 1 },
  { name: "Carbs", src: [440, 1228, 330, 184], at: [620, 860], scale: 1.06, depth: 2 },
  { name: "Fat", src: [780, 1228, 330, 184], at: [640, 1140], scale: 1.0, depth: 3 },
];

const Crop: React.FC<{ file: string; c: (typeof CROPS)[number]; fan: number }> = ({ file, c, fan }) => {
  const [sx, sy, sw, sh] = c.src;
  const w = sw * c.scale;
  const h = sh * c.scale;
  return (
    <div
      style={{
        position: "absolute",
        left: c.at[0],
        top: c.at[1] + (1 - fan) * 120 * (c.depth + 1),
        width: w,
        height: h,
        overflow: "hidden",
        borderRadius: 28,
        background: "#1E1A19",
        boxShadow: "0 30px 70px rgba(0,0,0,0.55)",
        opacity: fan,
        filter: `blur(${c.depth * 0.6}px) brightness(${1 - c.depth * 0.06})`,
      }}
    >
      <Img src={staticFile(file)} style={{ position: "absolute", left: -sx * c.scale, top: -sy * c.scale, width: 1206 * c.scale }} />
    </div>
  );
};

const Numbers: React.FC<{ fan: number; blade: number; frame: number }> = ({ fan, blade, frame }) => (
  <AbsoluteFill>
    <AbsoluteFill
      style={{ background: `radial-gradient(ellipse 800px 900px at ${AXIS}px ${H * 0.45}px, #3A2618, transparent 75%)`, opacity: 0.06 }}
    />
    {CROPS.map((c) => (
      <Crop key={c.name} file={BEFORE} c={c} fan={fan} />
    ))}
    <AbsoluteFill style={{ clipPath: `inset(0 ${W * (1 - blade)}px 0 0)` }}>
      {CROPS.map((c) => (
        <Crop key={c.name} file={AFTER} c={c} fan={fan} />
      ))}
    </AbsoluteFill>
    {CROPS.map((c, i) => {
      const w = c.src[2] * c.scale;
      const x = c.at[0] + w / 2;
      return <Callout key={c.name} label={c.name} at={[x, c.at[1] - 10]} labelY={c.at[1] - 70} from={456 + 6 * i} to={576} />;
    })}
    {void frame}
  </AbsoluteFill>
);
