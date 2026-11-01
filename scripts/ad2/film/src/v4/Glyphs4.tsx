import { C } from "../lib/brand";

/** Everyday moments as bold graphic glyphs (400 × 400 grid). Pure vector: no photo, no stock. */
export type Kind = "sunrise" | "meal" | "weights" | "card" | "agenda" | "checklist" | "water" | "moon";

const Defs: React.FC = () => (
  <defs>
    <linearGradient id="gw" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#FFFFFF" />
      <stop offset="1" stopColor="#A9CBEB" />
    </linearGradient>
    <linearGradient id="gs" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stopColor={C.sapphireBright} />
      <stop offset="1" stopColor={C.sapphireDeep} />
    </linearGradient>
    <linearGradient id="gsun" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#FFE08A" />
      <stop offset="1" stopColor="#FF7A45" />
    </linearGradient>
    <linearGradient id="gwater" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stopColor="#9BD4FF" />
      <stop offset="1" stopColor={C.sapphireDeep} />
    </linearGradient>
    <linearGradient id="gmoon" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stopColor="#FFFFFF" />
      <stop offset="1" stopColor="#B9A8FF" />
    </linearGradient>
    <mask id="mmoon">
      <rect width="400" height="400" fill="#fff" />
      <circle cx="262" cy="150" r="118" fill="#000" />
    </mask>
  </defs>
);

const Art: React.FC<{ kind: Kind }> = ({ kind }) => {
  switch (kind) {
    case "sunrise":
      return (
        <>
          {Array.from({ length: 9 }, (_, i) => {
            const a = Math.PI + (Math.PI * (i + 0.5)) / 9;
            return <line key={i} x1={200 + Math.cos(a) * 168} y1={282 + Math.sin(a) * 168} x2={200 + Math.cos(a) * 214} y2={282 + Math.sin(a) * 214} stroke="#FFD27A" strokeWidth="14" strokeLinecap="round" />;
          })}
          <path d="M62 282 A138 138 0 0 1 338 282 Z" fill="url(#gsun)" />
          <rect x="30" y="292" width="340" height="16" rx="8" fill="url(#gw)" />
          <rect x="90" y="324" width="220" height="12" rx="6" fill="#fff" opacity="0.55" />
          <rect x="140" y="350" width="120" height="10" rx="5" fill="#fff" opacity="0.3" />
        </>
      );
    case "meal":
      return (
        <>
          <rect x="28" y="70" width="16" height="262" rx="8" fill="url(#gw)" />
          <rect x="14" y="70" width="8" height="90" rx="4" fill="url(#gw)" />
          <rect x="50" y="70" width="8" height="90" rx="4" fill="url(#gw)" />
          <path d="M364 70 C390 110 388 190 366 214 L366 332 L350 332 L350 70 Z" fill="url(#gw)" />
          <circle cx="204" cy="204" r="128" fill="url(#gw)" />
          <circle cx="204" cy="204" r="96" fill="none" stroke="#FF7A3D" strokeWidth="12" />
          <circle cx="178" cy="190" r="30" fill="#FF7A3D" />
          <circle cx="226" cy="224" r="24" fill="#7CE0A0" />
          <circle cx="232" cy="172" r="16" fill="#FFD27A" />
        </>
      );
    case "weights":
      return (
        <>
          <rect x="24" y="188" width="352" height="24" rx="12" fill="url(#gw)" />
          <rect x="62" y="104" width="38" height="192" rx="14" fill="url(#gs)" />
          <rect x="104" y="132" width="28" height="136" rx="12" fill="url(#gw)" />
          <rect x="300" y="104" width="38" height="192" rx="14" fill="url(#gs)" />
          <rect x="268" y="132" width="28" height="136" rx="12" fill="url(#gw)" />
          <rect x="138" y="180" width="18" height="40" rx="6" fill="#4E9BE0" />
          <rect x="244" y="180" width="18" height="40" rx="6" fill="#4E9BE0" />
        </>
      );
    case "card":
      return (
        <>
          <rect x="20" y="86" width="360" height="236" rx="34" fill="url(#gs)" />
          <rect x="20" y="132" width="360" height="40" fill="#07101C" opacity="0.55" />
          <rect x="54" y="204" width="62" height="46" rx="11" fill="#FFD27A" />
          <rect x="54" y="272" width="170" height="14" rx="7" fill="#fff" opacity="0.85" />
          <rect x="54" y="296" width="100" height="10" rx="5" fill="#fff" opacity="0.5" />
          <path d="M300 230 q16 -16 32 0 q16 16 32 0" fill="none" stroke="#fff" strokeWidth="9" strokeLinecap="round" opacity="0.85" />
        </>
      );
    case "agenda":
      return (
        <>
          <rect x="44" y="64" width="312" height="290" rx="42" fill="url(#gw)" />
          <path d="M44 106 a42 42 0 0 1 42 -42 h228 a42 42 0 0 1 42 42 v38 h-312 Z" fill="#FF6B6B" />
          <rect x="116" y="38" width="22" height="52" rx="10" fill="#D6E9FA" />
          <rect x="262" y="38" width="22" height="52" rx="10" fill="#D6E9FA" />
          {Array.from({ length: 12 }, (_, i) => {
            const cx = 98 + (i % 4) * 68;
            const cy = 196 + Math.floor(i / 4) * 52;
            return i === 6 ? <circle key={i} cx={cx} cy={cy} r="27" fill={C.sapphire} /> : <circle key={i} cx={cx} cy={cy} r="13" fill="#B7C9DB" />;
          })}
        </>
      );
    case "checklist":
      return (
        <>
          <rect x="26" y="50" width="348" height="300" rx="44" fill="#fff" opacity="0.14" stroke="#fff" strokeOpacity="0.35" strokeWidth="4" />
          {[0, 1, 2].map((i) => (
            <g key={i}>
              <rect x="58" y={84 + i * 90} width="62" height="62" rx="18" fill={i < 2 ? "#7CE0A0" : "none"} stroke={i < 2 ? "none" : "#fff"} strokeWidth="6" />
              {i < 2 && <path d={`M72 ${116 + i * 90} l16 16 l28 -32`} fill="none" stroke="#07101C" strokeWidth="9" strokeLinecap="round" strokeLinejoin="round" />}
              <rect x="146" y={102 + i * 90} width={i === 1 ? 150 : 190} height="26" rx="13" fill="url(#gw)" opacity={i < 2 ? 0.9 : 0.7} />
            </g>
          ))}
        </>
      );
    case "water":
      return (
        <>
          <path d="M108 52 H292 L262 336 Q200 358 138 336 Z" fill="#fff" opacity="0.14" stroke="#D6E9FA" strokeWidth="8" strokeLinejoin="round" />
          <path d="M120 140 Q160 118 200 140 T280 140 L262 330 Q200 348 138 330 Z" fill="url(#gwater)" />
          <circle cx="176" cy="238" r="12" fill="#fff" opacity="0.6" />
          <circle cx="222" cy="280" r="8" fill="#fff" opacity="0.5" />
          <circle cx="214" cy="196" r="6" fill="#fff" opacity="0.5" />
          <path d="M200 6 C230 40 244 60 200 78 C156 60 170 40 200 6 Z" fill="#9BD4FF" />
        </>
      );
    case "moon":
      return (
        <>
          <circle cx="190" cy="206" r="148" fill="url(#gmoon)" mask="url(#mmoon)" />
        </>
      );
  }
};

export const Glyph: React.FC<{ kind: Kind; size: number; dim?: number }> = ({ kind, size, dim = 1 }) => (
  <svg width={size} height={size} viewBox="0 0 400 400" style={{ display: "block", overflow: "visible", filter: `brightness(${dim})` }}>
    <Defs />
    <Art kind={kind} />
  </svg>
);

/** Invented generic app glyphs (no real logo): white shapes on a tile, 100 × 100 grid. */
export const TileIcon: React.FC<{ n: number }> = ({ n }) => {
  const f = "#fff";
  switch (n % 10) {
    case 0:
      return <circle cx="50" cy="50" r="26" fill="none" stroke={f} strokeWidth="11" />;
    case 1:
      return <polygon points="50,12 88,50 50,88 12,50" fill={f} />;
    case 2:
      return <polygon points="58,10 24,56 46,56 40,90 76,42 54,42" fill={f} />;
    case 3:
      return <path d="M16 62 A34 34 0 0 1 84 62 Z" fill={f} />;
    case 4:
      return (
        <>
          <circle cx="38" cy="50" r="22" fill="none" stroke={f} strokeWidth="9" />
          <circle cx="62" cy="50" r="22" fill="none" stroke={f} strokeWidth="9" />
        </>
      );
    case 5:
      return <path d="M10 40 q10 -14 20 0 t20 0 t20 0 t20 0 M10 62 q10 -14 20 0 t20 0 t20 0 t20 0" fill="none" stroke={f} strokeWidth="9" strokeLinecap="round" />;
    case 6:
      return (
        <>
          <rect x="18" y="18" width="29" height="29" rx="8" fill={f} />
          <rect x="53" y="18" width="29" height="29" rx="8" fill={f} opacity="0.6" />
          <rect x="18" y="53" width="29" height="29" rx="8" fill={f} opacity="0.6" />
          <rect x="53" y="53" width="29" height="29" rx="8" fill={f} />
        </>
      );
    case 7:
      return <polygon points="50,16 88,82 12,82" fill={f} />;
    case 8:
      return <polygon points="50,10 85,30 85,70 50,90 15,70 15,30" fill="none" stroke={f} strokeWidth="10" strokeLinejoin="round" />;
    default:
      return <path d="M50 16 V84 M16 50 H84" stroke={f} strokeWidth="14" strokeLinecap="round" />;
  }
};
