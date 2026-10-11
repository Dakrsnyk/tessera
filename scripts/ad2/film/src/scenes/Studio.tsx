import { ThreeCanvas } from "@remotion/three";
import { AbsoluteFill, Easing, Img, interpolate, staticFile } from "remotion";
import * as THREE from "three";
import { Callout } from "../components/Callout";
import { Grain } from "../components/Grain";
import { CameraLook, lensFov, PHONE, Phone3D, SCREEN, StudioEnvironment } from "../components/Phone3D";
import { Seam } from "../components/Seam";
import { SplitText } from "../components/SplitText";
import { AXIS, C, clamp, ease, H, type, W } from "../lib/brand";
import { HERO_WIDGETS, heroHome, heroWidget, k, type Rect } from "../lib/kit";
import { useFilmFrame } from "../lib/time";
import { roundRectPath, useCanvasTexture } from "../lib/useCanvas";
import { useImages } from "../lib/useImages";

/**
 * Design your widget (added 2026-10-11 at the user's request: designing widgets to one's taste is the
 * app's most important point after its usefulness). The macros widget leaves the Home for the Studio,
 * where a theme, styles and a palette are tapped, one per beat: each tap, a blade between two real
 * captures of the Studio (testAdStudio). Ends on « Make it yours. ».
 */
type Step = { at: number; file: string; tap: Rect; section: "Theme" | "Style" | "Colours" };
const STEPS_ALL: Omit<Step, "at">[] = [
  { file: "studio-preset-midnight", tap: [60, 1476, 527, 255], section: "Theme" },
  { file: "studio-preset-sunset", tap: [60, 1807, 527, 255], section: "Theme" },
  { file: "studio-style-aurora", tap: [618, 1805, 527, 255], section: "Style" },
  { file: "studio-style-neon", tap: [618, 1591, 527, 255], section: "Style" },
  { file: "studio-style-paper", tap: [618, 1874, 527, 255], section: "Style" },
  { file: "studio-style-liquidGlass", tap: [60, 1700, 527, 255], section: "Style" },
  { file: "studio-palette-gold", tap: [845, 1584, 240, 86], section: "Colours" },
];
/** The widget's preview on the Studio captures (px). */
const PREVIEW: Rect = [126, 360, 953, 445];
const U = "crepuscule";
const MACROS = HERO_WIDGETS[0];
/** The pane: the Studio capture down to its grid, 900 px wide. */
const PS = 900 / 1206;
const CROP = 2240;

export const Studio: React.FC<{ audio?: boolean; steps?: number[]; at?: number[]; end?: number; words?: boolean; suffix?: string }> = ({
  steps = [0, 1, 2, 3, 4, 5, 6],
  at = [90, 120, 150, 180, 210, 240, 270],
  end = 360,
  words = true,
  suffix = "",
}) => {
  const frame = useFilmFrame();
  const plan: Step[] = steps.map((i, j) => ({ ...STEPS_ALL[i], at: at[j] }));
  const file = (n: string) => k(`${n}${suffix}.png`);
  const images = useImages([heroHome(U)]);
  const screen = useCanvasTexture();
  const lift = interpolate(frame, [0, 36], [0, 1], { ...clamp, easing: ease.lift });
  if (images) {
    const ctx = screen.ctx;
    ctx.drawImage(images[heroHome(U)], 0, 0);
    if (frame >= 0) {
      ctx.save();
      roundRectPath(ctx, MACROS.rect, 66);
      ctx.fillStyle = "rgba(10,6,12,0.5)";
      ctx.fill();
      ctx.clip();
      ctx.shadowColor = "rgba(255,224,204,0.9)";
      ctx.shadowBlur = 60;
      ctx.lineWidth = 36;
      ctx.strokeStyle = "rgba(255,224,204,0.18)";
      ctx.stroke();
      ctx.restore();
    }
    screen.texture.needsUpdate = true;
  }

  // The phone (from the universes' end: 85 mm) falls back as the Studio opens.
  const fraction = interpolate(frame, [0, 60], [0.78, 0.6], { ...clamp, easing: ease.transfer });
  const S = ((H * fraction) / PHONE.h) * (SCREEN.w / 1206);
  const [x, y, w, h] = MACROS.rect;
  const slot: Rect = [AXIS + (x - 603) * S, H / 2 + (y - 1311) * S, w * S, h * S];
  // The pane forms around the widget (36–66): the lifted widget lands on the preview.
  const form = interpolate(frame, [30, 66], [0, 1], { ...clamp, easing: ease.transfer });
  const recede = interpolate(frame, [end - 60, end - 30], [0, 1], { ...clamp, easing: ease.transfer });
  const paneX = (W - 900) / 2;
  const paneY = 290;
  const preview: Rect = [paneX + PREVIEW[0] * PS, paneY + PREVIEW[1] * PS, PREVIEW[2] * PS, PREVIEW[3] * PS];
  const liftedMid: Rect = [AXIS - 470, 520, 940, (940 * 510) / 1092];
  const mix = (a: Rect, b: Rect, p: number) => a.map((v, j) => v + (b[j] - v) * p) as Rect;
  const widgetRect = mix(mix(slot, liftedMid, lift), preview, form);
  widgetRect[1] -= Math.sin(Math.PI * lift) * 30 * (1 - form);

  // Which capture is on the pane, and the blade between two of them.
  let current = file("studio-content");
  let next: string | null = null;
  let wipe = 0;
  for (const st of plan) {
    if (frame >= st.at + 12) current = file(st.file);
    else if (frame >= st.at) {
      next = file(st.file);
      wipe = interpolate(frame, [st.at, st.at + 12], [0, 1], { easing: Easing.bezier(0.45, 0, 0.2, 1) });
    }
  }
  const tapping = plan.find((st) => frame >= st.at - 10 && frame < st.at + 8);
  const ring = tapping ? interpolate(frame, [tapping.at - 10, tapping.at + 8], [0, 1], { ...clamp, easing: ease.split }) : 1;
  const sectionNow = (s: Step["section"]) => {
    const own = plan.filter((p) => p.section === s);
    return own.length ? { from: own[0].at - 2, to: own[own.length - 1].at + 26 } : null;
  };
  const pane = (src: string, extra?: React.CSSProperties) => (
    <Img src={staticFile(src)} style={{ position: "absolute", left: 0, top: 0, width: 900, height: 2622 * PS, ...extra }} />
  );
  const cropH = CROP * PS;

  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)` }} />
      {images && form < 1 && (
        <AbsoluteFill style={{ filter: `blur(${8 * lift}px) brightness(${1 - 0.5 * lift})`, opacity: 1 - form }}>
          <ThreeCanvas width={W} height={H}>
            <StudioEnvironment />
            <CameraLook lens={85} position={new THREE.Vector3(0, 0, PHONE.h / (2 * Math.tan(THREE.MathUtils.degToRad(lensFov(85)) / 2) * fraction))} target={new THREE.Vector3(0, 0, 0)} />
            <Phone3D yaw={0} screen={screen.texture} screenOn={1} />
          </ThreeCanvas>
        </AbsoluteFill>
      )}
      {/* The Studio pane. */}
      {form > 0 && (
        <div
          style={{
            position: "absolute",
            left: paneX,
            top: paneY,
            width: 900,
            height: cropH,
            borderRadius: 44,
            overflow: "hidden",
            opacity: form,
            scale: `${(0.94 + 0.06 * form) * (1 - 0.08 * recede)}`,
            filter: `blur(${8 * recede}px) brightness(${1 - 0.5 * recede})`,
            boxShadow: "0 40px 90px rgba(0,0,0,0.6)",
            maskImage: "linear-gradient(to bottom, black 88%, transparent 100%)",
            WebkitMaskImage: "linear-gradient(to bottom, black 88%, transparent 100%)",
          }}
        >
          {pane(current)}
          {next && pane(next, { clipPath: `inset(0 ${(1 - wipe) * 100}% 0 0)` })}
          {tapping && ring < 1 && (
            <div
              style={{
                position: "absolute",
                left: tapping.tap[0] * PS,
                top: tapping.tap[1] * PS,
                width: tapping.tap[2] * PS,
                height: tapping.tap[3] * PS,
                borderRadius: 26,
                border: `3px solid ${C.peach}`,
                boxShadow: "0 0 24px 4px rgba(255,224,204,0.55)",
                scale: `${1 + 0.1 * ring}`,
                opacity: 0.95 * (1 - ring),
              }}
            />
          )}
        </div>
      )}
      {next && <Seam x={paneX + 900 * wipe} top={paneY} height={cropH} spread={0.5} intensity={Math.sin(Math.PI * wipe)} />}
      {/* The lifted widget, until it has become the Studio's preview. */}
      {form < 1 && (
        <Img
          src={staticFile(heroWidget(U, MACROS.index))}
          style={{ position: "absolute", left: widgetRect[0], top: widgetRect[1], width: widgetRect[2], height: widgetRect[3], opacity: 1 - form * 0.9, filter: `drop-shadow(0 30px 60px rgba(0,0,0,${0.6 * (1 - form)}))` }}
        />
      )}
      {/* What each section holds (Faits vérifiés): 16 complete themes, 57 styles, 14 palettes. */}
      {(["Theme", "Style", "Colours"] as const).map((s) => {
        const r = sectionNow(s);
        const label = { Theme: "16 themes", Style: "57 styles", Colours: "14 palettes" }[s];
        return r ? <Callout key={s} label={label} at={[AXIS, paneY - 6]} labelY={paneY - 70} from={r.from} to={Math.min(r.to, end - 64)} /> : null;
      })}
      {words && (
        <SplitText from={end - 58} exitAt={end - 12} top={1250} height={160}>
          <span style={type.hero}>Make it yours.</span>
        </SplitText>
      )}
      <Grain />
    </AbsoluteFill>
  );
};
