import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { ArdaneLogo } from "../components/ArdaneLogo";
import { C, INTER } from "../lib/brand";
import { AppIcon, HomeScreen } from "./Home";
import { BEFORE, iconXY, rectOf, SCREENS, SH, SW } from "./screens";

// « Voici ton téléphone… et voici le mien » — 1080 x 1920, 30 i/s, 18 s.
// Avant (vraie capture iOS) → glissement de page → Sport (Volt) → morphing des widgets → Organisation (Glacier)
// → balayage de lumière → Finance (Marine et or) → les trois téléphones côte à côte → carte de fin.
export const FPS_AA = 30;
export const T = {
  before: 0,
  swipe: 92,
  s1: 118,
  morph: 196,
  s2: 226,
  sweep: 300,
  s3: 328,
  lineup: 402,
  end: 474,
  total: 540,
};

const CARD = 0.6; // échelle de l'écran dans la vidéo (1206 x 2622 → 724 x 1573)
const CARD_TOP = 262;
const RADIUS = 165; // coins de l'écran d'un iPhone 16 Pro, en px de capture

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const io = Easing.bezier(0.65, 0, 0.35, 1);
const out = Easing.bezier(0.16, 1, 0.3, 1);
const p = (f: number, a: number, b: number, e = io) => interpolate(f, [a, b], [0, 1], { ...clamp, easing: e });
const mix = (a: number, b: number, t: number) => a + (b - a) * t;

const font = (w: number, px: number): React.CSSProperties => ({ fontFamily: `"${INTER}", Helvetica, Arial, sans-serif`, fontWeight: w, fontSize: px });

/** Un écran posé dans la vidéo : coins arrondis d'iPhone, ombre, aucune coque dessinée (règle d'Apple : pas d'imitation d'appareil). */
const Card: React.FC<{ x: number; y: number; scale: number; children: React.ReactNode; opacity?: number }> = ({ x, y, scale, children, opacity = 1 }) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      width: SW,
      height: SH,
      transform: `scale(${scale})`,
      transformOrigin: "0 0",
      borderRadius: RADIUS,
      overflow: "hidden",
      opacity,
      boxShadow: "0 40px 120px rgba(0,0,0,0.55), 0 0 0 3px rgba(255,255,255,0.10)",
    }}
  >
    {children}
  </div>
);

/** Fond de la vidéo : le fond d'écran courant, très flou et assombri (lumière d'ambiance). */
const Ambient: React.FC<{ walls: { src: string; o: number }[] }> = ({ walls }) => (
  <AbsoluteFill style={{ background: "#050607" }}>
    {walls.map((w) =>
      w.o > 0 ? (
        <Img
          key={w.src}
          src={staticFile(w.src)}
          style={{ position: "absolute", left: -200, top: -200, width: 1480, height: 2320, objectFit: "cover", filter: "blur(90px) brightness(0.42) saturate(1.3)", opacity: w.o }}
        />
      ) : null,
    )}
    <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 55%, rgba(0,0,0,0) 30%, rgba(0,0,0,0.55) 100%)" }} />
  </AbsoluteFill>
);

const Caption: React.FC<{ text: string; f: number; at: number; until: number; y?: number; size?: number }> = ({ text, f, at, until, y = 120, size = 66 }) => {
  const words = text.split(" ");
  const fadeOut = 1 - p(f, until - 8, until);
  return (
    <div style={{ position: "absolute", left: 60, right: 60, top: y, textAlign: "center", color: "#F5F5F7", letterSpacing: -1.2, ...font(700, size), opacity: fadeOut }}>
      {words.map((w, i) => {
        const e = p(f, at + i * 4, at + i * 4 + 14, out);
        return (
          <span key={i} style={{ display: "inline-block", opacity: e, transform: `translateY(${(1 - e) * 26}px)`, filter: `blur(${(1 - e) * 8}px)`, marginRight: 18 }}>
            {w}
          </span>
        );
      })}
    </div>
  );
};

/** Apparition échelonnée des widgets puis des icônes d'un écran. */
const stagger = (f: number, start: number) => (i: number) => p(f, start + i * 5, start + i * 5 + 18, out);

/** Morphing Sport → Organisation : chaque widget glisse vers sa nouvelle place et change de taille, les icônes changent de coin,
 *  le fond se remplace de haut en bas. MAP : widget de l'écran Sport → widget de l'écran Organisation. */
const MAP: [number, number][] = [
  [0, 0], // séance du jour (moyen, en haut) → tâches (petit, en haut à gauche)
  [1, 2], // calories (petit) → agenda (moyen, même rangée)
  [2, 3], // volume (moyen, en bas) → taux de réussite (petit, en bas à droite)
];
const Morph: React.FC<{ t: number }> = ({ t }) => {
  const [a, b] = [SCREENS[0], SCREENS[1]];
  const wipe = interpolate(t, [0.05, 0.85], [0, 1], { ...clamp, easing: io });
  const swap = interpolate(t, [0.36, 0.56], [0, 1], clamp);
  const move = interpolate(t, [0, 0.8], [0, 1], { ...clamp, easing: io });
  const fresh = b.widgets.map((_, j) => j).filter((j) => !MAP.some(([, k]) => k === j));
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", background: "#000" }}>
      <Img src={staticFile(a.wall)} style={{ position: "absolute", left: -40, top: 0, width: SW + 80, height: SH }} />
      <div style={{ position: "absolute", inset: 0, clipPath: `inset(0 0 ${(1 - wipe) * 100}% 0)` }}>
        <Img src={staticFile(b.wall)} style={{ position: "absolute", left: -40, top: 0, width: SW + 80, height: SH }} />
      </div>
      {MAP.map(([i, j]) => {
        const ra = rectOf(a.widgets[i]);
        const rb = rectOf(b.widgets[j]);
        const r = ra.map((v, k) => mix(v, rb[k], move));
        return (
          <div key={i} style={{ position: "absolute", left: r[0], top: r[1], width: r[2], height: r[3], borderRadius: 70, overflow: "hidden", boxShadow: "0 14px 30px rgba(0,0,0,0.22)" }}>
            <Img src={staticFile(b.widgets[j].file)} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "top left" }} />
            <Img src={staticFile(a.widgets[i].file)} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "top left", opacity: 1 - swap }} />
          </div>
        );
      })}
      {fresh.map((j) => {
        const [x, y, w, h] = rectOf(b.widgets[j]);
        const e = interpolate(t, [0.45, 1], [0, 1], { ...clamp, easing: out });
        return <Img key={j} src={staticFile(b.widgets[j].file)} style={{ position: "absolute", left: x, top: y, width: w, height: h, opacity: e, transform: `scale(${0.85 + 0.15 * e})` }} />;
      })}
      {a.icons.map((ic) => {
        const [x, y] = iconXY(ic.c, ic.r);
        const o = 1 - interpolate(t, [0, 0.28], [0, 1], clamp);
        return <AppIcon key={ic.name} name={ic.name} x={x} y={y} label={false} opacity={o} scale={0.7 + 0.3 * o} />;
      })}
      {b.icons.map((ic, i) => {
        const [x, y] = iconXY(ic.c, ic.r);
        const e = interpolate(t, [0.55 + i * 0.06, 0.85 + i * 0.04], [0, 1], { ...clamp, easing: out });
        return <AppIcon key={ic.name} name={ic.name} x={x} y={y} label={false} opacity={e} scale={0.7 + 0.3 * e} />;
      })}
      <div style={{ position: "absolute", inset: 0, opacity: interpolate(t, [0.85, 1], [0, 1], clamp) }}>
        <HomeScreen screen={b} />
      </div>
      <div style={{ position: "absolute", inset: 0, opacity: 1 - interpolate(t, [0.85, 1], [0, 1], clamp) }}>
        <HomeScreen screen={{ ...a, widgets: [], icons: [], dock: t < 0.5 ? a.dock : b.dock, glass: t < 0.5 ? a.glass : b.glass }} noWall />
      </div>
    </div>
  );
};

export const AvantApresFilm: React.FC = () => {
  const f = useCurrentFrame();
  const [s1, s2, s3] = SCREENS;
  const cardX = (1080 - SW * CARD) / 2;

  // ---- l'écran au centre (avant → Sport → Organisation → Finance) ----
  const swipe = p(f, T.swipe, T.s1 + 4);
  const morph = p(f, T.morph, T.s2 + 4);
  const sweep = p(f, T.sweep, T.s3 + 2, Easing.bezier(0.5, 0, 0.25, 1));
  const lineup = p(f, T.lineup, T.lineup + 34);
  const endP = p(f, T.end, T.end + 26);

  const push = 1 + 0.025 * p(f, 0, T.swipe, Easing.linear) - 0.025 * swipe; // lente poussée sur l'avant
  const enterCard = p(f, 0, 16, out);

  let center: React.ReactNode;
  if (f < T.morph) {
    center = (
      <>
        <div style={{ position: "absolute", inset: 0, transform: `translateX(${-swipe * SW}px)` }}>
          <Img src={staticFile(BEFORE)} style={{ width: SW, height: SH, display: "block", filter: "saturate(0.9)" }} />
        </div>
        <div style={{ position: "absolute", inset: 0, transform: `translateX(${(1 - swipe) * SW}px)` }}>
          <HomeScreen screen={s1} wallX={(1 - swipe) * -320} enter={stagger(f, T.swipe + 6)} />
        </div>
      </>
    );
  } else if (f < T.sweep) {
    center = morph < 1 ? <Morph t={morph} /> : <HomeScreen screen={s2} />;
  } else {
    const edge = mix(-0.25, 1.25, sweep); // bord du balayage, en fraction de largeur (diagonale)
    const poly = `polygon(${(edge - 0.25) * 100}% 0, 200% 0, 200% 100%, ${(edge + 0.25) * 100}% 100%)`;
    center = (
      <>
        <HomeScreen screen={s3} enter={stagger(f, T.sweep + 10)} />
        {sweep < 1 && (
          <div style={{ position: "absolute", inset: 0, clipPath: poly }}>
            <HomeScreen screen={s2} />
          </div>
        )}
        {sweep > 0 && sweep < 1 && (
          <div
            style={{
              position: "absolute",
              top: -400,
              left: (edge - 0.02) * SW - 200,
              width: 400,
              height: SH + 800,
              transform: "rotate(10.6deg)",
              background: "linear-gradient(90deg, rgba(229,181,103,0) 0%, rgba(255,226,170,0.85) 50%, rgba(229,181,103,0) 100%)",
              filter: "blur(18px)",
              mixBlendMode: "screen",
            }}
          />
        )}
      </>
    );
  }

  // ---- alignement final : trois écrans côte à côte ----
  const small = 0.27;
  const gap = 26;
  const rowW = 3 * SW * small + 2 * gap;
  const rowX = (1080 - rowW) / 2;
  const rowY = 560;
  const slot = (k: number) => rowX + k * (SW * small + gap);
  const centerScale = mix(CARD * push, small, lineup);
  const centerX = mix(cardX + (SW * CARD * (1 - push)) / 2, slot(2), lineup);
  const centerY = mix(CARD_TOP + (SH * CARD * (1 - push)) / 2, rowY, lineup);

  const ambient = [
    { src: BEFORE, o: 1 - swipe },
    { src: s1.wall, o: f < T.morph ? swipe : 1 - morph },
    { src: s2.wall, o: f < T.sweep ? morph : 1 - sweep },
    { src: s3.wall, o: sweep },
  ];

  const endY = mix(0, -150, endP);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Ambient walls={ambient} />
      <div style={{ position: "absolute", inset: 0, transform: `translateY(${endY}px)`, opacity: 1 - 0.25 * endP }}>
        {lineup > 0 && (
          <>
            <Card x={slot(0)} y={rowY + (1 - p(f, T.lineup + 10, T.lineup + 40, out)) * 420} scale={small} opacity={p(f, T.lineup + 10, T.lineup + 30)}>
              <HomeScreen screen={s1} />
            </Card>
            <Card x={slot(1)} y={rowY + (1 - p(f, T.lineup + 4, T.lineup + 34, out)) * 420} scale={small} opacity={p(f, T.lineup + 4, T.lineup + 24)}>
              <HomeScreen screen={s2} />
            </Card>
          </>
        )}
        <Card x={centerX} y={centerY + (1 - enterCard) * 40} scale={centerScale * (0.96 + 0.04 * enterCard)} opacity={enterCard}>
          {center}
        </Card>
      </div>

      <Caption text="This is your phone…" f={f} at={8} until={T.swipe + 6} />
      <Caption text="…and this is mine." f={f} at={T.swipe + 10} until={T.lineup + 2} />
      {SCREENS.map((sc, k) => {
        const a = [T.s1 - 6, T.s2 - 4, T.s3 - 6][k];
        const b = [T.morph + 6, T.sweep + 4, T.lineup + 2][k];
        const o = p(f, a, a + 12, out) * (1 - p(f, b - 8, b));
        return o > 0 ? (
          <div key={sc.id} style={{ position: "absolute", left: 0, right: 0, top: 214, display: "flex", justifyContent: "center", opacity: o }}>
            <div style={{ padding: "10px 26px", borderRadius: 40, background: "rgba(255,255,255,0.10)", border: `2px solid ${sc.accent}55`, color: "#F5F5F7", letterSpacing: 0.4, ...font(600, 30), transform: `translateY(${(1 - o) * 10}px)` }}>
              <span style={{ color: sc.accent }}>●</span>&nbsp;&nbsp;{sc.title}
            </div>
          </div>
        ) : null;
      })}
      <Caption text="Your widgets. Your way." f={f} at={T.lineup + 14} until={T.end + 8} y={300} size={72} />

      {/* mention Premium : beaucoup de ces widgets et styles sont « With Premium » */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: 52,
          textAlign: "center",
          color: "rgba(245,245,247,0.62)",
          ...font(500, 30),
          opacity: p(f, T.s1, T.s1 + 12) * (1 - p(f, T.end, T.end + 10)),
        }}
      >
        Some widgets and styles With Premium
      </div>

      {/* carte de fin */}
      {endP > 0 && (
        <AbsoluteFill style={{ opacity: endP }}>
          <ArdaneLogo size={190} cx={540} cy={1290} tile={1} glow={0} />
          <div style={{ position: "absolute", left: 0, right: 0, top: 1410, textAlign: "center", color: C.type1, letterSpacing: -1, ...font(700, 74) }}>Ardane</div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 1515, textAlign: "center", color: C.type2, ...font(500, 38) }}>Coming soon to the App Store</div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 1590, textAlign: "center", color: C.type3, ...font(500, 28) }}>
            Some widgets and styles With Premium
          </div>
        </AbsoluteFill>
      )}
    </AbsoluteFill>
  );
};

/** Aperçu fixe d'un écran (PNG pour validation) : `which` = before | volt | glacier | marine. */
export const AvantApresStill: React.FC<{ which: string }> = ({ which }) => {
  const s = SCREENS.find((x) => x.id === which);
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {s ? <HomeScreen screen={s} /> : <Img src={staticFile(BEFORE)} style={{ width: SW, height: SH }} />}
    </AbsoluteFill>
  );
};
