// The procedural iPhone (§2.3): titanium rails, black front glass, the real capture as an emissive
// screen, frosted back glass. Units are millimetres (iPhone 16 Pro: 71.5 × 149.6 × 8.25).
import { useThree } from "@react-three/fiber";
import { useLayoutEffect, useMemo } from "react";
import * as THREE from "three";
import { C } from "../lib/brand";

export const PHONE = { w: 71.5, h: 149.6, d: 8.25, r: 11.6 };
/** Screen of the 1206 × 2622 simctl captures (aspect 0.46), centred, uniform black border around it. */
export const SCREEN = { w: 66.6, h: 66.6 * (2622 / 1206), r: 9.4 };

const roundedRect = (w: number, h: number, r: number) => {
  const s = new THREE.Shape();
  const x = -w / 2;
  const y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r);
  s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h);
  s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
};

/** A flat rounded rectangle whose UVs span 0…1 over its bounds (so a capture maps edge to edge). */
const panel = (w: number, h: number, r: number) => {
  const g = new THREE.ShapeGeometry(roundedRect(w, h, r), 24);
  const pos = g.attributes.position;
  const uv = g.attributes.uv;
  for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / w + 0.5, pos.getY(i) / h + 0.5);
  uv.needsUpdate = true;
  return g;
};

/** A soft vertical band (Gaussian across x) for glass reflections and the light sweep. */
const bandTexture = (sigma: number) => {
  const canvas = document.createElement("canvas");
  canvas.width = 512;
  canvas.height = 1;
  const ctx = canvas.getContext("2d")!;
  const img = ctx.createImageData(512, 1);
  for (let i = 0; i < 512; i++) {
    const v = Math.round(255 * Math.exp(-(((i / 511 - 0.5) / sigma) ** 2) / 2));
    img.data.set([v, v, v, 255], i * 4);
  }
  ctx.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(canvas);
  t.wrapS = THREE.ClampToEdgeWrapping;
  return t;
};

/**
 * Studio environment rendered once into a PMREM map: two vertical strip softboxes (the warm key 30°
 * camera-left, a dim fill camera-right) and a narrow cool top strip, on black. Every reflection on the
 * titanium reads as a vertical line, the echo of the « A ».
 */
export const StudioEnvironment: React.FC = () => {
  const { gl, scene } = useThree();
  useLayoutEffect(() => {
    const env = new THREE.Scene();
    const strip = (w: number, h: number, color: string, power: number, azimuthDeg: number, elevation = 0, distance = 10) => {
      const m = new THREE.Mesh(
        new THREE.PlaneGeometry(w, h),
        new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(power), side: THREE.DoubleSide }),
      );
      const a = THREE.MathUtils.degToRad(azimuthDeg);
      m.position.set(Math.sin(a) * distance, elevation, Math.cos(a) * distance);
      m.lookAt(0, 0, 0);
      env.add(m);
    };
    // A faint grey studio so the metal is never pure black between the strips.
    env.background = new THREE.Color(0.018, 0.018, 0.02);
    strip(1.8, 16, C.seamWarm, 16, -30);
    strip(0.5, 16, "#FFFFFF", 30, -30);
    strip(1.2, 14, "#FFFFFF", 5, 58);
    strip(1.0, 12, "#FFFFFF", 3, 180 + 30);
    strip(1.0, 12, "#FFFFFF", 2.5, 180 - 40);
    const top = new THREE.Mesh(
      new THREE.PlaneGeometry(10, 0.8),
      new THREE.MeshBasicMaterial({ color: new THREE.Color("#E8F0FF").multiplyScalar(4), side: THREE.DoubleSide }),
    );
    top.position.set(0, 9, 2);
    top.lookAt(0, 0, 0);
    env.add(top);
    const pmrem = new THREE.PMREMGenerator(gl);
    const target = pmrem.fromScene(env, 0.02);
    scene.environment = target.texture;
    return () => {
      scene.environment = null;
      target.dispose();
      pmrem.dispose();
    };
  }, [gl, scene]);
  return null;
};

export type PhoneProps = {
  /** Rotation around the vertical axis in degrees (0 = screen to camera, 90 = edge-on). */
  yaw: number;
  pitch?: number;
  roll?: number;
  position?: [number, number, number];
  screen: THREE.Texture | null;
  /** 0 = screen off (black glass), 1 = lit. */
  screenOn: number;
  /** Light sweep across the glass: −1 = none, 0…1 = band position left to right. */
  sweep?: number;
};

export const Phone3D: React.FC<PhoneProps> = ({ yaw, pitch = 0, roll = 0, position = [0, 0, 0], screen, screenOn, sweep = -1 }) => {
  const geo = useMemo(() => {
    const bevel = { size: 1.5, thickness: 1.05 };
    const body = new THREE.ExtrudeGeometry(roundedRect(PHONE.w - 2 * bevel.size, PHONE.h - 2 * bevel.size, PHONE.r - bevel.size), {
      depth: PHONE.d - 2 * bevel.thickness,
      bevelEnabled: true,
      bevelSize: bevel.size,
      bevelThickness: bevel.thickness,
      bevelSegments: 10,
      curveSegments: 32,
    });
    body.translate(0, 0, -(PHONE.d - 2 * bevel.thickness) / 2);
    body.computeVertexNormals();
    // Buttons on the rails: action and volume on the left, side button and Camera Control on the right.
    const button = (len: number) => {
      const g = new THREE.CapsuleGeometry(0.75, len, 8, 16);
      return g;
    };
    return {
      body,
      glass: panel(PHONE.w - 2.6, PHONE.h - 2.6, PHONE.r - 1.3),
      screen: panel(SCREEN.w, SCREEN.h, SCREEN.r),
      back: panel(PHONE.w - 2.6, PHONE.h - 2.6, PHONE.r - 1.3),
      buttons: [
        { g: button(6), x: -PHONE.w / 2, y: 44 },
        { g: button(12), x: -PHONE.w / 2, y: 30 },
        { g: button(12), x: -PHONE.w / 2, y: 14 },
        { g: button(18), x: PHONE.w / 2, y: 30 },
        { g: button(9), x: PHONE.w / 2, y: -24 },
      ],
    };
  }, []);

  const mat = useMemo(
    () => ({
      titanium: new THREE.MeshPhysicalMaterial({ color: "#8A8781", metalness: 1, roughness: 0.3, anisotropy: 0.6, anisotropyRotation: Math.PI / 2 }),
      // Unlit black glass: with the environment set on the scene, envMapIntensity does not dim a material's
      // reflection, and an infinitely distant studio seen through an 85 mm lens covers the whole glass.
      // Its reflection is the drawn streak (§2.3).
      glass: new THREE.MeshBasicMaterial({ color: "#030304" }),
      back: new THREE.MeshPhysicalMaterial({ color: "#2A2926", metalness: 0.15, roughness: 0.6 }),
      streak: { tex: bandTexture(0.12), sweepTex: bandTexture(0.08) },
    }),
    [],
  );

  const front = PHONE.d / 2;
  // The resting reflection drifts across the glass as the phone turns (like a real softbox would).
  const streakOffset = 0.18 + (yaw / 90) * 0.4;
  mat.streak.tex.offset.x = -streakOffset + 0.5;
  mat.streak.sweepTex.offset.x = sweep < 0 ? 2 : 0.5 - sweep * 1.4 + 0.2;

  return (
    <group
      position={position}
      rotation={[THREE.MathUtils.degToRad(pitch), THREE.MathUtils.degToRad(yaw), THREE.MathUtils.degToRad(roll)]}
    >
      <mesh geometry={geo.body} material={mat.titanium} />
      {geo.buttons.map((b, i) => (
        <mesh key={i} geometry={b.g} material={mat.titanium} position={[b.x, b.y, 0]} scale={[0.6, 1, 1]} />
      ))}
      <mesh geometry={geo.glass} material={mat.glass} position={[0, 0, front + 0.12]} />
      {screen && screenOn > 0 && (
        <mesh geometry={geo.screen} position={[0, 0, front + 0.24]} renderOrder={1}>
          <meshBasicMaterial map={screen} toneMapped={false} transparent opacity={screenOn} depthWrite={false} />
        </mesh>
      )}
      <mesh geometry={geo.glass} position={[0, 0, front + 0.36]} renderOrder={2}>
        <meshBasicMaterial
          map={mat.streak.tex}
          transparent
          opacity={0.1}
          blending={THREE.AdditiveBlending}
          depthWrite={false}
          toneMapped={false}
        />
      </mesh>
      {sweep >= 0 && (
        <mesh geometry={geo.glass} position={[0, 0, front + 0.42]} renderOrder={3}>
          <meshBasicMaterial
            map={mat.streak.sweepTex}
            transparent
            opacity={0.18}
            blending={THREE.AdditiveBlending}
            depthWrite={false}
            toneMapped={false}
          />
        </mesh>
      )}
      <mesh geometry={geo.back} material={mat.back} position={[0, 0, -front - 0.12]} rotation={[0, Math.PI, 0]} />
    </group>
  );
};

/** Screen pixel (on the 1206 × 2622 capture) → point on the glass, in the phone's own space (mm). */
export const screenPoint = (px: number, py: number, lift = 0.5) =>
  new THREE.Vector3((px / 1206 - 0.5) * SCREEN.w, (0.5 - py / 2622) * SCREEN.h, PHONE.d / 2 + lift);

/** The phone's transform, as Phone3D places it (to start a lifted layer exactly where it sits on the glass). */
export const phoneMatrix = (yaw: number, pitch = 0, roll = 0, position: [number, number, number] = [0, 0, 0]) => {
  const o = new THREE.Object3D();
  o.position.set(...position);
  o.rotation.set(THREE.MathUtils.degToRad(pitch), THREE.MathUtils.degToRad(yaw), THREE.MathUtils.degToRad(roll));
  o.updateMatrixWorld(true);
  return o.matrixWorld.clone();
};

/** The lens of §2.7 on a 36 mm vertical gate: 85 mm = 23.9°, 50 mm = 39.6°, 135 mm = 15.2°. */
export const lensFov = (mm: number) => THREE.MathUtils.radToDeg(2 * Math.atan(18 / mm));

export const CameraRig: React.FC<{ lens: number; distance: number; height?: number; lookY?: number; x?: number }> = ({
  lens,
  distance,
  height = 0,
  lookY = 0,
  x = 0,
}) => {
  const { camera } = useThree();
  const cam = camera as THREE.PerspectiveCamera;
  cam.fov = lensFov(lens);
  // A near plane far from the lens keeps depth precise (glass and screen sit 0.1 mm apart).
  cam.near = 40;
  cam.far = 5000;
  cam.position.set(x, height, distance);
  cam.lookAt(x, lookY, 0);
  cam.updateProjectionMatrix();
  return null;
};

/** A camera at `position` looking at `target` (both in mm), with the given lens. */
export const CameraLook: React.FC<{ lens: number; position: THREE.Vector3; target: THREE.Vector3 }> = ({ lens, position, target }) => {
  const { camera } = useThree();
  const cam = camera as THREE.PerspectiveCamera;
  cam.fov = lensFov(lens);
  cam.near = 40;
  cam.far = 5000;
  cam.position.copy(position);
  cam.up.set(0, 1, 0);
  cam.lookAt(target);
  cam.updateProjectionMatrix();
  return null;
};
