// The ads themselves: one entry = one TikTok. A new ad is a new entry (captures by name, texts, durations).
import type { SpecA } from "./TemplateA";
import type { SpecC } from "./TemplateC";

/** Widget rectangles on the real Home Screens (px of the 1206 x 2622 capture, src/lib/kit.ts of the campaign). */
const MACROS: [number, number, number, number] = [57, 204, 1092, 510];
const NEXTSET_M: [number, number, number, number] = [57, 813, 1092, 510];
const SMALL_L: [number, number, number, number] = [57, 813, 510, 510];
const SMALL_R: [number, number, number, number] = [638, 813, 510, 510];

export const A_WIDGETS: SpecA = {
  id: "A-widgets",
  template: "A",
  shots: [
    { kind: "screen", src: "home-hero-aurore", focusY: 0.45, caption: "my Home Screen tracks my whole life now", captionY: 330, size: 70, premium: true, dur: 2.2 },
    { kind: "spot", src: "home-hero-aurore", rect: MACROS, caption: "calories and macros, no app to open", captionY: 1000, premium: true, dur: 2.5 },
    { kind: "spot", src: "home-hero-aurore", rect: NEXTSET_M, caption: "my next set, right there", captionY: 320, premium: true, dur: 2.5 },
    { kind: "screen", src: "app-finances-s00", focusY: 0.42, caption: "and what's left of my budget", captionY: 300, dur: 2.6 },
    { kind: "end", src: "home-hero-aurore", caption: "it's called Ardane", sub: "coming soon on the App Store", dur: 2.4 },
  ],
};

export const C_WIDGETS: SpecC = {
  id: "C-widgets",
  template: "C",
  source: "home-free3",
  hook: { title: "3 widgets", subtitle: "I check 20 times a day", note: "(no app to open)", dur: 2.2 },
  items: [
    { label: "Calories & macros", rect: MACROS },
    { label: "Next set", rect: SMALL_L },
    { label: "Today's top 3", rect: SMALL_R },
  ],
  itemDur: 2.4,
  end: { focusY: 0.4, caption: "all 3 come from one app: Ardane", sub: "coming soon on the App Store", dur: 2.6 },
};
