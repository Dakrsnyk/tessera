import { AbsoluteFill, Easing, Img, interpolate, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { eanModules, EAN } from "../components/Barcode";
import { AXIS, C, clamp, ease, H, INTER, W } from "../lib/brand";
import { asset, seqName } from "../lib/kit";
import { useT } from "../lib/i18n";
import { KineticLine } from "../v3/fx";

/**
 * A mini-app of the Ardane ecosystem: its title, the REAL full screen of the app (1206 × 2622 capture, never
 * cropped: 676 × 1470 on the 1080 × 1920 frame), one key gesture, then the widgets it gives the Home Screen.
 * The first and last 30 frames are the links: the whole page slides, the Seam crosses, the next app takes over.
 */
export type Screen = {
  at: number;
  src: string;
  /** An exercise animation played over a box of the capture (capture px), over a flat fill. */
  demo?: { name: string; count: number; box: [number, number, number, number]; fill: string; from: number };
  /** The scan: a printed barcode enters the aiming square, a line reads it. */
  scan?: { enter: number; read: number };
  /** Flat patch over a band of the capture (a label the capture still shows in French). */
  cover?: [number, number, number, number, string][];
  /** Cross through black instead of a blade (two screens never mix with cut text). */
  dip?: boolean;
};
export type WidgetDef = { src: string; w: number; top: number };
export type Cam = { at: number; cx: number; cy: number; z: number };
export type Hi = { from: number; to: number; rect: [number, number, number, number]; label: string };
export type AppDef = {
  /** Camera on the real screen (capture px of the focus, zoom): slow pushes towards the key area, depth blur elsewhere. */
  cam: Cam[];
  /** Sober highlights on the element being explained (capture px). */
  hi: Hi[];
  /** Horizontal drift of the whole phone card over the scene (px), the widgets move against it (parallax). */
  drift: [number, number];
  title: string;
  subs: { at: number; key: string }[];
  accent: string;
  length: number;
  screens: Screen[];
  widgets?: { at: number; items: WidgetDef[] };
};

const SW = 648;
const SH = 1410;
const SX = (W - SW) / 2;
const SY = 396;
const K = SW / 1206;
const BLADE = 16;

const Bars: React.FC<{ w: number; h: number }> = ({ w, h }) => {
  const bits = eanModules(EAN);
  const m = w / (bits.length + 18);
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
      {bits.split("").map((b, i) => (b === "1" ? <rect key={i} x={9 * m + i * m} y={0} width={m * 1.02} height={h - 30} fill="#111" /> : null))}
      <text x={w / 2} y={h - 6} textAnchor="middle" fontFamily={INTER} fontSize={22} fill="#111" letterSpacing="3">
        {EAN.replace(/^(\d)(\d{6})(\d{6})$/, "$1 $2 $3")}
      </text>
    </svg>
  );
};

export const MiniApp: React.FC<{ app: AppDef }> = ({ app }) => {
  const f = useCurrentFrame();
  const t = useT();
  const L = app.length;
  const inP = interpolate(f, [0, 30], [0, 1], { ...clamp, easing: ease.split });
  const outP = interpolate(f, [L - 30, L], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) });
  const dx = (1 - inP) * 170 - outP * 170;
  const wAt = app.widgets ? app.widgets.at : 99999;
  const rec = interpolate(f, [wAt - 8, wAt + 22], [0, 1], { ...clamp, easing: ease.transfer });

  // Which screen is up, which one the blade is bringing in.
  let cur = app.screens[0];
  let nxt: Screen | null = null;
  let wipe = 0;
  let wipeX = 0;
  let dipping = false;
  for (let i = 1; i < app.screens.length; i++) {
    const s = app.screens[i];
    if (f >= s.at + BLADE) cur = s;
    else if (f >= s.at) {
      nxt = s;
      wipe = interpolate(f, [s.at, s.at + BLADE], [0, 1], { easing: Easing.bezier(0.45, 0, 0.2, 1) });
      wipeX = wipe;
      dipping = !!s.dip;
    }
  }
  const settle = interpolate(f, [4, 40], [0, 1], { ...clamp, easing: ease.arrival });
  const camEase = Easing.bezier(0.45, 0, 0.2, 1);
  const ats = app.cam.map((c) => c.at);
  const z = interpolate(f, ats, app.cam.map((c) => c.z), { ...clamp, easing: camEase });
  const ccx = interpolate(f, ats, app.cam.map((c) => c.cx), { ...clamp, easing: camEase });
  const ccy = interpolate(f, ats, app.cam.map((c) => c.cy), { ...clamp, easing: camEase });
  const zf = Math.min(1, Math.max(0, (z - 1) / 0.25)) * (1 - rec);
  // Camera push: the whole card scales about the focus point (never cropped sideways), the focus drifts to the middle.
  const g = Math.min(1, Math.max(0, (z - 1) / 0.25)) * (1 - rec);
  const fx = SX + ccx * K;
  const fy = SY + ccy * K;
  let cdx = (W / 2 - fx) * g;
  const left = fx + (SX - fx) * z + cdx;
  const right = left + SW * z;
  if (left < 66) cdx += 66 - left;
  if (right > W - 66) cdx -= right - (W - 66);
  let cdy = (H / 2 - 40 - fy) * g;
  // The whole screen must stay in the frame at the end of every push (nothing important leaves it, margins ~5 %).
  const topY = fy + (SY - fy) * z + cdy;
  if (topY < 104) cdy += 104 - topY;
  const botY = fy + (SY + SH - fy) * z + cdy;
  if (botY > H - 104) cdy -= botY - (H - 104);
  const toStageX = (cx0: number) => fx + (SX + cx0 - fx) * z + cdx;
  const toStageY = (cy0: number) => fy + (SY + cy0 - fy) * z + cdy;
  const drift = interpolate(f, [0, L], app.drift) * (1 - rec * 0.5);
  const bob = Math.sin(f / 46) * 7;
  const activeHi = app.hi.find((h) => f >= h.from - 6 && f <= h.to + 6) ?? null;
  const hiP = activeHi ? interpolate(f, [activeHi.from, activeHi.from + 12, activeHi.to - 10, activeHi.to], [0, 1, 1, 0], { ...clamp, easing: ease.split }) : 0;
  const mc = activeHi ? [(activeHi.rect[0] + activeHi.rect[2] / 2) * K, (activeHi.rect[1] + activeHi.rect[3] / 2) * K, activeHi.rect[2] * K * 0.62 + 70, activeHi.rect[3] * K * 0.62 + 70] : [ccx * K, ccy * K, 260, 260];
  const mask = `radial-gradient(ellipse ${mc[2]}px ${mc[3]}px at ${mc[0]}px ${mc[1]}px, #000 62%, rgba(0,0,0,${1 - 0.93 * zf}) 100%)`;
  const ry = interpolate(f, [0, L], [-5, 5]) + (1 - inP) * 14 - outP * 14;
  const sub = [...app.subs].reverse().find((s) => f >= s.at) ?? app.subs[0];
  const subIdx = app.subs.indexOf(sub);
  const subP = interpolate(f, [sub.at, sub.at + 14], [0, 1], { ...clamp, easing: ease.split });

  const renderScreen = (s: Screen, clip?: string) => (
    <div style={{ position: "absolute", inset: 0, clipPath: clip }}>
      <Img src={asset(s.src)} style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH }} />
      {s.cover && s.cover.map((c, i) => <div key={i} style={{ position: "absolute", left: c[0] * K, top: c[1] * K, width: c[2] * K, height: c[3] * K, background: c[4] }} />)}
      {s.demo && f >= s.demo.from - 6 && (
        <div
          style={{
            position: "absolute",
            left: s.demo.box[0] * K,
            top: s.demo.box[1] * K,
            width: s.demo.box[2] * K,
            height: s.demo.box[3] * K,
            borderRadius: 22,
            background: s.demo.fill,
            overflow: "hidden",
            opacity: interpolate(f, [s.demo.from - 6, s.demo.from], [0, 1], clamp),
          }}
        >
          <Img
            src={asset(`kit/${seqName(s.demo.name, ((f - s.demo.from) * 1) % s.demo.count)}.png`)}
            style={{ position: "absolute", left: 0, top: "50%", width: "100%", transform: "translateY(-50%)" }}
          />
        </div>
      )}
      {s.scan && (() => {
        const sq = { x: 232 * K, y: 882 * K, s: 735 * K };
        const e = interpolate(f, [s.scan.enter, s.scan.enter + 26], [0, 1], { ...clamp, easing: ease.lift });
        const lw = sq.s * 0.74;
        const lh = lw * 0.62;
        const line = interpolate(f, [s.scan.read, s.scan.read + 22, s.scan.read + 44], [0, 1, 0], { ...clamp, easing: Easing.bezier(0.4, 0, 0.6, 1) });
        const reading = f >= s.scan.read && f < s.scan.read + 44;
        const done = interpolate(f, [s.scan.read + 44, s.scan.read + 52], [0, 1], clamp);
        return (
          <>
            <div
              style={{
                position: "absolute",
                left: sq.x + (sq.s - lw) / 2 + (1 - e) * 260,
                top: sq.y + (sq.s - lh) / 2 + (1 - e) * 120,
                width: lw,
                height: lh,
                borderRadius: 14,
                background: "#F4F4F2",
                boxShadow: "0 24px 50px rgba(0,0,0,0.55)",
                transform: `rotate(${(1 - e) * 14 - 2}deg) scale(${0.8 + 0.2 * e})`,
                opacity: Math.min(1, e * 2),
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Bars w={lw - 36} h={lh - 30} />
            </div>
            {reading && (
              <div
                style={{
                  position: "absolute",
                  left: sq.x,
                  top: sq.y + sq.s * (0.12 + 0.76 * line) - 2,
                  width: sq.s,
                  height: 4,
                  background: C.pale,
                  boxShadow: `0 0 18px 4px ${C.sapphire}`,
                }}
              />
            )}
            {done > 0 && done < 1 && <div style={{ position: "absolute", left: sq.x - 10, top: sq.y - 10, width: sq.s + 20, height: sq.s + 20, borderRadius: 30, border: `4px solid ${C.pale}`, opacity: 1 - done, boxShadow: `0 0 40px ${C.sapphire}` }} />}
          </>
        );
      })()}
    </div>
  );

  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ backgroundColor: C.void, opacity: inP }} />
      <AbsoluteFill style={{ background: `radial-gradient(circle 900px at ${AXIS}px ${H / 2}px, ${C.lifted}, ${C.void} 70%)`, opacity: inP }} />
      <AbsoluteFill style={{ background: `radial-gradient(ellipse 620px 900px at ${AXIS}px 1000px, ${app.accent}22, transparent 72%)`, opacity: inP * (1 - outP) }} />
      <AbsoluteFill style={{ transform: `translateX(${dx}px)`, opacity: inP * (1 - outP), filter: `blur(${(1 - inP) * 10 + outP * 10}px)` }}>
        <div style={{ opacity: 1 - g }}>
          <KineticLine words={[{ t: t(app.title), at: 6 }]} frame={f} top={100} size={128} />
        </div>
        <div style={{ position: "absolute", left: 0, top: 252, width: W, height: 70, opacity: 1 - g, display: "flex", justifyContent: "center", fontFamily: INTER, fontWeight: 500, fontSize: 52, letterSpacing: "-0.01em", color: C.type2, whiteSpace: "nowrap" }}>
          {subIdx > 0 && <span style={{ position: "absolute", opacity: 1 - subP, transform: `translateY(${-subP * 20}px)` }}>{t(app.subs[subIdx - 1].key)}</span>}
          <span style={{ position: "absolute", opacity: subP, transform: `translateY(${(1 - subP) * 24}px)` }}>{t(sub.key)}</span>
        </div>
        {/* the real screen, whole */}
        <div style={{ position: "absolute", inset: 0, perspective: 2200 }}>
          <div style={{ position: "absolute", inset: 0, transformOrigin: `${fx}px ${fy}px`, transform: `translate(${cdx}px, ${cdy}px) scale(${z})` }}>
          <div
            style={{
              position: "absolute",
              left: SX,
              top: SY,
              width: SW,
              height: SH,
              borderRadius: 56,
              overflow: "hidden",
              boxShadow: "0 50px 100px rgba(0,0,0,0.65), 0 0 0 2px rgba(255,255,255,0.12)",
              transform: `translate(${drift}px, ${bob}px) rotateY(${ry}deg) rotateX(1.5deg) scale(${(0.9 + 0.1 * settle) * (1 - 0.14 * rec)}) translateY(${-24 * rec}px)`,
              filter: `blur(${7 * rec}px) brightness(${1 - 0.7 * rec})`,
              opacity: Math.min(1, settle * 2),
            }}
          >
            <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH }}>
              {zf > 0.02 && (
                <div style={{ position: "absolute", inset: 0, filter: `blur(${7 * zf}px) brightness(${1 - 0.5 * zf})` }}>
                  {renderScreen(cur)}
                  {nxt && renderScreen(nxt, `inset(0 ${(1 - wipe) * 100}% 0 0)`)}
                </div>
              )}
              <div style={{ position: "absolute", inset: 0, maskImage: zf > 0.02 ? mask : undefined, WebkitMaskImage: zf > 0.02 ? mask : undefined }}>
                <div style={{ position: "absolute", inset: 0, opacity: dipping ? 1 - Math.min(1, wipe * 2) : 1 }}>{renderScreen(cur)}</div>
                {nxt && (dipping ? <div style={{ position: "absolute", inset: 0, opacity: Math.max(0, wipe * 2 - 1) }}>{renderScreen(nxt)}</div> : renderScreen(nxt, `inset(0 ${(1 - wipe) * 100}% 0 0)`))}
              </div>
              {activeHi && hiP > 0 && (
                <div
                  style={{
                    position: "absolute",
                    left: activeHi.rect[0] * K - 8,
                    top: activeHi.rect[1] * K - 8,
                    width: activeHi.rect[2] * K + 16,
                    height: activeHi.rect[3] * K + 16,
                    borderRadius: 24,
                    border: `3px solid ${C.pale}`,
                    boxShadow: `0 0 ${24 + 10 * Math.sin(f / 7)}px 2px rgba(78,155,224,0.7), inset 0 0 22px rgba(78,155,224,0.25)`,
                    opacity: hiP,
                    transform: `scale(${1.04 - 0.04 * hiP})`,
                  }}
                />
              )}
            </div>
          </div>
          </div>
        </div>
        {activeHi && hiP > 0 && (() => {
          const rx = toStageX(activeHi.rect[0] * K) + drift;
          const ry2 = toStageY(activeHi.rect[1] * K) + bob;
          const rw = activeHi.rect[2] * K * z;
          const rh = activeHi.rect[3] * K * z;
          const cx0 = Math.min(W - 300, Math.max(300, rx + rw / 2));
          const above = ry2 - 84 > 40;
          const top = above ? ry2 - 84 : Math.min(H - 150, ry2 + rh + 26);
          return (
            <div style={{ position: "absolute", left: cx0 - 260, top, width: 520, display: "flex", justifyContent: "center", opacity: hiP, transform: `translateY(${(1 - hiP) * (above ? 14 : -14)}px)` }}>
              <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 30, color: C.type1, padding: "0 30px", height: 64, borderRadius: 32, display: "flex", alignItems: "center", gap: 14, border: "1.5px solid rgba(214,233,250,0.75)", background: "rgba(7,16,28,0.88)", boxShadow: "0 0 34px rgba(78,155,224,0.45)", whiteSpace: "nowrap" }}>
                <span style={{ width: 12, height: 12, borderRadius: 6, background: C.sapphireBright, boxShadow: `0 0 12px ${C.sapphire}` }} />
                {activeHi.label}
              </div>
            </div>
          );
        })()}
        {nxt && !dipping && <Seam x={SX + drift + SW * wipeX} top={SY} height={SH} spread={0.5} intensity={Math.sin(Math.PI * wipe)} />}
        {/* its widgets, whole, lifted off the screen */}
        {app.widgets &&
          app.widgets.items.map((w, i) => {
            const p = interpolate(f, [wAt + 10 * i, wAt + 10 * i + 28], [0, 1], { ...clamp, easing: ease.lift });
            if (p <= 0) return null;
            const float = Math.sin((f + i * 30) / 28) * 5;
            return (
              <Img
                key={i}
                src={asset(w.src)}
                style={{
                  position: "absolute",
                  left: (W - w.w) / 2 - drift * 1.1,
                  top: w.top + (1 - p) * 90 + float,
                  width: w.w,
                  opacity: p,
                  transform: `scale(${0.9 + 0.1 * p})`,
                  filter: "drop-shadow(0 40px 60px rgba(0,0,0,0.6))",
                }}
              />
            );
          })}
      </AbsoluteFill>
      {/* the link: the Seam crosses the page as the app takes over / leaves */}
      <Seam x={interpolate(f, [0, 30], [W + 80, -80], clamp)} top={120} height={H - 240} intensity={f < 30 ? Math.sin((Math.PI * f) / 30) * 0.9 : 0} spread={0.8} />
      <Grain />
    </AbsoluteFill>
  );
};
