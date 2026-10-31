import { Composition, Folder } from "remotion";
import { FPS, H, W } from "./lib/brand";
import { MAIN_LENGTH, MainFilm } from "./scenes/MainFilm";
import { filmLength, FilmId } from "./films/CutFilm";
import { FilmFormat, FormatProps, SceneFormat } from "./films/Formatted";
import { SIZE } from "./lib/formats";
import { PhoneTest } from "./scenes/PhoneTest";


const base: FormatProps = { format: "9x16", lang: "en" };
/** Output size follows the `format` prop: --props='{"format":"4x5","lang":"fr"}'. */
const calc = ({ props }: { props: FormatProps }) => ({ width: SIZE[props.format].w, height: SIZE[props.format].h });

const filmComp = (id: string, film: FilmId) => (
  <Composition key={id} id={id} component={FilmFormat} defaultProps={{ ...base, film }} calculateMetadata={calc} durationInFrames={filmLength(film)} fps={FPS} width={W} height={H} />
);
const sceneComp = (id: string, frames: number) => (
  <Composition key={id} id={id} component={SceneFormat} defaultProps={{ ...base, scene: id }} calculateMetadata={calc} durationInFrames={frames} fps={FPS} width={W} height={H} />
);

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {filmComp("MainFilm", "main")}
    <Composition id="MainFilm58" component={MainFilm} durationInFrames={MAIN_LENGTH} fps={FPS} width={W} height={H} />
    {filmComp("Film30", "s30")}
    {filmComp("Film8", "s8")}
    {filmComp("Film15", "s15")}
    {filmComp("FilmFitness", "fitness")}
    {filmComp("FilmPerso", "perso")}
    {filmComp("FilmNutrition", "nutrition")}
      <Folder name="Principal">
        {/* Shots 1–3: f0–359. */}
        {sceneComp("Opening", 360)}
        {/* Shots 4–6: f360–959. */}
        {sceneComp("Universes", 600)}
        {sceneComp("Studio", 360)}
      {/* Shots 7–10: f960–1559. */}
        {sceneComp("Fitness", 600)}
        {/* Shots 11–13: f1560–1919. */}
        {sceneComp("LockScreen", 360)}
        {/* Shots 14–18: f1920–2519. */}
        {sceneComp("Nutrition", 600)}
        {/* Shot 14: f1920–2009. */}
        {sceneComp("Daylight", 90)}
        {/* Shots 19–21: f2520–2879. */}
        {sceneComp("Essentials", 360)}
        {/* Shots 22–23: f2880–3179. */}
        {sceneComp("Gather", 300)}
        {/* Shots 24–25: f3180–3479 of the main film. */}
        {sceneComp("Close", 300)}
      </Folder>
      <Folder name="Essais">
        <Composition id="PhoneTest" component={PhoneTest} durationInFrames={3} fps={FPS} width={W} height={H} />
      </Folder>
    </>
  );
};
