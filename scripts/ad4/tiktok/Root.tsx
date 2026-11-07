// TikTok ads (chantier 19.15). Own entry point (index.ts), separate from the campaign films' Root.
import React from "react";
import { Composition } from "remotion";
import { FPS, H, W } from "./lib";
import { A_WIDGETS, C_WIDGETS, J1_FULL, J2_PHONE, J3_PHOTO, W1_WORKOUT } from "./specs";
import { SpecA, TemplateA } from "./TemplateA";
import { lengthC, SpecC, TemplateC } from "./TemplateC";
import { lengthJ, SpecJ, TemplateJ } from "./TemplateJ";
import { lengthW, SpecW, TemplateW } from "./TemplateW";

const lenA = (s: SpecA) => s.shots.reduce((a, x) => a + Math.round(x.dur * FPS), 0);

const A: React.FC<{ spec: SpecA }> = ({ spec }) => <TemplateA spec={spec} />;
const C: React.FC<{ spec: SpecC }> = ({ spec }) => <TemplateC spec={spec} />;
const J: React.FC<{ spec: SpecJ }> = ({ spec }) => <TemplateJ spec={spec} />;
const Wk: React.FC<{ spec: SpecW }> = ({ spec }) => <TemplateW spec={spec} />;

export const TikTokRoot: React.FC = () => (
  <>
    {[A_WIDGETS].map((s) => (
      <Composition key={s.id} id={s.id} component={A} durationInFrames={lenA(s)} fps={FPS} width={W} height={H} defaultProps={{ spec: s }} />
    ))}
    {[C_WIDGETS].map((s) => (
      <Composition key={s.id} id={s.id} component={C} durationInFrames={lengthC(s)} fps={FPS} width={W} height={H} defaultProps={{ spec: s }} />
    ))}
    {[J1_FULL, J2_PHONE, J3_PHOTO].map((s) => (
      <Composition key={s.id} id={s.id} component={J} durationInFrames={lengthJ(s)} fps={FPS} width={W} height={H} defaultProps={{ spec: s }} />
    ))}
    {[W1_WORKOUT].map((s) => (
      <Composition key={s.id} id={s.id} component={Wk} durationInFrames={lengthW(s)} fps={FPS} width={W} height={H} defaultProps={{ spec: s }} />
    ))}
  </>
);
