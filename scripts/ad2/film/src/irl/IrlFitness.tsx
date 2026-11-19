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
 * graded red / black / grey, cut on the beat (120 BPM = 30 frames at 60 fps), cut with REAL Ardane captures (current app, kit runs
 * 471/472): Live Activity, workout, program, then Create -> choose -> style -> Home Screen. No face of the footage is ever shown next to
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
  choose: [30 * B, 3 * B],
  style: [33 * B, 4 * B],
  home: [37 * B, 8 * B],
  b9: [45 * B, 4 * B],
  end: [49 * B, 170],
} as const;
export const IRL_LENGTH = T.end[0] + T.end[1]; // 1640 = 27.3 s (the audio script irl_audio.py uses the same beat grid)

const clip = (n: string) => staticFile(`irl/fitness/${n}.mp4`);
const RED = "#C3162B";

/** Real footage, graded: mostly desaturated, red midtones, crushed blacks, vignette, slow push-in. */
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
        style={{ width: "100%", height: "100%", objectFit: "cover", transform: `scale(${bg ? 1.15 : z})`, filter: `saturate(0.2) contrast(1.22) brightness(${bg ? 0.42 : 0.88})${bg ? " blur(22px)" : ""}` }}
      />
      <AbsoluteFill style={{ background: RED, mixBlendMode: "color", opacity: 0.5 }} />
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

/** Studio « style » beat: the same Next set widget (the one chosen) in three real styles, the last one (Neon) is the Home's. */
const STYLES = ["nextSet-s-light", "nextSet-s-luxury", "nextSet-s-neon"];
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
            style={{ position: "absolute", left: 540 - 300, top: 960 - 300, width: 600, height: 600, opacity: a * out, transform: `scale(${pop})`, filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.6))" }}
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
    wall: k("wall-ruby"),
    dark: true,
    icons: "",
    glow: "#FF3D8B",
    slots: [
      { file: k("weeklyVolume-m-neon"), rect: [57, 204, 1092, 510] },
      { file: k("nextSet-s-neon"), rect: [57, 813, 510, 510] },
      { file: k("restTimer-s-neon"), rect: [638, 813, 510, 510] },
    ],
  },
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
      <Seq t={[T.create[0], T.create[1] + T.choose[1] + T.style[1]]}>
        <Footage name="bg-make" dur={T.create[1] + T.choose[1] + T.style[1]} rate={0.75} bg />
      </Seq>
      <Seq t={T.create}>
        <Screen dur={T.create[1]}>
          <Cap name="pub26-create-dark" />
        </Screen>
        <Word text="create." until={T.create[1]} y={70} />
      </Seq>
      <Seq t={T.choose}>
        <Screen dur={T.choose[1]}>
          <Cap name="creator-fitness-medium" />
        </Screen>
        <Word text="choose." until={T.choose[1]} y={70} />
      </Seq>
      <Seq t={T.style}>
        <StyleCycle dur={T.style[1]} />
        <Word text="style." until={T.style[1]} y={330} />
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

const HookLock: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <Screen dur={T.hook[1]} top={160}>
      <LockLive t={60 + f} />
    </Screen>
  );
};
