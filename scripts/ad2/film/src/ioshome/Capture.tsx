import { useEffect, useState } from "react";
import { AbsoluteFill, continueRender, delayRender, useCurrentFrame } from "remotion";
import { INTER } from "../lib/brand";
import { dockIconFiles, drawIosChrome, iconFiles, IOS, IOS_CAPTURES, iosFill, iosRect, Rect } from "../lib/iosHome";
import { asset, setKitLang } from "../lib/kit";

const load = (src: string) =>
  new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`cannot load ${src}`));
    img.src = src;
  });

/**
 * A Home capture of the app recomposed as a real iPhone Home Screen (frame i = the i-th entry of IOS_CAPTURES): the same wallpaper
 * and the same widgets (kit files, in the film's language) on the measured iOS grid, real Apple icons in the free cells, « Ardane »
 * under each widget, iOS status bar, Search pill and Dock. Render with --concurrency=1 (each frame loads its own pictures).
 */
export const IosHomeCapture: React.FC<{ lang: "en" | "fr" }> = ({ lang }) => {
  setKitLang(lang);
  const f = useCurrentFrame();
  const name = Object.keys(IOS_CAPTURES)[f];
  const [out, setOut] = useState<{ name: string; url: string } | null>(null);
  useEffect(() => {
    const spec = IOS_CAPTURES[name];
    const handle = delayRender(`ioshome ${name}`);
    const rects: Rect[] = spec.widgets.map((w) => iosRect(w.size, w.c, w.r));
    const icons = iosFill(rects, spec.widgets.map((w) => w.file));
    const files = [`kit/${spec.wall}`, ...spec.widgets.map((w) => `kit/${w.file}`), ...iconFiles(icons), ...dockIconFiles()];
    Promise.all([document.fonts.load(`500 36px "${INTER}"`), document.fonts.load(`600 52px "${INTER}"`), ...files.map((p) => load(asset(p)))])
      .then((res) => {
        const imgs: Record<string, HTMLImageElement> = {};
        files.forEach((p, i) => (imgs[p] = res[i + 2] as HTMLImageElement));
        const cv = document.createElement("canvas");
        cv.width = IOS.w;
        cv.height = IOS.h;
        const ctx = cv.getContext("2d")!;
        ctx.drawImage(imgs[`kit/${spec.wall}`], 0, 0, IOS.w, IOS.h);
        spec.widgets.forEach((w, i) => {
          ctx.save();
          ctx.shadowColor = "rgba(0,0,0,0.22)";
          ctx.shadowBlur = 30;
          ctx.shadowOffsetY = 14;
          ctx.drawImage(imgs[`kit/${w.file}`], ...rects[i]);
          ctx.restore();
        });
        drawIosChrome(ctx, imgs, { dark: spec.dark, icons, widgetLabels: rects, clear: false });
        setOut({ name, url: cv.toDataURL("image/png") });
      })
      .catch((e) => console.error(e))
      .finally(() => setTimeout(() => continueRender(handle), 50));
  }, [name]);
  return <AbsoluteFill style={{ background: "#000" }}>{out?.name === name && <img src={out.url} style={{ width: IOS.w, height: IOS.h }} />}</AbsoluteFill>;
};
