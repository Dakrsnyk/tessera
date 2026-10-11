import { Composition, Folder } from "remotion";
import { FPS, H, W } from "./lib/brand";
import { Close } from "./scenes/Close";

export const RemotionRoot: React.FC = () => {
  return (
    <Folder name="Principal">
      {/* Shots 24–25: f3180–3479 of the main film. */}
      <Composition id="Close" component={Close} durationInFrames={300} fps={FPS} width={W} height={H} />
    </Folder>
  );
};
