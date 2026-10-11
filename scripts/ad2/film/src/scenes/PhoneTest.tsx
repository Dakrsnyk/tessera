import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, staticFile, useCurrentFrame } from "remotion";
import { CameraRig, Phone3D, StudioEnvironment } from "../components/Phone3D";
import { H, W } from "../lib/brand";
import { useImageTexture } from "../lib/useTexture";

/** Look-development of the phone: frame 0 edge-on, 1 three-quarter, 2 frontal. */
export const PhoneTest: React.FC = () => {
  const frame = useCurrentFrame();
  const screen = useImageTexture(staticFile("test-screen.png"));
  const yaw = [90, 35, 0][frame] ?? 0;
  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      <ThreeCanvas width={W} height={H}>
        <StudioEnvironment />
        <CameraRig lens={85} distance={460} height={14} />
        <Phone3D yaw={frame === 2 ? 0 : yaw} pitch={frame === 2 ? -60 : 0} screen={screen} screenOn={frame === 0 ? 0 : 1} />
      </ThreeCanvas>
    </AbsoluteFill>
  );
};
