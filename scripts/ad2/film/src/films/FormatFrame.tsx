import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { ArdaneLogo } from "../components/ArdaneLogo";
import { Grain } from "../components/Grain";
import { C, clamp, ease, INTER, type } from "../lib/brand";
import { Format, LAYOUT, SIZE } from "../lib/formats";
import { Lang, LangContext, translate } from "../lib/i18n";

/**
 * The envelope: the 9:16 scene (rendered at its native 1080 × 1920) inside a frame made for another format.
 * 9:16 passes through untouched. For the others the frame owns the brand background, the lockup (mark +
 * wordmark), the headline and the sub line with their own entrance, placed in the format's text zone; the
 * scene shows through a window (scaled, centred on its interest point, feathered towards the text).
 * The headline waits for the hook to close and leaves before the end card, so it never repeats the scene's own type.
 */
export type FrameText = {
  /** i18n keys of the headline and the sub line. */
  headline: string;
  sub?: string;
  /** Headline visible from / until (film frames). */
  show: number;
  hide: number;
};

const Reveal: React.FC<{ at: number; out: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ at, out, children, style }) => {
  const f = useCurrentFrame();
  const p = interpolate(f, [at, at + 26], [0, 1], { ...clamp, easing: ease.split });
  const o = interpolate(f, [out, out + 14], [1, 0], clamp);
  if (f < at || o <= 0) return null;
  return <div style={{ opacity: Math.min(1, p * 1.6) * o, transform: `translateY(${(1 - p) * 34}px)`, ...style }}>{children}</div>;
};

const Lockup: React.FC<{ size: number; word: number }> = ({ size, word }) => (
  <div style={{ display: "flex", alignItems: "center", gap: size * 0.28, height: size }}>
    <div style={{ position: "relative", width: size, height: size }}>
      <ArdaneLogo size={size} cx={size / 2} cy={size / 2} glow={0.9} />
    </div>
    <span style={{ ...type.wordmark, fontSize: word, color: C.type1, lineHeight: 1 }}>Ardane</span>
  </div>
);

export const FormatFrame: React.FC<{ format: Format; lang: Lang; text: FrameText; children: React.ReactNode }> = ({ format, lang, text, children }) => {
  if (format === "9x16") return <LangContext.Provider value={lang}>{children}</LangContext.Provider>;
  const { w, h } = SIZE[format];
  const L = LAYOUT[format];
  const t = (k?: string) => (k ? translate(lang, k) : "");
  const win = L.window;
  const sx = win.w / 2 - 540 * L.scale;
  const sy = win.h / 2 - L.focusY * L.scale;

  // The window's edge fades into the text zone (mask in output pixels).
  const layers: string[] = [];
  if (L.feather.top) layers.push(`linear-gradient(to bottom, transparent 0px, black ${L.feather.top}px)`);
  if (L.feather.left) layers.push(`linear-gradient(to right, transparent 0px, black ${L.feather.left}px)`);
  // The scene's own black ground meets the frame's: soften its side edges where the window is narrower than the frame.
  if (L.scale * 1080 < win.w) {
    const e = Math.round(80 * L.scale);
    const x0 = Math.round(win.w / 2 - 540 * L.scale);
    layers.push(`linear-gradient(to right, transparent ${x0}px, black ${x0 + e}px, black ${win.w - x0 - e}px, transparent ${win.w - x0}px)`);
  }
  const windowMask = layers.length ? layers.join(", ") : undefined;

  const headStyle: React.CSSProperties = { ...type.super, color: C.type1 };
  const subStyle: React.CSSProperties = { ...type.tagline, color: C.type2 };

  let textZone: React.ReactNode;
  if (format === "16x9") {
    textZone = (
      <div style={{ position: "absolute", left: L.margin, top: 0, width: 800, height: h }}>
        <div style={{ position: "absolute", top: 96 }}>
          <Lockup size={84} word={60} />
        </div>
        <div style={{ position: "absolute", top: 330, width: 800 }}>
          <Reveal at={text.show} out={text.hide} style={{ ...headStyle, fontSize: 80, lineHeight: 1.06 }}>
            {t(text.headline)}
          </Reveal>
          {text.sub && (
            <Reveal at={text.show + 12} out={text.hide} style={{ ...subStyle, fontSize: 36, marginTop: 36, lineHeight: 1.3 }}>
              {t(text.sub)}
            </Reveal>
          )}
        </div>
      </div>
    );
  } else if (format === "4x5") {
    textZone = (
      <div style={{ position: "absolute", left: L.margin, top: 0, width: w - 2 * L.margin, height: win.y }}>
        <div style={{ position: "absolute", top: 64 }}>
          <Lockup size={64} word={46} />
        </div>
        <div style={{ position: "absolute", top: 160, width: "100%" }}>
          <Reveal at={text.show} out={text.hide} style={{ ...headStyle, fontSize: 52, lineHeight: 1.06 }}>
            {t(text.headline)}
          </Reveal>
          {text.sub && (
            <Reveal at={text.show + 12} out={text.hide} style={{ ...subStyle, fontSize: 30, marginTop: 18 }}>
              {t(text.sub)}
            </Reveal>
          )}
        </div>
      </div>
    );
  } else {
    // 1:1: the mark on the left; the wordmark, then the headline, beside it.
    const row: React.CSSProperties = { position: "absolute", top: 0, left: 0, right: 0, display: "flex", alignItems: "center", height: 120 };
    textZone = (
      <div style={{ position: "absolute", left: L.margin, top: 44, width: w - 2 * L.margin, height: 120, display: "flex", alignItems: "center", gap: 28 }}>
        <div style={{ position: "relative", width: 92, height: 92, flex: "none" }}>
          <ArdaneLogo size={92} cx={46} cy={46} glow={0.9} />
        </div>
        <div style={{ position: "relative", flex: 1, height: 120 }}>
          <Reveal at={0} out={text.show - 6} style={{ ...type.wordmark, fontSize: 56, color: C.type1, ...row }}>
            Ardane
          </Reveal>
          <Reveal at={text.show} out={text.hide} style={{ ...headStyle, fontSize: 42, lineHeight: 1.08, ...row }}>
            {t(text.headline)}
          </Reveal>
        </div>
      </div>
    );
  }

  return (
    <LangContext.Provider value={lang}>
      <AbsoluteFill style={{ backgroundColor: C.void, fontFamily: INTER }}>
        <div
          style={{
            position: "absolute",
            left: win.x,
            top: win.y,
            width: win.w,
            height: win.h,
            overflow: "hidden",
            maskImage: windowMask,
            WebkitMaskImage: windowMask,
            WebkitMaskComposite: "source-in",
            maskComposite: "intersect",
          }}
        >
          <div style={{ position: "absolute", left: 0, top: 0, width: 1080, height: 1920, transformOrigin: "0 0", transform: `translate(${sx}px, ${sy}px) scale(${L.scale})` }}>
            {children}
          </div>
        </div>
        {textZone}
        <Grain />
      </AbsoluteFill>
    </LangContext.Provider>
  );
};
