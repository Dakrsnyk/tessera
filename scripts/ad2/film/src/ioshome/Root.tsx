import { Composition } from "remotion";
import { IOS, IOS_CAPTURES } from "../lib/iosHome";
import { IosHomeCapture } from "./Capture";

/** One frame per recomposed capture, in the order of IOS_CAPTURES (ios_homes.sh names the frames). */
export const IosHomeRoot: React.FC = () => (
  <Composition id="IosHomeCapture" component={IosHomeCapture} durationInFrames={Object.keys(IOS_CAPTURES).length} fps={30} width={IOS.w} height={IOS.h} defaultProps={{ lang: "en" as "en" | "fr" }} />
);
