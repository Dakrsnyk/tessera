import { AbsoluteFill, Easing, Img, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { FormatFrame } from "../films/FormatFrame";
import { FormatProps } from "../films/Formatted";
import { C, clamp, ease, W } from "../lib/brand";
import { asset } from "../lib/kit";
import { MainLook } from "../v5/mainLook";
import { AppDef, MiniApp5 } from "../v5/MiniApp5";
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
      <Caption lines={["All your essentials", "on your home screen."]} at={24} until={H.len - 34} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ Sequence 3: Nutrition. Fitness. Planning. (template of v5/MiniApp5)
const appDef = (id: keyof typeof APP_SHOTS): AppDef => {
  const a = APP_SHOTS[id];
  const T = MAIN.apps;
  const [fx, fy] = a.focus;
  return {
    id,
    title: a.title,
    titleAt: T.titleAt,
    subs: [],
    accent: a.accent,
    length: T.seqLen,
    drift: [-30, 30],
    safeTop: true,
    screens: [{ at: 0, src: `kit/${a.capture}.png` }],
    cam: [
      { at: 0, cx: 603, cy: 1311, z: 1 },
      { at: T.camFocusAt, cx: fx, cy: fy, z: a.zoom },
      { at: T.camBackAt, cx: fx, cy: fy, z: a.zoom },
      { at: T.camBackAt + 14, cx: 603, cy: 1311, z: 1 },
    ],
    hi: [{ from: T.hi.from, to: T.hi.to, rect: [...a.rect] as [number, number, number, number], label: a.label, below: "below" in a ? a.below : false }],
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
      {MAIN.apps.ids.map((id, i) => (
        <Sequence key={id} from={MAIN.apps.from + i * MAIN.apps.effective} durationInFrames={MAIN.apps.seqLen} layout="absolute-fill">
          <MiniApp5 app={appDef(id)} />
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
