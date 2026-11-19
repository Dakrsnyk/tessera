import { AbsoluteFill, Easing, Img, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { FormatFrame } from "../films/FormatFrame";
import { FormatProps } from "../films/Formatted";
import { C, clamp, ease, W } from "../lib/brand";
import { asset } from "../lib/kit";
import { MainLook } from "../v5/mainLook";
import { AppDef, Cam, MiniApp5, Screen } from "../v5/MiniApp5";
import { HomeBuilder } from "../v5/part2/Home";
import { HookS } from "../v5/short/HookS";
import { MAIN_HOMES, MAKE_HOMES, MAKE_ISOLATED } from "./configs26";
import { Caption, EndCard, FadeIn, OptionalAudio } from "./parts";
import { APP_SHOTS } from "./shots";
import { MAIN } from "./timing26";

export const MAIN26_LENGTH = MAIN.total;
const AUDIO = "audio/en/mix-pub26-main.wav";

// ------------------------------------------------------------------ Sequence 2: one Home Screen per need, one at a time
const Homes: React.FC = () => {
  const f = useCurrentFrame();
  const H = MAIN.homes;
  const out = interpolate(f, [H.len - H.exit, H.len], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) });
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ transform: `translateX(${-out * 170}px)`, opacity: 1 - out, filter: `blur(${out * 10}px)` }}>
        {/* as in the validated opening of FilmMainV5Short: a flat screen (no drawn iPhone) that opens out of the Sapphire line */}
        <HomeBuilder configs={MAIN_HOMES} morphAt={H.morphAt} morphLen={H.morphLen} installAt={0} swallow={[99998, 99999]} lineOpen install={false} />
      </AbsoluteFill>
      <Caption lines={["Meet Ardane."]} at={H.meetAt} until={H.meetUntil} />
      <Caption lines={["All your essentials", "on your home screen."]} at={H.captionAt} until={H.len - 34} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ Sequence 3: Nutrition. Fitness. Planning. (template of v5/MiniApp5)
// Several screens per mini-app (version 2): each step = a highlighted zone of a capture, commented by the voice.
type AppT = (typeof MAIN.apps.list)[number];
const OVERVIEW = { cx: 603, cy: 1311, z: 1 };
const appDef = (a: AppT): AppDef => {
  const S = APP_SHOTS[a.id];
  const steps = a.steps.map((t) => ({ t, s: S.steps[t.key] }));
  const screens: Screen[] = [];
  const cam: Cam[] = [{ at: 0, ...OVERVIEW }];
  // PDG, 2026-11-18 (v2.1): inside one mini-app the camera stays close from one explanation to the next (no pull-back to the whole
  // screen between two of them); it only goes back to the whole screen at the app's own entry and exit (the existing plan transitions).
  // b[i] = where step i takes over: the blade of its screen (+8) or, on the same screen, its highlight.
  const isNew = (i: number) => i === 0 || steps[i - 1].s.capture !== steps[i].s.capture;
  const b = steps.map(({ t }, i) => (i === 0 ? t.hi[0] : isNew(i) ? t.at + 8 : t.hi[0]));
  const focusOf = (i: number) => ({ cx: steps[i].s.focus[0], cy: steps[i].s.focus[1], z: steps[i].s.zoom ?? 1.1 });
  steps.forEach(({ t }, i) => {
    if (i === 0) cam.push({ at: t.hi[0] - 4, ...focusOf(0) });
    else {
      cam.push({ at: isNew(i) ? t.at : b[i] - 8, ...focusOf(i - 1) }, { at: b[i] + 14, ...focusOf(i) });
    }
    if (i === steps.length - 1) cam.push({ at: t.hi[1], ...focusOf(i) }, { at: t.hi[1] + 14, ...OVERVIEW });
  });
  steps.forEach(({ t, s }, i) => {
    if (isNew(i)) {
      screens.push({
        at: t.at,
        src: `kit/${s.capture}.png`,
        premium: s.premium,
        cover: s.cover ? s.cover.map((c) => [...c] as [number, number, number, number, string]) : undefined,
        demo: s.demo ? { ...s.demo, box: [...s.demo.box] as [number, number, number, number], from: t.at + s.demo.from } : undefined,
      });
    }
  });
  return {
    id: a.id,
    title: S.title,
    titleAt: MAIN.apps.titleAt,
    subs: [],
    accent: S.accent,
    length: a.seqLen,
    drift: [-30, 30],
    safeTop: true,
    screens,
    cam,
    // the highlights follow each other without a gap (the zone in focus never falls back to the default one)
    hi: steps.map(({ t, s }, i) => ({ from: b[i], to: i < steps.length - 1 ? b[i + 1] : t.hi[1], rect: [...s.rect] as [number, number, number, number], label: s.label, below: !!s.below })),
  };
};

// ------------------------------------------------------------------ Sequence 4: Make everyday your own.
const Isolated: React.FC = () => {
  const f = useCurrentFrame();
  const inP = interpolate(f, [0, 30], [0, 1], { ...clamp, easing: ease.split });
  const outP = interpolate(f, [MAIN.make.homeFrom, MAIN.make.isolatedLen], [0, 1], clamp);
  const float = Math.sin(f / 30) * 8;
  const w = 960;
  return (
    <AbsoluteFill style={{ backgroundColor: C.void, opacity: 1 - outP * outP }}>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 900px 1100px at 50% 46%, #4a3d30 0%, #1a1511 55%, #0a0908 100%)", opacity: inP }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 55%, rgba(0,0,0,0) 30%, rgba(0,0,0,0.55) 100%)" }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 820px 520px at 540px 880px, rgba(255,226,196,0.32), transparent 70%)", opacity: inP }} />
      <Img
        src={asset(MAKE_ISOLATED)}
        style={{ position: "absolute", left: (W - w) / 2, top: 880 - (w * 510) / 1092 / 2 + float + (1 - inP) * 60, width: w, opacity: inP, transform: `scale(${0.9 + 0.1 * inP}) rotateX(${(1 - inP) * 14}deg)`, filter: "drop-shadow(0 50px 70px rgba(0,0,0,0.6))" }}
      />
      <Grain />
    </AbsoluteFill>
  );
};

const Make: React.FC = () => {
  const K = MAIN.make;
  return (
    <AbsoluteFill>
      <Sequence from={0} durationInFrames={K.isolatedLen} layout="absolute-fill">
        <Isolated />
      </Sequence>
      <Sequence from={K.homeFrom} durationInFrames={K.homeLen} layout="absolute-fill">
        <FadeIn n={K.homeFade}>
          <HomeBuilder configs={MAKE_HOMES} morphAt={K.morphAt} morphLen={K.morphLen} installAt={K.installAt} swallow={K.swallow} lineOpen />
        </FadeIn>
      </Sequence>
      <Caption lines={["Make everyday your own."]} at={K.captionAt} until={K.homeFrom + 120} top={44} size={62} />
    </AbsoluteFill>
  );
};

export const MainPub26: React.FC<{ silent?: boolean }> = ({ silent = false }) => (
  <AbsoluteFill style={{ backgroundColor: "#000" }}>
    {/* 1. the validated hook, untouched */}
    <Sequence from={MAIN.hook.from} durationInFrames={MAIN.hook.len} layout="absolute-fill">
      <HookS />
    </Sequence>
    <Sequence from={MAIN.homes.from} durationInFrames={MAIN.homes.len} layout="absolute-fill">
      <Homes />
    </Sequence>
    <MainLook.Provider value={true}>
      {MAIN.apps.list.map((a) => (
        <Sequence key={a.id} from={a.from} durationInFrames={a.seqLen} layout="absolute-fill">
          <MiniApp5 app={appDef(a)} />
        </Sequence>
      ))}
    </MainLook.Provider>
    <Sequence from={MAIN.make.from} durationInFrames={MAIN.make.len} layout="absolute-fill">
      <Make />
    </Sequence>
    {/* 5. the validated outro, untouched */}
    <Sequence from={MAIN.close.from} durationInFrames={MAIN.close.len} layout="absolute-fill">
      <EndCard />
    </Sequence>
    <Grain amount={0.012} />
    <OptionalAudio file={AUDIO} silent={silent} />
  </AbsoluteFill>
);

export const MainPub26Format: React.FC<FormatProps & { silent?: boolean }> = ({ format, lang, silent }) => (
  <FormatFrame format={format} lang={lang} text={{ headline: "frame.main", sub: "frame.main.sub", show: 99999, hide: 99999 }}>
    <MainPub26 silent={silent} />
  </FormatFrame>
);
