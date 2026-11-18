/**
 * EVERYTHING that depends on the layout of an app screen lives here, so it can be retuned fast when the new kit (current app,
 * Build 467 and later) replaces the images of public/kit2026/en/ under the same file names. Capture px = the 1206 x 2622 capture.
 * Status of each value: "467" = measured on the PDG's Build 467 capture (pdg-467-*.png, scaled to 1206 x 2622);
 * "OLD" = guessed on the OLD kit image (31 Oct): CHECK IT on the new capture.
 */
import type { StepId } from "./timing26";

export type Rect = [number, number, number, number];

/** Mini-apps of the Main ad: one capture, one label that points the most telling function. */
export const APP_SHOTS = {
  nutrition: {
    title: "Nutrition.",
    accent: "#F2994A",
    capture: "pub26-nutrition-dark",
    label: "Calories left",
    below: true,
    rect: [62, 757, 1082, 520] as Rect, // ring + macros card (pub26-nutrition-dark, measured)
    focus: [603, 1017] as [number, number],
    zoom: 1.1,
  },
  fitness: {
    title: "Fitness.",
    accent: "#E0707A",
    capture: "pub26-fitness-dark",
    label: "Live workout",
    below: true, // above, the label covered the dates of the week strip
    rect: [62, 757, 1082, 600] as Rect, // the LIVE WORKOUT card and its progress line (pub26-fitness-dark, measured)
    focus: [603, 962] as [number, number],
    zoom: 1.1,
  },
  planning: {
    title: "Planning.",
    accent: "#3B6BFF",
    capture: "pub26-planning-dark",
    label: "Your whole week",
    below: true,
    rect: [62, 1195, 1084, 1150] as Rect, // Day/Week/Month/Year + week grid (pub26-planning-dark, measured)
    focus: [603, 1770] as [number, number],
    zoom: 1.1,
  },
} as const;
export type AppId = keyof typeof APP_SHOTS;

/** Widget ad, customisation: the capture shown at each step (kit names, see scripts/ad_screens.txt). */
export const SHOTS: Record<StepId, string> = {
  create: "pub26-create-dark", // « What size for your widget? »
  editor: "pub26-editor-dark", // the Workshop, chapter 1 Content (small Calories widget)
  content: "studio-content-dark", // same chapter, Medium Macros widget (the one the Style steps then restyle)
  styleAurora: "studio-style-aurora-dark",
  styleNeon: "studio-style-neon-dark",
  palette: "studio-palette-gold-dark",
};
/** The little pill under the card at each step (what changes). */
export const PILLS: Record<StepId, string> = {
  create: "Pick a size",
  editor: "Choose what it shows",
  content: "Make it Medium",
  styleAurora: "Change the style",
  styleNeon: "Another style",
  palette: "Pick your colors",
};

/**
 * Bands of a capture that a phone's edge would cut (scrolling chips, tiles under the footer): a fade to the screen's own background.
 * Empty for the new captures: the OLD kit's values (v4/Process.tsx FADES) were tuned on the OLD layout and are not carried over.
 */
export type Fade = { y0: number; y1: number; l?: number; r?: number; t?: number; b?: number; c0?: string; c1?: string; h?: boolean };
export const FADES: Record<string, Fade[]> = {};
