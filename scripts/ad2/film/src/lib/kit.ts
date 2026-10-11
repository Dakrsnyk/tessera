// The real pieces of the ad kit (pub/kit, copied to public/kit) and where they sit, measured by
// scripts/ad2/kit_layout.py on the Home Screens the app drew itself (px of the 1206 × 2622 capture).
import * as THREE from "three";
import { H, W } from "./brand";

export type Rect = [number, number, number, number];

/** The hero Home Screen: macros M, nextSet M, budgetLeft S + priorities S on a real Store setup. */
export const HERO_WIDGETS: { kind: string; index: number; rect: Rect }[] = [
  { kind: "macros", index: 0, rect: [57, 204, 1092, 510] },
  { kind: "nextSet", index: 1, rect: [57, 813, 1092, 510] },
  { kind: "budgetLeft", index: 2, rect: [57, 1422, 510, 510] },
  { kind: "priorities", index: 3, rect: [638, 1421, 510, 510] },
];
/** Dock icons (indexes 4–7 of icons-<setup>.json), the same slots in every setup. */
export const DOCK: Rect[] = [
  [64, 2340, 222, 222],
  [349, 2340, 222, 222],
  [635, 2340, 222, 222],
  [920, 2340, 222, 222],
];

/** The universes of S2, in the film's order: Aurora → Space → Paper → Neon → Minimal → Sunset. */
export const UNIVERSES = [
  { id: "aurore", wall: "wall-aurora.png", name: "Aurora" },
  { id: "espace", wall: "wall-midnight.png", name: "Space" },
  { id: "etudes", wall: "wall-paper.png", name: "Paper" },
  { id: "neon", wall: "wall-synthwave.png", name: "Neon" },
  { id: "graphite", wall: "wall-graphite.png", name: "Minimal" },
  { id: "crepuscule", wall: "wall-sunset.png", name: "Sunset" },
] as const;
export type UniverseId = (typeof UNIVERSES)[number]["id"];

export const k = (file: string) => `kit/${file}`;
export const heroHome = (u: string) => k(`home-hero-${u}.png`);
export const heroWidget = (u: string, index: number) => k(`setup-hero-${u}-${index}.png`);
export const dockIcon = (u: string, slot: number) => k(`icons-${u}-${slot + 4}.png`);
export const wall = (u: string) => k(UNIVERSES.find((x) => x.id === u)!.wall);

/** Every file of one universe (home, its four widgets, its dock icons, its wallpaper). */
export const universeFiles = (u: string) => [
  heroHome(u),
  wall(u),
  ...HERO_WIDGETS.map((w) => heroWidget(u, w.index)),
  ...DOCK.map((_, i) => dockIcon(u, i)),
];

/** Screen pixel of a world point, for a camera at `position` looking at `target` with a `lens` (mm). */
export const project = (point: THREE.Vector3, position: THREE.Vector3, target: THREE.Vector3, lens: number) => {
  const cam = new THREE.PerspectiveCamera(THREE.MathUtils.radToDeg(2 * Math.atan(18 / lens)), W / H, 40, 5000);
  cam.position.copy(position);
  cam.up.set(0, 1, 0);
  cam.lookAt(target);
  cam.updateMatrixWorld(true);
  cam.updateProjectionMatrix();
  const p = point.clone().project(cam);
  return [((p.x + 1) / 2) * W, ((1 - p.y) / 2) * H] as [number, number];
};
