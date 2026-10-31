// THE OPENING: palette, curves and timeline (Concept-THE-OPENING §2–3, docs/memoire/campagne-v2).
import { useEffect, useState } from "react";
import { continueRender, delayRender, Easing, staticFile } from "remotion";

export const W = 1080;
export const H = 1920;
export const FPS = 60;
/** Every super is centred on the seam axis. */
export const AXIS = 540;

export const C = {
  void: "#000000",
  lifted: "#07101C",
  seamCore: "#FFFFFF",
  /** Saphir identity (icon "ArdaneIcon": gradient 160deg #4E9BE0 -> #1B4A7A, halves white / #D6E9FA). */
  paleWarm: "#F2F8FE",
  pale: "#D6E9FA",
  sapphire: "#4E9BE0",
  sapphireDeep: "#1B4A7A",
  sapphireBright: "#68B5F5",
  type1: "#F5F5F7",
  type2: "#A1A1A6",
  type3: "#6E6E73",
};

export const ease = {
  /** Camera arrivals: long tail, nothing stops dead. */
  arrival: Easing.bezier(0.25, 0.1, 0, 1),
  /** Camera transfers. */
  transfer: Easing.bezier(0.65, 0, 0.35, 1),
  /** Type split from the seam. */
  split: Easing.bezier(0.16, 1, 0.3, 1),
  /** Lift of a widget off the glass. */
  lift: Easing.bezier(0.3, 0, 0.1, 1),
  /** Split chapter change. */
  chapter: Easing.bezier(0.7, 0, 0.2, 1),
  easeIn: Easing.bezier(0.42, 0, 1, 1),
};

/** 120 BPM: a beat is 30 frames, a bar 120. Integer frames only. */
export const at = (bar: number, beat = 0, offset = 0) => (bar - 1) * 120 + beat * 30 + offset;

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const INTER = "Inter Ardane";

// Inter (variable, with the optical-size axis: 32 = the Display cut). Rendering waits for it.
const fontHandle = delayRender("Inter");
const inter = new FontFace(INTER, `url(${staticFile("fonts/Inter-opsz.woff2")}) format("woff2")`, {
  weight: "100 900",
});
inter
  .load()
  .then((face) => {
    document.fonts.add(face);
    continueRender(fontHandle);
  })
  .catch((err) => {
    console.error(err);
    continueRender(fontHandle);
  });

/** True once Inter is usable (for text drawn into canvases: textures, labels). Rendering waits for it. */
export const useFontsReady = () => {
  const [ready, setReady] = useState(() => document.fonts.check(`600 40px "${INTER}"`));
  const [handle] = useState(() => (ready ? null : delayRender("Inter for canvases")));
  useEffect(() => {
    if (ready) return;
    let tries = 0;
    const poll = () => {
      if (document.fonts.check(`600 40px "${INTER}"`) || tries++ > 200) {
        setReady(true);
        if (handle !== null) continueRender(handle);
      } else {
        setTimeout(poll, 25);
      }
    };
    poll();
  }, [ready, handle]);
  return ready;
};

/** Type styles of §2.6. `display` uses the 32 optical size. */
export const type = {
  hero: { fontFamily: INTER, fontWeight: 700, fontSize: 132, letterSpacing: "-0.03em", fontVariationSettings: "'opsz' 32" },
  super: {
    fontFamily: INTER,
    fontWeight: 600,
    fontSize: 88,
    lineHeight: 1.04,
    letterSpacing: "-0.02em",
    fontVariationSettings: "'opsz' 32",
  },
  eyebrow: {
    fontFamily: INTER,
    fontWeight: 600,
    fontSize: 25,
    letterSpacing: "0.14em",
    textTransform: "uppercase",
    color: C.type2,
    fontVariationSettings: "'opsz' 14",
  },
  wordmark: { fontFamily: INTER, fontWeight: 600, fontSize: 120, letterSpacing: "-0.02em", fontVariationSettings: "'opsz' 32" },
  tagline: { fontFamily: INTER, fontWeight: 400, fontSize: 40, color: C.type2, fontVariationSettings: "'opsz' 20" },
  cta: { fontFamily: INTER, fontWeight: 500, fontSize: 32, fontVariationSettings: "'opsz' 20" },
} as const;
