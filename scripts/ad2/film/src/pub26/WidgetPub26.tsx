import { AbsoluteFill, Easing, Img, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { FormatFrame } from "../films/FormatFrame";
import { FormatProps } from "../films/Formatted";
import { AXIS, C, clamp, ease, H, W } from "../lib/brand";
import { IOS } from "../lib/iosHome";
import { BEFORE } from "../avantapres/screens";
import { HomeBuilder } from "../v5/part2/Home";
import { AFTER_HOMES, RESULT_HOMES } from "./configs26";
import { Caption, EndCard, FadeIn, OptionalAudio } from "./parts";
import { Process26 } from "./Process26";
import { WIDGET } from "./timing26";

export const WIDGET26_LENGTH = WIDGET.total;
const AUDIO = "audio/en/mix-pub26-widget.wav";

// card geometry of HomeBuilder (CARD 0.62, top 150), so the « before » phone and the Homes of « after » sit in the same place
const CARD = 0.62;
const CW = 1206;
const CH = 2622;

/** Sequence 1a: the real iOS Home Screen BEFORE Ardane (capture of the simulator), screen only, rounded corners, shadow. */
const Before: React.FC = () => {
  const f = useCurrentFrame();
  const B = WIDGET.before;
  const enter = interpolate(f, [0, 22], [0, 1], { ...clamp, easing: ease.split });
  const sw = interpolate(f, [B.len - B.collapse, B.len], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.5) });
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <Img src={staticFile(BEFORE)} style={{ position: "absolute", left: -200, top: -200, width: 1480, height: 2320, objectFit: "cover", opacity: enter, filter: "blur(90px) brightness(0.42) saturate(1.3)" }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 55%, rgba(0,0,0,0) 30%, rgba(0,0,0,0.55) 100%)" }} />
      <Seam x={AXIS} top={150} height={H - 300} intensity={0.9 * Math.sin(Math.PI * Math.min(1, sw)) + 0.5 * (1 - enter)} />
      <div
        style={{
          position: "absolute",
          left: (W - CW * CARD) / 2,
          top: 150,
          width: CW * CARD,
          height: CH * CARD,
          borderRadius: IOS.radius * CARD,
          overflow: "hidden",
          opacity: enter * (1 - sw * sw * sw),
          transform: `translateY(${Math.sin(f / 52) * 6}px) scale(${(0.94 + 0.06 * enter)}) scaleX(${1 - 0.985 * sw})`,
          boxShadow: "0 40px 120px rgba(0,0,0,0.55), 0 0 0 3px rgba(255,255,255,0.10)",
          background: "#000",
        }}
      >
        <Img src={staticFile(BEFORE)} style={{ position: "absolute", left: 0, top: 0, width: CW * CARD, height: CH * CARD }} />
      </div>
      <Grain />
    </AbsoluteFill>
  );
};

/** Sequence 1b: five very different Homes, one at a time, opening out of the Sapphire line. */
const After: React.FC = () => (
  <HomeBuilder configs={AFTER_HOMES} morphAt={WIDGET.after.morphAt} morphLen={WIDGET.after.morphLen} installAt={0} swallow={[99998, 99999]} lineOpen install={false} />
);

export const WidgetPub26: React.FC<{ silent?: boolean }> = ({ silent = false }) => (
  <AbsoluteFill style={{ backgroundColor: "#000" }}>
    <Sequence from={WIDGET.before.from} durationInFrames={WIDGET.before.len} layout="absolute-fill">
      <Before />
    </Sequence>
    <Sequence from={WIDGET.after.from} durationInFrames={WIDGET.after.len} layout="absolute-fill">
      <After />
    </Sequence>
    <Caption lines={["You want your phone", "to look like this?"]} at={30} until={WIDGET.process.from - 40} />
    <Sequence from={WIDGET.process.from} durationInFrames={WIDGET.process.len} layout="absolute-fill">
      <Process26 />
    </Sequence>
    <Sequence from={WIDGET.result.from} durationInFrames={WIDGET.result.len} layout="absolute-fill">
      <FadeIn n={WIDGET.result.fade}>
        <HomeBuilder configs={RESULT_HOMES} morphAt={WIDGET.result.morphAt} morphLen={WIDGET.result.morphLen} installAt={WIDGET.result.installAt} swallow={WIDGET.result.swallow} lineOpen />
      </FadeIn>
      <Caption lines={["Your phone. Your style.", "Your widgets."]} at={WIDGET.result.titleAt} until={WIDGET.result.swallow[0]} />
    </Sequence>
    <Sequence from={WIDGET.close.from} durationInFrames={WIDGET.close.len} layout="absolute-fill">
      <EndCard />
    </Sequence>
    <Grain amount={0.012} />
    <OptionalAudio file={AUDIO} silent={silent} />
  </AbsoluteFill>
);

export const WidgetPub26Format: React.FC<FormatProps & { silent?: boolean }> = ({ format, lang, silent }) => (
  <FormatFrame format={format} lang={lang} text={{ headline: "frame.main", sub: "frame.main.sub", show: 99999, hide: 99999 }}>
    <WidgetPub26 silent={silent} />
  </FormatFrame>
);
