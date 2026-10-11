import { Composition, Folder } from "remotion";
import { FPS, H, W } from "./lib/brand";
import { Close } from "./scenes/Close";
import { Daylight } from "./scenes/Daylight";
import { LockScreen } from "./scenes/LockScreen";
import { Opening } from "./scenes/Opening";
import { PhoneTest } from "./scenes/PhoneTest";

export const RemotionRoot: React.FC = () => {
  return (
    <>
    <Folder name="Principal">
      {/* Shots 1–3: f0–359. */}
      <Composition id="Opening" component={Opening} durationInFrames={360} fps={FPS} width={W} height={H} />
      {/* Shots 11–13: f1560–1919. */}
      <Composition id="LockScreen" component={LockScreen} durationInFrames={360} fps={FPS} width={W} height={H} />
      {/* Shot 14: f1920–2009. */}
      <Composition id="Daylight" component={Daylight} durationInFrames={90} fps={FPS} width={W} height={H} />
      {/* Shots 24–25: f3180–3479 of the main film. */}
      <Composition id="Close" component={Close} durationInFrames={300} fps={FPS} width={W} height={H} />
    </Folder>
    <Folder name="Essais">
      <Composition id="PhoneTest" component={PhoneTest} durationInFrames={3} fps={FPS} width={W} height={H} />
    </Folder>
    </>
  );
};
