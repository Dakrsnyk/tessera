import { Composition, registerRoot } from "remotion";
import { setKitLang } from "../lib/kit";
import { LangContext } from "../lib/i18n";
import { FPS, H, W } from "../lib/brand";
import { Homes, HOMES_FRAMES } from "./Homes";
import { Process, PROCESS_FRAMES } from "./Process";

const En: React.FC<{ c: React.FC }> = ({ c: C }) => {
  setKitLang("en");
  return (
    <LangContext.Provider value="en">
      <C />
    </LangContext.Provider>
  );
};
const P: React.FC = () => <En c={Process} />;
const Hm: React.FC = () => <En c={Homes} />;

registerRoot(() => (
  <>
    <Composition id="V4Process" component={P} durationInFrames={PROCESS_FRAMES} fps={FPS} width={W} height={H} />
    <Composition id="V4Homes" component={Hm} durationInFrames={HOMES_FRAMES} fps={FPS} width={W} height={H} />
  </>
));
