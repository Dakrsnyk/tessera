import { Config, Slot } from "../v5/part2/configs";

/**
 * Home Screens of the 2026-11-18 ads. Widgets = exports of the app (kit, by name), wallpapers = public/mainpub, public/avantapres or the kit's
 * wall-*; real Apple apps fill the free cells (HomeBuilder / gridFill). Rects are in the kit's old geometry (HomeBuilder converts with toIOS).
 */
type Rect = [number, number, number, number];
const M = (y: number): Rect => [57, y, 1092, 510];
const L = (y: number): Rect => [57, y, 1092, 1146];
const SL = (y: number): Rect => [57, y, 510, 510];
const SR = (y: number): Rect => [638, y, 510, 510];
const R0 = 204;
const R2 = 813;
const R4 = 1422;
const s = (n: string, rect: Rect): Slot => ({ file: `kit/${n}`, rect });
const MP = (n: string) => `mainpub/${n}.png`;
const AA = (n: string) => `avantapres/${n}.png`;

// ---------------------------------------------------------------- Main ad, sequence 2: one Home per need
export const MAIN_HOMES: Config[] = [
  { id: "prod", label: "Planning & focus", wall: MP("wall-mp-ivory"), dark: false, icons: "", glow: "#E39A62", slots: [s("weekView-m-light", M(R0)), s("tasks-s-light", SL(R2)), s("priorities-s-light", SR(R2)), s("habits-m-light", M(R4))] },
  { id: "sport", label: "Sport & wellness", wall: MP("wall-mp-indigo"), dark: true, icons: "", glow: "#B9A8FF", slots: [s("todaysWorkout-m-dark", M(R0)), s("restTimer-s-dark", SL(R2)), s("calories-s-dark", SR(R2)), s("weeklyVolume-m-dark", M(R4))] },
  { id: "food", label: "Nutrition", wall: MP("wall-mp-clay"), dark: false, icons: "", glow: "#C8714E", slots: [s("macros-m-paper", M(R0)), s("quickFood-m-paper", M(R2)), s("calories-s-paper", SL(R4))] },
  { id: "all", label: "Everything in one place", wall: MP("wall-mp-bronze"), dark: true, icons: "", glow: "#D3AE78", slots: [s("macros-m-luxury", M(R0)), s("budgetLeft-s-luxury", SL(R2)), s("calories-s-luxury", SR(R2)), s("nextSet-s-luxury", SL(R4))] },
];

// ---------------------------------------------------------------- Main ad, sequence 4: the widget on a Home, then wallpaper + theme matched to it
// v2.1 (PDG, 2026-11-18): the SAME three widgets in both, only their style changes (light -> Aurora). Before, Budget ($1,631) faded into
// Meditate (12 days) in the same cell and a 4th widget (Today's workout) faded in over the app icons: a visible double image.
export const MAKE_HOMES: Config[] = [
// v2.5 (PDG, 2026-11-18): the Planning widget (Weekly schedule, Large) must be on these last shots: it replaces Calories and Meditate.
// The Macros widget (the one shown alone just before) lands first, in the bottom row; then the Weekly schedule.
  { id: "plain", label: "Your widget", wall: "kit/wall-cream", dark: false, icons: "", glow: "#E39A62", slots: [s("macros-m-light", M(R4)), s("timetable-l-light", L(R0))] },
  { id: "aurora", label: "Aurora", wall: MP("wall-mp-aurora"), dark: true, icons: "", glow: "#5FE3D6", slots: [s("macros-m-aurora", M(R4)), s("timetable-l-aurora", L(R0))] },
];
/** The isolated widget of sequence 4 (same one that lands on the Home). */
export const MAKE_ISOLATED = "kit/macros-m-light";
export const MAKE_ISOLATED_WALL = "kit/wall-cream";

// ---------------------------------------------------------------- Widget ad, sequence 1: five very different Homes
export const AFTER_HOMES: Config[] = [
  { id: "minimal", label: "Minimal", wall: AA("wall-aa-glacier"), dark: false, icons: "", glow: "#2F7BD8", slots: [s("upNext-m-glacier", M(R2)), s("habitRate-s-glacier", SL(R4))] },
  { id: "premium", label: "Premium", wall: MP("wall-mp-bronze"), dark: true, icons: "", glow: "#D3AE78", slots: [s("macros-m-luxury", M(R0)), s("budgetLeft-s-luxury", SL(R2)), s("calories-s-luxury", SR(R2)), s("nextSet-s-luxury", SL(R4))] },
  { id: "color", label: "Colorful", wall: AA("wall-aa-rose"), dark: false, icons: "", glow: "#F0508A", slots: [s("mealsToday-m-blossom", M(R0)), s("countdown-s-blossom", SL(R2)), s("birthday-s-blossom", SR(R2)), s("calories-s-blossom", SL(R4)), s("priorities-s-blossom", SR(R4))] },
  { id: "sober", label: "Sober", wall: MP("wall-mp-indigo"), dark: true, icons: "", glow: "#B9A8FF", slots: [s("weekView-m-dark", M(R0)), s("upNext-s-dark", SL(R2)), s("priorities-s-dark", SR(R2))] },
  { id: "creative", label: "Creative", wall: "kit/wall-synthwave", dark: true, icons: "", glow: "#FF3DB8", slots: [s("macros-m-synthwave", M(R0)), s("calories-s-synthwave", SL(R2))] },
];

// ---------------------------------------------------------------- Widget ad, sequence 3: the widgets made in the Studio, S / M / L, then other compositions
export const RESULT_HOMES: Config[] = [
  { id: "created", label: "Your widgets", wall: MP("wall-mp-neon"), dark: true, icons: "", glow: "#FF3DB8", slots: [s("macros-m-neon", M(R0)), s("calories-s-neon", SL(R2)), s("habitStreak-s-neon", SR(R2)), s("weeklyVolume-m-neon", M(R4))] },
  { id: "large", label: "Aurora", wall: MP("wall-mp-aurora"), dark: true, icons: "", glow: "#5FE3D6", slots: [s("timetable-l-aurora", L(R0)), s("calories-s-aurora", SL(R4)), s("habitStreak-s-aurora", SR(R4))] },
  { id: "editorial", label: "Planner", wall: MP("wall-mp-clay"), dark: false, icons: "", glow: "#C8714E", slots: [s("timetable-l-editorial", L(R0)), s("calories-s-editorial", SL(R4))] },
  { id: "day", label: "Everyday", wall: MP("wall-mp-ivory"), dark: false, icons: "", glow: "#E39A62", slots: [s("macros-m-light", M(R0)), s("calories-s-light", SL(R2)), s("budgetLeft-s-light", SR(R2)), s("todaysWorkout-m-light", M(R4))] },
];
