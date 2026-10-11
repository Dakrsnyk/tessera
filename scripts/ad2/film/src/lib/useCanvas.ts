import { useMemo } from "react";
import * as THREE from "three";
import type { Rect } from "./kit";

/**
 * A canvas the scene redraws on every frame, and its three.js texture (sRGB). A ThreeCanvas only redraws
 * when the frame changes, so the scene must mount it once every picture the canvas needs is decoded.
 */
export const useCanvasTexture = (width = 1206, height = 2622) =>
  useMemo(() => {
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d")!;
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = 8;
    return { canvas, ctx, texture };
  }, [width, height]);

export const roundRectPath = (ctx: CanvasRenderingContext2D, [x, y, w, h]: Rect, r: number) => {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
};

/** A vertical blade of light at x across a rectangle (2 px core, peach glow), drawn into a canvas. */
export const drawBlade = (ctx: CanvasRenderingContext2D, x: number, top: number, height: number, strength = 1) => {
  if (strength <= 0) return;
  ctx.save();
  const g = ctx.createLinearGradient(x - 60, 0, x + 60, 0);
  g.addColorStop(0, "rgba(255,122,89,0)");
  g.addColorStop(0.4, `rgba(255,122,89,${0.18 * strength})`);
  g.addColorStop(0.5, `rgba(255,224,204,${0.75 * strength})`);
  g.addColorStop(0.6, `rgba(255,122,89,${0.18 * strength})`);
  g.addColorStop(1, "rgba(255,122,89,0)");
  ctx.fillStyle = g;
  ctx.fillRect(x - 60, top, 120, height);
  ctx.fillStyle = `rgba(255,255,255,${0.95 * strength})`;
  ctx.fillRect(x - 1.5, top, 3, height);
  ctx.restore();
};

/** Draws `img` at a rect, lifted by `b` (0…1): slightly larger, with a soft shadow under it. */
export const drawLifted = (ctx: CanvasRenderingContext2D, img: CanvasImageSource, [x, y, w, h]: Rect, b: number) => {
  const s = 1 + 0.035 * b;
  ctx.save();
  ctx.shadowColor = `rgba(0,0,0,${0.45 * b})`;
  ctx.shadowBlur = 40 * b;
  ctx.shadowOffsetY = 14 * b;
  ctx.drawImage(img, x + (w - w * s) / 2, y + (h - h * s) / 2 - 6 * b, w * s, h * s);
  ctx.restore();
};
