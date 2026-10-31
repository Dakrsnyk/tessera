import { CutFilm, FilmId, SCENES } from "./CutFilm";
import { FormatFrame, FrameText } from "./FormatFrame";
import { Format } from "../lib/formats";
import { Lang } from "../lib/i18n";
import cuts from "./cuts.json";

/** Every film (cuts.json) and every scene in any of the 4 formats and the 2 languages. */
export type FormatProps = { format: Format; lang: Lang };

const FRAME_KEY: Record<FilmId, string> = { main: "frame.main", s30: "frame.s30", s15: "frame.s15", s8: "frame.s8", fitness: "frame.fitness", nutrition: "frame.nutrition", perso: "frame.perso" };

const textOf = (film: FilmId): FrameText => {
  const segs = cuts.films[film].segments as { scene: string; at: number; props?: { hook?: { to: number } } }[];
  const hookTo = segs[0]?.props?.hook?.to ?? 0;
  const close = segs.find((s) => s.scene === "Close");
  const key = FRAME_KEY[film];
  return { headline: key, sub: `${key}.sub`, show: hookTo + 34, hide: (close ? close.at : cuts.films[film].length) - 24 };
};

export const FilmFormat: React.FC<FormatProps & { film: FilmId; audioLang?: Lang }> = ({ film, format, lang, audioLang }) => (
  <FormatFrame format={format} lang={lang} text={textOf(film)}>
    <CutFilm film={film} audioLang={audioLang ?? lang} />
  </FormatFrame>
);

/** A single scene (stills and checks). The frame's headline is shown after the opening hook, never over the end card. */
const SCENE_TEXT: Record<string, { show: number; hide: number }> = { Opening: { show: 130, hide: 99999 }, Close: { show: 99999, hide: 99999 } };

export const SceneFormat: React.FC<FormatProps & { scene: string; props?: Record<string, unknown> }> = ({ scene, format, lang, props }) => {
  const El = SCENES[scene];
  const t = SCENE_TEXT[scene] ?? { show: 20, hide: 99999 };
  return (
    <FormatFrame format={format} lang={lang} text={{ headline: "frame.main", sub: "frame.main.sub", ...t }}>
      <El {...(props ?? {})} />
    </FormatFrame>
  );
};
