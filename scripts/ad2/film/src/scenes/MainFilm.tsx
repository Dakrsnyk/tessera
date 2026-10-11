import { Audio } from "@remotion/media";
import { AbsoluteFill, Sequence, staticFile } from "remotion";
import { SplitOut } from "../components/SplitOut";
import { Close } from "./Close";
import { Essentials } from "./Essentials";
import { Fitness } from "./Fitness";
import { Gather } from "./Gather";
import { LockScreen } from "./LockScreen";
import { Nutrition } from "./Nutrition";
import { Opening } from "./Opening";
import { Universes } from "./Universes";

/**
 * « The Opening », the main film: 58.0 s, 3480 frames at 60 fps, 1080 × 1920 (Concept-THE-OPENING §5).
 * One mix for the whole film (scripts/ad2/mix.py: score, SFX on their frames, voice). Chapters change on
 * a seam event: continuous moves at 6, 16 and 53 s, the Line at 26 s, Splits at 32, 42 and 48 s.
 */
const SCENES = [
  { from: 0, length: 360, El: Opening },
  { from: 360, length: 600, El: Universes },
  { from: 960, length: 600, El: Fitness },
  { from: 1560, length: 360, El: LockScreen, split: true },
  { from: 1920, length: 600, El: Nutrition, split: true },
  { from: 2520, length: 360, El: Essentials, split: true },
  { from: 2880, length: 300, El: Gather },
  { from: 3180, length: 300, El: Close },
];

export const MAIN_LENGTH = 3480;

export const MainFilm: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: "#000" }}>
    {SCENES.map(({ from, length, El }) => (
      <Sequence key={from} from={from} durationInFrames={length} layout="absolute-fill">
        <El audio={false} />
      </Sequence>
    ))}
    {/* Splits: the outgoing scene keeps playing in two halves over the first 30 frames of the next one. */}
    {SCENES.filter((s) => s.split).map(({ from, length, El }) => (
      <Sequence key={`split-${from}`} from={from + length} durationInFrames={30} layout="absolute-fill">
        <SplitOut>
          <Sequence from={-length} layout="absolute-fill">
            <El audio={false} />
          </Sequence>
        </SplitOut>
      </Sequence>
    ))}
    <Audio src={staticFile("audio/mix-main.wav")} />
  </AbsoluteFill>
);
