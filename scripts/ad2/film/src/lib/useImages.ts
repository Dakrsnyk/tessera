import { useEffect, useState } from "react";
import { continueRender, delayRender, staticFile } from "remotion";
import * as THREE from "three";

/** Decoded images of public/ (rendering waits for all of them). */
export const useImages = (files: string[]): Record<string, HTMLImageElement> | null => {
  const [images, setImages] = useState<Record<string, HTMLImageElement> | null>(null);
  const [handle] = useState(() => delayRender(`images ${files.length}`));
  const key = files.join("|");
  useEffect(() => {
    let cancelled = false;
    Promise.all(
      files.map(
        (file) =>
          new Promise<[string, HTMLImageElement]>((resolve, reject) => {
            const img = new Image();
            img.onload = () => img.decode().then(() => resolve([file, img]), () => resolve([file, img]));
            img.onerror = () => reject(new Error(`cannot load ${file}`));
            img.src = staticFile(file);
          }),
      ),
    )
      .then((pairs) => {
        if (!cancelled) setImages(Object.fromEntries(pairs));
        continueRender(handle);
      })
      .catch((err) => {
        console.error(err);
        continueRender(handle);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, handle]);
  return images;
};

/** A three.js texture of a decoded image (sRGB, mipmapped). */
export const imageTexture = (img: HTMLImageElement) => {
  const t = new THREE.Texture(img);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  t.needsUpdate = true;
  return t;
};
