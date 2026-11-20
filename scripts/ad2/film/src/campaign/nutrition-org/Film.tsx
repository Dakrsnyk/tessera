import { AbsoluteFill, getStaticFiles, Img, interpolate, OffthreadVideo, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../../components/Grain";
import { clamp, INTER } from "../../lib/brand";
import { setKitLang } from "../../lib/kit";
import { LangContext } from "../../lib/i18n";
import { TimeRemap } from "../../lib/time";
import { StatusBar } from "../../avantapres/Home";
import { IosAppIcon, IosLabel } from "../../lib/IosChromeDom";
import { appleIcon, dockX, glassTint, iconXY, IOS, IOS_DOCK, iosRect } from "../../lib/iosHome";
import { FadeIn, OptionalAudio } from "../../pub26/parts";
import { Close } from "../../scenes/Close";
import { Seq, Word } from "../lib";

/**
 * v5 (2026-11-20): the photo scan of a COOKED dish, set down (grilled chicken, white rice, green salad: plate-done.mp4), then a hard
 *   cut on the app's real result (camp-scan-recap-photo2: three « Estimation » lines, ≈ total); « Or search. » moves to the food
 *   search. The scan takes one more beat, the targets one less: from 15.8 s on, every time is v4's. v4 kept in FilmV4.tsx.txt.
 *   No shutter in scan-frame-white (the simulator has no camera, so FoodScanView hides its controls): no touch drawn on the scanner.
 * v4 (2026-11-20): the scanner aims at a dish already made (breakfast-done.mp4), never at one being prepared; v3 kept in FilmV3.tsx.txt.
 * Campaign 2026-11, « nutrition » ORGANIC v3 (2026-11-20; v2 in FilmV2.tsx.txt, v1 in FilmV1.tsx.txt). v3, after the user's review of
 * the night's ads (« good bases »): 20 to 30 s, the customisation in every ad (Studio on its Style part, then the widget in real
 * styles), more essential functions (macros, the day's meals, the week, the targets). v2 header below.
 * Campaign 2026-11, « nutrition » ORGANIC v2 (2026-11-20; v1 kept in FilmV1.tsx.txt), on the model of the validated Fitness organic
 * v4.3 (../fitness-org/Film.tsx) and Planning organic v2 (../planning-org2/Film.tsx); parts copied here, nothing shared is modified.
 * No voice, music only: Pixabay pop-fresh-pop-141468, measured 100.0 BPM (kick attacks at 0.12 s mod 0.6 of the track), played in
 * one piece from 0.2 s; its first drop (kick at 9.71 s of the track, after a 16-beat intro) lands on the iPhone at 1.4 s. Beats of the
 * film: 0.2 + 0.6 k s = frame 12 + 36 k; every cut is on one.
 * Art direction « Nutrition »: warm and appetising (light kitchen, daylight), captions in ink with an orange accent (the calorie ring of
 * the app is orange, NutritionColors).
 * The story follows the app's real path from the widget (no simulator-only button):
 * - the Calories left widget (medium, Light, export camp-caloriesLeft-m-light of run 44697889437) on a Home Screen with real Apple
 *   apps; its « Scan » button is a Link to DeepLink.scanFood (Shared/Render/Tiles/TileView.swift, NutritionTiles headerButton), which
 *   the app opens as `FoodSearchView(startsWithScanner: true)` (App/ArdaneApp.swift, Router.handle .scanFood);
 * - the scanner (real capture scan-frame-white of 2026-11-20, its camera area drawn white: a real salad is put under it by multiply
 *   only, nothing redrawn); its « Search or create the food » calls onFinish(.search) (FoodScanView.swift), which closes the scanner
 *   on the « Add a food » search under it (NutritionSpace.swift FoodSearchView: `scanOutcome = outcome; showsScanner = false`);
 * - « Add a food » -> Plain Greek yogurt -> its amount, Save (nut-1, nut-2 of the UI test testAdNutritionAdd, kit of 2026-11-19);
 * - the calorie card of the Nutrition page in close-up: 1,672 then 1,569 kcal left (nut-0 / nut-3 of the same test).
 * The widget's own demo numbers (1,122 left of 2,200) are another data set than the app screens (1,672 -> 1,569 of 2,750): the widget
 * stays small on the Home Screen at the start, never in close-up, and the close-up comes six beats later.
 * v3: then the macros on the same card -> the day's meals (nut-3: Breakfast 562 kcal, 4 foods) -> the 7-day history (Premium) -> the
 * weight goal targets -> « Make it yours. » (greens) -> the Studio, Style part, on Calories left -> the widget in 7 real styles ->
 * the final Home Screen -> salad shot -> end card. 26.3 s. The widget's data set (1,122) comes back only from 17.0 s, after
 * three other screens: never next to the close-up of the app's card (1,672 -> 1,569, 7.4 .. 10.4 s).
 * Sound: ~/ardane-tools/campaign/nutrition/org_audio.py (copy in pub/campagne-2026-11/nutrition/organique/).
 * Safe zone (TikTok / Reels): texts in x 60..940, y 220..1540.
 */
export const FPS = 60;
const B = 36; // one beat at 100 BPM
const g = (k: number) => 12 + B * k; // film frame of beat k
const T = {
  hook: [0, g(2)], // 0 .. 1.4 s
  home: [g(2), 4 * B], // 1.4 .. 3.8 s: the phone comes up; captions at 2.0 and 2.6 s; touch on « Scan » at 3.2 s
  scan: [g(6), 3 * B], // 3.8 .. 5.6 s: the scanner on the plate one beat, the result two beats (v5)
  search: [g(9), 2 * B], // 5.6 .. 6.8 s: touch on the yogurt at 6.2 s
  amount: [g(11), 2 * B], // 6.8 .. 8.0 s: touch on Save at 7.4 s
  after: [g(13), 5 * B], // 8.0 .. 11.0 s: 1,672 one beat, 1,569 two beats, then the macros two beats
  meals: [g(18), 3 * B], // 11.0 .. 12.8 s
  history: [g(21), 3 * B], // 12.8 .. 14.6 s
  plan: [g(24), 2 * B], // 14.6 .. 15.8 s (v5: one beat less)
  yours: [g(26), 2 * B], // 15.8 .. 17.0 s
  studio: [g(28), 3 * B], // 17.0 .. 18.8 s
  styles: [g(31), 4 * B], // 18.8 .. 21.2 s: a style every half beat (18 frames)
  homeEnd: [g(35), 4 * B], // 21.2 .. 23.6 s
  meal: [g(39), 2 * B], // 23.6 .. 24.8 s: the music fades over the last beat
  end: [g(41), 90], // 24.8 .. 26.3 s
} as const;
export const ORG_NUTRITION_LENGTH = T.end[0] + T.end[1]; // 1578 = 26.3 s
const f = (s: number) => Math.round(s * FPS);
const INK = "#1E140C";
const ORANGE = "#F07A00"; // accent on light backgrounds (the app's ring FF9500, a shade deeper to read on cream)
const clip = (n: string) => staticFile(`campaign/nutrition-org/${n}.mp4`);
const cap = (n: string) => staticFile(`campaign/nutrition-org/${n}.png`);

/** Footage, warm daylight grade, slow push-in; `bg`: blurred, lifted and creamed behind a screen. */
const Footage: React.FC<{ name: string; dur: number; from?: number; zoom?: [number, number]; bg?: boolean }> = ({ name, dur, from = 0, zoom = [1.03, 1.07], bg = false }) => {
  const fr = useCurrentFrame();
  const z = interpolate(fr, [0, dur], zoom);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#F3E6D6" }}>
      <OffthreadVideo src={clip(name)} muted startFrom={from} style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${bg ? 1.15 : z})`, filter: bg ? "blur(24px) saturate(0.9) brightness(1.08)" : "saturate(1.08) contrast(1.04) brightness(1.03)" }} />
      <AbsoluteFill style={{ background: "#FFB45A", mixBlendMode: "soft-light", opacity: 0.22 }} />
      {bg && <AbsoluteFill style={{ background: "rgba(255,247,236,0.42)" }} />}
    </AbsoluteFill>
  );
};

/** Big left-aligned caption, Inter 800, hard in, hard out. Each line: [text, colour]. */
type Line = [string, string];
const Big: React.FC<{ lines: Line[]; top: number; size: number; lh?: number; shadow?: string }> = ({ lines, top, size, lh = Math.round(size * 1.08), shadow = "none" }) => (
  <div style={{ position: "absolute", left: 60, top, fontFamily: INTER, fontWeight: 800, fontSize: size, lineHeight: `${lh}px`, letterSpacing: "-0.025em", whiteSpace: "nowrap", textShadow: shadow }}>
    {lines.map(([t, c], i) => (
      <div key={i} style={{ color: c }}>
        {t}
      </div>
    ))}
  </div>
);
/** One-line caption over a light shot: ink, then the accent. */
const Head: React.FC<{ ink: string; accent?: string; size?: number }> = ({ ink, accent, size = 84 }) => (
  <div style={{ position: "absolute", left: 60, top: 230, fontFamily: INTER, fontWeight: 800, fontSize: size, lineHeight: 1, letterSpacing: "-0.025em", color: INK, whiteSpace: "nowrap", textShadow: "0 2px 18px rgba(255,248,240,0.7)" }}>
    {ink}
    {accent && <span style={{ color: ORANGE }}>{accent}</span>}
  </div>
);
/** Small Premium line in the safe zone. */
const Premium: React.FC<{ top: number; text: string }> = ({ top, text }) => (
  <div style={{ position: "absolute", left: 60, top, fontFamily: INTER, fontWeight: 500, fontSize: 28, color: "rgba(30,20,12,0.62)" }}>{text}</div>
);

/** A ring that beats on each `beats` frame (scale 1.08 -> 1, opacity 1 -> 0.55). Capture px when drawn inside a screen. */
const Ring: React.FC<{ x: number; y: number; w: number; h: number; r: number; color?: string; beats: number[]; width?: number }> = ({ x, y, w, h, r, color = ORANGE, beats, width = 10 }) => {
  const fr = useCurrentFrame();
  const last = [...beats].reverse().find((b) => fr >= b);
  if (last === undefined) return null;
  const p = interpolate(fr - last, [0, 22], [0, 1], clamp);
  return <div style={{ position: "absolute", left: x, top: y, width: w, height: h, borderRadius: r, border: `${width}px solid ${color}`, boxSizing: "border-box", opacity: 1 - 0.45 * p, transform: `scale(${1.08 - 0.08 * p})`, boxShadow: `0 0 30px ${color}88` }} />;
};

/** The touch indicator (no hand), capture px: a disc lands at `at` (small bounce), a ripple, gone at `until`. */
const Touch: React.FC<{ cx: number; cy: number; at: number; until: number; r?: number }> = ({ cx, cy, at, until, r = 90 }) => {
  const fr = useCurrentFrame();
  if (fr < at - 8 || fr >= until) return null;
  const k = fr - (at - 8);
  const s = interpolate(k, [0, 8, 13, 18], [1.5, 0.86, 1.04, 1], clamp);
  const o = interpolate(k, [0, 6], [0, 1], clamp);
  const rp = interpolate(fr, [at, at + 22], [0, 1], clamp);
  return (
    <>
      {fr >= at && <div style={{ position: "absolute", left: cx - r * 1.25, top: cy - r * 1.25, width: r * 2.5, height: r * 2.5, borderRadius: r * 1.25, border: "10px solid rgba(255,255,255,0.95)", boxSizing: "border-box", opacity: 1 - rp, transform: `scale(${1 + 1.4 * rp})`, boxShadow: "0 0 18px rgba(0,0,0,0.25)" }} />}
      <div style={{ position: "absolute", left: cx - r, top: cy - r, width: 2 * r, height: 2 * r, borderRadius: r, background: "rgba(120,120,120,0.35)", border: "7px solid rgba(255,255,255,0.95)", boxSizing: "border-box", boxShadow: "0 8px 30px rgba(0,0,0,0.35)", opacity: o, transform: `scale(${s})` }} />
    </>
  );
};

// ---------------------------------------------------------------- the phone: a bare rounded screen (no drawn case), 600 px wide
// 600 px (as Fitness): every touched control and the history chart stay above the bottom 380 px hidden by TikTok.
const STOP = 370;
const PW = 600;
// `crop`: the screen cut at that capture y (rounded bottom too), to leave out what lies below (the simulator-only « Add a food »).
const Phone: React.FC<{ y?: number; crop?: number; children: React.ReactNode }> = ({ y = 0, crop = 2622, children }) => {
  const sc = PW / 1206;
  return (
    <div style={{ position: "absolute", left: (1080 - PW) / 2, top: STOP, width: PW, height: crop * sc, borderRadius: crop < 2622 ? `${165 * sc}px ${165 * sc}px ${40 * sc}px ${40 * sc}px` : 165 * sc, overflow: "hidden", transform: `translateY(${y}px)`, boxShadow: "0 50px 130px rgba(90,50,10,0.32), 0 0 0 2px rgba(0,0,0,0.06)", background: "#fff" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, transform: `scale(${sc})`, transformOrigin: "0 0" }}>{children}</div>
    </div>
  );
};
const Cap: React.FC<{ name: string }> = ({ name }) => <Img src={cap(name)} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />;
/** A shot of the demo: the blurred breakfast behind, the phone (still, the same place in every shot: the screen changes, not the frame). */
const DemoShot: React.FC<{ dur: number; arrive?: boolean; crop?: number; bg?: string; children: React.ReactNode }> = ({ dur, arrive = false, crop, bg = "breakfast-done", children }) => {
  const fr = useCurrentFrame();
  // damped spring as Fitness v4.3: settled by ~0.5 s
  const t = fr / FPS;
  const p = arrive ? 1 - Math.exp(-t / 0.12) * Math.cos((2 * Math.PI * t) / 0.7) : 1;
  return (
    <AbsoluteFill>
      {hasClip(bg) && <Footage name={bg} dur={dur} bg />}
      <Phone y={(1 - p) * 1700} crop={crop}>
        {children}
      </Phone>
    </AbsoluteFill>
  );
};

/** The calorie card of the Nutrition page (capture x 60..1146, y 760..1282, measured on nut-0 / nut-3), alone, 1000 px wide, y 700.
 * Its calorie ring (centre x 276, y 960 of the capture) marked on the beats once it shows the new total. */
const CARD = { x: 60, y: 760, w: 1086, h: 522 };
const CW = 1000;
const CS = CW / CARD.w;
const RingCard: React.FC<{ name: string; marked: boolean; macros?: boolean }> = ({ name, marked, macros = false }) => (
  <div style={{ position: "absolute", left: 40, top: 700, width: CW, height: CARD.h * CS, borderRadius: 64 * CS, overflow: "hidden", boxShadow: "0 40px 110px rgba(90,50,10,0.3)" }}>
    <div style={{ position: "absolute", left: -CARD.x * CS, top: -CARD.y * CS, width: 1206, height: 2622, transform: `scale(${CS})`, transformOrigin: "0 0" }}>
      <Cap name={name} />
      {marked && !macros && <Ring x={86} y={770} w={380} h={380} r={190} beats={[B, 2 * B]} />}
      {/* the three macro bars (Protein 107/156, Carbs 150/338, Fat 17/86): x 490..1110, y 820..1120, measured */}
      {macros && <Ring x={480} y={812} w={636} h={316} r={40} beats={[3 * B, 4 * B]} />}
    </div>
  </div>
);

// ---------------------------------------------------------------- the Home Screen (real iOS grid, real Apple icons, real export)
/** The medium Calories left widget at row 0 (iosRect: x 81, y 272, 1046 x 489), eight real Apple apps under it (none of the Dock,
 * never Utilities nor Calendar), the warm Dunes wallpaper of the Store. « Scan » in the export: x 880..1064, y 72..136 of 1092 x 510. */
const WIDGET = iosRect("m", 0, 0);
const WK = WIDGET[2] / 1092;
const SCAN = { x: WIDGET[0] + 880 * WK, y: WIDGET[1] + 72 * WK, w: 184 * WK, h: 64 * WK };
const APPS: [string, number, number][] = [
  ["Health", 0, 2],
  ["Fitness", 1, 2],
  ["Reminders", 2, 2],
  ["Maps", 3, 2],
  ["Wallet", 0, 3],
  ["News", 1, 3],
  ["Files", 2, 3],
  ["Contacts", 3, 3],
];
/** Final Home: the medium widget in the style picked in the Studio, the small Calories left ring (Light, camp-caloriesLeft-s-light,
 * same data set) under it on the left, eight Apple apps around (none of the Dock, never Utilities nor Calendar). */
const APPS_END: [string, number, number][] = [
  ["Health", 2, 2],
  ["Fitness", 3, 2],
  ["Reminders", 2, 3],
  ["Maps", 3, 3],
  ["Wallet", 0, 4],
  ["News", 1, 4],
  ["Files", 2, 4],
  ["Contacts", 3, 4],
];
const SMALL = iosRect("s", 0, 2);
const HomePage: React.FC<{ widget?: string; final?: boolean }> = ({ widget = "camp-caloriesLeft-m-light", final = false }) => {
  const tint = glassTint(false);
  return (
    <>
      <Img src={cap("wall-dunes")} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />
      {has(widget) ? <Img src={cap(widget)} style={{ position: "absolute", left: WIDGET[0], top: WIDGET[1], width: WIDGET[2], height: WIDGET[3], filter: "drop-shadow(0 8px 14px rgba(0,0,0,0.16))" }} /> : <Missing name={widget} rect={WIDGET} />}
      <IosLabel x={WIDGET[0]} y={WIDGET[1] + WIDGET[3] + 18} w={WIDGET[2]} text="Ardane" dark={false} />
      {final && (
        <>
          <Img src={cap("camp-caloriesLeft-s-light")} style={{ position: "absolute", left: SMALL[0], top: SMALL[1], width: SMALL[2], height: SMALL[3], filter: "drop-shadow(0 8px 14px rgba(0,0,0,0.16))" }} />
          <IosLabel x={SMALL[0]} y={SMALL[1] + SMALL[3] + 18} w={SMALL[2]} text="Ardane" dark={false} />
        </>
      )}
      {(final ? APPS_END : APPS).map(([name, c, r]) => {
        const [x, y] = iconXY(c, r);
        return <IosAppIcon key={name} name={name} x={x} y={y} dark={false} />;
      })}
      <StatusBar ink="#1E140C" />
      <div style={{ position: "absolute", left: 0, width: 1206, top: 2146, display: "flex", justifyContent: "center", gap: 26 }}>
        <div style={{ width: 22, height: 22, borderRadius: 11, background: "rgba(255,255,255,0.95)" }} />
        <div style={{ width: 22, height: 22, borderRadius: 11, background: "rgba(255,255,255,0.45)" }} />
      </div>
      <div style={{ position: "absolute", left: 52, top: IOS.dockTop, width: 1100, height: 304, borderRadius: 120, background: tint.fill, border: `2px solid ${tint.line}`, boxSizing: "border-box" }} />
      {IOS_DOCK.map((name, i) => (
        <Img key={name} src={staticFile(appleIcon(name))} style={{ position: "absolute", left: dockX(i, IOS_DOCK.length), top: IOS.dockIconTop, width: IOS.icon, height: IOS.icon, filter: "drop-shadow(0 6px 9px rgba(0,0,0,0.18))" }} />
      ))}
    </>
  );
};

// ---------------------------------------------------------------- customisation (exports of the [adkit-en] run of 2026-11-20, morning)
/** A file of public/campaign/nutrition-org exists? (the Studio pieces arrive after the rest: until then a grey placeholder) */
const RECAP = "camp-scan-recap-photo2"; // the photo scan's result (kit, adkit-en of 2026-11-20), copied here
const PLATE = "plate-done"; // Pexels 34453034, 4.5 .. 7.5 s (tongs gone by 4.0 s, a gloved hand from 13.5 s): roast chicken leg on rice, salad bowl
const hasClip = (n: string) => getStaticFiles().some((x) => x.name === `campaign/nutrition-org/${n}.mp4`);
const has = (n: string) => {
  try {
    return getStaticFiles().some((x) => x.name === `campaign/nutrition-org/${n}.png`);
  } catch {
    return true;
  }
};
const Missing: React.FC<{ name: string; rect?: number[] }> = ({ name, rect = [0, 0, 1206, 2622] }) => (
  <div style={{ position: "absolute", left: rect[0], top: rect[1], width: rect[2], height: rect[3], background: "#C9CED6", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: INTER, fontSize: 56, color: "#333", textAlign: "center" }}>
    MISSING
    <br />
    {name}
  </div>
);
/** The Studio on its Style part, opened on the medium Calories left widget (capture camp-studio-caloriesLeft-light). */
const STUDIO = "camp-studio-caloriesLeft-light";
/** The widget in 7 real styles (exports camp-caloriesLeft-m-st-*, same data set), one per half beat, HARD cuts, no dissolve: the free
 * ones first (Light, Dark, Minimal), then the Premium ones (Pastel, Aurora, Neon, Blossom) with the mention, the last one FINAL_STYLE
 * (the final Home Screen). */
const STYLES = ["light", "dark", "minimal", "pastel", "aurora", "neon", "blossom"];
const PREMIUM_STYLES = ["pastel", "blossom", "aurora", "neon"];
const FINAL_STYLE = "light"; // v5.1 (2026-11-20): the user asked for the Light widget (macros) on the final Home Screen instead of Blossom (pink)
const stFile = (st: string) => `camp-caloriesLeft-m-st-${st}`;
const StyleCycle: React.FC = () => {
  const fr = useCurrentFrame();
  const i = Math.min(STYLES.length - 1, Math.floor(fr / 18));
  const n = stFile(STYLES[i]);
  const W = 960;
  return (
    <AbsoluteFill>
      <Img src={cap("wall-dunes")} style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover", transform: "scale(1.15)", filter: "blur(6px)" }} />
      {has(n) ? <Img src={cap(n)} style={{ position: "absolute", left: 60, top: 720, width: W, height: (W * 510) / 1092, filter: "drop-shadow(0 40px 80px rgba(90,50,10,0.35))" }} /> : <Missing name={n} rect={[60, 720, W, (W * 510) / 1092]} />}
      {PREMIUM_STYLES.includes(STYLES[i]) && <Premium top={1200} text="Some styles With Premium" />}
    </AbsoluteFill>
  );
};

/** scan-frame-white: the camera area starts at y 426 (capture px); « Search or create the food »: centre x 602, y 2418, measured. */
const CAM = 426;
const PLATE_ZOOM = 1.0; // plate-done fills the camera area as shot: salad bowl and plate both in the viewfinder (measured)
const PLATE_ORIGIN = "50% 50%";

export const OrgNutrition: React.FC<{ silent?: boolean }> = ({ silent = false }) => {
  setKitLang("en");
  const fr = useCurrentFrame();
  const local = (s: readonly [number, number]) => fr - s[0];
  return (
    <LangContext.Provider value="en">
      <AbsoluteFill style={{ background: "#F7EDE2", fontFamily: INTER }}>
        {/* 0.0 s the hook on a real breakfast, finished and set down (v4: no hand garnishing it, arms hanging at the edge only) */}
        <Seq t={T.hook}>
          <Footage name="breakfast-done" dur={T.hook[1]} zoom={[1.03, 1.08]} />
          <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(255,246,234,0.55) 0px, rgba(255,246,234,0) 720px)" }} />
          <Big lines={[["Still guessing", INK], ["your calories?", ORANGE]]} top={230} size={100} lh={108} shadow="0 2px 22px rgba(255,248,240,0.8)" />
        </Seq>

        {/* 1.4 s on the drop: the iPhone comes up on the Home Screen with the Calories left widget; 2.0 s « Right on your Home Screen. »,
            2.6 s « Tap Scan. » and the ring on « Scan », 3.2 s the touch */}
        <Seq t={T.home}>
          <DemoShot dur={T.home[1]} arrive>
            <HomePage />
            <Ring x={SCAN.x - 14} y={SCAN.y - 14} w={SCAN.w + 28} h={SCAN.h + 28} r={(SCAN.h + 28) / 2} beats={[2 * B]} />
            <Touch cx={SCAN.x + SCAN.w / 2} cy={SCAN.y + SCAN.h / 2} at={3 * B} until={4 * B} r={70} />
          </DemoShot>
          {local(T.home) >= B && (local(T.home) < 2 * B ? <Head ink="Right on your " accent="Home Screen." size={76} /> : <Head ink="Tap " accent="Scan." />)}
        </Seq>

        {/* 3.8 s the scanner on a cooked dish, set down (grilled chicken, white rice, green salad), by multiply only (nothing redrawn);
            4.4 s a hard cut on the app's result for that dish (three « Estimation » lines, ≈ total). Free: no Premium mention. */}
        <Seq t={T.scan}>
          <DemoShot dur={T.scan[1]} bg={PLATE}>
            {local(T.scan) < B ? (
              <>
                <Cap name="scan-frame-white" />
                <div style={{ position: "absolute", left: 0, top: CAM, width: 1206, height: 2622 - CAM, overflow: "hidden" }}>
                  {hasClip(PLATE) ? (
                    <OffthreadVideo src={clip(PLATE)} muted style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover", transform: `scale(${PLATE_ZOOM})`, transformOrigin: PLATE_ORIGIN, filter: "saturate(1.08) contrast(1.04) brightness(1.06)" }} />
                  ) : (
                    <Missing name={PLATE} rect={[0, 0, 1206, 2622 - CAM]} />
                  )}
                  <Img src={cap("scan-frame-white")} style={{ position: "absolute", left: 0, top: -CAM, width: 1206, height: 2622, mixBlendMode: "multiply" }} />
                </div>
              </>
            ) : has(RECAP) ? (
              <Cap name={RECAP} />
            ) : (
              <Missing name={RECAP} />
            )}
          </DemoShot>
          {local(T.scan) < B ? <Head ink="Snap your " accent="plate." /> : <Head ink="Every food, " accent="found." />}
        </Seq>

        {/* 5.6 s the food search (nut-1), « Or search. » one beat then « Pick a food. »; 6.2 s the touch on « Plain Greek yogurt 0% » (row y 1700..1880, its ⊕ at x 1078, y 1784) */}
        <Seq t={T.search}>
          <DemoShot dur={T.search[1]}>
            <Cap name="nut-1" />
            <Ring x={34} y={1690} w={1138} h={200} r={50} beats={[0]} />
            <Touch cx={1078} cy={1784} at={B} until={2 * B} r={80} />
          </DemoShot>
          {local(T.search) < B ? <Head ink="Or " accent="search." /> : <Head ink="Pick a " accent="food." />}
        </Seq>

        {/* 6.8 s its amount (nut-2: Plain Greek yogurt 0 %, 175 g = ¾ cup), 7.4 s the touch on Save */}
        <Seq t={T.amount}>
          <DemoShot dur={T.amount[1]}>
            <Cap name="nut-2" />
            {/* the « ¾ cup » chip: x 410..624, y 1030..1136, measured */}
            <Ring x={396} y={1016} w={242} h={134} r={67} beats={[0]} width={8} />
            <Touch cx={1052} cy={332} at={B} until={2 * B} r={80} />
          </DemoShot>
          <Head ink="Set the " accent="amount." />
          {/* the sheet lists fiber and sugars: nutrients beyond the 4 macros are Premium (Nutrient.free, FoodLogSheet) */}
          <Premium top={326} text="More nutrients With Premium" />
        </Seq>

        {/* 8.0 s the calorie card in close-up, a hard cut, not a zoom: before (nut-0, 1,672 kcal left) one beat, then on the beat after
            (nut-3, 1,569 kcal left, 1,181 eaten): the same crop of both real captures */}
        <Seq t={T.after}>
          <AbsoluteFill>
            <Footage name="breakfast-done" dur={T.after[1]} bg />
            <RingCard name={local(T.after) < B ? "nut-0" : "nut-3"} marked={local(T.after) >= B} macros={local(T.after) >= 3 * B} />
          </AbsoluteFill>
          {local(T.after) >= B && local(T.after) < 3 * B && <Big lines={[["Always know", INK], ["what's left.", ORANGE]]} top={400} size={100} lh={108} shadow="0 2px 22px rgba(255,248,240,0.8)" />}
          {local(T.after) >= 3 * B && <Big lines={[["Protein, carbs,", INK], ["fat. All of it.", ORANGE]]} top={400} size={100} lh={108} shadow="0 2px 22px rgba(255,248,240,0.8)" />}
        </Seq>

        {/* 11.0 s the day's meals (nut-3, after the yogurt: Breakfast 562 kcal, 4 foods; row x 60..1146, y 1960..2100, measured);
            the screen cut at y 2150, above the simulator-only « Add a food » button */}
        <Seq t={T.meals}>
          <DemoShot dur={T.meals[1]} crop={2150}>
            <Cap name="nut-3" />
            <Ring x={40} y={1950} w={1126} h={160} r={44} beats={[0, B, 2 * B]} />
          </DemoShot>
          <Head ink="Every meal, " accent="logged." />
        </Seq>

        {/* 12.8 s the 7-day history (camp-nutrition-history, 2026-11-20; the 7/30-day history is Premium) */}
        <Seq t={T.history}>
          <DemoShot dur={T.history[1]}>
            <Cap name="camp-nutrition-history" />
          </DemoShot>
          <Head ink="Your whole " accent="week." />
          <Premium top={326} text="With Premium" />
        </Seq>

        {/* 14.6 s the weight goal: daily targets worked out (WeightPlanSummaryView, estimates; free; camp-nutrition-plan, 2026-11-20) */}
        <Seq t={T.plan}>
          <DemoShot dur={T.plan[1]}>
            <Cap name="camp-nutrition-plan" />
          </DemoShot>
          <Head ink="Targets for " accent="your goal." size={80} />
        </Seq>

        {/* 15.8 s greens in a bowl (hands only): the customisation part */}
        <Seq t={T.yours}>
          <Footage name="greens" dur={T.yours[1]} />
          <AbsoluteFill style={{ background: "linear-gradient(180deg, rgba(255,246,234,0.6) 0px, rgba(255,246,234,0) 700px)" }} />
          <Big lines={[["Make it", INK], ["yours.", ORANGE]]} top={230} size={104} lh={112} shadow="0 2px 22px rgba(255,248,240,0.8)" />
        </Seq>

        {/* 17.0 s the Studio, Style part, on the Calories left widget */}
        <Seq t={T.studio}>
          <DemoShot dur={T.studio[1]} crop={1700}>
            {has(STUDIO) ? <Cap name={STUDIO} /> : <Missing name={STUDIO} />}
            {/* the Studio preview shows the app's data set (1,672 of 2,750): the Light export of the same widget (widget data set, 1,122,
                as the 7 styles after it) laid exactly over the preview card (x 128..1078, y 453..897, measured); the screen cut at
                y 1700 leaves out the style thumbnails (app data set too) */}
            <Img src={cap(stFile("light"))} style={{ position: "absolute", left: 128, top: 453, width: 950, height: (950 * 510) / 1092 }} />
            {/* « 3 Style », the part open: x 790..1140, y 1200..1320, measured */}
            <Ring x={786} y={1196} w={360} h={128} r={64} beats={[0, B, 2 * B]} />
          </DemoShot>
          <Head ink="Pick a " accent="style." />
        </Seq>

        {/* 18.8 s the widget in 7 real styles, hard cuts on the half beats */}
        <Seq t={T.styles}>
          <StyleCycle />
          <Head ink="Your " accent="colors." />
        </Seq>

        {/* 21.2 s the final Home Screen: the widget in its new style, the small ring, real Apple apps */}
        <Seq t={T.homeEnd}>
          <DemoShot dur={T.homeEnd[1]}>
            <HomePage widget={stFile(FINAL_STYLE)} final />
          </DemoShot>
          <Head ink="Always " accent="in sight." />
          {PREMIUM_STYLES.includes(FINAL_STYLE) && <Premium top={326} text="Some widgets and styles With Premium" />}
        </Seq>

        {/* 23.6 s a real salad, hands only */}
        <Seq t={T.meal}>
          <Footage name="salad" dur={T.meal[1]} from={f(3.4)} />
          <Word text="every bite, counted." until={T.meal[1]} size={68} />
        </Seq>

        {/* 24.8 s short end card: the validated Close on its settled state, « Available on the App Store » (decision of 2026-11-19) */}
        <Seq t={T.end}>
          <FadeIn n={8}>
            <TimeRemap input={[0, T.end[1]]} output={[196, 216]}>
              <Close audio={false} tagline="" cta="AVAILABLE ON THE APP STORE" ctaScale={1.15} tile />
            </TimeRemap>
          </FadeIn>
        </Seq>
        <Grain amount={0.02} />
        <OptionalAudio file="campaign/nutrition-org/mix.wav" silent={silent} />
      </AbsoluteFill>
    </LangContext.Provider>
  );
};
