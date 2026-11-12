import { createContext, useContext } from "react";

/**
 * The look of the main film since 2026-11-11 (demande du PDG: « plus propre et pro », at the level of the « avant / après » ad):
 * ambient light from the screen on show instead of black, iPhone screen corners, sober pills with an accent dot. Only the main
 * film turns it on (FilmMainV5Short), so the library films that share MiniApp5 keep their look.
 */
export const MainLook = createContext(false);
export const useMainLook = () => useContext(MainLook);

/** A sober pill: translucent dark glass, a thin border tinted by the accent, white text. */
export const pillStyle = (accent: string): React.CSSProperties => ({
  background: "rgba(14,16,20,0.72)",
  backdropFilter: "blur(20px)",
  border: `2px solid ${accent}66`,
  color: "#F5F5F7",
  boxShadow: "0 10px 30px rgba(0,0,0,0.35)",
});
