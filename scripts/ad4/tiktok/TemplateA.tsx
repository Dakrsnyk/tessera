// Template A « natif TikTok »: real captures in full screen, spotlight zooms on a widget, TikTok captions, hard cuts.
import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption, clamp, FPS, onScreen, out, PremiumTag, Rect, Screen, W } from "./lib";

export type ShotA =
  | { kind: "screen"; src: string; focusY?: number; caption?: string; captionY?: number; size?: number; premium?: boolean; dur: number }
  | { kind: "spot"; src: string; rect: Rect; focusY?: number; caption?: string; captionY?: number; size?: number; premium?: boolean; dur: number }
  | { kind: "end"; src: string; focusY?: number; caption: string; sub: string; dur: number };

export type SpecA = { id: string; template: "A"; music?: string; shots: ShotA[] };

const Spot: React.FC<{ shot: Extract<ShotA, { kind: "spot" }> }> = ({ shot }) => {
  const f = useCurrentFrame();
  const fy = shot.focusY ?? 0.45;
  const r = onScreen(shot.rect, fy);
  const z = interpolate(f, [0, 14], [1, 1.08], { ...clamp, easing: out });
  const dim = interpolate(f, [2, 12], [0, 0.66], clamp);
  return (
    <Screen src={shot.src} focusY={fy} zoom={z} ox={r.x + r.w / 2} oy={r.y + r.h / 2} drift={0.01}>
      {/* The spotlight: everything but the widget is dimmed (a huge shadow around the widget's rounded box). */}
      <div
        style={{
          position: "absolute",
          left: r.x,
          top: r.y,
          width: r.w,
          height: r.h,
          borderRadius: 66 * (W / 1206),
          boxShadow: `0 0 0 3000px rgba(0,0,0,${dim})`,
        }}
      />
    </Screen>
  );
};

const End: React.FC<{ shot: Extract<ShotA, { kind: "end" }> }> = ({ shot }) => {
  const f = useCurrentFrame();
  const blur = interpolate(f, [0, 10], [0, 26], clamp);
  const dark = interpolate(f, [0, 10], [0, 0.35], clamp);
  return (
    <AbsoluteFill>
      <Screen src={shot.src} focusY={shot.focusY ?? 0.45} blur={blur} drift={0.02} />
      <AbsoluteFill style={{ background: `rgba(0,0,0,${dark})` }} />
      <Caption text={shot.caption} y={760} at={6} size={76} />
      <Caption text={shot.sub} y={880} at={14} size={48} dark />
    </AbsoluteFill>
  );
};

export const TemplateA: React.FC<{ spec: SpecA }> = ({ spec }) => {
  const { durationInFrames } = useVideoConfig();
  let from = 0;
  const music = spec.music ?? "lifestyle/music.wav";
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {spec.shots.map((s, i) => {
        const d = Math.round(s.dur * FPS);
        const start = from;
        from += d;
        return (
          <Sequence key={i} from={start} durationInFrames={d}>
            {s.kind === "screen" && (
              <AbsoluteFill>
                <Screen src={s.src} focusY={s.focusY ?? 0.45} />
                {i === 0 && <AbsoluteFill style={{ background: "rgba(0,0,0,0.25)" }} />}
                {s.caption && <Caption text={s.caption} y={s.captionY ?? 320} size={s.size} />}
                {s.premium && <PremiumTag />}
              </AbsoluteFill>
            )}
            {s.kind === "spot" && (
              <AbsoluteFill>
                <Spot shot={s} />
                {s.caption && <Caption text={s.caption} y={s.captionY ?? 320} size={s.size} />}
                {s.premium && <PremiumTag />}
              </AbsoluteFill>
            )}
            {s.kind === "end" && <End shot={s} />}
          </Sequence>
        );
      })}
      <Audio
        src={staticFile(music)}
        volume={(fr) => interpolate(fr, [0, 6, durationInFrames - 18, durationInFrames], [0, 0.9, 0.9, 0], clamp)}
      />
    </AbsoluteFill>
  );
};
