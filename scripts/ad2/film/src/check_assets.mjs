// check_assets: lists the captures the 2026 films ask for (by name, through lib/kit.ts) and where each one comes from.
//   node src/check_assets.mjs [--strict] [--lang fr|en]      (from the film project; or: python scripts/ad2/render_all.py check-assets)
// For each name and language: "new" (public/kit2026/<lang>/), "other-lang" (the other language of kit2026), "alt" (a declared
// alternative or legacy alias), "old" (public/kit/, the old kit) or "MISSING" (the film shows a stand-in « à capturer »).
// --strict exits 1 while something is missing or only served by the old kit.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SRC = path.join(ROOT, "src");
const PUB = path.join(ROOT, "public");
const args = process.argv.slice(2);
const strict = args.includes("--strict");
const langs = args.includes("--lang") ? [args[args.indexOf("--lang") + 1]] : ["fr", "en"];

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]));
const kitText = fs.readFileSync(path.join(SRC, "lib", "kit.ts"), "utf8");
const literal = (name) => {
  const m = kitText.match(new RegExp(`const ${name}[^=]*= (\\{[\\s\\S]*?\\n\\});`));
  return m ? new Function(`return (${m[1]})`)() : {};
};
const LEGACY = literal("LEGACY");
const ALTERNATIVES = literal("ALTERNATIVES");

const has = (rel) => fs.existsSync(path.join(PUB, rel));
const other = (l) => (l === "fr" ? "en" : "fr");
const resolve = (name, lang) => {
  const names = [name, ...(LEGACY[name] ? [LEGACY[name]] : []), ...(ALTERNATIVES[name] ?? [])];
  for (const [i, n] of names.entries()) {
    if (has(`kit2026/${lang}/${n}.png`)) return i === 0 ? "new" : `alt:${n}`;
    if (has(`kit2026/${other(lang)}/${n}.png`)) return i === 0 ? "other-lang" : `alt:${n}`;
  }
  for (const n of names) if (has(`kit/${n}.png`)) return n === name ? "old" : `alt:${n}(old)`;
  return "MISSING";
};

// Every string literal that looks like the name of a capture, in every source file (the compositions pass names, not paths).
const FAMILY =
  "home|lock|app|scan|studio|wall|macros|calories|nextSet|budgetLeft|weekView|priorities|habitStreak|habits|upNext|timetable|quickExpense|quickFood|spendingByCategory|moneyDashboard|todaysWorkout|trainingStreak|restTimer|mywidgets|myday|nutrition|profile|live|demo|setup|icons|session|plan|hab|lib|ex|nut";
const re = new RegExp(`["'\`](?:kit/)?((?:${FAMILY})(?:-[\\w.]+)*)(?:\\.png)?["'\`]`, "g");
const BARE = new Set(["studio", "nutrition", "habits", "plan", "lib", "ex", "nut", "hab", "session", "profile", "live", "demo", "setup", "icons", "app", "scan", "home", "lock", "wall"]);
const seen = new Map();
for (const file of walk(SRC).filter((f) => /\.(tsx?|ts)$/.test(f) && !/kit\.ts$/.test(f))) {
  const text = fs.readFileSync(file, "utf8");
  for (const m of text.matchAll(re)) {
    const name = m[1].replace(/\.png$/, "");
    if (/\.(tsx?|json)$/.test(name) || name.includes("${") || BARE.has(name)) continue;
    if (!seen.has(name)) seen.set(name, new Set());
    seen.get(name).add(path.relative(SRC, file).replace(/\\/g, "/"));
  }
}
// image sequences (demo-…-dark, live-…-night/real): the base name stands for NNNN / NNN files
const seq = (n) => /^(demo-|live-(rest|afterset)-)/.test(n) && !/\d$/.test(n) && !/(light|clear|paused|ready)$/.test(n);
const firstOf = (n) => (n.startsWith("demo-") ? `${n}-0000` : `${n}-000`);

const rows = [];
for (const [name, files] of [...seen].sort(([a], [b]) => a.localeCompare(b))) {
  const probe = seq(name) ? firstOf(name) : name;
  const res = langs.map((l) => resolve(probe, l));
  rows.push({ name: seq(name) ? `${name}-<seq>` : name, res, files: [...files] });
}
const bad = (r) => r === "MISSING";
const old = (r) => r === "old" || r.endsWith("(old)");
const width = Math.max(...rows.map((r) => r.name.length)) + 2;
console.log(`check_assets: ${rows.length} capture names asked for in src/ (languages: ${langs.join(", ")})\n`);
for (const r of rows) console.log(`${r.name.padEnd(width)}${r.res.map((x, i) => `${langs[i]}:${x}`).join("  ")}`);
const missing = rows.filter((r) => r.res.some(bad));
const onlyOld = rows.filter((r) => !r.res.some(bad) && r.res.some(old));
console.log(`\nMISSING in the new kit AND the old one (stand-in frame « à capturer »): ${missing.length}`);
for (const r of missing) console.log(`  ${r.name}   (${langs.map((l, i) => `${l}:${r.res[i]}`).join(" ")})   used by ${r.files.join(", ")}`);
console.log(`\nServed by the old kit only (works, but corail / old data until public/kit2026/<lang>/ has it): ${onlyOld.length}`);
console.log(onlyOld.map((r) => r.name).join(", "));
if (strict && (missing.length || onlyOld.length)) process.exit(1);
