import { Composition } from "remotion";
import { AvantApresFilm, AvantApresStill, FPS_AA, T } from "./Film";
import { SH, SW } from "./screens";

export const AvantApresRoot: React.FC = () => (
  <>
    <Composition id="AvantApres" component={AvantApresFilm} durationInFrames={T.total} fps={FPS_AA} width={1080} height={1920} />
    <Composition id="AvantApresStill" component={AvantApresStill} durationInFrames={1} fps={FPS_AA} width={SW} height={SH} defaultProps={{ which: "volt" }} />
  </>
);
