// Shared pieces of the TikTok templates (chantier 19.15): font, real captures, TikTok-style captions.
import React, { useState } from "react";
import { continueRender, delayRender, Easing, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";

export const W = 1080;
export const H = 1920;
export const FPS = 30;
/** Captures of the app are 1206 x 2622 (src/lib/kit.ts of the campaign). */
export const CAP_W = 1206;
export const CAP_H = 2622;
export type Rect = [number, number, number, number];

export const FONT = "Inter Ardane TikTok";
const handle = delayRender("Inter");
new FontFace(FONT, `url(${staticFile("fonts/Inter-opsz.woff2")}) format("woff2")`, { weight: "100 900" })
  .load()
  .then((f) => {
    document.fonts.add(f);
    continueRender(handle);
  })
  .catch((e) => {
    console.error(e);
    continueRender(handle);
  });

/** A capture of the English kit by name. */
export const cap = (name: string) => staticFile(`kit2026/en/${name}.png`);

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
export const out = Easing.bezier(0.16, 1, 0.3, 1);

/** Scale that fits a capture to the frame width, and its height on screen. */
export const S = W / CAP_W;
export const SCREEN_H = CAP_H * S;

/** Vertical offset (px, <= 0) that puts focusY (0–1 of the capture) at the frame's centre, without showing past the edges. */
export const topFor = (focusY: number) => Math.min(0, Math.max(H - SCREEN_H, H / 2 - SCREEN_H * focusY));

/**
 * A capture in full screen. `zoom` scales around (ox, oy) in frame pixels; the entry "punch" of a TikTok cut
 * (1.06 → 1 in 6 frames) and a slow drift are applied on top.
 */
export const Screen: React.FC<{
  src: string;
  focusY?: number;
  zoom?: number;
  ox?: number;
  oy?: number;
  drift?: number;
  blur?: number;
  children?: React.ReactNode;
}> = ({ src, focusY = 0.5, zoom = 1, ox = W / 2, oy = H / 2, drift = 0.03, blur = 0, children }) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const punch = interpolate(f, [0, 6], [1.06, 1], { ...clamp, easing: out });
  const slow = interpolate(f, [0, durationInFrames], [1, 1 + drift], clamp);
  const top = topFor(focusY);
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", background: "#000" }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          transform: `scale(${zoom * punch * slow})`,
          transformOrigin: `${ox}px ${oy}px`,
          filter: blur ? `blur(${blur}px)` : undefined,
        }}
      >
        <Img src={cap(src)} style={{ position: "absolute", left: 0, top, width: W, height: SCREEN_H }} />
        {children}
      </div>
    </div>
  );
};

/** Where a rectangle of the capture lands on screen (before any zoom). */
export const onScreen = (r: Rect, focusY: number) => {
  const top = topFor(focusY);
  return { x: r[0] * S, y: top + r[1] * S, w: r[2] * S, h: r[3] * S };
};

/** TikTok's classic text: each line in its own rounded box. Pops in at `at` frames. */
export const Caption: React.FC<{
  text: string;
  y: number;
  at?: number;
  size?: number;
  dark?: boolean;
}> = ({ text, y, at = 3, size = 62, dark = false }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f - at, fps, config: { damping: 14, stiffness: 220, mass: 0.6 } });
  if (f < at) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: 120,
        right: 120,
        top: y,
        textAlign: "center",
        transform: `scale(${0.82 + 0.18 * s})`,
        opacity: Math.min(1, s * 1.6),
        transformOrigin: "50% 0%",
      }}
    >
      <span
        style={{
          fontFamily: FONT,
          fontWeight: 700,
          fontSize: size,
          lineHeight: 1.36,
          color: dark ? "#fff" : "#000",
          background: dark ? "#000" : "#fff",
          padding: `${size * 0.06}px ${size * 0.36}px`,
          borderRadius: size * 0.26,
          WebkitBoxDecorationBreak: "clone",
          boxDecorationBreak: "clone",
          fontVariationSettings: `"opsz" 32`,
        }}
      >
        {text}
      </span>
    </div>
  );
};

/** « With Premium », shown whenever a Premium style or more than 3 widgets are on screen (campaign rule). */
export const PremiumTag: React.FC<{ y?: number }> = ({ y = 1500 }) => (
  <div style={{ position: "absolute", left: 0, right: 0, top: y, display: "flex", justifyContent: "center" }}>
    <div
      style={{
        fontFamily: FONT,
        fontWeight: 600,
        fontSize: 30,
        color: "#fff",
        background: "rgba(0,0,0,0.6)",
        padding: "8px 22px",
        borderRadius: 26,
      }}
    >
      With Premium
    </div>
  </div>
);

/** A widget cut out of a real Home Screen capture, with the iOS corner radius (66 px on the capture). */
export const WidgetCut: React.FC<{ src: string; rect: Rect; width: number; style?: React.CSSProperties }> = ({ src, rect, width, style }) => {
  const k = width / rect[2];
  return (
    <div style={{ position: "relative", width, height: rect[3] * k, borderRadius: 66 * k, overflow: "hidden", ...style }}>
      <Img src={cap(src)} style={{ position: "absolute", left: -rect[0] * k, top: -rect[1] * k, width: CAP_W * k, height: CAP_H * k }} />
    </div>
  );
};

/** Sum of shot durations in frames. */
export const total = (durs: number[]) => durs.reduce((a, d) => a + Math.round(d * FPS), 0);

export const useOnce = <T,>(make: () => T) => useState(make)[0];
