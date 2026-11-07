// The « student » ad (2026-11-06), school-notebook style: lined paper, tape, yellow highlighter, blue-pen doodles.
// The paper schedule is the app's own sample timetable (Shared/Data/SampleData.swift: 4 courses, 3 slots a day, 15 slots);
// the import screens are rebuilt on the 1206 x 2622 grid with the app's real English texts (Localizable.xcstrings,
// App/Screens/MiniApps/Planning/ScheduleImportView.swift); every other screen is a real capture.
import React from "react";
import { Img, interpolate, spring } from "remotion";
import { cap, clamp, FONT, out } from "../lib";
import { CH, CW, Tap } from "./Screens";

export const PAPER = "#FBF8F0";
const LINE = "#C9D8EE";
const MARGIN = "#E9A3A3";
export const PEN = "#2747A8";
/** Planning is blue: its highlighter is cyan (rule of 2026-11-06: each ad in its mini-app's colours). */
export const HIGHLIGHT = "rgba(64,214,232,0.75)";
const ACCENT = "#3366FF";
const GREY = "#7C838E";
const INK = "#10151C";

// ------------------------------------------------------------------------------------------------ notebook
export const Notebook: React.FC = () => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      background: `linear-gradient(90deg, transparent 138px, ${MARGIN} 138px, ${MARGIN} 142px, transparent 142px), repeating-linear-gradient(180deg, ${PAPER} 0px, ${PAPER} 62px, ${LINE} 62px, ${LINE} 64px)`,
      backgroundColor: PAPER,
    }}
  />
);

export const Tape: React.FC<{ x: number; y: number; w?: number; rot?: number }> = ({ x, y, w = 190, rot = -8 }) => (
  <div style={{ position: "absolute", left: x, top: y, width: w, height: 62, background: "rgba(236,226,196,0.78)", transform: `rotate(${rot}deg)`, boxShadow: "0 2px 6px rgba(0,0,0,0.08)" }} />
);

/** A word or two in marker style: Inter Black with a yellow highlighter stroke that sweeps in. */
export const Marker: React.FC<{ text: string; f: number; at?: number; y: number; size?: number; rot?: number }> = ({ text, f, at = 0, y, size = 92, rot = -2 }) => {
  const sweep = interpolate(f, [at, at + 10], [0, 1], { ...clamp, easing: out });
  const o = interpolate(f, [at, at + 4], [0, 1], clamp);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: y, display: "flex", justifyContent: "center", transform: `rotate(${rot}deg)`, opacity: o }}>
      <div style={{ position: "relative", padding: "0 18px" }}>
        <div style={{ position: "absolute", left: 0, top: size * 0.42, height: size * 0.62, width: `${sweep * 100}%`, background: HIGHLIGHT, borderRadius: 8 }} />
        <div style={{ position: "relative", fontFamily: FONT, fontWeight: 900, fontSize: size, color: INK, whiteSpace: "nowrap", fontVariationSettings: `"opsz" 32` }}>{text}</div>
      </div>
    </div>
  );
};

/** A hand-drawn blue-pen stroke (SVG path) that draws itself. */
export const Doodle: React.FC<{ d: string; f: number; at: number; dur?: number; w?: number; h?: number; x?: number; y?: number; width?: number }> = ({ d, f, at, dur = 12, w = 1080, h = 1920, x = 0, y = 0, width = 9 }) => {
  const p = interpolate(f, [at, at + dur], [0, 1], { ...clamp, easing: out });
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ position: "absolute", left: x, top: y, overflow: "visible" }}>
      <path d={d} fill="none" stroke={PEN} strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" pathLength={1} strokeDasharray="1" strokeDashoffset={1 - p} />
    </svg>
  );
};

export const PenNote: React.FC<{ text: string; x: number; y: number; f: number; at: number; rot?: number; size?: number }> = ({ text, x, y, f, at, rot = -4, size = 50 }) => (
  <div style={{ position: "absolute", left: x, top: y, transform: `rotate(${rot}deg)`, fontFamily: FONT, fontWeight: 800, fontSize: size, color: PEN, opacity: interpolate(f, [at, at + 6], [0, 1], clamp), whiteSpace: "nowrap" }}>{text}</div>
);

// ------------------------------------------------------------------------------------------------ the paper schedule
const MATH = "Math";
const BIO = "Biology";
const HIS = "History";
const ENG = "English";
const ROWS = [
  { time: "08:30\n10:20", cells: [[MATH, "B-204"], [BIO, "Lab 3"], [HIS, "A-110"], [ENG, "C-015"], [MATH, "B-204"]] },
  { time: "13:00\n14:50", cells: [[BIO, "Lab 3"], [ENG, "C-015"], [MATH, "B-204"], [HIS, "A-110"], [BIO, "Lab 1"]] },
  { time: "15:00\n16:20", cells: [[HIS, "A-110"], [MATH, "B-204"], [ENG, "C-015"], [BIO, "Lab 3"], [ENG, "C-015"]] },
];
const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri"];

export const PaperSchedule: React.FC<{ w?: number }> = ({ w = 860 }) => {
  const k = w / 860;
  const cell = (n: number) => n * k;
  return (
    <div style={{ width: w, padding: cell(40), boxSizing: "border-box", background: "#FFFFFF", boxShadow: "0 18px 40px rgba(0,0,0,0.18)", fontFamily: FONT, color: "#1B1B1B" }}>
      <div style={{ fontSize: cell(26), fontWeight: 700, letterSpacing: 3, color: "#555" }}>FALL 2026</div>
      <div style={{ fontSize: cell(44), fontWeight: 800, marginBottom: cell(24) }}>Class schedule</div>
      <div style={{ display: "grid", gridTemplateColumns: `${cell(120)}px repeat(5, 1fr)`, border: "2px solid #333" }}>
        <div style={{ borderRight: "2px solid #333", borderBottom: "2px solid #333" }} />
        {DAYS.map((d) => (
          <div key={d} style={{ textAlign: "center", fontWeight: 800, fontSize: cell(28), padding: `${cell(12)}px 0`, borderRight: "1px solid #999", borderBottom: "2px solid #333", background: "#EFEFEF" }}>{d}</div>
        ))}
        {ROWS.map((r) => (
          <React.Fragment key={r.time}>
            <div style={{ whiteSpace: "pre", textAlign: "center", fontSize: cell(24), fontWeight: 700, padding: `${cell(26)}px 0`, borderRight: "2px solid #333", borderBottom: "1px solid #999", lineHeight: 1.3 }}>{r.time}</div>
            {r.cells.map(([c, room], i) => (
              <div key={i} style={{ textAlign: "center", padding: `${cell(22)}px ${cell(4)}px`, borderRight: "1px solid #999", borderBottom: "1px solid #999" }}>
                <div style={{ fontWeight: 700, fontSize: cell(26) }}>{c}</div>
                <div style={{ fontSize: cell(22), color: "#555", marginTop: cell(6) }}>{room}</div>
              </div>
            ))}
          </React.Fragment>
        ))}
      </div>
      <div style={{ fontSize: cell(20), color: "#777", marginTop: cell(18) }}>Exams: Biology midterm, Gym · Math final, B-204</div>
    </div>
  );
};

// ------------------------------------------------------------------------------------------------ import screens (rebuilt)
const StatusBar: React.FC = () => <Img src={cap("app-planning-s04")} style={{ position: "absolute", left: 0, top: 0, width: CW, height: CH, clipPath: "inset(0 0 2480px 0)" }} />;

const Nav: React.FC<{ title: string }> = ({ title }) => (
  <>
    <div style={{ position: "absolute", left: 60, top: 196, fontFamily: FONT, fontSize: 48, color: ACCENT }}>Cancel</div>
    <div style={{ position: "absolute", left: 0, right: 0, top: 196, textAlign: "center", fontFamily: FONT, fontWeight: 700, fontSize: 50, color: INK }}>{title}</div>
  </>
);

const Section: React.FC<{ y: number; title: string }> = ({ y, title }) => (
  <div style={{ position: "absolute", left: 60, top: y, display: "flex", alignItems: "center", gap: 20 }}>
    <div style={{ width: 9, height: 56, borderRadius: 5, background: ACCENT }} />
    <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 54, color: INK }}>{title}</div>
  </div>
);

const Button: React.FC<{ y: number; label: string; prominent?: boolean; h?: number }> = ({ y, label, prominent = true, h = 132 }) => (
  <div
    style={{
      position: "absolute",
      left: 60,
      top: y,
      width: CW - 120,
      height: h,
      borderRadius: h / 2,
      background: prominent ? ACCENT : "#E6ECFF",
      color: prominent ? "#fff" : ACCENT,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: FONT,
      fontWeight: 700,
      fontSize: 50,
    }}
  >
    {label}
  </div>
);

const SLOTS = ROWS[0].cells.map((c, i) => ({ title: c[0], day: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"][i], time: "08:30 – 10:20", room: c[1] })).concat(
  ROWS[1].cells.slice(0, 2).map((c, i) => ({ title: c[0], day: ["Monday", "Tuesday"][i], time: "13:00 – 14:50", room: c[1] })),
);

/** The import, frame by frame (30 fps): start sheet → « Reading your schedule… » → review → added. */
export const ImportFlow: React.FC<{ f: number; fps: number }> = ({ f, fps }) => {
  const READ = 26;
  const REVIEW = 54;
  const ADDED = 132;
  const bg = "#F2F2F7";
  if (f < READ) {
    return (
      <div style={{ position: "absolute", width: CW, height: CH, background: bg }}>
        <StatusBar />
        <Nav title="Import my schedule" />
        <Section y={380} title="Your schedule" />
        <div style={{ position: "absolute", left: 60, right: 60, top: 480, fontFamily: FONT, fontSize: 44, lineHeight: 1.35, color: GREY }}>
          Choose a clear photo or a PDF of your class schedule. It is read on your iPhone: nothing is sent.
        </div>
        <Button y={720} label="Choose a photo" />
        <Button y={880} label="Choose a PDF" prominent={false} />
        <div style={{ position: "absolute", left: 60, right: 60, top: 1060, fontFamily: FONT, fontSize: 38, lineHeight: 1.35, color: GREY }}>
          You can check and correct each class before adding it. Nothing changes without your approval.
        </div>
        <Tap f={f} at={18} x={603} y={786} />
      </div>
    );
  }
  if (f < REVIEW) {
    const spin = (f * 12) % 360;
    return (
      <div style={{ position: "absolute", width: CW, height: CH, background: bg }}>
        <StatusBar />
        <Nav title="Import my schedule" />
        <svg width="140" height="140" viewBox="0 0 58 58" style={{ position: "absolute", left: 533, top: 1050, transform: `rotate(${spin}deg)` }}>
          <circle cx="29" cy="29" r="22" fill="none" stroke="rgba(51,102,255,0.18)" strokeWidth="6" />
          <path d="M29 7 A22 22 0 0 1 51 29" fill="none" stroke={ACCENT} strokeWidth="6" strokeLinecap="round" />
        </svg>
        <div style={{ position: "absolute", left: 0, right: 0, top: 1240, textAlign: "center", fontFamily: FONT, fontWeight: 700, fontSize: 52, color: INK }}>Reading your schedule…</div>
        <div style={{ position: "absolute", left: 0, right: 0, top: 1320, textAlign: "center", fontFamily: FONT, fontSize: 40, color: GREY }}>This may take a few seconds.</div>
      </div>
    );
  }
  if (f < ADDED) {
    const t = f - REVIEW;
    const scroll = interpolate(t, [24, 70], [0, 520], { ...clamp, easing: out });
    return (
      <div style={{ position: "absolute", width: CW, height: CH, background: bg, overflow: "hidden" }}>
        <div style={{ position: "absolute", left: 0, top: -scroll, width: CW }}>
          <div style={{ position: "absolute", left: 60, right: 60, top: 330, fontFamily: FONT, fontSize: 42, lineHeight: 1.35, color: GREY }}>
            Check what was read, fix anything that&apos;s wrong, then add the classes to your schedule.
          </div>
          {SLOTS.map((s, i) => {
            const o = spring({ frame: t - 2 - i * 4, fps, config: { damping: 16, stiffness: 160 } });
            const doubt = i === 4;
            return (
              <div key={i} style={{ position: "absolute", left: 48, top: 520 + i * 300, width: CW - 96, height: 270, borderRadius: 48, background: "#fff", opacity: o, transform: `translateY(${(1 - o) * 50}px)`, boxShadow: "0 6px 20px rgba(40,60,90,0.08)" }}>
                <div style={{ position: "absolute", left: 40, top: 46, width: 64, height: 64, borderRadius: 32, background: ACCENT, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 40, fontWeight: 800, fontFamily: FONT }}>✓</div>
                <div style={{ position: "absolute", left: 140, top: 40, fontFamily: FONT, fontWeight: 700, fontSize: 52, color: INK }}>{s.title}</div>
                {doubt && <div style={{ position: "absolute", right: 40, top: 46, fontFamily: FONT, fontWeight: 700, fontSize: 34, color: "#C26A00", background: "#FFF1DC", padding: "8px 20px", borderRadius: 24 }}>To check</div>}
                <div style={{ position: "absolute", left: 140, top: 120, fontFamily: FONT, fontSize: 42, color: GREY }}>{s.day} · {s.time}</div>
                <div style={{ position: "absolute", left: 140, top: 184, fontFamily: FONT, fontSize: 40, color: GREY }}>Room {s.room}</div>
              </div>
            );
          })}
        </div>
        <div style={{ position: "absolute", left: 0, top: 0, width: CW, height: 300, background: bg }}>
          <StatusBar />
          <Nav title="Import my schedule" />
        </div>
        <div style={{ position: "absolute", left: 0, top: 2290, width: CW, height: 332, background: `linear-gradient(to bottom, rgba(242,242,247,0), ${bg} 30%)` }}>
          <Button y={60} label="Add to my schedule (15)" />
        </div>
        <Tap f={f} at={ADDED - 6} x={603} y={2416} />
      </div>
    );
  }
  const a = spring({ frame: f - ADDED, fps, config: { damping: 12, stiffness: 160 } });
  return (
    <div style={{ position: "absolute", width: CW, height: CH, background: bg }}>
      <StatusBar />
      <Nav title="Import my schedule" />
      <div style={{ position: "absolute", left: 503, top: 960, width: 200, height: 200, borderRadius: 100, background: "#2FA84F", color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 120, fontWeight: 900, fontFamily: FONT, transform: `scale(${a})` }}>✓</div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 1230, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 60, color: INK, opacity: a }}>15 slots added</div>
      <Button y={2290} label="Done" />
    </div>
  );
};

/** Two Home Screen pages of a student, swiped: the week (Weekly schedule) then next class / next exam (real captures). */
export const StudentHomes: React.FC<{ f: number; swipeAt: number }> = ({ f, swipeAt }) => {
  const p = interpolate(f, [swipeAt, swipeAt + 12], [0, 1], { ...clamp, easing: out });
  return (
    <div style={{ position: "absolute", width: CW, height: CH, overflow: "hidden", background: "#000" }}>
      <Img src={cap("home-profile-student")} style={{ position: "absolute", left: -p * CW, top: 0, width: CW, height: CH }} />
      <Img src={cap("home-etudes")} style={{ position: "absolute", left: (1 - p) * CW, top: 0, width: CW, height: CH }} />
    </div>
  );
};
