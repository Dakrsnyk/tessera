import { Composition, registerRoot } from "remotion";
import { createElement } from "react";
import { OrgFitness, ORG_FITNESS_LENGTH } from "./Film";

registerRoot(() => createElement(Composition, { id: "OrgFitness", component: OrgFitness, durationInFrames: ORG_FITNESS_LENGTH, fps: 60, width: 1080, height: 1920 }));
