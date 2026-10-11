import { ThreeCanvas } from "@remotion/three";
import { useMemo } from "react";
import { AbsoluteFill, Easing, interpolate } from "remotion";
import * as THREE from "three";
import { Grain } from "../components/Grain";
import { CameraLook, StudioEnvironment } from "../components/Phone3D";
import { BarcodeLabel, LABEL } from "../components/Barcode";
import { AXIS, C, clamp, ease, H, useFontsReady, W } from "../lib/brand";
import { useFilmFrame } from "../lib/time";

/** The daylight pool on the floor: #F2F2F4 at its heart, falling off to black. */
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
  // The label's contact shadow: a long thin ellipse under its standing edge.
  ctx.save();
  ctx.translate(512, 512);
  ctx.scale(1, 0.2);
  const s = ctx.createRadialGradient(0, 0, 0, 0, 0, 52);
  s.addColorStop(0, "rgba(0,0,0,0.5)");
  s.addColorStop(0.6, "rgba(0,0,0,0.2)");
  s.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = s;
  ctx.fillRect(-60, -60, 120, 120);
  ctx.restore();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
};

const Floor: React.FC<{ light: number }> = ({ light }) => {
  const tex = useMemo(poolTexture, []);
  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]}>
      <planeGeometry args={[1400, 1400]} />
      <meshBasicMaterial map={tex} toneMapped={false} color={new THREE.Color(light, light, light)} />
    </mesh>
  );
};

/** The label at 1.6× (about 10 cm wide), standing on the pool. */
const SCALE = 1.6;

/**
 * Shot 14 of the main film (f1920–2009, 32.0–33.5 s): S5 « Daylight ». The light snaps on at f1920 (the
 * brightest image of the film): a printed barcode, and nothing else, turns 40° on the pool while the camera
 * dollies in. No product: everyone knows what a barcode is (decision of 2026-10-11).
 */
export const Daylight: React.FC = () => {
  const frame = useFilmFrame();
  const fonts = useFontsReady();
  // Light on: instant, with a 4-frame settle (a softbox, not a fade).
  const light = interpolate(frame, [0, 4], [0.82, 1], clamp);
  const turn = interpolate(frame, [0, 89], [-0.35, 0.35], { ...clamp, easing: Easing.bezier(0.3, 0, 0.6, 1) });
  const dolly = interpolate(frame, [0, 89], [980, 900], { ...clamp, easing: ease.arrival });
  const centre = (LABEL.h * SCALE) / 2;
  const target = new THREE.Vector3(0, centre, 0);
  const position = new THREE.Vector3(0, centre + dolly * 0.24, dolly);

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      {fonts && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment variant="daylight" />
          <directionalLight position={[60, 600, 160]} intensity={2.2 * light} />
          <ambientLight intensity={0.25 * light} />
          <CameraLook lens={85} position={position} target={target} />
          <Floor light={light} />
          <BarcodeLabel rotationY={turn} position={[0, centre, 0]} scale={SCALE} />
        </ThreeCanvas>
      )}
      {/* Frame edges fall to black (the pool is the only bright surface). */}
      <AbsoluteFill
        style={{ background: `radial-gradient(ellipse 760px 1150px at ${AXIS}px ${H * 0.52}px, transparent 55%, rgba(0,0,0,0.85) 100%)` }}
      />
      <Grain />
    </AbsoluteFill>
  );
};
