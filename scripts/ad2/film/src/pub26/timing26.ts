/**
 * ALL the timings of the two 2026-11-18 ads (frames at 60 fps; seconds = f / 60). Nothing else carries a duration.
 * HOOK and CLOSE_LEN are the validated ones: v5/short/timing.json `hookLength` (446) and v5/part2/timing.json sequences.close.length (170).
 */
export const FPS26 = 60;
export const HOOK = 446;
export const CLOSE_LEN = 170;
/** The validated end card: Close.tsx played through this remap (local frame -> Close frame), as in FilmMainV5Part2. */
export const CLOSE_REMAP = { input: [0, 30, CLOSE_LEN - 22, CLOSE_LEN], output: [56, 96, 216, 216] };

export type VoLine = { id: string; text: string; at: number; words: number };
/** Voice duration, estimated: a calm female voice at ~2.6 words per second. */
export const WPS = 2.6;
export const voFrames = (words: number) => Math.round((words / WPS) * FPS26);

// ---------------------------------------------------------------- Film 1: MainPub26 (target 29-30 s)
const M_HOMES_FROM = HOOK; // 446
const M_HOMES_LEN = 420; // 7.0 s
const M_APPS_FROM = M_HOMES_FROM + M_HOMES_LEN; // 866
const APP_EFFECTIVE = 130; // 2.17 s per mini-app
const APP_LINK = 30; // overlap = the app's own entry / exit
const M_APPS_LEN = 3 * APP_EFFECTIVE; // 390 = 6.5 s
const M_MAKE_FROM = M_APPS_FROM + M_APPS_LEN; // 1256
const M_MAKE_LEN = 330; // 5.5 s
const M_CLOSE_FROM = M_MAKE_FROM + M_MAKE_LEN; // 1586

export const MAIN = {
  hook: { from: 0, len: HOOK },
  homes: { from: M_HOMES_FROM, len: M_HOMES_LEN, morphAt: [96, 198, 300], morphLen: [22, 22, 22], exit: 30 },
  apps: {
    from: M_APPS_FROM,
    effective: APP_EFFECTIVE,
    link: APP_LINK,
    /** length of each app's Sequence = effective + link (the next app enters while this one leaves) */
    seqLen: APP_EFFECTIVE + APP_LINK,
    titleAt: 12,
    hi: { from: 40, to: 124 },
    camFocusAt: 36,
    camBackAt: 124,
    ids: ["nutrition", "fitness", "planning"] as const,
  },
  make: {
    from: M_MAKE_FROM,
    len: M_MAKE_LEN,
    isolatedLen: 112, // isolated widget (fades out under the Home that fades in)
    homeFrom: 90, // local frame where the Home Screen starts (its own frame 0)
    homeLen: M_MAKE_LEN - 90,
    homeFade: 12,
    installAt: 12,
    morphAt: [128],
    morphLen: [30],
    swallow: [M_MAKE_LEN - 90 - 46, M_MAKE_LEN - 90 - 8] as [number, number],
    captionAt: 56,
  },
  close: { from: M_CLOSE_FROM, len: CLOSE_LEN },
  total: M_CLOSE_FROM + CLOSE_LEN, // 1756 = 29.27 s
};
export const MAIN_VO: VoLine[] = [
  { id: "M1", text: "All your essentials on your home screen.", at: M_HOMES_FROM + 24, words: 7 },
  { id: "M2", text: "Nutrition.", at: M_APPS_FROM + 12, words: 1 },
  { id: "M3", text: "Fitness.", at: M_APPS_FROM + APP_EFFECTIVE + 12, words: 1 },
  { id: "M4", text: "Planning.", at: M_APPS_FROM + 2 * APP_EFFECTIVE + 12, words: 1 },
  { id: "M5", text: "Make everyday your own.", at: M_MAKE_FROM + 56, words: 4 },
];

// ---------------------------------------------------------------- Film 2: WidgetPub26 (target 27-30 s)
const W_BEFORE_LEN = 90; // 1.5 s: the real iOS Home, no Ardane
const W_AFTER_LEN = 330; // 5.5 s: five Homes, one at a time
const W_PROC_FROM = W_BEFORE_LEN + W_AFTER_LEN; // 420
const W_PROC_LEN = 720; // 12 s
const W_RES_FROM = W_PROC_FROM + W_PROC_LEN; // 1140
const W_RES_LEN = 420; // 7 s
const W_CLOSE_FROM = W_RES_FROM + W_RES_LEN; // 1560

/** Process steps (local to the Process sequence). `scene` groups the steps that share one card; a scene change slides. */
export type StepId = "create" | "editor" | "content" | "styleAurora" | "styleNeon" | "palette";
export const PROCESS = {
  len: W_PROC_LEN,
  squeeze: 34, // the last frames: the card is drawn into the Sapphire line (the cut to the Home Screen)
  scenes: [
    { start: 0, label: "Create", word: "Create." },
    { start: 130, label: "Workshop", word: "Choose." },
    { start: 372, label: "Style", word: "Style." },
  ],
  steps: [
    { id: "create", at: 0, scene: 0 },
    { id: "editor", at: 130, scene: 1 },
    { id: "content", at: 250, scene: 1 },
    { id: "styleAurora", at: 372, scene: 2 },
    { id: "styleNeon", at: 452, scene: 2 },
    { id: "palette", at: 532, scene: 2 },
  ] as { id: StepId; at: number; scene: number }[],
  /** « With Premium » while a Premium option is on screen (styles Aurora / Neon, palette, background). */
  premium: { from: 380, to: 690 },
  pillFrom: 10,
  blade: 20,
  sceneTransition: 32,
};

export const WIDGET = {
  before: { from: 0, len: W_BEFORE_LEN, collapse: 16 },
  after: { from: W_BEFORE_LEN, len: W_AFTER_LEN, morphAt: [64, 130, 196, 262], morphLen: [30, 30, 30, 30] }, // 30: HomeBuilder staggers each slot by 3 frames (j * 3 must stay under morphLen ; 20 broke the render with 8 slots)
  process: { from: W_PROC_FROM, len: W_PROC_LEN },
  result: {
    from: W_RES_FROM,
    len: W_RES_LEN,
    installAt: 20,
    morphAt: [150, 238, 324],
    morphLen: [30, 30, 30],
    swallow: [W_RES_LEN - 44, W_RES_LEN - 8] as [number, number],
    fade: 8,
  },
  close: { from: W_CLOSE_FROM, len: CLOSE_LEN },
  total: W_CLOSE_FROM + CLOSE_LEN, // 1730 = 28.83 s
};
export const WIDGET_VO: VoLine[] = [
  { id: "W1", text: "You want your phone to look like this?", at: 30, words: 8 },
  { id: "W2", text: "With Ardane, you can customize your own widgets.", at: W_PROC_FROM + 20, words: 8 },
  { id: "W3", text: "And styles.", at: W_PROC_FROM + 372, words: 2 },
];
