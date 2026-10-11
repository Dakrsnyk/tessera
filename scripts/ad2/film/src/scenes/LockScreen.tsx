import { Audio } from "@remotion/media";
import { useThree } from "@react-three/fiber";
import { ThreeCanvas } from "@remotion/three";
import { useMemo } from "react";
import { AbsoluteFill, Easing, Img, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import * as THREE from "three";
import { Callout } from "../components/Callout";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, Phone3D, phoneMatrix, SCREEN, screenPoint, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { imageTexture, useImages } from "../lib/useImages";

const LOCK = "kit/lock-crepuscule.png";
const REST = [0, 1, 2, 3, 4].map((i) => `kit/live-rest-real-${String(i).padStart(3, "0")}.png`);
const AFTER = [0, 1].map((i) => `kit/live-afterset-real-${String(i).padStart(3, "0")}.png`);
const FILES = [LOCK, ...REST, ...AFTER];

/** Ambient tint: the Live Activity's own colour, desaturated 40 %, at most 6 % spill. */
const TINT = "#3A2A24";
/** The Live Activity's slot on the Lock Screen (px of the 1206 × 2622 capture), above the bottom buttons. */
const SLOT = { x: 45, y: 1790, w: 1116, h: 465, r: 66 };
const LA_MM = { w: (SLOT.w / 1206) * SCREEN.w, h: (SLOT.h / 2622) * SCREEN.h };
/** Lifted: 1000 px wide (§2.5 minimum for a Live Activity), centred. */
const RECT = { x: AXIS - 500, y: H / 2 - (1000 * SLOT.h) / SLOT.w / 2, w: 1000, h: (1000 * SLOT.h) / SLOT.w };
/** Points read off the capture (fractions of the Live Activity): the countdown, the « Série faite » button. */
const COUNTDOWN_X = 976 / 1116;
const BUTTON = { x0: 750 / 1116, x1: 1060 / 1116, y0: 303 / 465, y1: 416 / 465 };
const PITCH = -60;
const LENS = 135;

/** Local timeline (frame 0 = f1560 of the main film, 26.0 s). */
const T = { detach: 102, lifted: 138, tap: 270, bladeEnd: 282, dock: 300, docked: 330 };

/** The Live Activity on screen: the real 1 Hz countdown (a new second every 60 frames, on the beats), then
 * after « Série faite » the real after-state (next set, the rest restarted at 2:00, 1:59 on f330). */
const laFile = (f: number) =>
  f < T.bladeEnd ? REST[Math.min(4, Math.max(0, Math.floor(f / 60)))] : f < T.docked ? AFTER[0] : AFTER[1];

/** Lift progress: detaches f102–138 (0.3, 0, 0.1, 1), docks back f300–330. */
const liftAt = (f: number) =>
  f < T.dock
    ? interpolate(f, [T.detach, T.lifted], [0, 1], { ...clamp, easing: ease.lift })
    : interpolate(f, [T.dock, T.docked], [1, 0], { ...clamp, easing: Easing.bezier(0.5, 0, 0.2, 1) });

/** The camera: glides along the glass from the clock to the Live Activity, holds (micro push 2 %), lifts away. */
const cameraAt = (f: number) => {
  const m = phoneMatrix(0, PITCH);
  const clock = screenPoint(603, 430, 0).applyMatrix4(m);
  const slot = screenPoint(SLOT.x + SLOT.w / 2, SLOT.y + SLOT.h / 2, 0).applyMatrix4(m);
  const glide = interpolate(f, [0, 84], [0, 1], { ...clamp, easing: ease.transfer });
  const target = clock.clone().lerp(slot, glide);
  const elevation = interpolate(f, [300, 359], [0.33, 0.62], { ...clamp, easing: Easing.bezier(0.45, 0, 0.6, 1) });
  const distance = interpolate(f, [0, 138, 300, 359], [572, 554, 543, 650], {
    ...clamp,
    easing: [ease.arrival, Easing.linear, Easing.bezier(0.45, 0, 0.6, 1)],
  });
  const dir = new THREE.Vector3(0, elevation, 1).normalize();
  return { position: target.clone().add(dir.multiplyScalar(distance)), target };
};

/** The Live Activity off the glass: from its slot on the phone to 1000 px in front of the camera, on a slight arc. */
const LiftedActivity: React.FC<{ p: number; texture: THREE.Texture }> = ({ p, texture }) => {
  const { camera } = useThree();
  const start = new THREE.Vector3();
  const startQ = new THREE.Quaternion();
  const m = phoneMatrix(0, PITCH);
  start.copy(screenPoint(SLOT.x + SLOT.w / 2, SLOT.y + SLOT.h / 2, 0.6).applyMatrix4(m));
  m.decompose(new THREE.Vector3(), startQ, new THREE.Vector3());
  const cam = camera as THREE.PerspectiveCamera;
  // Distance at which the layer is exactly RECT.w pixels wide.
  const d = (LA_MM.w * H) / (RECT.w * 2 * Math.tan(THREE.MathUtils.degToRad(lensFov(LENS)) / 2));
  const forward = new THREE.Vector3(0, 0, -1).applyQuaternion(cam.quaternion);
  const up = new THREE.Vector3(0, 1, 0).applyQuaternion(cam.quaternion);
  const end = cam.position.clone().add(forward.multiplyScalar(d));
  // Rises about 40 px on the way and settles.
  const position = start.clone().lerp(end, p).add(up.multiplyScalar(Math.sin(Math.PI * p) * 2.5));
  const quaternion = startQ.clone().slerp(cam.quaternion, p);
  return (
    <mesh position={position} quaternion={quaternion}>
      <planeGeometry args={[LA_MM.w, LA_MM.h]} />
      <meshBasicMaterial map={texture} transparent toneMapped={false} depthWrite={false} />
    </mesh>
  );
};

export const LockScreen: React.FC = () => {
  const frame = useCurrentFrame();
  const images = useImages(FILES);
  const canvas = useMemo(() => {
    const c = document.createElement("canvas");
    c.width = 1206;
    c.height = 2622;
    return c;
  }, []);
  const screen = useMemo(() => {
    const t = new THREE.CanvasTexture(canvas);
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = 8;
    return t;
  }, [canvas]);
  const textures = useMemo(() => (images ? Object.fromEntries(FILES.map((f) => [f, imageTexture(images[f])])) : null), [images]);

  const p = liftAt(frame);
  const lifted = frame >= T.detach && frame < T.docked;

  // The screen: the Lock Screen, and the Live Activity in its slot (a socket of light while it is lifted).
  if (images) {
    const ctx = canvas.getContext("2d")!;
    ctx.globalAlpha = 1;
    ctx.filter = "none";
    ctx.drawImage(images[LOCK], 0, 0);
    if (!lifted) {
      // Lift prelude: a 2 px blade draws down the left edge (f90–96), then crosses it, +8 % exposure behind it.
      const crossing = interpolate(frame, [96, 102], [0, 1], clamp);
      if (crossing > 0 && frame < T.detach) {
        ctx.drawImage(images[laFile(frame)], SLOT.x, SLOT.y);
        ctx.save();
        ctx.beginPath();
        ctx.rect(SLOT.x, SLOT.y, SLOT.w * crossing, SLOT.h);
        ctx.clip();
        ctx.filter = "brightness(1.08)";
        ctx.drawImage(images[laFile(frame)], SLOT.x, SLOT.y);
        ctx.restore();
      } else {
        ctx.drawImage(images[laFile(frame)], SLOT.x, SLOT.y);
      }
      const edge = interpolate(frame, [90, 96], [0, 1], clamp);
      const bladeX = frame < 96 ? SLOT.x : SLOT.x + SLOT.w * crossing;
      if (frame >= 90 && frame < T.detach) {
        ctx.fillStyle = "rgba(255,244,236,0.95)";
        ctx.shadowColor = C.peach;
        ctx.shadowBlur = 24;
        ctx.fillRect(bladeX - 3, SLOT.y, 6, SLOT.h * (frame < 96 ? edge : 1));
        ctx.shadowBlur = 0;
      }
      // Dock: the socket flashes 30 % for 4 frames on contact, then a blade seals it right to left.
      const flash = interpolate(frame, [T.docked, T.docked + 4], [0.3, 0], clamp);
      if (frame >= T.docked && flash > 0) {
        ctx.fillStyle = `rgba(255,224,204,${flash})`;
        ctx.beginPath();
        ctx.roundRect(SLOT.x, SLOT.y, SLOT.w, SLOT.h, SLOT.r);
        ctx.fill();
      }
      const seal = interpolate(frame, [T.docked + 4, T.docked + 16], [0, 1], { ...clamp, easing: ease.split });
      if (frame >= T.docked + 4 && seal < 1) {
        ctx.fillStyle = "rgba(255,244,236,0.95)";
        ctx.shadowColor = C.peach;
        ctx.shadowBlur = 24;
        ctx.fillRect(SLOT.x + SLOT.w * (1 - seal) - 3, SLOT.y, 6, SLOT.h);
        ctx.shadowBlur = 0;
      }
    } else {
      // The empty slot glows as a socket (peach inner glow 18 %).
      ctx.save();
      ctx.beginPath();
      ctx.roundRect(SLOT.x, SLOT.y, SLOT.w, SLOT.h, SLOT.r);
      ctx.fillStyle = "rgba(10,8,8,0.55)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(255,224,204,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 40;
      ctx.strokeStyle = "rgba(255,224,204,0.18)";
      ctx.stroke();
      ctx.restore();
    }
    screen.needsUpdate = true;
  }

  const cam = cameraAt(frame);
  const wake = interpolate(frame, [0, 22], [0.25, 1], { ...clamp, easing: Easing.bezier(0.2, 0, 0.2, 1) });
  const sleep = interpolate(frame, [336, 356], [1, 0], { ...clamp, easing: Easing.bezier(0.4, 0, 0.8, 1) });
  // Focus: the LA plane is sharp once the glide lands; the far end of the glass (the clock) stays soft.
  const focusBlur = interpolate(frame, [36, 60], [6, 0], { ...clamp, easing: ease.transfer });
  const liftBlur = interpolate(frame, [T.detach, T.detach + 24, T.dock, T.dock + 26], [0, 10, 10, 0], clamp);
  const dim = interpolate(frame, [T.detach, T.detach + 24, T.dock, T.dock + 26], [1, 0.5, 0.5, 1], clamp);

  // Tap pulse on « Série faite » (f270, 18 frames), then the blade outward from the button (12 frames).
  const btn = {
    x: RECT.x + BUTTON.x0 * RECT.w,
    y: RECT.y + BUTTON.y0 * RECT.h,
    w: (BUTTON.x1 - BUTTON.x0) * RECT.w,
    h: (BUTTON.y1 - BUTTON.y0) * RECT.h,
  };
  const btnX = btn.x + btn.w / 2;
  const ring = interpolate(frame, [T.tap, T.tap + 18], [0, 1], { ...clamp, easing: ease.split });
  const blade = interpolate(frame, [T.tap, T.bladeEnd], [0, 1], { ...clamp, easing: Easing.bezier(0.45, 0, 0.2, 1) });
  const xL = btnX - blade * (btnX - RECT.x);
  const xR = btnX + blade * (RECT.x + RECT.w - btnX);

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      <AbsoluteFill
        style={{ background: `radial-gradient(ellipse 800px 700px at ${AXIS}px ${H / 2}px, ${TINT}, transparent 75%)`, opacity: 0.06 * sleep }}
      />
      <AbsoluteFill style={{ filter: `blur(${focusBlur + liftBlur}px) brightness(${dim})` }}>
        {/* Mounted once the pictures are decoded: the canvas only redraws when the frame changes. */}
        {images && (
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={LENS} position={cam.position} target={cam.target} />
            <Phone3D yaw={0} pitch={PITCH} screen={screen} screenOn={wake * sleep} />
          </ThreeCanvas>
        )}
      </AbsoluteFill>
      {/* Depth of field of the macro lens: the far part of the glass (top of frame) stays soft. */}
      <AbsoluteFill
        style={{
          backdropFilter: "blur(7px)",
          maskImage: "linear-gradient(to bottom, black 0%, black 18%, transparent 46%)",
          WebkitMaskImage: "linear-gradient(to bottom, black 0%, black 18%, transparent 46%)",
          opacity: lifted ? 0 : 1,
        }}
      />
      {lifted && textures && (
        <ThreeCanvas width={W} height={H} style={{ position: "absolute", inset: 0 }}>
          <CameraLook lens={LENS} position={cam.position} target={cam.target} />
          <LiftedActivity p={p} texture={textures[laFile(frame)]} />
        </ThreeCanvas>
      )}

      {/* The real after-state behind the blade, outward from the button. */}
      {frame >= T.tap && frame < T.bladeEnd && (
        <>
          <Img
            src={staticFile(AFTER[0])}
            style={{
              position: "absolute",
              left: RECT.x,
              top: RECT.y,
              width: RECT.w,
              height: RECT.h,
              clipPath: `inset(0px ${RECT.x + RECT.w - xR}px 0px ${xL - RECT.x}px)`,
            }}
          />
          <Seam x={xL} top={RECT.y} height={RECT.h} spread={0.45} />
          <Seam x={xR} top={RECT.y} height={RECT.h} spread={0.45} />
        </>
      )}
      {frame >= T.tap && ring < 1 && (
        <div
          style={{
            position: "absolute",
            left: btn.x,
            top: btn.y,
            width: btn.w,
            height: btn.h,
            borderRadius: btn.h / 2,
            border: `3px solid ${C.peach}`,
            boxShadow: `0 0 24px 4px rgba(255,224,204,0.5)`,
            scale: `${1 + ring * 0.18}`,
            opacity: 0.95 * (1 - ring),
          }}
        />
      )}

      <Callout label="Rest" at={[RECT.x + COUNTDOWN_X * RECT.w, RECT.y - 8]} labelY={RECT.y - 110} from={140} to={216} />
      <Callout label="Set done" at={[btnX, RECT.y + RECT.h + 8]} labelY={RECT.y + RECT.h + 108} from={234} to={276} />
      <SplitText from={288} exitAt={336} top={1330} height={100}>
        <span style={type.super}>Without opening the app.</span>
      </SplitText>
      <Grain />

      <Audio src={staticFile("sfx/lock.wav")} />
      <Sequence from={38} layout="none">
        <Audio src={staticFile("vo/main-V7.wav")} />
      </Sequence>
      <Sequence from={220} layout="none">
        <Audio src={staticFile("vo/main-V8.wav")} />
      </Sequence>
    </AbsoluteFill>
  );
};
