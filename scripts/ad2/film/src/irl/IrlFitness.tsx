import { AbsoluteFill, Audio, Easing, getStaticFiles, Img, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { clamp, INTER } from "../lib/brand";
import { asset, setKitLang } from "../lib/kit";
import { LangContext } from "../lib/i18n";
import { HomeBuilder } from "../v5/part2/Home";
import type { Config } from "../v5/part2/configs";
import { LockLive } from "../v5/lib/LockLive";
import { EndCard } from "../pub26/parts";

/**
 * « IRL » Fitness ad (2026-11-18): real gym footage (Pexels, free licence, see docs/memoire/campagne-2026/23-pub-irl-fitness.md)
 * in black and white (v2, 2026-11-19; v1 was graded red), cut on the beat (120 BPM = 30 frames at 60 fps), cut with REAL Ardane captures (current app, kit runs
 * 471/472): Live Activity, workout, program, then Create -> Studio (Style) -> colours -> Home Screen (v3). No face of the footage is ever shown next to
 * a phone (Pexels licence: no implied endorsement).
 */
export const IRL_FPS = 60;
const B = 30; // one beat
const T = {
  hook: [0, 4 * B],
  b1: [4 * B, 2 * B],
  b2: [6 * B, 2 * B],
  b3: [8 * B, 2 * B],
  s1: [10 * B, 4 * B],
  b5: [14 * B, 2 * B],
  b6: [16 * B, 2 * B],
  b7: [18 * B, 2 * B],
  s2: [20 * B, 4 * B],
  b8: [24 * B, 3 * B],
  create: [27 * B, 3 * B],
  studio: [30 * B, 4 * B],
  colors: [34 * B, 5 * B],
  home: [39 * B, 8 * B],
  b9: [47 * B, 4 * B],
  end: [51 * B, 170],
} as const;
export const IRL_LENGTH = T.end[0] + T.end[1]; // 1700 = 28.3 s (irl_audio.py / irl_music.py use the same beat grid)

const clip = (n: string) => staticFile(`irl/fitness/${n}.mp4`);

/** Real footage in contrasted black and white (user, 2026-11-19: no red filter), vignette, slow push-in. Only the Ardane screens are in colour. */
const Footage: React.FC<{ name: string; dur: number; from?: number; rate?: number; bg?: boolean }> = ({ name, dur, from = 0, rate = 1, bg = false }) => {
  const f = useCurrentFrame();
  const z = interpolate(f, [0, dur], [1.03, 1.1]);
  return (
    <AbsoluteFill style={{ overflow: "hidden", background: "#000" }}>
      <OffthreadVideo
        src={clip(name)}
        muted
        playbackRate={rate}
        startFrom={from}
        style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${bg ? 1.15 : z})`, filter: `grayscale(1) contrast(1.28) brightness(${bg ? 0.45 : 0.95})${bg ? " blur(22px)" : ""}` }}
      />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 75% 60% at 50% 48%, rgba(0,0,0,0) 40%, rgba(0,0,0,0.65) 100%)" }} />
    </AbsoluteFill>
  );
};

/** One small lowercase word in the middle, like the reference reels. */
const Word: React.FC<{ text: string; at?: number; until: number; y?: number }> = ({ text, at = 4, until, y = 900 }) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [at, at + 6, until - 5, until], [0, 1, 1, 0], clamp);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: y, textAlign: "center", opacity: o, color: "#fff", fontFamily: INTER, fontWeight: 500, fontSize: 46, letterSpacing: -0.5, textShadow: "0 2px 18px rgba(0,0,0,0.7)" }}>
      {text}
    </div>
  );
};

const PW = 780;
const SCL = PW / 1206;
const PH = 2622 * SCL;
/** A real capture as a bare screen (rounded corners + shadow, no drawn case), arriving with a small lift, slow push-in. */
const Screen: React.FC<{ dur: number; children: React.ReactNode; top?: number }> = ({ dur, children, top = 150 }) => {
  const f = useCurrentFrame();
  const a = interpolate(f, [0, 12], [0, 1], { ...clamp, easing: Easing.bezier(0.16, 1, 0.3, 1) });
  const z = interpolate(f, [0, dur], [1, 1.05]);
  return (
    <div
      style={{
        position: "absolute",
        left: (1080 - PW) / 2,
        top,
        width: PW,
        height: PH,
        borderRadius: 165 * SCL,
        overflow: "hidden",
        opacity: a,
        transform: `translateY(${(1 - a) * 80}px) scale(${(0.94 + 0.06 * a) * z})`,
        boxShadow: "0 50px 140px rgba(0,0,0,0.7), 0 0 0 2px rgba(255,255,255,0.10)",
        background: "#000",
      }}
    >
      <div style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622, transform: `scale(${SCL})`, transformOrigin: "0 0" }}>{children}</div>
    </div>
  );
};
const Cap: React.FC<{ name: string }> = ({ name }) => <Img src={asset(`kit/${name}.png`)} style={{ position: "absolute", left: 0, top: 0, width: 1206, height: 2622 }} />;

/** v4 (user, 2026-11-19): the medium combined widget « Next set + Consistency » in five real styles (kit exports
 * irl-nextSet-combo-*); the last one, Carbon (black, red accent, striped background), is the Home's. Matte black (square buttons) is gone. */
const STYLES = ["light", "luxury", "mars", "neon", "carbon"].map((s) => `irl-nextSet-combo-${s}`);
const StyleCycle: React.FC<{ dur: number }> = ({ dur }) => {
  const f = useCurrentFrame();
  const step = dur / STYLES.length;
  return (
    <>
      {STYLES.map((n, i) => {
        const a = interpolate(f, [i * step, i * step + 8], [0, 1], clamp);
        const out = i < STYLES.length - 1 ? interpolate(f, [(i + 1) * step, (i + 1) * step + 8], [1, 0], clamp) : 1;
        const pop = interpolate(f, [i * step, i * step + 14], [0.86, 1], { ...clamp, easing: Easing.bezier(0.2, 1.4, 0.4, 1) });
        return (
          <Img
            key={n}
            src={asset(`kit/${n}.png`)}
            style={{ position: "absolute", left: 540 - 470, top: 960 - 220, width: 940, height: (940 * 510) / 1092, opacity: a * out, transform: `scale(${pop})`, filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.6))" }}
          />
        );
      })}
    </>
  );
};

const k = (n: string) => `kit/${n}`;
const HOME: Config[] = [
  {
    id: "fitness",
    label: "Fitness",
    wall: "irl/fitness/wall-irl-apps.png", // scripts/ad2/irl_wall.py --sans-halteres: black, red glow, thin red frame
    dark: true,
    icons: "",
    glow: "#E5383B",
    // v4: real iPhone apps in the free cells and the Dock (lib/iosHome.ts), widgets in Carbon like the last style shown
    slots: [
      // medium, small with four apps beside it, medium (the Carbon rest timer shows 0:00, so Volume instead)
      { file: k("irl-nextSet-combo-carbon"), rect: [57, 204, 1092, 510] },
      { file: k("irl-personalRecords-s-carbon"), rect: [57, 813, 510, 510] },
      { file: k("irl-weeklyVolume-m-carbon"), rect: [57, 1422, 1092, 510] },
    ],
  } as Config,
];

const Seq: React.FC<{ t: readonly [number, number]; children: React.ReactNode }> = ({ t, children }) => (
  <Sequence from={t[0]} durationInFrames={t[1]} layout="absolute-fill">
    {children}
  </Sequence>
);
const Roll: React.FC<{ t: readonly [number, number]; name: string; word?: string }> = ({ t, name, word }) => (
  <Seq t={t}>
    <Footage name={name} dur={t[1]} />
    {word && <Word text={word} until={t[1]} />}
  </Seq>
);

export const IrlFitness: React.FC<{ silent?: boolean }> = ({ silent = false }) => {
  setKitLang("en"); // English captures (the kit defaults to French)
  let hasAudio = false;
  try {
    hasAudio = !silent && getStaticFiles().some((s) => s.name === "irl/fitness/mix.wav");
  } catch {
    hasAudio = false;
  }
  return (
    <LangContext.Provider value="en">
    <AbsoluteFill style={{ background: "#000" }}>
      {/* hook: the workout Live Activity on the Lock Screen, « Set done » tapped (LockLive local time 60 .. 180: tap at 100) */}
      <Seq t={T.hook}>
        <Footage name="bg-hook" dur={T.hook[1]} bg />
        <HookLock />
        <Word text="set done." at={46} until={T.hook[1]} y={70} />
      </Seq>
      <Roll t={T.b1} name="b1" word="discipline" />
      <Roll t={T.b2} name="b2" word="every set" />
      <Roll t={T.b3} name="b3" word="every rep" />
      <Seq t={T.s1}>
        <Footage name="bg-screen" dur={T.s1[1]} bg />
        <Screen dur={T.s1[1]}>
          <Cap name="session-0-dark" />
        </Screen>
        <Word text="tracked." until={T.s1[1]} y={70} />
      </Seq>
      <Roll t={T.b5} name="b5" />
      <Roll t={T.b6} name="b6" word="consistency" />
      <Roll t={T.b7} name="b7" />
      <Seq t={T.s2}>
        <Footage name="bg-screen" from={120} dur={T.s2[1]} bg />
        <Screen dur={T.s2[1]}>
          <Cap name="pub26-fitness-dark" />
        </Screen>
        <Word text="your program." until={T.s2[1]} y={70} />
      </Seq>
      <Roll t={T.b8} name="b8" word="getting stronger" />
      <Seq t={[T.create[0], T.create[1] + T.studio[1] + T.colors[1]]}>
        <Footage name="bg-make" dur={T.create[1] + T.studio[1] + T.colors[1]} rate={0.75} bg />
      </Seq>
      <Seq t={T.create}>
        <Screen dur={T.create[1]}>
          <Cap name="pub26-create-dark" />
        </Screen>
        <Word text="create." until={T.create[1]} y={70} />
      </Seq>
      {/* v3: the Studio on its Style part (combined widget, Matte black, red accent), then the style list scrolled */}
      <Seq t={T.studio}>
        <Screen dur={T.studio[1]}>
          <StudioStyle capture="studio-style-luxury-dark" widget="irl-nextSet-combo-luxury" />
          <StudioSwap at={2 * B}>
            <StudioStyle capture="studio-style-neon-dark" widget="irl-nextSet-combo-neon" />
          </StudioSwap>
        </Screen>
        <Word text="style." until={T.studio[1]} y={70} />
      </Seq>
      <Seq t={T.colors}>
        <StyleCycle dur={T.colors[1]} />
        <Word text="your colors." until={T.colors[1]} y={560} />
      </Seq>
      <Seq t={T.home}>
        <HomeBuilder configs={HOME} morphAt={[]} morphLen={[]} installAt={6} swallow={[99998, 99999]} lineOpen />
        <Word text="on your home screen." at={30} until={T.home[1]} y={60} />
      </Seq>
      <Roll t={T.b9} name="b9" word="every day." />
      <Seq t={T.end}>
        <EndCard />
      </Seq>
      <Grain amount={0.02} />
      {hasAudio && <Audio src={staticFile("irl/fitness/mix.wav")} />}
    </AbsoluteFill>
    </LangContext.Provider>
  );
};

/**
 * The Studio on its Style part (real captures studio-style-<style>-dark, current app) with the widget being styled, the
 * combined « Next set + Consistency » widget (real exports irl-nextSet-combo-<style> of the same style), laid over the
 * capture's preview (measured: x 126..1080, y 450..896 of the 1206 x 2622 capture). The kit could not open the Studio on a
 * combined widget (run 44465910005: captures irl-studio-style* failed), and the app's code is not changed for the ads.
 */
const StudioStyle: React.FC<{ capture: string; widget: string }> = ({ capture, widget }) => (
  <>
    <Cap name={capture} />
    <div style={{ position: "absolute", left: 110, top: 434, width: 986, height: 478, background: "rgb(18,31,43)" }} />
    <Img src={asset(`kit/${widget}.png`)} style={{ position: "absolute", left: 126, top: 450, width: 954, height: 446 }} />
  </>
);
const StudioSwap: React.FC<{ at: number; children: React.ReactNode }> = ({ at, children }) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [at, at + 10], [0, 1], clamp);
  return o > 0 ? <div style={{ position: "absolute", inset: 0, opacity: o }}>{children}</div> : null;
};

const HookLock: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <Screen dur={T.hook[1]} top={160}>
      <LockLive t={60 + f} />
    </Screen>
  );
};
