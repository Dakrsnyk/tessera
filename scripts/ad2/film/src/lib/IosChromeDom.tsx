import React from "react";
import { Img, staticFile } from "remotion";
import { StatusBar } from "../avantapres/Home";
import { INTER } from "./brand";
import { appleIcon, dockX, glassTint, IOS, IOS_DOCK, IosIcon, labelInk } from "./iosHome";

/** DOM twin of drawIosChrome (lib/iosHome.ts) for the films laid out in HTML (ad26): same grid, same Apple icons, same chrome. */
const font = (w: number, px: number): React.CSSProperties => ({ fontFamily: `"${INTER}", -apple-system, Helvetica, Arial, sans-serif`, fontWeight: w, fontSize: px });

export const IosLabel: React.FC<{ x: number; y: number; w: number; text: string; dark: boolean; opacity?: number }> = ({ x, y, w, text, dark, opacity = 1 }) => (
  <div style={{ position: "absolute", left: x - 50, top: y, width: w + 100, textAlign: "center", color: labelInk(dark), textShadow: dark ? "0 1px 6px rgba(0,0,0,0.35)" : "none", opacity, ...font(500, 36) }}>{text}</div>
);

export const IosAppIcon: React.FC<{ name: string; x: number; y: number; label?: boolean; dark?: boolean }> = ({ name, x, y, label = true, dark = true }) => (
  <>
    <Img src={staticFile(appleIcon(name))} style={{ position: "absolute", left: x, top: y, width: IOS.icon, height: IOS.icon, filter: "drop-shadow(0 6px 9px rgba(0,0,0,0.18))" }} />
    {label && <IosLabel x={x} y={y + IOS.icon + 10} w={IOS.icon} text={name} dark={dark} />}
  </>
);

/** Status bar, grid icons, Search pill, Dock and its Apple apps, over a wallpaper of 1206 x 2622. */
export const IosChrome: React.FC<{ dark: boolean; glass?: boolean; icons?: IosIcon[]; dock?: string[] }> = ({ dark, glass, icons = [], dock = IOS_DOCK }) => {
  const tint = glassTint(dark, glass);
  const ink = labelInk(dark);
  const plate = (x: number, y: number, w: number, h: number, r: number): React.CSSProperties => ({ position: "absolute", left: x, top: y, width: w, height: h, borderRadius: r, background: tint.fill, border: `2px solid ${tint.line}`, boxSizing: "border-box" });
  return (
    <>
      {icons.map((ic) => (
        <IosAppIcon key={ic.name} name={ic.name} x={ic.x} y={ic.y} dark={dark} />
      ))}
      <StatusBar ink={dark ? "#FFFFFF" : "#000000"} />
      <div style={plate(488, 2113, 230, 84, 42)} />
      <div style={{ position: "absolute", left: 488, top: 2113, width: 230, height: 84, display: "flex", alignItems: "center", justifyContent: "center", gap: 14, color: ink, ...font(500, 36) }}>
        <svg width={28} height={28} viewBox="0 0 34 34">
          <circle cx={14} cy={14} r={11} fill="none" stroke={ink} strokeWidth={4.5} />
          <line x1={22} y1={22} x2={31} y2={31} stroke={ink} strokeWidth={4.5} strokeLinecap="round" />
        </svg>
        Search
      </div>
      <div style={plate(52, IOS.dockTop, 1100, 304, 120)} />
      {dock.map((name, i) => (
        <IosAppIcon key={name} name={name} x={dockX(i, dock.length)} y={IOS.dockIconTop} label={false} />
      ))}
    </>
  );
};
