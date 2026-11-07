// Template C « Top 3 »: a big hook, then one numbered widget per shot on a light background, end on the full Home Screen.
import React from "react";
import { AbsoluteFill, Audio, interpolate, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Caption, clamp, FONT, FPS, out, PremiumTag, Rect, Screen, WidgetCut } from "./lib";

export type ItemC = { label: string; rect: Rect };
export type SpecC = {
  id: string;
  template: "C";
  music?: string;
  /** The Home Screen capture the widgets are cut from, and shown whole at the end. */
  source: string;
  premium?: boolean;
  hook: { title: string; subtitle: string; note?: string; dur: number };
  items: ItemC[];
  itemDur: number;
  end: { focusY?: number; caption: string; sub: string; dur: number };
};

const CREAM = "#F6F3EC";
const INK = "#141418";
const BLUE = "#1D4E9E";

const text = (size: number, weight: number, color = INK): React.CSSProperties => ({
  fontFamily: FONT,
  fontWeight: weight,
  fontSize: size,
  color,
  textAlign: "center",
  fontVariationSettings: `"opsz" ${size >= 60 ? 32 : 14}`,
  lineHeight: 1.1,
});

const Hook: React.FC<{ hook: SpecC["hook"] }> = ({ hook }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const a = spring({ frame: f, fps, config: { damping: 13, stiffness: 180 } });
  const b = spring({ frame: f - 8, fps, config: { damping: 15, stiffness: 160 } });
  const c = interpolate(f, [18, 26], [0, 1], clamp);
  return (
    <AbsoluteFill style={{ background: CREAM, alignItems: "center", justifyContent: "center", paddingBottom: 260 }}>
      <div style={{ ...text(150, 900), transform: `scale(${1.25 - 0.25 * a})`, opacity: Math.min(1, a * 2) }}>{hook.title}</div>
      <div style={{ ...text(76, 700), marginTop: 24, transform: `translateY(${(1 - b) * 40}px)`, opacity: b }}>{hook.subtitle}</div>
      {hook.note && <div style={{ ...text(48, 500, "#6E6E74"), marginTop: 70, opacity: c }}>{hook.note}</div>}
    </AbsoluteFill>
  );
};

const Item: React.FC<{ n: number; item: ItemC; source: string; premium?: boolean }> = ({ n, item, source, premium }) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  const num = spring({ frame: f, fps, config: { damping: 12, stiffness: 200 } });
  const lab = interpolate(f, [4, 12], [0, 1], { ...clamp, easing: out });
  const card = spring({ frame: f - 6, fps, config: { damping: 14, stiffness: 140 } });
  const float = Math.sin(f / 14) * 6;
  const medium = item.rect[2] > 600;
  const width = medium ? 920 : 620;
  return (
    <AbsoluteFill style={{ background: CREAM, alignItems: "center" }}>
      <div style={{ ...text(230, 900, BLUE), marginTop: 190, transform: `translateY(${(1 - num) * -90}px)`, opacity: Math.min(1, num * 2) }}>{n}</div>
      <div style={{ ...text(80, 700), marginTop: 30, opacity: lab, transform: `translateY(${(1 - lab) * 20}px)` }}>{item.label}</div>
      <div
        style={{
          marginTop: 110,
          transform: `translateY(${(1 - card) * 420 + float}px) scale(${0.9 + 0.1 * card})`,
          filter: "drop-shadow(0 30px 40px rgba(0,0,0,0.22))",
        }}
      >
        <WidgetCut src={source} rect={item.rect} width={width} />
      </div>
      {premium && <PremiumTag y={1500} />}
    </AbsoluteFill>
  );
};

const End: React.FC<{ spec: SpecC }> = ({ spec }) => {
  const f = useCurrentFrame();
  const z = interpolate(f, [0, 20], [1.14, 1], { ...clamp, easing: out });
  return (
    <AbsoluteFill>
      <Screen src={spec.source} focusY={spec.end.focusY ?? 0.4} zoom={z} drift={0.01} />
      <Caption text={spec.end.caption} y={1280} at={10} size={62} />
      <Caption text={spec.end.sub} y={1470} at={18} size={46} />
      {spec.premium && <PremiumTag y={1200} />}
    </AbsoluteFill>
  );
};

export const TemplateC: React.FC<{ spec: SpecC }> = ({ spec }) => {
  const { durationInFrames } = useVideoConfig();
  const hook = Math.round(spec.hook.dur * FPS);
  const item = Math.round(spec.itemDur * FPS);
  const endAt = hook + item * spec.items.length;
  return (
    <AbsoluteFill style={{ background: CREAM }}>
      <Sequence durationInFrames={hook}>
        <Hook hook={spec.hook} />
      </Sequence>
      {spec.items.map((it, i) => (
        <Sequence key={i} from={hook + i * item} durationInFrames={item}>
          <Item n={i + 1} item={it} source={spec.source} premium={spec.premium} />
        </Sequence>
      ))}
      <Sequence from={endAt} durationInFrames={Math.round(spec.end.dur * FPS)}>
        <End spec={spec} />
      </Sequence>
      <Audio
        src={staticFile(spec.music ?? "lifestyle/music.wav")}
        volume={(fr) => interpolate(fr, [0, 6, durationInFrames - 18, durationInFrames], [0, 0.9, 0.9, 0], clamp)}
      />
    </AbsoluteFill>
  );
};
