/**
 * EVERYTHING that depends on the layout of an app screen lives here (version 2, 2026-11-18). Capture px = the 1206 x 2622 capture of
 * public/kit2026/en/ (kit runs 471 / 472, current app; catalogue: scripts/ad2/pub26_v2/catalogue-captures.json, ok: true only).
 * Every rect / focus below was measured on the capture itself. The timings of these steps are in timing26.ts (MAIN.apps).
 */
import type { StepId } from "./timing26";

export type Rect = [number, number, number, number];
/** One beat of a mini-app: a capture (a new screen when it differs from the previous beat), a highlighted zone and its label. */
export type AppStep = {
  capture: string;
  label: string;
  rect: Rect;
  focus: [number, number];
  zoom?: number;
  below?: boolean;
  /** « With Premium » at the top-right while this screen is up. */
  premium?: boolean;
  /** an animation played inside a zone of the capture (frames kit/<name>-0000.png ...), from `from` frames after the screen arrives */
  demo?: { name: string; count: number; box: Rect; fill: string; from: number };
  /** plain rects drawn over the capture (capture px + colour): French words left in a capture */
  cover?: [number, number, number, number, string][];
};

/** Mini-apps of the Main ad. The keys of `steps` are the ones of MAIN.apps[].steps in timing26.ts. */
export const APP_SHOTS: Record<"nutrition" | "fitness" | "planning", { title: string; accent: string; steps: Record<string, AppStep> }> = {
  nutrition: {
    title: "Nutrition.",
    accent: "#F2994A",
    steps: {
      ring: { capture: "pub26-nutrition-dark", label: "Calories left", rect: [62, 757, 1082, 520], focus: [603, 1017], zoom: 1.1, below: true },
      scan: { capture: "pub26-nutrition-dark", label: "Scan or search", rect: [215, 2165, 770, 160], focus: [603, 2000], zoom: 1.1 },
      search: { capture: "nut-1-dark", label: "Search any food", rect: [36, 405, 1134, 120], focus: [603, 900], zoom: 1.1, below: true },
      amount: { capture: "nut-2-dark", label: "Pick the amount", rect: [36, 820, 1134, 330], focus: [603, 1100], zoom: 1.1, below: true },
      added: { capture: "nut-3-dark", label: "Added to your day", rect: [62, 757, 1082, 520], focus: [603, 1017], zoom: 1.1, below: true },
    },
  },
  fitness: {
    title: "Fitness.",
    accent: "#E0707A",
    steps: {
      live: { capture: "pub26-fitness-dark", label: "Live workout", rect: [62, 757, 1082, 600], focus: [603, 962], zoom: 1.1, below: true },
      sets: { capture: "session-0-dark", label: "Set 3 of 4", rect: [36, 645, 1134, 900], focus: [603, 1100], zoom: 1.1 },
      rest: { capture: "session-1-dark", label: "Rest timer", rect: [50, 1200, 1110, 150], focus: [603, 1270], zoom: 1.1, below: true },
      library: { capture: "app-fitness-library-dark", label: "163 exercises", rect: [36, 1000, 1134, 1160], focus: [603, 1500], zoom: 1.1, premium: true },
      demo: {
        capture: "ex-1-dark",
        label: "Animated demo",
        rect: [60, 366, 1086, 704],
        focus: [603, 900],
        zoom: 1.1,
        below: true,
        premium: true,
        // the current animation of the app (white figure, muscles in red), on the card colour of the sheet (#1A1B1E)
        demo: { name: "demo-back-squat-card", count: 234, box: [60, 366, 1086, 704], fill: "#1A1B1E", from: 0 },
        cover: [[30, 1118, 1146, 172, "rgb(8,14,20)"]], // « Remontée » and « Profil » (French words left in the capture)
      },
      record: { capture: "app-fitness-exercise-back-squat-end", label: "Personal best", rect: [40, 560, 1126, 830], focus: [603, 975], zoom: 1.1, below: true, premium: true },
    },
  },
  planning: {
    title: "Planning.",
    accent: "#3B6BFF",
    steps: {
      week: { capture: "pub26-planning-dark", label: "Your whole week", rect: [62, 1195, 1084, 1150], focus: [603, 1770], zoom: 1.1, below: true },
      events: { capture: "app-planning-week-dark", label: "Classes and events", rect: [36, 500, 1134, 1420], focus: [603, 1200], zoom: 1.1, below: true },
      tasks: { capture: "app-planning-week-dark", label: "Today's tasks", rect: [36, 2150, 1134, 200], focus: [603, 2000], zoom: 1.1 },
      streak: { capture: "hab-0-dark", label: "Streak: 12 days", rect: [36, 500, 1100, 400], focus: [603, 900], zoom: 1.1, below: true, premium: true },
      done: { capture: "hab-1-dark", label: "4 of 4 done", rect: [36, 500, 1100, 400], focus: [603, 900], zoom: 1.1, below: true, premium: true },
    },
  },
};
export type AppId = keyof typeof APP_SHOTS;

/** Widget ad, customisation: the capture shown at each step (kit names, see scripts/ad_screens.txt). All show the SAME Medium Macros widget from `styleAurora` on. */
export const SHOTS: Record<StepId, string> = {
  create: "pub26-create-dark", // « What size for your widget? »
  editor: "pub26-editor-dark", // the Workshop, chapter 1 Content (small Calories widget, sizes)
  styleAurora: "studio-style-aurora-dark",
  styleNeon: "studio-style-neon-dark",
  styleSpace: "studio-style-space-dark",
  styleGlass: "studio-style-liquidGlass-dark",
  colorGold: "studio-palette-gold-dark",
  paletteOcean: "studio-palette-ocean-dark", // « Palettes : everything changes at once »
  colorDusk: "studio-palette-sunset-dark",
  themeMidnight: "studio-theme-midnight-dark", // Style > Theme (« A theme sets everything at once ») = kit-472/studio-content-dark.png (the kit one shows the Content chapter)
  themeLuxury: "studio-preset-luxury-dark",
  themeCyber: "studio-preset-cyber-dark",
  myWidgets: "pub26-mywidgets-dark-b", // My widgets, with « Add to screen »
};
/** The little pill under the card at each step (what changes). */
export const PILLS: Record<StepId, string> = {
  create: "Pick a size",
  editor: "Choose what it shows",
  styleAurora: "Aurora",
  styleNeon: "Neon",
  styleSpace: "Space",
  styleGlass: "Liquid Glass",
  colorGold: "Gold",
  paletteOcean: "Palette: Ocean",
  colorDusk: "Dusk",
  themeMidnight: "Themes",
  themeLuxury: "Luxury",
  themeCyber: "Cyber",
  myWidgets: "Add to screen",
};

/**
 * Bands of a capture that a phone's edge would cut (scrolling chips, tiles under the footer): a fade to the screen's own background.
 * Empty for the new captures (the app already cuts its lists itself).
 */
export type Fade = { y0: number; y1: number; l?: number; r?: number; t?: number; b?: number; c0?: string; c1?: string; h?: boolean };
export const FADES: Record<string, Fade[]> = {};
