import { Audio } from "@remotion/media";
import { staticFile } from "remotion";

/** A scene's preview plays the main film's final mix from its own first frame (the film has one mix). */
export const FilmAudio: React.FC<{ from: number; file?: string }> = ({ from, file = "audio/mix-main.wav" }) => (
  <Audio src={staticFile(file)} trimBefore={from} />
);
