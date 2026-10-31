import { Audio } from "@remotion/media";
import { AbsoluteFill, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import { Seam } from "../components/Seam";
import { SplitOut } from "../components/SplitOut";
import { AXIS, clamp } from "../lib/brand";
import { TimeRemap } from "../lib/time";
import { Close } from "../scenes/Close";
import { Essentials } from "../scenes/Essentials";
import { Fitness } from "../scenes/Fitness";
import { FitnessCold } from "../scenes/FitnessCold";
import { Gather } from "../scenes/Gather";
import { LineOpen } from "../scenes/LineOpen";
import { MyDay } from "../scenes/MyDay";
import { LockScreen } from "../scenes/LockScreen";
import { Nutrition } from "../scenes/Nutrition";
import { Opening } from "../scenes/Opening";
import { Build, FivePhones, LockIcon, StyleCycle } from "../scenes/Perso";
import { Studio } from "../scenes/Studio";
import { Universes } from "../scenes/Universes";
import { HookCard } from "../components/Hook";
import { WidgetLift } from "../scenes/WidgetLift";
import { audioFile, Lang } from "../lib/i18n";
import cuts from "./cuts.json";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const SCENES: Record<string, React.FC<any>> = { Opening, Universes, Fitness, LockScreen, Nutrition, Essentials, Gather, Close, LineOpen, MyDay, FitnessCold, Build, StyleCycle, LockIcon, FivePhones, WidgetLift, Studio, HookCard };

type Segment = { scene: string; at: number; input: number[]; output: number[]; transition?: string; props?: Record<string, unknown> };
export type FilmId = keyof typeof cuts.films;

const length = (s: Segment) => s.input[s.input.length - 1];

const Play: React.FC<{ seg: Segment; offset?: number }> = ({ seg, offset = 0 }) => {
  const El = SCENES[seg.scene];
  return (
    <TimeRemap input={seg.input.map((x) => x + offset)} output={seg.output}>
      <El audio={false} {...(seg.props ?? {})} />
    </TimeRemap>
  );
};

/** The seam carries a cut: a line flashes at the axis across the change. */
const LineCut: React.FC = () => {
  const f = useCurrentFrame();
  const i = interpolate(f, [0, 10, 34], [0, 1, 0], clamp);
  return <Seam x={AXIS} top={300} height={1320} intensity={i} />;
};

/** A cut-down film from cuts.json: its segments, transitions, and its own mix (pub/film/mix-<id>.wav). */
export const CutFilm: React.FC<{ film: FilmId; audioLang?: Lang }> = ({ film, audioLang = "en" }) => {
  const segs = cuts.films[film].segments as Segment[];
  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      {segs.map((seg, i) => (
        <Sequence key={`s${i}`} from={seg.at} durationInFrames={length(seg)} layout="absolute-fill">
          <Play seg={seg} />
        </Sequence>
      ))}
      {segs.map((seg, i) => {
        if (i === 0 || !seg.transition || seg.transition === "cut") return null;
        const prev = segs[i - 1];
        if (seg.transition === "split") {
          return (
            <Sequence key={`t${i}`} from={seg.at} durationInFrames={30} layout="absolute-fill">
              <SplitOut>
                <Play seg={prev} offset={-length(prev)} />
              </SplitOut>
            </Sequence>
          );
        }
        return (
          <Sequence key={`t${i}`} from={seg.at - 10} durationInFrames={36} layout="absolute-fill">
            <LineCut />
          </Sequence>
        );
      })}
      <Audio src={staticFile(audioFile(audioLang, film))} />
    </AbsoluteFill>
  );
};

export const filmLength = (film: FilmId) => cuts.films[film].length;
