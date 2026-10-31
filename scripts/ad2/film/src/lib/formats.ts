import { W, H } from "./brand";

/** Output formats. The scenes are authored at 1080 × 1920 (W × H); the other formats wrap them (FormatFrame). */
export type Format = "9x16" | "1x1" | "4x5" | "16x9";
export const FORMAT_IDS: Format[] = ["9x16", "1x1", "4x5", "16x9"];

export const SIZE: Record<Format, { w: number; h: number }> = {
  "9x16": { w: W, h: H },
  "1x1": { w: 1080, h: 1080 },
  "4x5": { w: 1080, h: 1350 },
  "16x9": { w: 1920, h: 1080 },
};

/**
 * Layout of each wrapped format: where the 9:16 scene shows (a window, in output pixels), at which scale, and
 * which point of the scene (focusY, scene pixels; x is always the axis 540) sits at the window's centre.
 * `feather` (output px) softens the window's edge towards the text zone; `margin` is the safe margin around text.
 */
export type Layout = {
  window: { x: number; y: number; w: number; h: number };
  scale: number;
  focusY: number;
  feather: { top?: number; left?: number };
  margin: number;
};

export const LAYOUT: Record<Exclude<Format, "9x16">, Layout> = {
  // Text row on top (mark + headline), phone window below.
  "1x1": { window: { x: 0, y: 200, w: 1080, h: 880 }, scale: 0.62, focusY: 960, feather: { top: 70 }, margin: 64 },
  // Taller text zone (mark, headline, sub), larger phone.
  "4x5": { window: { x: 0, y: 340, w: 1080, h: 1010 }, scale: 0.73, focusY: 960, feather: { top: 90 }, margin: 72 },
  // Two columns: text left, phone right.
  "16x9": { window: { x: 960, y: 0, w: 960, h: 1080 }, scale: 0.76, focusY: 960, feather: { left: 120 }, margin: 110 },
};
