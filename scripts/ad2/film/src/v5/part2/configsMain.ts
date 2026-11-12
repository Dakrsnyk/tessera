import { Config, Slot } from "./configs";

/**
 * The Homes of the main film's ending, restyled at the level of the « avant / après » ad (demande du PDG du 2026-11-11):
 * one coherent style per screen, a new wallpaper made for it (scripts/ad2/make_walls_main.py, public/mainpub), real Apple apps
 * on the measured iOS grid. The styles are NOT those of the avant / après ad (no Sport, Glacier, Business, Blossom, Forest).
 * Rects are in the kit's old geometry (HomeBuilder converts them with toIOS). `glow` is the accent of the name pill.
 */
type Rect = [number, number, number, number];
const k = (n: string) => `kit/${n}`;
const W = (n: string) => `mainpub/${n}.png`;
const M = (y: number): Rect => [57, y, 1092, 510];
const L = (y: number): Rect => [57, y, 1092, 1146];
const SL = (y: number): Rect => [57, y, 510, 510];
const SR = (y: number): Rect => [638, y, 510, 510];
const R0 = 204;
const R2 = 813;
const R4 = 1422;
const s = (file: string, rect: Rect): Slot => ({ file: k(file), rect });

export const MAIN_CONFIGS: Config[] = [
  // installation: the four widgets of part 1 (nutrition, finances, fitness) land on a light, warm Home
  {
    id: "everyday", label: "Everyday", wall: W("wall-mp-ivory"), dark: false, icons: "", glow: "#E39A62",
    slots: [s("macros-m-light", M(R0)), s("calories-s-light", SL(R2)), s("budgetLeft-s-light", SR(R2)), s("todaysWorkout-m-light", M(R4))],
  },
  // a calm dark Home for the week, the apps below
  {
    id: "focus", label: "Focus", wall: W("wall-mp-indigo"), dark: true, icons: "", glow: "#B9A8FF",
    slots: [s("weekView-m-dark", M(R0)), s("upNext-s-dark", SL(R2)), s("priorities-s-dark", SR(R2))],
  },
  // editorial: a large timetable, a small calories card, apps beside it
  {
    id: "planner", label: "Planner", wall: W("wall-mp-clay"), dark: false, icons: "", glow: "#C8714E",
    slots: [s("timetable-l-editorial", L(R0)), s("calories-s-editorial", SL(R4))],
  },
  {
    id: "neon", label: "Neon", wall: W("wall-mp-neon"), dark: true, icons: "", glow: "#FF3DB8",
    slots: [s("macros-m-neon", M(R0)), s("calories-s-neon", SL(R2)), s("habitStreak-s-neon", SR(R2)), s("weeklyVolume-m-neon", M(R4))],
  },
  {
    id: "luxury", label: "Luxury", wall: W("wall-mp-bronze"), dark: true, icons: "", glow: "#D3AE78",
    slots: [s("macros-m-luxury", M(R0)), s("budgetLeft-s-luxury", SL(R2)), s("calories-s-luxury", SR(R2)), s("nextSet-s-luxury", SL(R4))],
  },
  {
    id: "aurora", label: "Aurora", wall: W("wall-mp-aurora"), dark: true, icons: "", glow: "#5FE3D6",
    slots: [s("macros-m-aurora", M(R0)), s("habitStreak-s-aurora", SL(R2)), s("calories-s-aurora", SR(R2)), s("todaysWorkout-m-aurora", M(R4))],
  },
];
