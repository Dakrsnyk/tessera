import type { Lang } from "../lib/i18n";
import available from "./available.json";

// Campaign 2026 captures: the new kit (public/kit2026/<lang>/<name>.png) first, then the old one (public/kit/<name>.png).
// available.json is written by `render_all.py index` (it lists the files of both kits), so a missing capture is known
// at render time and drawn as a labelled placeholder instead of failing the render.
const AV = available as { kit: string[]; kit2026: Record<string, string[]> };
const OLD = new Set(AV.kit);
const NEW: Record<string, Set<string>> = Object.fromEntries(Object.entries(AV.kit2026).map(([l, v]) => [l, new Set(v)]));

/** Path (for staticFile) of a capture by name (no extension), or null when no kit has it. */
export const kitSrc26 = (name: string, lang: Lang = "fr"): string | null => {
  if (NEW[lang]?.has(name)) return `kit2026/${lang}/${name}.png`;
  if (OLD.has(name)) return `kit/${name}.png`;
  return null;
};
