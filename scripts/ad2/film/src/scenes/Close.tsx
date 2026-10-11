import { Audio } from "@remotion/media";
import { AbsoluteFill, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { ArdaneLogo, LOGO_GAP } from "../components/ArdaneLogo";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, type } from "../lib/brand";

/**
 * Shots 24–25 of the main film (f3180–3479, 53.0–58.0 s), as frames 0–299.
 * The edge-on line holds at the centre, contracts into the gap of the « A »; the white half grows out
 * of it on D5 (f60 = f3240), the peach half on A5 (f90: the eighth rest is the gap), the coral light
 * blooms in the gap, then the end card: wordmark, CTA (V17 « Coming soon to the App Store »), tagline.
 */
export const LOGO = { size: 300, cx: AXIS, cy: 700 };
const SLOT_TOP = LOGO.cy - LOGO.size / 2 + LOGO_GAP.top * LOGO.size;
const SLOT_HEIGHT = (LOGO_GAP.bottom - LOGO_GAP.top) * LOGO.size;

export const Close: React.FC = () => {
  const frame = useCurrentFrame();

  // The line: from the phone seen edge-on (1500 px tall, centred) into the gap of the logo.
  const lineTop = interpolate(frame, [0, 66], [210, SLOT_TOP], { ...clamp, easing: ease.transfer });
  const lineHeight = interpolate(frame, [0, 66], [1500, SLOT_HEIGHT], { ...clamp, easing: ease.transfer });
  const lineIntensity = interpolate(frame, [96, 150], [1, 0.4], { ...clamp, easing: ease.arrival });

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

      <Audio src={staticFile("sfx/close.wav")} />
      <Sequence from={72} layout="none">
        <Audio src={staticFile("vo/main-V16.wav")} />
      </Sequence>
      <Sequence from={132} layout="none">
        <Audio src={staticFile("vo/main-V17.wav")} />
      </Sequence>
    </AbsoluteFill>
  );
};
