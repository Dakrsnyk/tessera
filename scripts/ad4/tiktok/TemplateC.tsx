// Template C « Top 3 » (v2, 2026-11-06): a hook, then one numbered page per theme with several widgets of different
// shapes (small, medium, Lock Screen circular / rectangular / inline, Live Activity), then a carousel of complete Home
// Screens in several widget styles and wallpapers, then the end card. Voice: the base ads' voice (vo_tiktok.py).
import React from "react";
import { AbsoluteFill, Audio, Img, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption, cap, clamp, FONT, FPS, H, out, PremiumTag, W } from "./lib";

/** A real widget capture, or a piece of Lock Screen (white parts) laid on a wallpaper panel. */
export type Tile =
  | { kind: "widget"; src: string; x: number; y: number; w: number; seq?: { count: number; fps: number } }
  | { kind: "lock"; x: number; y: number; w: number; h: number; wall?: string; parts: { src: string; x: number; y: number; w: number }[] };

export type PageC = { label: string; vo: string; tiles: Tile[]; premium?: boolean };
export type SpecC = {
  id: string;
  template: "C";
  music?: string;
  hook: { title: string; subtitle: string; vo: string };
  pages: PageC[];
  styles: { homes: string[]; caption: string; vo: string; premium: boolean };
  end: { line: string; sub: string; vo: string };
  /** Length of each voice line in seconds (vo/<id>.json, written by vo_tiktok.py). */
  voLen: Record<string, number>;
};

const CREAM = "#F6F3EC";
const INK = "#141418";
const BLUE = "#1D4E9E";
const LEAD = 0.25; // the voice starts this long after the cut

/** Every part of the ad with its start and length in frames (the voice sets the rhythm). */
export const timeline = (s: SpecC) => {
  const sec = (vo: string, min: number, tail: number) => Math.max(min, (s.voLen[vo] ?? 0) + LEAD + tail);
  const parts: { key: string; vo: string; dur: number }[] = [
    { key: "hook", vo: s.hook.vo, dur: sec(s.hook.vo, 2.4, 0.4) },
    ...s.pages.map((p, i) => ({ key: `page${i}`, vo: p.vo, dur: sec(p.vo, 3.6, 0.5) })),
    { key: "styles", vo: s.styles.vo, dur: sec(s.styles.vo, 4.8, 1.3) },
    { key: "end", vo: s.end.vo, dur: sec(s.end.vo, 3.0, 0.8) },
  ];
  let from = 0;
  return parts.map((p) => {
    const d = Math.round(p.dur * FPS);
    const r = { ...p, from, frames: d };
    from += d;
    return r;
  });
};
export const lengthC = (s: SpecC) => timeline(s).reduce((a, p) => a + p.frames, 0);

const text = (size: number, weight: number, color = INK): React.CSSProperties => ({
  fontFamily: FONT,
  fontWeight: weight,
  fontSize: size,
  color,
  textAlign: "center",
  fontVariationSettings: `"opsz" ${size >= 60 ? 32 : 14}`,
  lineHeight: 1.08,
});

const Hook: React.FC<{ hook: SpecC["hook"] }> = ({ hook }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 13, stiffness: 180 } });
  const b = spring({ frame: f - 8, fps, config: { damping: 15, stiffness: 160 } });
  return (
    <AbsoluteFill style={{ background: CREAM, alignItems: "center", justifyContent: "center", paddingBottom: 300 }}>
      <div style={{ ...text(150, 900), transform: `scale(${1.25 - 0.25 * a})`, opacity: Math.min(1, a * 2) }}>{hook.title}</div>
      <div style={{ ...text(76, 700), marginTop: 26, maxWidth: 900, transform: `translateY(${(1 - b) * 40}px)`, opacity: b }}>{hook.subtitle}</div>
    </AbsoluteFill>
  );
};

/** Pop-in of the k-th tile of a page. */
const usePop = (k: number) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f - 8 - k * 6, fps, config: { damping: 13, stiffness: 170, mass: 0.7 } });
  return { s, float: Math.sin((f + k * 9) / 16) * 4 };
};

const WidgetTile: React.FC<{ t: Extract<Tile, { kind: "widget" }>; k: number }> = ({ t, k }) => {
  const f = useCurrentFrame();
  const { s, float } = usePop(k);
  const src = t.seq ? `${t.src}-${String(Math.floor((f / FPS) * t.seq.fps) % t.seq.count).padStart(3, "0")}` : t.src;
  return (
    <Img
      src={cap(src)}
      style={{
        position: "absolute",
        left: t.x,
        top: t.y,
        width: t.w,
        transform: `translateY(${(1 - s) * 80 + float}px) scale(${0.7 + 0.3 * s})`,
        opacity: Math.min(1, s * 1.5),
        filter: "drop-shadow(0 22px 30px rgba(0,0,0,0.20))",
      }}
    />
  );
};

const LockTile: React.FC<{ t: Extract<Tile, { kind: "lock" }>; k: number }> = ({ t, k }) => {
  const { s, float } = usePop(k);
  return (
    <div
      style={{
        position: "absolute",
        left: t.x,
        top: t.y,
        width: t.w,
        height: t.h,
        borderRadius: 54,
        overflow: "hidden",
        transform: `translateY(${(1 - s) * 80 + float}px) scale(${0.7 + 0.3 * s})`,
        opacity: Math.min(1, s * 1.5),
        boxShadow: "0 22px 40px rgba(0,0,0,0.22)",
      }}
    >
      <Img src={staticFile(`kit/${t.wall ?? "wall-midnight.png"}`)} style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover" }} />
      <AbsoluteFill style={{ background: "rgba(0,0,0,0.18)" }} />
      <div style={{ position: "absolute", left: 26, top: 16, ...text(22, 600, "rgba(255,255,255,0.75)"), textAlign: "left", letterSpacing: 2 }}>LOCK SCREEN</div>
      {t.parts.map((p, i) => (
        <Img key={i} src={cap(p.src)} style={{ position: "absolute", left: p.x, top: p.y, width: p.w }} />
      ))}
    </div>
  );
};

const Page: React.FC<{ n: number; page: PageC }> = ({ n, page }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const num = spring({ frame: f, fps, config: { damping: 12, stiffness: 200 } });
  const lab = interpolate(f, [3, 11], [0, 1], { ...clamp, easing: out });
  return (
    <AbsoluteFill style={{ background: CREAM }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: 100, ...text(190, 900, BLUE), transform: `translateY(${(1 - num) * -80}px)`, opacity: Math.min(1, num * 2) }}>{n}</div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 316, ...text(70, 700), opacity: lab, transform: `translateY(${(1 - lab) * 20}px)` }}>{page.label}</div>
      {page.tiles.map((t, k) => (t.kind === "widget" ? <WidgetTile key={k} t={t} k={k} /> : <LockTile key={k} t={t} k={k} />))}
      {page.premium && <PremiumTag y={1580} />}
    </AbsoluteFill>
  );
};

/** Complete Home Screens in a carousel: centre phone big, neighbours smaller; the background is the centre screen, blurred. */
const Styles: React.FC<{ st: SpecC["styles"] }> = ({ st }) => {
  const f = useCurrentFrame();
  const step = Math.round(0.68 * FPS);
  const move = Math.round(0.26 * FPS);
  const k = Math.floor(f / step);
  const local = f - k * step;
  const p = Math.min(k, st.homes.length - 1) + (k < st.homes.length - 1 ? interpolate(local, [step - move, step], [0, 1], { ...clamp, easing: out }) : 0);
  const centre = Math.round(p);
  const PH = 1180;
  const PW = Math.round((PH * 1206) / 2622);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Img src={cap(st.homes[centre])} style={{ position: "absolute", inset: -60, width: W + 120, height: H + 120, objectFit: "cover", filter: "blur(40px) brightness(0.7)" }} />
      {st.homes.map((h, i) => {
        const d = i - p;
        if (Math.abs(d) > 2.2) return null;
        const sc = 1 - Math.min(Math.abs(d), 1) * 0.24;
        return (
          <div
            key={h}
            style={{
              position: "absolute",
              left: W / 2 - PW / 2 + d * 520,
              top: 330,
              width: PW,
              height: PH,
              transform: `scale(${sc})`,
              opacity: 1 - Math.min(Math.abs(d), 1.6) * 0.35,
              zIndex: 10 - Math.round(Math.abs(d) * 3),
              borderRadius: 64,
              border: "10px solid #111114",
              overflow: "hidden",
              boxShadow: "0 40px 70px rgba(0,0,0,0.45)",
            }}
          >
            <Img src={cap(h)} style={{ width: "100%", height: "100%" }} />
          </div>
        );
      })}
      <Caption text={st.caption} y={140} at={4} size={60} />
      {st.premium && <PremiumTag y={1580} />}
    </AbsoluteFill>
  );
};

const End: React.FC<{ end: SpecC["end"] }> = ({ end }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 14, stiffness: 150 } });
  const b = interpolate(f, [10, 20], [0, 1], clamp);
  return (
    <AbsoluteFill style={{ background: `linear-gradient(180deg, #07101C 0%, #1D4E9E 100%)`, alignItems: "center" }}>
      <Img
        src={staticFile("store/ardane-icon.png")}
        style={{ position: "absolute", top: 560, left: W / 2 - 130, width: 260, height: 260, borderRadius: 58, transform: `scale(${0.8 + 0.2 * a})`, opacity: a, boxShadow: "0 30px 60px rgba(0,0,0,0.4)" }}
      />
      <div style={{ position: "absolute", top: 880, left: 0, right: 0, ...text(84, 700, "#fff"), letterSpacing: 6, opacity: a }}>ARDANE</div>
      <div style={{ position: "absolute", top: 1000, left: 0, right: 0, ...text(52, 500, "#BED0E6"), opacity: b }}>{end.line}</div>
      <div style={{ position: "absolute", top: 1150, left: 0, right: 0, ...text(40, 600, "#fff"), opacity: b }}>{end.sub}</div>
    </AbsoluteFill>
  );
};

export const TemplateC: React.FC<{ spec: SpecC }> = ({ spec }) => {
  const { durationInFrames } = useVideoConfig();
  const tl = timeline(spec);
  const voAt = tl.map((p) => ({ start: p.from + Math.round(LEAD * FPS), end: p.from + Math.round((LEAD + (spec.voLen[p.vo] ?? 0)) * FPS) }));
  /** 0 → 1 while the voice speaks, with 6-frame ramps so the music dips smoothly under it. */
  const duck = (fr: number) => Math.max(0, ...voAt.map((v) => interpolate(fr, [v.start - 8, v.start - 2, v.end + 2, v.end + 10], [0, 1, 1, 0], clamp)));
  return (
    <AbsoluteFill style={{ background: CREAM }}>
      {tl.map((p, i) => (
        <Sequence key={p.key} from={p.from} durationInFrames={p.frames}>
          {p.key === "hook" && <Hook hook={spec.hook} />}
          {p.key.startsWith("page") && <Page n={i} page={spec.pages[i - 1]} />}
          {p.key === "styles" && <Styles st={spec.styles} />}
          {p.key === "end" && <End end={spec.end} />}
          <Sequence from={Math.round(LEAD * FPS)}>
            <Audio src={staticFile(`tiktok/vo/${spec.id}-${p.vo}.wav`)} volume={1} />
          </Sequence>
        </Sequence>
      ))}
      <Audio
        src={staticFile(spec.music ?? "lifestyle/music.wav")}
        volume={(fr) =>
          interpolate(fr, [0, 6, durationInFrames - 20, durationInFrames], [0, 1, 1, 0], clamp) * (0.6 - 0.38 * duck(fr))
        }
      />
    </AbsoluteFill>
  );
};
