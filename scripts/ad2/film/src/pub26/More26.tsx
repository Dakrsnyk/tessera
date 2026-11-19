import { AbsoluteFill, Easing, Img, interpolate, useCurrentFrame } from "remotion";
import { Grain } from "../components/Grain";
import { Seam } from "../components/Seam";
import { AXIS, C, clamp, ease, H, INTER, W } from "../lib/brand";
import { asset } from "../lib/kit";
import { KineticLine } from "../v3/fx";
import { pillStyle } from "../v5/mainLook";
import { MORE_SHOTS } from "./shots";
import { MAIN } from "./timing26";

/**
 * Main ad, v2.3 (PDG, 2026-11-18): « And much more. » after the three mini-apps, at most 2 s: real screens of the other mini-apps
 * (current captures only, see MORE_SHOTS in shots.ts) scroll from right to left under the title, then the film goes on to
 * « Make everyday your own. ». Each card carries the name of its mini-app (and « With Premium » on a Premium screen).
 */
const CW = 470;
const CH = (CW * 2622) / 1206;
const GAP = 60;
const CY = 1060;

export const More26: React.FC = () => {
  const f = useCurrentFrame();
  const L = MAIN.more.len;
  const inP = interpolate(f, [0, 16], [0, 1], { ...clamp, easing: ease.split });
  const outP = interpolate(f, [L - 16, L], [0, 1], { ...clamp, easing: Easing.bezier(0.6, 0, 0.9, 0.4) });
  const n = MORE_SHOTS.length;
  const step = CW + GAP;
  // the row travels from « first card just right of centre » to « last card just left of centre »
  const x0 = W / 2 + 260;
  const x1 = W / 2 - 260 - (n - 1) * step;
  const t = interpolate(f, [0, L], [0, 1], { ...clamp, easing: Easing.bezier(0.35, 0, 0.65, 1) });
  const rowX = x0 + (x1 - x0) * t;
  return (
    <AbsoluteFill style={{ backgroundColor: C.void }}>
      <AbsoluteFill style={{ background: `radial-gradient(circle 1000px at ${AXIS}px ${CY}px, ${C.lifted}, ${C.void} 72%)`, opacity: inP }} />
      <AbsoluteFill style={{ opacity: inP * (1 - outP), filter: `blur(${(1 - inP) * 8 + outP * 8}px)` }}>
        <KineticLine words={[{ t: "And much more.", at: MAIN.more.titleAt }]} frame={f} top={100} size={112} />
        <div style={{ position: "absolute", inset: 0, perspective: 2000 }}>
          {MORE_SHOTS.map((m, i) => {
            const cx = rowX + i * step;
            const d = (cx - W / 2) / W; // -0.5 .. 0.5 on screen
            if (cx < -CW || cx > W + CW) return null;
            const sc = 1 - Math.min(0.12, Math.abs(d) * 0.18);
            return (
              <div key={i} style={{ position: "absolute", left: cx - CW / 2, top: CY - CH / 2, width: CW, height: CH, transform: `rotateY(${-d * 28}deg) scale(${sc})` }}>
                <Img src={asset(`kit/${m.capture}.png`)} style={{ width: CW, height: CH, borderRadius: 165 * (CW / 1206), display: "block", boxShadow: "0 40px 110px rgba(0,0,0,0.55), 0 0 0 3px rgba(255,255,255,0.10)" }} />
                <div style={{ position: "absolute", left: 0, right: 0, top: CH + 34, display: "flex", justifyContent: "center", gap: 12 }}>
                  <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 32, color: C.type1, padding: "0 26px", height: 60, borderRadius: 30, display: "flex", alignItems: "center", gap: 12, whiteSpace: "nowrap", ...pillStyle(m.accent) }}>
                    <span style={{ width: 12, height: 12, borderRadius: 6, background: m.accent }} />
                    {m.label}
                  </div>
                  {m.premium && (
                    <div style={{ fontFamily: INTER, fontWeight: 600, fontSize: 26, color: C.pale, padding: "0 20px", height: 60, borderRadius: 30, display: "flex", alignItems: "center", whiteSpace: "nowrap", ...pillStyle(m.accent) }}>With Premium</div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
      {/* the link from Planning: the Seam crosses the page as the row takes over */}
      <Seam x={interpolate(f, [0, 30], [W + 80, -80], clamp)} top={120} height={H - 240} intensity={f < 30 ? Math.sin((Math.PI * f) / 30) * 0.9 : 0} spread={0.8} />
      <Grain />
    </AbsoluteFill>
  );
};
