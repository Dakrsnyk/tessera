import { useEffect, useState } from "react";
import { continueRender, delayRender } from "remotion";
import * as THREE from "three";

/** A texture that holds rendering until it is decoded (no frame is captured with an empty screen). */
export const useImageTexture = (src: string | null): THREE.Texture | null => {
  const [texture, setTexture] = useState<THREE.Texture | null>(null);
  const [handle] = useState(() => (src ? delayRender(`texture ${src}`) : null));
  useEffect(() => {
    if (!src || handle === null) return;
    new THREE.TextureLoader().load(
      src,
      (t) => {
        t.colorSpace = THREE.SRGBColorSpace;
        t.anisotropy = 8;
        t.generateMipmaps = true;
        t.minFilter = THREE.LinearMipmapLinearFilter;
        setTexture(t);
        continueRender(handle);
      },
      undefined,
      (err) => {
        console.error(err);
        continueRender(handle);
      },
    );
  }, [src, handle]);
  return texture;
};
