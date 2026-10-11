import { ThreeCanvas } from "@remotion/three";
import { useMemo } from "react";
import { AbsoluteFill, Easing, interpolate } from "remotion";
import * as THREE from "three";
import { Callout } from "../components/Callout";
import { FilmAudio } from "../components/FilmAudio";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { SplitText } from "../components/SplitText";
import { Strata } from "../components/Strata";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { DOCK, dockIcon, HERO_WIDGETS, heroHome, heroWidget, project, UNIVERSES, universeFiles, wall } from "../lib/kit";
import { drawBlade, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";
import { useFilmFrame } from "../lib/time";

/** Local frame 0 = f360 of the main film (6.0 s). Universe changes on the beats of 9, 10, 11, 12, 13 s. */
const CHANGES = [180, 240, 300, 360, 420];
const IDS = UNIVERSES.map((u) => u.id);
const FILES = [...new Set(IDS.flatMap(universeFiles))];
/** Layer depths above the glass when fully exploded (mm): icons, then widgets. */
const Z_ICONS = 30;
const Z_WIDGETS = 66;
const front = PHONE.d / 2 + 0.3;

/** Which universes are on screen and how far the blade has gone, for a layer that starts its wipe `delay` late. */
const wipeAt = (f: number, delay: number) => {
  let from = 0;
  for (let i = 0; i < CHANGES.length; i++) {
    const t0 = CHANGES[i] + delay;
    if (f < t0) return { old: IDS[from], next: IDS[from], p: 0 };
    if (f < t0 + 10)
      return { old: IDS[i], next: IDS[i + 1], p: interpolate(f, [t0, t0 + 10], [0, 1], { easing: Easing.bezier(0.45, 0, 0.55, 1) }) };
    from = i + 1;
  }
  return { old: IDS[from], next: IDS[from], p: 0 };
};

/** Camera: the phone's apparent height (fraction of the frame), the lens, the phone's turn. */
const shotAt = (f: number) => {
  // Nothing stops dead: the turn, the dolly and the strata never all rest at once (the turn reverses at 150
  // and 420, the dolly keeps moving through both; a slow push holds the hero word).
  const yaw = interpolate(f, [0, 150, 420, 560], [0, 26, 12, 0], {
    ...clamp,
    easing: [ease.arrival, Easing.bezier(0.4, 0, 0.6, 1), ease.transfer],
  });
  const pitch = interpolate(f, [0, 150, 420, 560], [0, -8, -6, 0], { ...clamp, easing: [ease.arrival, Easing.linear, ease.transfer] });
  const lens = interpolate(f, [0, 90, 470, 560], [85, 50, 50, 85], { ...clamp, easing: ease.transfer });
  const fraction = interpolate(f, [0, 120, 420, 540, 599], [0.875, 0.62, 0.66, 0.76, 0.82], {
    ...clamp,
    easing: [ease.arrival, Easing.linear, ease.transfer, Easing.linear],
  });
  const distance = PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(lens)) / 2) * fraction);
  return { yaw, pitch, lens, distance };
};

const Guides: React.FC<{ e: number; opacity: number }> = ({ e, opacity }) => {
  const geo = useMemo(() => new THREE.BufferGeometry(), []);
  const corners = [
    [-SCREEN.w / 2, SCREEN.h / 2],
    [SCREEN.w / 2, SCREEN.h / 2],
    [SCREEN.w / 2, -SCREEN.h / 2],
    [-SCREEN.w / 2, -SCREEN.h / 2],
  ];
  const zs = [front, front + Z_ICONS * e, front + Z_WIDGETS * e];
  const pts: number[] = [];
  // Corner to corner between the planes (an architectural exploded view), and each plane's outline.
  for (const [x, y] of corners) pts.push(x, y, zs[0], x, y, zs[2]);
  for (const z of zs.slice(1)) {
    for (let i = 0; i < 4; i++) {
      const [x0, y0] = corners[i];
      const [x1, y1] = corners[(i + 1) % 4];
      pts.push(x0, y0, z, x1, y1, z);
    }
  }
  geo.setAttribute("position", new THREE.Float32BufferAttribute(pts, 3));
  return (
    <lineSegments geometry={geo}>
      <lineBasicMaterial color="#FFFFFF" transparent opacity={0.3 * opacity} depthWrite={false} />
    </lineSegments>
  );
};

export const Universes: React.FC<{ audio?: boolean }> = ({ audio = true }) => {
  const frame = useFilmFrame();
  const images = useImages(FILES);
  const base = useCanvasTexture();
  const widgets = useCanvasTexture();
  const icons = useCanvasTexture();

  const e =
    frame < 450
      ? interpolate(frame, [6, 42], [0, 1], { ...clamp, easing: ease.lift })
      : interpolate(frame, [450, 480], [1, 0], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 1) });
  const exploded = e > 0.002;

  if (images) {
    const img = (f: string) => images[f];
    // Base: the Home Screen; once exploded, its widgets and icons leave (the wallpaper shows in their slots).
    const drawBase = (u: string) => {
      base.ctx.drawImage(img(heroHome(u)), 0, 0);
      if (exploded) {
        for (const [x, y, w, h] of [...HERO_WIDGETS.map((w) => w.rect), ...DOCK]) {
          base.ctx.drawImage(img(wall(u)), x - 30, y - 30, w + 60, h + 66, x - 30, y - 30, w + 60, h + 66);
        }
      }
    };
    const drawWidgets = (u: string) => HERO_WIDGETS.forEach((w) => widgets.ctx.drawImage(img(heroWidget(u, w.index)), ...w.rect));
    const drawIcons = (u: string) => DOCK.forEach((r, i) => icons.ctx.drawImage(img(dockIcon(u, i)), ...r));
    const layer = (target: typeof base, delay: number, draw: (u: string) => void, clipRects?: [number, number, number, number][]) => {
      const { old, next, p } = wipeAt(frame, delay);
      target.ctx.clearRect(0, 0, 1206, 2622);
      draw(old);
      if (p > 0) {
        target.ctx.save();
        target.ctx.beginPath();
        target.ctx.rect(0, 0, 1206 * p, 2622);
        target.ctx.clip();
        target.ctx.clearRect(0, 0, 1206 * p, 2622);
        draw(next);
        target.ctx.restore();
        target.ctx.save();
        if (clipRects) {
          target.ctx.beginPath();
          for (const r of clipRects) target.ctx.rect(...r);
          target.ctx.clip();
        }
        drawBlade(target.ctx, 1206 * p, 0, 2622, Math.sin(Math.PI * p));
        target.ctx.restore();
      }
      target.texture.needsUpdate = true;
    };
    // The blade crosses the planes front to back: widgets, then icons (+4 frames), then the wallpaper (+8).
    layer(
      widgets,
      0,
      drawWidgets,
      HERO_WIDGETS.map((w) => w.rect),
    );
    layer(icons, 4, drawIcons, DOCK);
    layer(base, 8, drawBase);
  }

  const shot = shotAt(frame);
  const camPos = new THREE.Vector3(0, 0, shot.distance);
  const target = new THREE.Vector3(0, 0, 0);
  const guides = interpolate(frame, [30, 60, 440, 470], [0, 1, 1, 0], clamp);

  // Eyebrows pinned to each plane (projected corners), 7.00–8.40 s.
  const group = new THREE.Object3D();
  group.rotation.set(THREE.MathUtils.degToRad(shot.pitch), THREE.MathUtils.degToRad(shot.yaw), 0);
  group.updateMatrixWorld(true);
  // A point of the screen (capture px) on a layer `z` mm above the glass, in frame pixels.
  const pin = (px: number, py: number, z: number) =>
    project(
      new THREE.Vector3((px / 1206 - 0.5) * SCREEN.w, (0.5 - py / 2622) * SCREEN.h, z).applyMatrix4(group.matrixWorld),
      camPos,
      target,
      shot.lens,
    );
  const pinW = pin(600, 204, front + Z_WIDGETS * e); // top of the macros widget
  const pinI = pin(175, 2562, front + Z_ICONS * e); // under the first dock icon
  const pinB = pin(160, 2080, front); // the wallpaper between the widgets and the dock

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      <Strata from={150} foldAt={420} register={CHANGES.map((at, i) => ({ at, file: UNIVERSES[i + 1].wall }))} />
      {images && (
        <ThreeCanvas width={W} height={H}>
          <StudioEnvironment />
          <CameraLook lens={shot.lens} position={camPos} target={target} />
          <group rotation={[THREE.MathUtils.degToRad(shot.pitch), THREE.MathUtils.degToRad(shot.yaw), 0]}>
            <Phone3D yaw={0} screen={base.texture} screenOn={1} />
            {exploded && (
              <>
                <mesh position={[0, 0, front + Z_ICONS * e]} renderOrder={4}>
                  <planeGeometry args={[SCREEN.w, SCREEN.h]} />
                  <meshBasicMaterial map={icons.texture} transparent toneMapped={false} depthWrite={false} />
                </mesh>
                <mesh position={[0, 0, front + Z_WIDGETS * e]} renderOrder={5}>
                  <planeGeometry args={[SCREEN.w, SCREEN.h]} />
                  <meshBasicMaterial map={widgets.texture} transparent toneMapped={false} depthWrite={false} />
                </mesh>
                <Guides e={e} opacity={guides} />
              </>
            )}
          </group>
        </ThreeCanvas>
      )}
      <Callout label="Widgets" at={pinW} labelY={pinW[1] - 90} from={60} to={144} />
      <Callout label="Icons" at={pinI} labelY={pinI[1] + 90} from={68} to={144} />
      <Callout label="Wallpaper" at={pinB} labelX={Math.max(250, pinB[0] - 130)} from={76} to={144} />
      {/* While the hero word is read, the lower part of the phone falls back (type never over UI data). */}
      <AbsoluteFill
        style={{
          background: "linear-gradient(to bottom, transparent 52%, rgba(0,0,0,0.75) 68%, rgba(0,0,0,0.88) 100%)",
          opacity: interpolate(frame, [470, 490, 570, 596], [0, 1, 1, 0], clamp),
        }}
      />
      <SplitText from={472} exitAt={578} top={1250} height={160}>
        <span style={type.hero}>Make it yours.</span>
      </SplitText>
      <Grain />
      {audio && <FilmAudio from={360} />}
    </AbsoluteFill>
  );
};
