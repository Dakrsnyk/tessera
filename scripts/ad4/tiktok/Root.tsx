// TikTok ads (chantier 19.15). Own entry point (index.ts), separate from the campaign films' Root.
import React from "react";
import { Composition } from "remotion";
import { FPS, H, W } from "./lib";
import { A_WIDGETS, C_WIDGETS } from "./specs";
import { SpecA, TemplateA } from "./TemplateA";
import { lengthC, SpecC, TemplateC } from "./TemplateC";

const lenA = (s: SpecA) => s.shots.reduce((a, x) => a + Math.round(x.dur * FPS), 0);

const A: React.FC<{ spec: SpecA }> = ({ spec }) => <TemplateA spec={spec} />;
const C: React.FC<{ spec: SpecC }> = ({ spec }) => <TemplateC spec={spec} />;

export const TikTokRoot: React.FC = () => (
  <>
    {[A_WIDGETS].map((s) => (
      <Composition key={s.id} id={s.id} component={A} durationInFrames={lenA(s)} fps={FPS} width={W} height={H} defaultProps={{ spec: s }} />
    ))}
    {[C_WIDGETS].map((s) => (
      <Composition key={s.id} id={s.id} component={C} durationInFrames={lengthC(s)} fps={FPS} width={W} height={H} defaultProps={{ spec: s }} />
    ))}
  </>
);
