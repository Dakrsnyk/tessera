import { createContext, useContext } from "react";
import data from "./i18n.json";

/** Languages of the on-screen texts (voice-overs are separate files: see audioFile). */
export type Lang = "en" | "fr";
export const LANGS: Lang[] = ["en", "fr"];

type Entry = Partial<Record<Lang, string>>;
const STRINGS = data.strings as Record<string, Entry>;

// Reverse index: a plain English text is also a valid key (hook lines from cuts.json, dynamic callout names).
const BY_EN: Record<string, Entry> = {};
for (const e of Object.values(STRINGS)) if (e.en) BY_EN[e.en] = e;

export const translate = (lang: Lang, key: string): string => {
  const e = STRINGS[key] ?? BY_EN[key];
  return e?.[lang] ?? e?.en ?? key;
};

export const LangContext = createContext<Lang>("en");

/** `const t = useT(); t("close.cta")`. */
export const useT = () => {
  const lang = useContext(LangContext);
  return (key: string) => translate(lang, key);
};
export const useLang = () => useContext(LangContext);

/**
 * The film's mix: English is audio/mix-<film>.wav (the existing files), other languages audio/<lang>/mix-<film>.wav.
 * The render script falls back to English when the file of that language does not exist yet.
 */
export const audioFile = (lang: Lang, film: string) => (lang === "en" ? `audio/mix-${film}.wav` : `audio/${lang}/mix-${film}.wav`);

/** Inline translated text: `<Tr>Make it yours.</Tr>` (the English text is the key). */
export const Tr: React.FC<{ children: string }> = ({ children }) => {
  const lang = useContext(LangContext);
  return <>{translate(lang, children)}</>;
};
