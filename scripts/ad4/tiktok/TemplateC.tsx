// Template C « Top 3 » (v2, 2026-11-06): a hook, then one numbered page per theme with several widgets of different
// shapes (small, medium, Lock Screen circular / rectangular / inline, Live Activity), then a carousel of complete Home
// Screens in several widget styles and wallpapers, then the end card. Voice: the base ads' voice (vo_tiktok.py).
import React, { createContext, useContext } from "react";
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
  /** The hook as a question (hook.title), then its answer (« Meet Ardane », asked on 2026-11-08) with the app icon and `sub`. */
  answer?: { text: string; vo: string; sub?: string };
  pages: PageC[];
  styles: { homes: string[]; caption: string; caption2?: string; vo: string; premium: boolean };
  end: { line: string; sub: string; vo: string };
  /** Length of each voice line in seconds (vo/<id>.json, written by vo_tiktok.py). */
  voLen: Record<string, number>;
  /** Speed of the hook and the numbered pages, picture and voice together (1.15 asked on 2026-11-06); the carousel and the end stay at 1. */
  introSpeed?: number;
};

const CREAM = "#F6F3EC";
const INK = "#141418";
const BLUE = "#1D4E9E";
const LEAD = 0.25; // the voice starts this long after the cut

/** Playback speed of the part being drawn: every animation of the hook and the pages reads its frame through useF(). */
const Speed = createContext(1);
const useF = () => useCurrentFrame() * useContext(Speed);

/** With an answer, the question starts at once and the answer follows a short beat later; the hook keeps its former
 * length (2026-11-08: the hook improves, the ad does not get longer). */
const HOOK_LEAD = 0.1;
const HOOK_GAP = 0.1;
const HOOK_TAIL = 0.17;

/** The voice lines of a part and when each starts (s of the part's own time, before its speed). */
const voicesC = (s: SpecC, key: string, vo: string) =>
  key === "hook" && s.answer
    ? [
        { vo: s.hook.vo, at: HOOK_LEAD },
        { vo: s.answer.vo, at: HOOK_LEAD + (s.voLen[s.hook.vo] ?? 0) + HOOK_GAP },
      ]
    : [{ vo, at: LEAD }];

/** Every part of the ad with its start and length in frames (the voice sets the rhythm). */
export const timeline = (s: SpecC) => {
  const sec = (vo: string, min: number, tail: number) => Math.max(min, (s.voLen[vo] ?? 0) + LEAD + tail);
  const fast = s.introSpeed ?? 1;
  const answer = voicesC(s, "hook", s.hook.vo)[1];
  const hookSec = answer ? Math.max(2.4, answer.at + (s.voLen[answer.vo] ?? 0) + HOOK_TAIL) : sec(s.hook.vo, 2.4, 0.4);
  const parts: { key: string; vo: string; dur: number; speed: number }[] = [
    { key: "hook", vo: s.hook.vo, dur: hookSec / fast, speed: fast },
    ...s.pages.map((p, i) => ({ key: `page${i}`, vo: p.vo, dur: sec(p.vo, 3.6, 0.5) / fast, speed: fast })),
    { key: "styles", vo: s.styles.vo, dur: sec(s.styles.vo, 4.8, 1.3), speed: 1 },
    { key: "end", vo: s.end.vo, dur: sec(s.end.vo, 3.0, 0.8), speed: 1 },
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
  const f = useF();
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

/** The hook as a question and its answer (2026-11-08): the question's words punch in with the voice, then it moves up
 * and shrinks while the app icon pops, « Meet Ardane » and the ad's promise (`sub`) come in under it. */
const HookQA: React.FC<{ spec: SpecC }> = ({ spec }) => {
  const f = useF();
  const { fps } = useVideoConfig();
  const [q, a] = voicesC(spec, "hook", spec.hook.vo);
  const answer = spec.answer!;
  const qFrames = (spec.voLen[q.vo] ?? 1) * FPS;
  const at = Math.round(a.at * FPS) - 2;
  const words = spec.hook.title.split(" ");
  const word = (i: number) => {
    const t0 = q.at * FPS + (i * qFrames * 0.8) / words.length;
    return interpolate(f, [t0, t0 + 4], [0, 1], clamp);
  };
  const up = spring({ frame: f - at, fps, config: { damping: 16, stiffness: 140 } });
  const pop = spring({ frame: f - at, fps, config: { damping: 12, stiffness: 180 } });
  const sub = spring({ frame: f - at - 7, fps, config: { damping: 15, stiffness: 160 } });
  return (
    <AbsoluteFill style={{ background: CREAM }}>
      <div style={{ position: "absolute", left: 70, right: 70, top: interpolate(up, [0, 1], [640, 250]), transform: `scale(${1 - 0.22 * up})`, transformOrigin: "50% 0" }}>
        <div style={text(112, 900)}>
          {words.map((w, i) => (
            <span key={i} style={{ display: "inline-block", opacity: word(i), transform: `scale(${1.25 - 0.25 * word(i)})`, marginRight: i < words.length - 1 ? "0.26em" : 0 }}>
              {w}
            </span>
          ))}
        </div>
      </div>
      {f >= at && (
        <>
          <Img src={staticFile("store/ardane-icon.png")} style={{ position: "absolute", left: W / 2 - 115, top: 700, width: 230, height: 230, borderRadius: 52, transform: `scale(${1.3 - 0.3 * pop})`, opacity: Math.min(1, pop * 2), boxShadow: "0 24px 50px rgba(29,78,158,0.28)" }} />
          <div style={{ position: "absolute", top: 975, left: 0, right: 0, ...text(104, 900, BLUE), opacity: Math.min(1, pop * 2) }}>{answer.text}</div>
          {answer.sub && <div style={{ position: "absolute", top: 1112, left: 40, right: 40, ...text(50, 700), opacity: sub, transform: `translateY(${(1 - sub) * 30}px)` }}>{answer.sub}</div>}
        </>
      )}
    </AbsoluteFill>
  );
};

/** Pop-in of the k-th tile of a page. */
const usePop = (k: number) => {
  const f = useF();
  const { fps } = useVideoConfig();
  const s = spring({ frame: f - 8 - k * 6, fps, config: { damping: 13, stiffness: 170, mass: 0.7 } });
  return { s, float: Math.sin((f + k * 9) / 16) * 4 };
};

const WidgetTile: React.FC<{ t: Extract<Tile, { kind: "widget" }>; k: number }> = ({ t, k }) => {
  // a captured countdown runs on the real clock (one capture per second), even when the page is sped up
  const f = useCurrentFrame();
  const { s, float } = usePop(k);
  const src = t.seq ? `${t.src}-${String(Math.min(t.seq.count - 1, Math.floor((f / FPS) * t.seq.fps))).padStart(3, "0")}` : t.src;
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
  const f = useF();
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
      <Caption text={st.caption} y={110} at={4} size={70} />
      {st.caption2 && <Caption text={st.caption2} y={218} at={12} size={50} dark />}
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
  const voAt = tl.flatMap((p) =>
    voicesC(spec, p.key, p.vo).map((v) => {
      const start = p.from + Math.round((v.at * FPS) / p.speed);
      return { start, end: start + Math.round(((spec.voLen[v.vo] ?? 0) * FPS) / p.speed) };
    }),
  );
  /** 0 → 1 while the voice speaks, with 6-frame ramps so the music dips smoothly under it. */
  const duck = (fr: number) => Math.max(0, ...voAt.map((v) => interpolate(fr, [v.start - 8, v.start - 2, v.end + 2, v.end + 10], [0, 1, 1, 0], clamp)));
  return (
    <AbsoluteFill style={{ background: CREAM }}>
      {tl.map((p, i) => (
        <Sequence key={p.key} from={p.from} durationInFrames={p.frames}>
          <Speed.Provider value={p.speed}>
          {p.key === "hook" && (spec.answer ? <HookQA spec={spec} /> : <Hook hook={spec.hook} />)}
          {p.key.startsWith("page") && <Page n={i} page={spec.pages[i - 1]} />}
          {p.key === "styles" && <Styles st={spec.styles} />}
          {p.key === "end" && <End end={spec.end} />}
          </Speed.Provider>
          {voicesC(spec, p.key, p.vo).map((v) => (
            <Sequence key={v.vo} from={Math.round((v.at * FPS) / p.speed)}>
              {/* the voice is sped up with the picture (pitch kept by the renderer's time-stretch) */}
              <Audio src={staticFile(`tiktok/vo/${spec.id}-${v.vo}.wav`)} volume={1} playbackRate={p.speed} />
            </Sequence>
          ))}
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
