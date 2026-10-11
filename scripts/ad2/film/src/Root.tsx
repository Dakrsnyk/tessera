import { Composition, Folder } from "remotion";
import { FPS, H, W } from "./lib/brand";
import { Close } from "./scenes/Close";
import { Daylight } from "./scenes/Daylight";
import { Essentials } from "./scenes/Essentials";
import { Fitness } from "./scenes/Fitness";
import { Gather } from "./scenes/Gather";
import { LockScreen } from "./scenes/LockScreen";
import { MAIN_LENGTH, MainFilm } from "./scenes/MainFilm";
import { Nutrition } from "./scenes/Nutrition";
import { Opening } from "./scenes/Opening";
import { Universes } from "./scenes/Universes";
import { PhoneTest } from "./scenes/PhoneTest";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="MainFilm" component={MainFilm} durationInFrames={MAIN_LENGTH} fps={FPS} width={W} height={H} />
      <Folder name="Principal">
        {/* Shots 1–3: f0–359. */}
        <Composition id="Opening" component={Opening} durationInFrames={360} fps={FPS} width={W} height={H} />
        {/* Shots 4–6: f360–959. */}
        <Composition id="Universes" component={Universes} durationInFrames={600} fps={FPS} width={W} height={H} />
        {/* Shots 7–10: f960–1559. */}
        <Composition id="Fitness" component={Fitness} durationInFrames={600} fps={FPS} width={W} height={H} />
        {/* Shots 11–13: f1560–1919. */}
        <Composition id="LockScreen" component={LockScreen} durationInFrames={360} fps={FPS} width={W} height={H} />
        {/* Shots 14–18: f1920–2519. */}
        <Composition id="Nutrition" component={Nutrition} durationInFrames={600} fps={FPS} width={W} height={H} />
        {/* Shot 14: f1920–2009. */}
        <Composition id="Daylight" component={Daylight} durationInFrames={90} fps={FPS} width={W} height={H} />
        {/* Shots 19–21: f2520–2879. */}
        <Composition id="Essentials" component={Essentials} durationInFrames={360} fps={FPS} width={W} height={H} />
        {/* Shots 22–23: f2880–3179. */}
        <Composition id="Gather" component={Gather} durationInFrames={300} fps={FPS} width={W} height={H} />
        {/* Shots 24–25: f3180–3479 of the main film. */}
        <Composition id="Close" component={Close} durationInFrames={300} fps={FPS} width={W} height={H} />
      </Folder>
      <Folder name="Essais">
        <Composition id="PhoneTest" component={PhoneTest} durationInFrames={3} fps={FPS} width={W} height={H} />
      </Folder>
    </>
  );
};
