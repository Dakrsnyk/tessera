import { Composition, registerRoot } from "remotion";
import { createElement } from "react";
import { OrgPlanning, ORG_PLANNING_LENGTH } from "./Film";

registerRoot(() => createElement(Composition, { id: "OrgPlanning", component: OrgPlanning, durationInFrames: ORG_PLANNING_LENGTH, fps: 60, width: 1080, height: 1920 }));
