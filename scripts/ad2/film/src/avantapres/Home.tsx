import React from "react";
import { getStaticFiles, Img, staticFile } from "remotion";
import { INTER } from "../lib/brand";
import { GRID, ICON_FALLBACK, iconXY, rectOf, Screen, SH, SW, WidgetSlot } from "./screens";

/** Chemin de l'icône d'une app Apple : la vraie (découpée dans la capture du simulateur) si elle existe, sinon celle du kit. */
const iconFile = (name: string) => {
  const real = `avantapres/apple-${name}.png`;
  return getStaticFiles().some((f) => f.name === real) ? real : ICON_FALLBACK[name];
};

const font = (w: number, px: number): React.CSSProperties => ({
  fontFamily: `"${INTER}", -apple-system, Helvetica, Arial, sans-serif`,
  fontWeight: w,
  fontSize: px,
});

/** Libellé sous une icône ou un widget, comme iOS : blanc, petite ombre portée. */
const Label: React.FC<{ x: number; y: number; w: number; text: string; opacity?: number }> = ({ x, y, w, text, opacity = 1 }) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      width: w,
      textAlign: "center",
      color: "rgba(255,255,255,0.96)",
      textShadow: "0 1px 6px rgba(0,0,0,0.35)",
      letterSpacing: 0.2,
      opacity,
      ...font(500, 36),
    }}
  >
    {text}
  </div>
);

export const AppIcon: React.FC<{ name: string; x: number; y: number; label?: boolean; opacity?: number; scale?: number }> = ({
  name,
  x,
  y,
  label = true,
  opacity = 1,
  scale = 1,
}) => (
  <>
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: GRID.icon,
        height: GRID.icon,
        borderRadius: GRID.icon * 0.2237,
        overflow: "hidden",
        opacity,
        transform: `scale(${scale})`,
        boxShadow: "0 6px 18px rgba(0,0,0,0.18)",
      }}
    >
      <Img src={staticFile(iconFile(name))} style={{ width: "100%", height: "100%", display: "block" }} />
    </div>
    {label && <Label x={x - 50} y={y + GRID.icon + 10} w={GRID.icon + 100} text={name} opacity={opacity} />}
  </>
);

/** Barre d'état iOS à 9:41, réseau, Wi-Fi et batterie pleins (règle marketing d'Apple). */
export const StatusBar: React.FC<{ ink: string }> = ({ ink }) => (
  <>
    <div style={{ position: "absolute", left: 117, top: 64, width: 200, textAlign: "center", color: ink, ...font(600, 52), letterSpacing: -0.3 }}>9:41</div>
    <div style={{ position: "absolute", left: 415, top: 43, width: 375, height: 108, borderRadius: 54, background: "#000" }} />
    <svg width={260} height={60} viewBox="0 0 260 60" style={{ position: "absolute", left: 860, top: 70 }}>
      {[12, 19, 27, 36].map((h, i) => (
        <rect key={i} x={5 + i * 16} y={45 - h} width={10} height={h} rx={3} fill={ink} />
      ))}
      {[24, 16, 8].map((r) => {
        const a0 = -Math.PI * 0.75;
        const a1 = -Math.PI * 0.25;
        const cx = 110;
        const cy = 43;
        return (
          <path
            key={r}
            d={`M ${cx + r * Math.cos(a0)} ${cy + r * Math.sin(a0)} A ${r} ${r} 0 0 1 ${cx + r * Math.cos(a1)} ${cy + r * Math.sin(a1)}`}
            fill="none"
            stroke={ink}
            strokeWidth={6}
            strokeLinecap="round"
          />
        );
      })}
      <circle cx={110} cy={41} r={4} fill={ink} />
      <rect x={160} y={10} width={70} height={35} rx={10} fill="none" stroke={ink} strokeOpacity={0.4} strokeWidth={3} />
      <rect x={165} y={15} width={60} height={25} rx={6.5} fill={ink} />
      <rect x={233} y={21} width={4.5} height={13} rx={2} fill={ink} fillOpacity={0.4} />
    </svg>
  </>
);

const glassStyle = (tint: string, r: number): React.CSSProperties => ({
  position: "absolute",
  borderRadius: r,
  background: tint,
  backdropFilter: "blur(28px) saturate(1.5)",
  border: "2px solid rgba(255,255,255,0.22)",
  boxShadow: "inset 0 1px 0 rgba(255,255,255,0.25)",
});

/**
 * Un écran d'accueil (1206 x 2622). `enter(i)` : 0..1 pour l'apparition de l'élément i (widgets puis icônes) ;
 * `content` : décalage x du contenu (glissement de page), `wallShift` : décalage du fond (parallaxe).
 */
export const HomeScreen: React.FC<{
  screen: Screen;
  enter?: (i: number) => number;
  contentX?: number;
  wallX?: number;
  hideWidgets?: boolean;
  chrome?: boolean;
  noWall?: boolean;
  widgetOverride?: (w: WidgetSlot, i: number) => React.CSSProperties | null;
}> = ({ screen, enter = () => 1, contentX = 0, wallX = 0, hideWidgets = false, chrome = true, noWall = false, widgetOverride }) => {
  const ink = "#FFFFFF";
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH, overflow: "hidden", background: noWall ? "transparent" : "#000" }}>
      {!noWall && <Img src={staticFile(screen.wall)} style={{ position: "absolute", left: wallX - 40, top: 0, width: SW + 80, height: SH, objectFit: "cover" }} />}
      <div style={{ position: "absolute", inset: 0, transform: `translateX(${contentX}px)` }}>
        {!hideWidgets &&
          screen.widgets.map((w, i) => {
            const [x, y, ww, hh] = rectOf(w);
            const e = enter(i);
            const over = widgetOverride?.(w, i);
            return (
              <React.Fragment key={w.file}>
                <Img
                  src={staticFile(w.file)}
                  style={{
                    position: "absolute",
                    left: x,
                    top: y,
                    width: ww,
                    height: hh,
                    opacity: Math.min(1, e * 1.6),
                    transform: `translateY(${(1 - e) * 60}px) scale(${0.92 + 0.08 * e})`,
                    filter: "drop-shadow(0 14px 30px rgba(0,0,0,0.22))",
                    ...(over ?? {}),
                  }}
                />
                {!over && <Label x={x} y={y + hh + 18} w={ww} text={w.label ?? "Ardane"} opacity={e} />}
              </React.Fragment>
            );
          })}
        {screen.icons.map((ic, i) => {
          const [x, y] = iconXY(ic.c, ic.r);
          const e = enter(screen.widgets.length + i);
          return <AppIcon key={ic.name} name={ic.name} x={x} y={y + (1 - e) * 40} opacity={e} scale={0.9 + 0.1 * e} />;
        })}
      </div>
      {chrome && (
        <>
          <StatusBar ink={ink} />
          <div style={{ ...glassStyle(screen.glass, 42), left: 488, top: 2113, width: 230, height: 84 }} />
          <div style={{ position: "absolute", left: 488, top: 2113, width: 230, height: 84, display: "flex", alignItems: "center", justifyContent: "center", gap: 14, color: ink, ...font(500, 36) }}>
            <svg width={28} height={28} viewBox="0 0 34 34">
              <circle cx={14} cy={14} r={11} fill="none" stroke={ink} strokeWidth={4.5} />
              <line x1={22} y1={22} x2={31} y2={31} stroke={ink} strokeWidth={4.5} strokeLinecap="round" />
            </svg>
            Search
          </div>
          <div style={{ ...glassStyle(screen.glass, 120), left: 52, top: GRID.dockTop, width: 1100, height: 304 }} />
          {screen.dock.map((name, i) => {
            // 4 icônes : les colonnes de la grille ; moins : centrées, 264 px d'écart (mesuré sur la vraie capture)
            const n = screen.dock.length;
            const x = n === 4 ? iconXY(i, 0)[0] : SW / 2 - GRID.icon / 2 + (i - (n - 1) / 2) * 264;
            return <AppIcon key={name} name={name} x={x} y={GRID.dockIconTop} label={false} />;
          })}
        </>
      )}
    </div>
  );
};
