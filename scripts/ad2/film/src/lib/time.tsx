import { createContext, useContext } from "react";
import { interpolate, useCurrentFrame } from "remotion";

/**
 * Time remap for the cut-downs: a film can play a scene's camera moves faster (piecewise linear, from
 * output frames to the scene's own frames). UI is never played faster than 1×: a remap only spans camera
 * moves, light and type; ranges with live UI (countdowns, demos, scrolls) are mapped 1:1.
 */
type Remap = { input: number[]; output: number[] } | null;
const RemapContext = createContext<Remap>(null);

export const TimeRemap: React.FC<{ input: number[]; output: number[]; children: React.ReactNode }> = ({ input, output, children }) => (
  <RemapContext.Provider value={{ input, output }}>{children}</RemapContext.Provider>
);

/** The scene's frame: the composition frame, remapped when a film says so. */
export const useFilmFrame = () => {
  const frame = useCurrentFrame();
  const remap = useContext(RemapContext);
  if (!remap) return frame;
  return interpolate(frame, remap.input, remap.output, { extrapolateLeft: "extend", extrapolateRight: "extend" });
};
