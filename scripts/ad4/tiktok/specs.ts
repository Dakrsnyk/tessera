// The ads themselves: one entry = one TikTok. A new ad is a new entry (captures by name, texts, voice lines).
import type { SpecA } from "./TemplateA";
import type { SpecC } from "./TemplateC";
import voC from "./vo/C-widgets.json";

/** Widget rectangles on the real Home Screens (px of the 1206 x 2622 capture, src/lib/kit.ts of the campaign). */
const MACROS: [number, number, number, number] = [57, 204, 1092, 510];
const NEXTSET_M: [number, number, number, number] = [57, 813, 1092, 510];

export const A_WIDGETS: SpecA = {
  id: "A-widgets",
  template: "A",
  shots: [
    { kind: "screen", src: "home-hero-aurore", focusY: 0.45, caption: "my Home Screen tracks my whole life now", captionY: 330, size: 70, premium: true, dur: 2.2 },
    { kind: "spot", src: "home-hero-aurore", rect: MACROS, caption: "calories and macros, no app to open", captionY: 1000, premium: true, dur: 2.5 },
    { kind: "spot", src: "home-hero-aurore", rect: NEXTSET_M, caption: "my next set, right there", captionY: 320, premium: true, dur: 2.5 },
    { kind: "screen", src: "app-finances-s00", focusY: 0.42, caption: "and what's left of my budget", captionY: 300, dur: 2.6 },
    { kind: "end", src: "home-hero-aurore", caption: "it's called Ardane", sub: "coming soon on the App Store", dur: 2.4 },
  ],
};

// Layout grid of a page (1080 x 1920): a full-width row at y 430, a row of two at y ~860, a Lock Screen strip at y ~1307.
// Every widget kind on the pages is a FREE kind in the light style (Faits-verifies.md §1); the Premium styles are in the carousel.
export const C_WIDGETS: SpecC = {
  id: "C-widgets",
  template: "C",
  voLen: voC,
  introSpeed: 1.15, // asked by the user on 2026-11-06: from the start up to the styles carousel
  hook: { title: "3 widget sets", subtitle: "that run my whole day", vo: "hook" },
  pages: [
    {
      label: "Food",
      vo: "i1",
      tiles: [
        { kind: "widget", src: "macros-m-light", x: 110, y: 430, w: 860 },
        { kind: "widget", src: "calories-s-light", x: 110, y: 862, w: 415 },
        {
          kind: "lock", x: 555, y: 862, w: 415, h: 415, wall: "wall-midnight.png",
          parts: [
            { src: "lock-caloriesLeft-circular", x: 117, y: 62, w: 180 },
            { src: "lock-caloriesLeft-inline", x: 27, y: 300, w: 360 },
          ],
        },
        { kind: "lock", x: 110, y: 1307, w: 860, h: 240, wall: "wall-ocean.png", parts: [{ src: "lock-macros-rect", x: 210, y: 30, w: 440 }] },
      ],
    },
    {
      label: "Training",
      vo: "i2",
      tiles: [
        { kind: "widget", src: "live-rest-real", x: 110, y: 430, w: 860, seq: { count: 16, fps: 1 } },
        { kind: "widget", src: "nextSet-s-light", x: 110, y: 818, w: 415 },
        {
          kind: "lock", x: 555, y: 818, w: 415, h: 415, wall: "wall-nebula.png",
          parts: [
            { src: "lock-trainingStreak-circular", x: 122, y: 50, w: 170 },
            { src: "lock-nextSet-rect", x: 22, y: 236, w: 370 },
          ],
        },
      ],
    },
    {
      label: "Money & my day",
      vo: "i3",
      tiles: [
        { kind: "widget", src: "habits-m-light", x: 110, y: 430, w: 860 },
        { kind: "widget", src: "budgetLeft-s-light", x: 110, y: 862, w: 415 },
        { kind: "widget", src: "priorities-s-light", x: 555, y: 862, w: 415 },
        {
          kind: "lock", x: 110, y: 1307, w: 860, h: 240, wall: "wall-graphite.png",
          parts: [
            { src: "lock-habitStreak-circular", x: 110, y: 44, w: 180 },
            { src: "lock-tasks-rect", x: 330, y: 32, w: 420 },
          ],
        },
      ],
    },
  ],
  styles: {
    // Only Home Screens whose widgets are whole: the hero-* setups and profile-athlete carry the medium Next set widget,
    // whose title and last line are cut in the kit (reported by the user on 2026-11-06). home-neon is left out: it shows a crypto widget.
    homes: ["home-jade", "home-crepuscule", "home-botanique", "home-pastel", "home-corail", "home-ocean", "home-creme"],
    caption: "customize it all",
    caption2: "shapes, styles & wallpapers",
    vo: "styles",
    premium: true,
  },
  end: { line: "Your whole life. One place.", sub: "Coming soon to the App Store", vo: "end" },
};

// ------------------------------------------------------------------------------------------------ « parcours » (2026-11-06)
// Open Ardane → Nutrition → scan a dish → customize the Macros widget → place it next to the Fitness widget (M).
// Three framings of the same journey, to choose from.
import type { SpecJ } from "./TemplateJ";
import voJ1 from "./vo/J1-journey-full.json";
import voJ2 from "./vo/J2-journey-phone.json";
import voJ3 from "./vo/J3-journey-photo.json";

const VO_J = { hook: "hook", open: "open", scan: "scan", custom: "custom", place: "place", end: "end" } as const;
const FINAL_J = { studio: "studio-preset-ocean", widget: "macros-m-preset-ocean" };
const POV_CAPTIONS = {
  open: "open Ardane, then Nutrition",
  scan: "1 photo = the foods + the calories",
  custom: "make the widget mine",
  place: "right next to my workout",
};

export const J1_FULL: SpecJ = {
  id: "J1-journey-full",
  template: "J",
  framing: "full",
  vo: VO_J,
  captions: { hook: "POV: my Home Screen knows what I just ate", ...POV_CAPTIONS },
  final: FINAL_J,
  voLen: voJ1,
};
export const J2_PHONE: SpecJ = {
  id: "J2-journey-phone",
  template: "J",
  framing: "phone",
  vo: VO_J,
  captions: { hook: "From your plate to your Home Screen" },
  final: FINAL_J,
  voLen: voJ2,
};
export const J3_PHOTO: SpecJ = {
  id: "J3-journey-photo",
  template: "J",
  framing: "photo",
  vo: VO_J,
  captions: { hook: "I scanned my lunch. Look where it ended up.", ...POV_CAPTIONS },
  final: FINAL_J,
  voLen: voJ3,
};

// ------------------------------------------------------------------------------------------------ séance de musculation (2026-11-06)
// Proposal 2 framing: library → set → medium workout widget on the Home Screen → Live Activity on the Lock Screen.
import type { SpecW } from "./TemplateW";
import voW1 from "./vo/W1-workout-phone.json";

export const W1_WORKOUT: SpecW = {
  id: "W1-workout-phone",
  template: "W",
  hook: "From the library to your Lock Screen",
  steps: { build: "Build", train: "Train", widget: "Widget", lock: "Lock Screen" },
  vo: { hook: "hook", build: "build", train: "train", widget: "widget", lock: "lock", end: "end" },
  voLen: voW1,
};
