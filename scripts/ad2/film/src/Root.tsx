import { Composition, Folder } from "remotion";
import { FPS, H, W } from "./lib/brand";
import { MAIN_LENGTH, MainFilm } from "./scenes/MainFilm";
import { filmLength, FilmId } from "./films/CutFilm";
import { FilmFormat, FormatProps, SceneFormat } from "./films/Formatted";
import { SIZE } from "./lib/formats";
import { PhoneTest } from "./scenes/PhoneTest";
import { FilmMainV3Format, V3_LENGTH } from "./v3/FilmMainV3";
import { FilmMainV4Format, V4_LENGTH } from "./v4/FilmMainV4";
import { FilmMainV5Format, V5_LENGTH } from "./v5/FilmMainV5";
import { FilmMainV5ShortFormat, V5S_LENGTH } from "./v5/short/FilmMainV5Short";
import { FilmMainV5Part2Format, V5P2_LENGTH } from "./v5/part2/FilmMainV5Part2";
import { LIB_COMPS } from "./v5/lib/registry";
import { Film26, FILM26, Film26Id } from "./ad26/films";
import { serieFolder } from "./v4/series/registry";


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
      <Folder name="Campagne-2026">
        {(Object.keys(FILM26) as Film26Id[]).map((id) => (
          <Composition key={FILM26[id].comp} id={FILM26[id].comp} component={Film26} defaultProps={{ ...base, film: id, audio: false }} calculateMetadata={calc} durationInFrames={FILM26[id].frames} fps={FPS} width={W} height={H} />
        ))}
      </Folder>
      <Folder name="V3">
        <Composition id="FilmMainV3" component={FilmMainV3Format} defaultProps={base} calculateMetadata={calc} durationInFrames={V3_LENGTH} fps={FPS} width={W} height={H} />
      </Folder>
      <Folder name="V4">
        <Composition id="FilmMainV4" component={FilmMainV4Format} defaultProps={base} calculateMetadata={calc} durationInFrames={V4_LENGTH} fps={FPS} width={W} height={H} />
      </Folder>
      {serieFolder()}
      <Folder name="V5">
        <Composition id="FilmMainV5Part2" component={FilmMainV5Part2Format} defaultProps={base} calculateMetadata={calc} durationInFrames={V5P2_LENGTH} fps={FPS} width={W} height={H} />
        <Composition id="FilmMainV5Short" component={FilmMainV5ShortFormat} defaultProps={base} calculateMetadata={calc} durationInFrames={V5S_LENGTH} fps={FPS} width={W} height={H} />
        <Composition id="FilmMainV5" component={FilmMainV5Format} defaultProps={base} calculateMetadata={calc} durationInFrames={V5_LENGTH} fps={FPS} width={W} height={H} />
      </Folder>
      <Folder name="Lib">
        {LIB_COMPS.map((c) => (
          <Composition key={c.id} id={c.id} component={c.Format} defaultProps={base} calculateMetadata={calc} durationInFrames={c.length} fps={FPS} width={W} height={H} />
        ))}
      </Folder>
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
