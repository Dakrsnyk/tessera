// « Voici ton téléphone… et voici le mien » (avant / après) : les écrans d'accueil composés.
// Géométrie d'un écran d'iPhone 16 Pro en pixels de capture (1206 x 2622, @3x), grille iOS de 4 x 6 cases.
// Les widgets sont les vrais exports de l'app (kit pub, données de démo) ; les fonds sont neufs (make_walls_aa.py).

export const SW = 1206;
export const SH = 2622;

/** Grille iOS mesurée sur la vraie capture du simulateur (iPhone 16 Pro, run CI [ios-home] du 2026-11-11, px @3x) :
 *  icônes de 188 px, colonnes tous les 277,7 px, rangées tous les 301 px, petit widget de 489 px, Dock à y 2263. */
export const GRID = {
  left: 81,
  right: 638,
  top: 272,
  /** une paire de rangées (un petit widget = icône de la rangée 1 jusqu'au bas de l'icône de la rangée 2 : 301 + 188) */
  pair: 602,
  small: 489,
  medium: [1046, 489] as [number, number],
  large: [1046, 1098] as [number, number],
  icon: 188,
  iconLeft: 92.5,
  iconStep: 277.7,
  dockTop: 2263,
  dockIconTop: 2322,
};

export type Size = "s" | "m" | "l";
export type WidgetSlot = { file: string; size: Size; c: 0 | 2; r: number; label?: string };
export type IconSlot = { name: string; c: number; r: number };
export type Screen = {
  id: string;
  title: string;
  wall: string;
  /** encre de la barre d'état et des libellés (iOS : libellés blancs sur l'écran d'accueil) */
  darkWall: boolean;
  widgets: WidgetSlot[];
  icons: IconSlot[];
  dock: string[];
  /** teinte du Dock et de la pilule Recherche */
  glass: string;
  accent: string;
};

export const rectOf = (w: { size: Size; c: number; r: number }): [number, number, number, number] => {
  const x = w.c === 0 ? GRID.left : GRID.right;
  const y = GRID.top + (w.r / 2) * GRID.pair;
  if (w.size === "s") return [x, y, GRID.small, GRID.small];
  if (w.size === "m") return [GRID.left, y, ...GRID.medium];
  return [GRID.left, y, ...GRID.large];
};

/** Case d'icône (c 0..3, r 0..5) : coin haut gauche de l'icône. */
export const iconXY = (c: number, r: number): [number, number] => {
  return [GRID.iconLeft + GRID.iconStep * c, GRID.top + r * (GRID.pair / 2)];
};

const K = "kit2026/en/";
const A = "avantapres/";

export const SCREENS: Screen[] = [
  {
    id: "volt",
    title: "Sport & nutrition",
    wall: A + "wall-aa-volt.png",
    darkWall: true,
    widgets: [
      { file: K + "todaysWorkout-m-sport.png", size: "m", c: 0, r: 0 },
      { file: K + "calories-s-sport.png", size: "s", c: 0, r: 2 },
      { file: K + "weeklyVolume-m-sport.png", size: "m", c: 0, r: 4 },
    ],
    icons: [
      { name: "Health", c: 2, r: 2 },
      { name: "Maps", c: 3, r: 2 },
      { name: "News", c: 2, r: 3 },
      { name: "Wallet", c: 3, r: 3 },
    ],
    dock: ["Messages", "Safari", "Photos", "Settings"],
    glass: "rgba(40,44,30,0.42)",
    accent: "#C6FF00",
  },
  {
    id: "glacier",
    title: "Organisation",
    wall: A + "wall-aa-glacier.png",
    darkWall: false,
    widgets: [
      { file: K + "tasks-s-glacier.png", size: "s", c: 0, r: 0 },
      { file: K + "habits-s-glacier.png", size: "s", c: 2, r: 0 },
      { file: K + "upNext-m-glacier.png", size: "m", c: 0, r: 2 },
      { file: K + "habitRate-s-glacier.png", size: "s", c: 2, r: 4 },
    ],
    icons: [
      { name: "Calendar", c: 0, r: 4 },
      { name: "Reminders", c: 1, r: 4 },
      { name: "Photos", c: 0, r: 5 },
      { name: "Settings", c: 1, r: 5 },
    ],
    dock: ["Messages", "Safari", "Maps", "Health"],
    glass: "rgba(255,255,255,0.30)",
    accent: "#2F7BD8",
  },
  {
    id: "marine",
    title: "Finance & business",
    wall: A + "wall-aa-marine.png",
    darkWall: true,
    widgets: [
      { file: K + "businessDashboard-l-businessw.png", size: "l", c: 0, r: 0 },
      { file: K + "budgetLeft-s-businessw.png", size: "s", c: 0, r: 4 },
    ],
    icons: [
      { name: "Wallet", c: 2, r: 4 },
      { name: "News", c: 3, r: 4 },
      { name: "Photos", c: 2, r: 5 },
      { name: "Settings", c: 3, r: 5 },
    ],
    dock: ["Messages", "Safari", "Calendar", "Maps"],
    glass: "rgba(20,34,60,0.45)",
    accent: "#E5B567",
  },
];

/** L'écran « avant » : la vraie capture de l'écran d'accueil du simulateur iOS (étape CI [ios-home]). */
export const BEFORE = A + "ios-home-light-fixed.png";

/**
 * Icônes d'apps Apple : découpées dans la vraie capture du simulateur (avantapres/apple-<Nom>.png) quand elle existe ;
 * en attendant, les icônes rendues par l'app (kit icons-*), même nom.
 */
export const ICON_FALLBACK: Record<string, string> = {
  Phone: K + "icons-jade-4.png",
  Messages: K + "icons-jade-5.png",
  Safari: K + "icons-jade-6.png",
  Camera: K + "icons-jade-7.png",
  Health: K + "icons-jade-0.png",
  Fitness: K + "icons-jade-1.png",
  Music: K + "icons-jade-2.png",
  Clock: K + "icons-espace-0.png",
  Maps: K + "icons-espace-3.png",
  Photos: K + "icons-creme-0.png",
  Calendar: K + "icons-etudes-2.png",
  Reminders: K + "icons-etudes-3.png",
  Notes: K + "icons-etudes-1.png",
  Mail: K + "icons-crepuscule-7.png",
  Settings: K + "icons-graphite-3.png",
  Wallet: K + "icons-nebuleuse-1.png",
};
