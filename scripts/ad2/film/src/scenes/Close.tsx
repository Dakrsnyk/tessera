import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, interpolate } from "remotion";
import * as THREE from "three";
import { ArdaneLogo, LOGO_GAP } from "../components/ArdaneLogo";
import { FilmAudio } from "../components/FilmAudio";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { heroHome } from "../lib/kit";
import { useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { useFilmFrame } from "../lib/time";

const HOME = heroHome("crepuscule");

/**
 * Shots 24–25 of the main film (f3180–3479, 53.0–58.0 s), as frames 0–299.
 * The phone (the final Home, as the merge left it) turns edge-on and becomes the line (f0–50, dolly in
 * 10 %); the line contracts into the gap of the « A »; the white half grows out
 * of it on D5 (f60 = f3240), the peach half on A5 (f90: the eighth rest is the gap), the coral light
 * blooms in the gap, then the end card: wordmark, CTA (V17 « Coming soon to the App Store »), tagline.
 */
export const LOGO = { size: 300, cx: AXIS, cy: 700 };
const SLOT_TOP = LOGO.cy - LOGO.size / 2 + LOGO_GAP.top * LOGO.size;
const SLOT_HEIGHT = (LOGO_GAP.bottom - LOGO_GAP.top) * LOGO.size;

export const Close: React.FC<{ audio?: boolean }> = ({ audio = true }) => {
  const frame = useFilmFrame();
  const images = useImages([HOME]);
  const screen = useCanvasTexture();
  if (images) {
    screen.ctx.drawImage(images[HOME], 0, 0);
    screen.texture.needsUpdate = true;
  }

  // The edge turn: yaw 0 → 90° with a 10 % dolly in, from the merge's framing (50 mm, 63 % of the height).
  const yaw = interpolate(frame, [0, 50], [0, 90], { ...clamp, easing: ease.transfer });
  const fraction = interpolate(frame, [0, 50], [0.632, 0.695], { ...clamp, easing: ease.transfer });
  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(50)) / 2) * fraction);
  const phoneH = H * fraction;
  const phoneFade = interpolate(frame, [44, 56], [1, 0], clamp);
  // The line: the rail catches the light as the phone goes edge-on, then contracts into the gap of the logo.
  const edgeOn = interpolate(yaw, [66, 88], [0, 1], { ...clamp, easing: ease.transfer });
  const lineTop = interpolate(frame, [48, 66], [H / 2 - phoneH * 0.48, SLOT_TOP], { ...clamp, easing: ease.transfer });
  const lineHeight = interpolate(frame, [48, 66], [phoneH * 0.96, SLOT_HEIGHT], { ...clamp, easing: ease.transfer });
  const lineIntensity = edgeOn * interpolate(frame, [96, 150], [1, 0.4], { ...clamp, easing: ease.arrival });

  const left = interpolate(frame, [60, 96], [0, 1], { ...clamp, easing: ease.split });
  const right = interpolate(frame, [90, 126], [0, 1], { ...clamp, easing: ease.split });
  const glow = interpolate(frame, [90, 170], [0, 1], { ...clamp, easing: ease.arrival });
  // Slow dolly on the mark only (type lives in its own screen-space plane): < 4 % per second.
  const push = interpolate(frame, [0, 299], [1.0, 1.035], clamp);

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(circle 450px at ${LOGO.cx}px ${LOGO.cy}px, ${C.lifted}, ${C.void})`,
        }}
      />
      {images && phoneFade > 0 && (
        <AbsoluteFill style={{ opacity: phoneFade }}>
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={50} position={new THREE.Vector3(0, 0, distance)} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={yaw} screen={screen.texture} screenOn={1} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}
      <AbsoluteFill style={{ scale: `${push}`, transformOrigin: `${LOGO.cx}px ${LOGO.cy}px` }}>
        <ArdaneLogo {...LOGO} left={left} right={right} glow={glow} />
        <Seam x={AXIS} top={lineTop} height={lineHeight} intensity={lineIntensity} />
      </AbsoluteFill>

      <SplitText from={96} top={905} height={150}>
        <span style={type.wordmark}>Ardane</span>
      </SplitText>
      <SplitText from={120} top={1212} height={76}>
        <div
          style={{
            ...type.cta,
            color: C.type1,
            height: 76,
            padding: "0 40px",
            borderRadius: 38,
            border: `1.5px solid rgba(255,255,255,0.55)`,
            display: "flex",
            alignItems: "center",
            boxSizing: "border-box",
          }}
        >
          Coming soon to the App Store
        </div>
      </SplitText>
      <SplitText from={170} top={1062} height={56}>
        <span style={type.tagline}>Life’s essentials, designed around you.</span>
      </SplitText>

      <Grain />

      {audio && <FilmAudio from={3180} />}
    </AbsoluteFill>
  );
};
