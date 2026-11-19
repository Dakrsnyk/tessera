/**
 * ALL the timings of the two 2026-11-18 ads, VERSION 2 (frames at 60 fps; seconds = f / 60). Nothing else carries a duration.
 * Version 2 (PDG's feedback on v1): the voice comments what the image shows, no voice gap over 1.5 s between the hook and the outro,
 * « Meet Ardane. » right after the hook of the Main ad, 60 s at most. Every voice line is placed on its MEASURED length
 * (pub/pub26/audio/vo/*.json, Kokoro af_heart), noted after each line as « (n f) ».
 * HOOK and CLOSE_LEN are the validated ones: v5/short/timing.json `hookLength` (446) and v5/part2/timing.json sequences.close.length (170).
 */
export const FPS26 = 60;
export const HOOK = 446;
export const CLOSE_LEN = 170;
/** The validated end card: Close.tsx played through this remap (local frame -> Close frame), as in FilmMainV5Part2. */
export const CLOSE_REMAP = { input: [0, 30, CLOSE_LEN - 22, CLOSE_LEN], output: [56, 96, 216, 216] };
/** The outro line (« Ardane. Your whole life. One place. ») starts this many frames after the end card (validated v5part2 offset). */
export const OUTRO_AT = 26;

export type VoLine = { id: string; text: string; at: number };

// ---------------------------------------------------------------- Film 1: MainPub26 (56.0 s)
const M_HOMES_FROM = HOOK; // 446
const M_HOMES_LEN = 544;
const APP_LINK = 30; // overlap = the app's own entry / exit
/** One mini-app: its steps (keys of APP_SHOTS[id].steps in shots.ts): `at` = the screen arrives (same capture = same screen), `hi` = the highlight. */
type AppStepT = { key: string; at: number; hi: [number, number] };
type AppT = { id: "nutrition" | "fitness" | "planning"; eff: number; steps: AppStepT[]; vo: { id: string; text: string; at: number }[] };
// v2.3 (PDG, 2026-11-18): linking words (« Inside the app, you have Nutrition. », « There's also Fitness. », « Finally, there's Planning. »),
// « Rest on the timer » removed, « And your training on your lock screen. » (the workout Live Activity) at the end of Fitness.
const APPS_T: AppT[] = [
  {
    id: "nutrition",
    eff: 520,
    steps: [
      { key: "ring", at: 0, hi: [120, 228] },
      { key: "scan", at: 0, hi: [232, 292] },
      { key: "search", at: 296, hi: [314, 350] },
      { key: "amount", at: 356, hi: [370, 430] },
      { key: "added", at: 436, hi: [450, 510] },
    ],
    vo: [
      { id: "NI", text: "Inside the app, you have Nutrition.", at: 4 }, // (110 f)
      { id: "N1", text: "Know what's left to eat.", at: 136 }, // (76 f)
      { id: "N2b", text: "Scan your food, or search for it.", at: 232 }, // (106 f)
      { id: "N3", text: "Log it, and your day updates.", at: 360 }, // (102 f)
    ],
  },
  {
    id: "fitness",
    eff: 750,
    steps: [
      { key: "live", at: 0, hi: [36, 84] },
      { key: "sets", at: 90, hi: [104, 190] },
      { key: "library", at: 200, hi: [214, 368] },
      { key: "demo", at: 376, hi: [390, 480] },
      { key: "record", at: 490, hi: [504, 584] },
      { key: "lock", at: 592, hi: [612, 740] },
    ],
    vo: [
      { id: "FI", text: "There's also Fitness.", at: 4 }, // (73 f)
      { id: "F1b", text: "Track every set as you go.", at: 98 }, // (88 f)
      { id: "F3b", text: "Choose from over 160 exercises.", at: 208 }, // (155 f) ExerciseLibrary.all = 163, each with its animation (ExerciseDemos.json)
      { id: "F4", text: "Each one, demonstrated.", at: 384 }, // (92 f)
      { id: "F5b", text: "Watch your records climb.", at: 498 }, // (80 f)
      { id: "FL", text: "And your training on your lock screen.", at: 600 }, // (93 f) the Live Activity pops up at 612, « Set done » tapped at 692
    ],
  },
  {
    id: "planning",
    eff: 420,
    steps: [
      { key: "week", at: 0, hi: [36, 110] },
      { key: "events", at: 114, hi: [128, 188] },
      { key: "tasks", at: 114, hi: [192, 244] },
      { key: "streak", at: 248, hi: [262, 324] },
      { key: "done", at: 328, hi: [342, 410] },
    ],
    vo: [
      { id: "PI2", text: "Stay organized with Planning.", at: 4 }, // (97 f) v2.4: no more « Finally » (« And much more. » follows)
      { id: "P1b", text: "Your classes, events, and tasks.", at: 122 }, // (111 f)
      { id: "P2", text: "Build your habits.", at: 256 }, // (61 f)
      { id: "P3b", text: "Keep your streak going.", at: 338 }, // (70 f)
    ],
  },
];
const M_APPS_FROM = M_HOMES_FROM + M_HOMES_LEN; // 990
let acc = M_APPS_FROM;
const APPS = APPS_T.map((a) => {
  const from = acc;
  acc += a.eff;
  return { ...a, from, seqLen: a.eff + APP_LINK };
});
/** « And much more. » (v2.4): the other mini-apps scroll by, 2 s at most (PDG). */
const M_MORE_FROM = acc; // 2680
const M_MORE_LEN = 120;
const M_MAKE_FROM = M_MORE_FROM + M_MORE_LEN; // 2800
const M_MAKE_LEN = 390;
const M_CLOSE_FROM = M_MAKE_FROM + M_MAKE_LEN; // 3190

export const MAIN = {
  hook: { from: 0, len: HOOK },
  homes: {
    from: M_HOMES_FROM,
    len: M_HOMES_LEN,
    morphAt: [200, 300, 392],
    morphLen: [22, 22, 22],
    exit: 30,
    /** captions: « Meet Ardane. » then the PDG's line */
    meetAt: 10,
    meetUntil: 74,
    captionAt: 80,
  },
  apps: { from: M_APPS_FROM, link: APP_LINK, titleAt: 12, list: APPS },
  more: { from: M_MORE_FROM, len: M_MORE_LEN, titleAt: 12 },
  make: {
    from: M_MAKE_FROM,
    len: M_MAKE_LEN,
    isolatedLen: 172, // isolated widget (fades out under the Home that fades in)
    homeFrom: 150, // local frame where the Home Screen starts (its own frame 0)
    homeLen: M_MAKE_LEN - 150,
    homeFade: 12,
    installAt: 12,
    morphAt: [100],
    morphLen: [30],
    swallow: [M_MAKE_LEN - 150 - 46, M_MAKE_LEN - 150 - 8] as [number, number],
    captionAt: 14,
  },
  close: { from: M_CLOSE_FROM, len: CLOSE_LEN },
  total: M_CLOSE_FROM + CLOSE_LEN, // 3360 = 56.0 s
};
export const MAIN_VO: VoLine[] = [
  { id: "M0", text: "Meet Ardane.", at: M_HOMES_FROM + 10 }, // (50 f)
  { id: "M1", text: "All your essentials on your home screen.", at: M_HOMES_FROM + 80 }, // (110 f, v1 recording)
  { id: "M1b", text: "See today's workout.", at: M_HOMES_FROM + 214 }, // (75 f) on « Sport & wellness »
  { id: "M1c", text: "Check your calories.", at: M_HOMES_FROM + 314 }, // (63 f) on « Nutrition »
  { id: "M1d", text: "Without opening a single app.", at: M_HOMES_FROM + 404 }, // (98 f) on « Everything in one place »
  ...APPS.flatMap((a) => a.vo.map((v) => ({ id: v.id, text: v.text, at: a.from + v.at }))),
  { id: "MORE", text: "And much more.", at: M_MORE_FROM + 14 }, // (50 f)
  { id: "M5", text: "Make everyday your own.", at: M_MAKE_FROM + 14 }, // (75 f, v1 recording) on the isolated widget
  { id: "K1", text: "Start with one widget.", at: M_MAKE_FROM + 104 }, // (75 f)
  { id: "K2", text: "Then give it your style.", at: M_MAKE_FROM + 262 }, // (71 f) on the morph to Aurora
];

// ---------------------------------------------------------------- Film 2: WidgetPub26 (38.8 s)
const W_BEFORE_LEN = 90; // 1.5 s: the real iOS Home, no Ardane
const W_AFTER_LEN = 410; // five Homes, one at a time, one word each
const W_PROC_FROM = W_BEFORE_LEN + W_AFTER_LEN; // 500
const W_PROC_LEN = 1100;
const W_RES_FROM = W_PROC_FROM + W_PROC_LEN; // 1600
const W_RES_LEN = 560;
const W_CLOSE_FROM = W_RES_FROM + W_RES_LEN; // 2160

/** Process steps (local to the Process sequence). `scene` groups the steps that share one card; a scene change slides. */
export type StepId =
  | "create"
  | "editor"
  | "styleAurora"
  | "styleNeon"
  | "styleSpace"
  | "styleGlass"
  | "colorGold"
  | "paletteOcean"
  | "colorDusk"
  | "themeMidnight"
  | "themeLuxury"
  | "themeCyber"
  | "myWidgets";
export const PROCESS = {
  len: W_PROC_LEN,
  squeeze: 34, // the last frames: the card is drawn into the Sapphire line (the cut to the Home Screen)
  scenes: [
    { start: 0, label: "Create", word: "Create." },
    { start: 150, label: "Workshop", word: "Choose." },
    { start: 270, label: "Style", word: "Style." },
    { start: 540, label: "Colors", word: "Colors." },
    { start: 750, label: "Themes", word: "Themes." },
    { start: 960, label: "My widgets", word: "Add." },
  ],
  steps: [
    { id: "create", at: 0, scene: 0 },
    { id: "editor", at: 150, scene: 1 },
    { id: "styleAurora", at: 270, scene: 2 },
    { id: "styleNeon", at: 340, scene: 2 },
    { id: "styleSpace", at: 400, scene: 2 },
    { id: "styleGlass", at: 460, scene: 2 },
    { id: "colorGold", at: 540, scene: 3 },
    { id: "paletteOcean", at: 620, scene: 3 },
    { id: "colorDusk", at: 690, scene: 3 },
    { id: "themeMidnight", at: 750, scene: 4 },
    { id: "themeLuxury", at: 830, scene: 4 },
    { id: "themeCyber", at: 900, scene: 4 },
    { id: "myWidgets", at: 960, scene: 5 },
  ] as { id: StepId; at: number; scene: number }[],
  /** « With Premium » while a Premium option is on screen (styles, colours, palettes, themes). */
  premium: { from: 278, to: 966 },
  pillFrom: 10,
  blade: 20,
  sceneTransition: 32,
};

export const WIDGET = {
  before: { from: 0, len: W_BEFORE_LEN, collapse: 16 },
  // 30: HomeBuilder staggers each slot by 3 frames (j * 3 must stay under morphLen ; 20 broke the render with 8 slots)
  after: { from: W_BEFORE_LEN, len: W_AFTER_LEN, morphAt: [70, 150, 230, 310], morphLen: [30, 30, 30, 30] },
  process: { from: W_PROC_FROM, len: W_PROC_LEN },
  result: {
    from: W_RES_FROM,
    len: W_RES_LEN,
    installAt: 20,
    morphAt: [150, 280, 390],
    morphLen: [30, 30, 30],
    swallow: [W_RES_LEN - 44, W_RES_LEN - 8] as [number, number],
    fade: 8,
    /** the title of the ad as a caption on the last Home */
    titleAt: 404,
  },
  close: { from: W_CLOSE_FROM, len: CLOSE_LEN },
  total: W_CLOSE_FROM + CLOSE_LEN, // 2330 = 38.83 s
};
export const WIDGET_VO: VoLine[] = [
  { id: "W1", text: "You want your phone to look like this?", at: 30 }, // (98 f, v1 recording)
  { id: "A1", text: "Elegant.", at: W_BEFORE_LEN + 86 }, // (39 f) bronze / Luxury
  { id: "A2", text: "Colorful.", at: W_BEFORE_LEN + 166 }, // (42 f) rose
  { id: "A3", text: "Sleek.", at: W_BEFORE_LEN + 246 }, // (36 f) indigo
  { id: "A4", text: "Or bold.", at: W_BEFORE_LEN + 326 }, // (45 f) synthwave
  { id: "W2", text: "With Ardane, you can customize your own widgets.", at: W_PROC_FROM + 20 }, // (153 f, v1 recording)
  { id: "S1", text: "Choose what it shows.", at: W_PROC_FROM + 190 }, // (64 f)
  { id: "W3", text: "And styles.", at: W_PROC_FROM + 280 }, // (51 f, v1 recording)
  { id: "S2", text: "Neon.", at: W_PROC_FROM + 350 }, // (38 f)
  { id: "S3", text: "Space.", at: W_PROC_FROM + 410 }, // (40 f)
  { id: "S4", text: "Liquid Glass.", at: W_PROC_FROM + 470 }, // (58 f)
  { id: "S5", text: "Pick your colors.", at: W_PROC_FROM + 550 }, // (57 f)
  { id: "S6", text: "Or a whole palette.", at: W_PROC_FROM + 630 }, // (61 f)
  { id: "S7", text: "Or start from a theme.", at: W_PROC_FROM + 760 }, // (73 f)
  { id: "S7b", text: "One tap, and it all changes.", at: W_PROC_FROM + 850 }, // (102 f)
  { id: "S8", text: "Then add it to your home screen.", at: W_PROC_FROM + 975 }, // (91 f)
  { id: "R1", text: "Watch your screen come together.", at: W_RES_FROM + 24 }, // (94 f) while the widgets land
  { id: "R2", text: "Small, medium, or large.", at: W_RES_FROM + 170 }, // (96 f) on the Large widget
  { id: "R3", text: "No two screens alike.", at: W_RES_FROM + 296 }, // (79 f)
  { id: "R4", text: "Your phone. Your style. Your widgets.", at: W_RES_FROM + 404 }, // (115 f)
];
