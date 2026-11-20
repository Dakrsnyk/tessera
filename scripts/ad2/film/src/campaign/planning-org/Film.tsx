import { AbsoluteFill, Img, interpolate, OffthreadVideo, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../../components/Grain";
import { INTER } from "../../lib/brand";
import { setKitLang } from "../../lib/kit";
import { LangContext } from "../../lib/i18n";
import { StatusBar } from "../../avantapres/Home";
import { IosAppIcon, IosLabel } from "../../lib/IosChromeDom";
import { appleIcon, dockX, glassTint, iconXY, IOS, IOS_DOCK, iosRect } from "../../lib/iosHome";
import { TimeRemap } from "../../lib/time";
import { FadeIn, OptionalAudio } from "../../pub26/parts";
import { Close } from "../../scenes/Close";
import { Footage, Seq } from "../lib";

/**
 * Campaign 2026-11, « planning » ORGANIC n°1 (2026-11-19): the lessons of docs/memoire/campagne-2026/25-lecons-videos-apps.md applied
 * to the planning ad. Spec: pub/campagne-2026-11/planning/organique/spec.json. 13.5 s, no voice, music only, hard cuts on the 120 BPM
 * grid (30 frames a beat), native-looking white labels. Paper to-do list (without) -> Top 3 widget close-up (with) -> the Home Screen
 * -> split comparison -> « DONE! » -> short end card « Coming soon ». Only free widgets (Top 3, Weekly schedule, Light style): no
 * Premium mention needed. Parts copied from ../planning/Film.tsx (page 1 of the Home, LightBg), nothing shared is modified.
 * Safe zone (TikTok / Reels): texts stay in x 60..940, y 220..1540.
 */
export const FPS = 60;
const f = (s: number) => Math.round(s * FPS);
const T = {
  hook: [0, f(2)],
  close: [f(2), f(2)],
  home: [f(4), f(4)], // one shot, the caption changes at 6.0 s
  split: [f(8), f(3)], // the verdict label lands at 9.5 s
  done: [f(11), f(1)],
  end: [f(12), 90],
} as const;
export const ORG_PLANNING_LENGTH = T.end[0] + T.end[1]; // 810 = 13.5 s

const clip = (n: string) => `campaign/planning/${n}.mp4`;
const wc = (n: string) => `campaign/kit/${n}.png`;

const LightBg: React.FC = () => <AbsoluteFill style={{ background: "linear-gradient(165deg, #F4F7FC 0%, #E3ECF8 55%, #D6E4F6 100%)" }} />;

/** lib Footage with a chosen transform origin (one slow push, no zoom out). */
const Anchored: React.FC<{ src: string; dur: number; from: number; zoom: [number, number]; origin: string }> = ({ src, dur, from, zoom, origin }) => {
  const fr = useCurrentFrame();
  const z = interpolate(fr, [0, dur], zoom);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#000" }}>
      <OffthreadVideo src={staticFile(src)} muted startFrom={from} style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${z})`, transformOrigin: origin, filter: "contrast(1.06) saturate(1.05)" }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 75% 60% at 50% 48%, rgba(0,0,0,0) 45%, rgba(0,0,0,0.5) 100%)" }} />
    </AbsoluteFill>
  );
};

/** Native-looking caption: black Inter 800 on white rounded labels, one label per line, centred on `cx`. Hard in, hard out. */
const Tag: React.FC<{ lines: string[]; top: number; size: number; cx?: number }> = ({ lines, top, size, cx = 540 }) => (
  <div style={{ position: "absolute", left: cx - 540, width: 1080, top, display: "flex", flexDirection: "column", alignItems: "center", filter: "drop-shadow(0 6px 18px rgba(0,0,0,0.22))" }}>
    {lines.map((l, i) => (
      <div key={i} style={{ background: "#fff", color: "#0B0B0C", fontFamily: INTER, fontWeight: 800, fontVariationSettings: "'opsz' 32", fontSize: size, lineHeight: 1.22, letterSpacing: "-0.02em", padding: `0 ${Math.round(size * 0.28)}px`, borderRadius: 22, whiteSpace: "nowrap", marginTop: i ? -1 : 0 }}>
        {l}
      </div>
    ))}
  </div>
);

// ---------------------------------------------------------------- page 1 of the Home Screen (real iOS grid, real Apple icons, real widget exports)
const widget = (file: string, r: number[]) => (
  <>
    <Img src={staticFile(wc(file))} style={{ position: "absolute", left: r[0], top: r[1], width: r[2], height: r[3] }} />
    <IosLabel x={r[0]} y={r[1] + r[3] + 18} w={r[2]} text="Ardane" dark={false} />
  </>
);
const cell = (name: string, c: number, r: number) => {
  const [x, y] = iconXY(c, r);
  return <IosAppIcon key={name} name={name} x={x} y={y} dark={false} />;
};
/** Wallpaper, Weekly schedule (large), Top 3 (small), 4 apps, status bar, page dots, Dock: the page 1 of ../planning/Film.tsx, still. */
const HomePage: React.FC = () => {
  const tint = glassTint(false);
  return (
    <>
      <Img src={staticFile("kit2026/en/wall-pastel.png")} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />
      {widget("camp-timetable-l-light", iosRect("l", 0, 0))}
      {widget("camp-priorities-s-light", iosRect("s", 0, 4))}
      {cell("Calendar", 2, 4)}
      {cell("Reminders", 3, 4)}
      {cell("News", 2, 5)}
      {cell("Maps", 3, 5)}
      <StatusBar ink="#000000" />
      <div style={{ position: "absolute", left: 0, width: 1206, top: 2146, display: "flex", justifyContent: "center", gap: 26 }}>
        <div style={{ width: 22, height: 22, borderRadius: 11, background: "rgba(30,36,48,0.85)" }} />
        <div style={{ width: 22, height: 22, borderRadius: 11, background: "rgba(30,36,48,0.35)" }} />
      </div>
      <div style={{ position: "absolute", left: 52, top: IOS.dockTop, width: 1100, height: 304, borderRadius: 120, background: tint.fill, border: `2px solid ${tint.line}`, boxSizing: "border-box" }} />
      {IOS_DOCK.map((name, i) => (
        <Img key={name} src={staticFile(appleIcon(name))} style={{ position: "absolute", left: dockX(i, IOS_DOCK.length), top: IOS.dockIconTop, width: IOS.icon, height: IOS.icon, filter: "drop-shadow(0 6px 9px rgba(0,0,0,0.18))" }} />
      ))}
    </>
  );
};
/** The page (1206 x 2622) laid at `left`, `top` of its parent with scale `s`. */
const Page: React.FC<{ left: number; top: number; s: number }> = ({ left, top, s }) => (
  <div style={{ position: "absolute", left, top, width: 1206, height: 2622, transform: `scale(${s})`, transformOrigin: "0 0" }}>
    <HomePage />
  </div>
);

/** 2.0 s: the Top 3 widget in close-up, the page full frame (no phone frame), one slow push on the widget, never back.
 * Seen on the key frames: with the spec's top (-1235) the caption lay across the coloured blocks of the Weekly schedule. Here the
 * page is as high as it can go (its bottom edge = the frame's): the large widget ends at y 330 (its last row of blocks in the top
 * 170 px), the caption covers its edge and its « Ardane » label, the Top 3 is at x 60..681, y 465..1086. */
const CLOSE = { s: 1.27, left: -43, top: -1409 }; // 1920 - 2622 x 1.27 = -1409.9
const HomeClose: React.FC<{ dur: number }> = ({ dur }) => {
  const fr = useCurrentFrame();
  const z = interpolate(fr, [0, dur], [1, 1.04]);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#fff" }}>
      <AbsoluteFill style={{ transform: `scale(${z})`, transformOrigin: "370px 775px" }}>
        <Page {...CLOSE} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** 4.0 s: the only widening. The bare rounded screen (as lib Screen, light) already in place at frame 0, slow push anchored at its top. */
const SCREEN = { width: 900, top: 330 };
const HomeScreen: React.FC<{ dur: number }> = ({ dur }) => {
  const fr = useCurrentFrame();
  const s = SCREEN.width / 1206;
  const z = interpolate(fr, [0, dur], [1, 1.02]);
  return (
    <div style={{ position: "absolute", left: (1080 - SCREEN.width) / 2, top: SCREEN.top, width: SCREEN.width, height: 2622 * s, borderRadius: 165 * s, overflow: "hidden", transform: `scale(${z})`, transformOrigin: "50% 0", boxShadow: "0 40px 110px rgba(0,0,0,0.28), 0 0 0 2px rgba(0,0,0,0.06)", background: "#000" }}>
      <Page left={0} top={0} s={s} />
    </div>
  );
};

/** 8.0 s: the comparison. Top: the paper list (post.mp4 from 0.5 s); bottom: the Home Screen, the Top 3 just there. A 6 px white line at y 760. */
const SPLIT_Y = 760;
// Seen on the key frames: with the spec's page (scale 0.8955, top -322) the half showed a cut row of the Weekly schedule and its
// « Ardane » label, and the verdict (y 790) lay across them. The half now starts just under that label; scale 0.98 so the page still
// reaches the bottom of the frame: Top 3 at x 28..508, y 802..1282, the verdict under it on the bare wallpaper (y 1350..1492, above
// the hidden bottom 380 px).
const SPLIT_PAGE = { s: 0.98, left: -51, top: -644 };
const Split: React.FC<{ dur: number; verdictAt: number }> = ({ dur, verdictAt }) => {
  const fr = useCurrentFrame();
  // the camera of the clip drifts down by ~200 px in these 3 s: the crop follows it, so « TO DO » and an empty box stay in the half
  const up = interpolate(fr, [0, dur], [300, 500]);
  return (
    <AbsoluteFill style={{ background: "#fff" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: 1080, height: SPLIT_Y - 3, overflow: "hidden", background: "#000" }}>
        <OffthreadVideo src={staticFile(clip("post"))} muted startFrom={f(0.5)} style={{ position: "absolute", left: 0, top: -up, width: 1080, height: 1920, objectFit: "cover", filter: "contrast(1.06) saturate(1.05)" }} />
      </div>
      <div style={{ position: "absolute", left: 0, top: SPLIT_Y + 3, width: 1080, height: 1920 - SPLIT_Y - 3, overflow: "hidden" }}>
        <Page left={SPLIT_PAGE.left} top={SPLIT_PAGE.top - SPLIT_Y - 3} s={SPLIT_PAGE.s} />
      </div>
      <Tag lines={["In a notebook: you have", "to remember it exists."]} top={235} size={58} />
      {fr >= verdictAt && <Tag lines={["On your Home Screen:", "it's just there."]} top={1350} size={58} />}
    </AbsoluteFill>
  );
};

export const OrgPlanning: React.FC<{ silent?: boolean }> = ({ silent = false }) => {
  setKitLang("en");
  const fr = useCurrentFrame();
  return (
    <LangContext.Provider value="en">
      <AbsoluteFill style={{ background: "#fff", fontFamily: INTER }}>
        {/* 0.0 s WITHOUT: the paper to-do list, the hook from frame 0 (it is the thumbnail) */}
        <Seq t={T.hook}>
          <Footage src={clip("post")} dur={T.hook[1]} zoom={[1, 1.05]} />
          <Tag lines={["You never look", "at your", "to-do list."]} top={230} size={104} />
        </Seq>

        {/* 2.0 s WITH: the Top 3 widget on a real Home Screen, close */}
        <Seq t={T.close}>
          <HomeClose dur={T.close[1]} />
          <Tag lines={["So put it", "where you DO look."]} top={255} size={76} />
        </Seq>

        {/* 4.0 s the whole Home Screen; at 6.0 s only the caption changes */}
        <Seq t={T.home}>
          <LightBg />
          <HomeScreen dur={T.home[1]} />
          <Tag lines={[fr < f(6) ? "Your whole week, too." : "No app to open."]} top={226} size={64} />
        </Seq>

        {/* 8.0 s the comparison; 9.5 s the verdict */}
        <Seq t={T.split}>
          <Split dur={T.split[1]} verdictAt={f(1.5)} />
        </Seq>

        {/* 11.0 s real shot: « DONE! » answers « TO DO » (b6 from 1.35 s: the pen no longer hides the word and its D is inside the frame); no text */}
        <Seq t={T.done}>
          <Anchored src={clip("b6")} dur={T.done[1]} from={f(1.35)} zoom={[1, 1.03]} origin="0% 50%" />
        </Seq>

        {/* 12.0 s short end card: the validated Close on its settled state, « Coming soon » (the app is not published), no tagline */}
        <Seq t={T.end}>
          <FadeIn n={8}>
            <TimeRemap input={[0, T.end[1]]} output={[196, 216]}>
              <Close audio={false} tagline="" cta="COMING SOON TO THE APP STORE" ctaScale={1.15} tile />
            </TimeRemap>
          </FadeIn>
        </Seq>
        <Grain amount={0.02} />
        <OptionalAudio file="campaign/planning-org/mix.wav" silent={silent} />
      </AbsoluteFill>
    </LangContext.Provider>
  );
};
