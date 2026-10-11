// The five films of the Ardane campaign. `common` runs first in the page (helpers shared by every
// film), then the film's `build` creates its elements and defines window.draw(t).
// The grid: 100 BPM, a bar = 2.4 s; cuts land on bars so they fall on the music's beats.

function common() {
  const C = window.CLIPS || {};
  window.clip = (scene, t, start = 0, speed = 1) => {
    const n = C[scene] || 1;
    const i = Math.max(0, Math.min(n - 1, Math.floor(start * 30 + Math.max(0, t) * 30 * speed)));
    return ASSETS + "clips/" + scene + "/" + String(i + 1).padStart(4, "0") + ".jpg";
  };
  // The parts of each recording a film plays, back to back: [start in the recording (s), length in
  // the film (s), speed]. Read on the contact sheets of the CI run (testVideo* scenes).
  const CUTS = {
    "fitness.main": [[19.4, 1.6], [27.6, 3.4]],
    "fitness.short": [[16.8, 0.8], [27.6, 2.0]],
    "fitness.film": [[16.8, 4.3], [27.6, 3.3]],
    "nutrition.main": [[14.1, 1.6], [20.2, 1.3], [23.4, 2.3]],
    "nutrition.short": [[14.2, 0.9], [20.2, 0.7], [24.0, 1.2]],
    "nutrition.film": [[12.8, 2.6], [20.0, 1.5], [23.4, 2.0], [29.6, 1.5]],
    "quotidien.main": [[21.4, 5.2, 1.4]],
    "studio.main": [[15.0, 1.6], [64.4, 1.6], [68.4, 2.0]],
    "studio.short": [[15.4, 1.0], [64.6, 1.0], [68.6, 1.6]],
    "finances.main": [[19.5, 1.2], [22.7, 1.6]],
    "icons.main": [[17.8, 3.2]],
  };
  window.cut = (key, t) => {
    const scene = key.split(".")[0], parts = CUTS[key];
    let rest = Math.max(0, t);
    for (const [start, length, speed = 1] of parts) {
      if (rest < length || parts[parts.length - 1][0] === start) return clip(scene, Math.min(rest, length), start, speed);
      rest -= length;
    }
  };
  window.win = (t, a, b, fi = 0.35, fo = 0.35) => Math.min(seg(t, a, a + fi), 1 - seg(t, b - fo, b));
  window.BG = {
    cream: "radial-gradient(1100px 900px at 15% 8%, #FFFFFF, rgba(255,255,255,0) 70%), linear-gradient(180deg,#F7F4EF,#E9E2D6)",
    night: "radial-gradient(900px 800px at 78% 18%, rgba(217,36,106,.38), rgba(0,0,0,0) 70%), radial-gradient(1000px 900px at 15% 92%, rgba(255,122,89,.28), rgba(0,0,0,0) 70%), #0B0A10",
    coral: "linear-gradient(160deg,#FF7A59,#D9246A)",
    gym: "radial-gradient(900px 900px at 50% 30%, rgba(229,72,77,.32), rgba(0,0,0,0) 70%), radial-gradient(900px 700px at 10% 100%, rgba(255,154,61,.18), rgba(0,0,0,0) 70%), #0A0A0C",
  };
  window.ground = (kind) => { const g = el("div", "layer"); g.style.background = BG[kind]; return g; };
  // A headline: eyebrow + title lines, revealed line by line from a mask, faded out at the end.
  window.headline = (eyebrow, lines, { color = "#1A1516", accent = "#D9246A", x = 80, y = 190, align = "left", size } = {}) => {
    const box = el("div", "abs"); box.style.left = x + "px"; box.style.top = y + "px"; box.style.width = (W - 2 * x) + "px"; box.style.textAlign = align;
    const eb = eyebrow ? el("div", "eyebrow", box, eyebrow) : null; if (eb) { eb.style.color = accent; eb.style.marginBottom = "18px"; }
    const tt = el("div", "title", box); tt.style.color = color; if (size) tt.style.fontSize = size + "px";
    tt.innerHTML = lines.map(l => '<span class="line"><span>' + l + "</span></span>").join("");
    const spans = [...tt.querySelectorAll(".line>span")];
    return { box, draw(t, a, b) {
      const o = 1 - seg(t, b - 0.3, b);
      box.style.display = t < a || t > b ? "none" : "block"; box.style.opacity = o;
      if (eb) { const k = ease.out(seg(t, a, a + 0.5)); eb.style.opacity = k; eb.style.transform = "translateY(" + (1 - k) * 14 + "px)"; }
      spans.forEach((s, i) => { const k = ease.expo(seg(t, a + 0.1 + i * 0.14, a + 0.9 + i * 0.14)); s.style.transform = "translateY(" + (1 - k) * 112 + "%)"; });
    } };
  };
  // A real piece of the app (matted PNG), floating with a soft shadow.
  window.piece = (name, w) => { const i = el("img", "abs"); i.src = ASSETS + "pieces/" + name + ".png"; i.style.width = w + "px"; i.style.filter = "drop-shadow(0 30px 40px rgba(20,16,24,.28))"; return i; };
  window.still = (p, name) => setImg(p.img, ASSETS + "stills/" + name + ".png");
  // The glare sweeping the glass of a phone.
  window.sweep = (p, t, a, d = 1.4) => { const k = seg(t, a, a + d); p.glare.style.transform = "translateX(" + lerp(-120, 120, ease.inOut(k)) + "%)"; p.glare.style.opacity = k > 0 && k < 1 ? 1 : 0; };
  // The Ardane mark: two halves of an A split by a gap (the app icon's geometry).
  window.mark = (size, left = "#FFFFFF", right = "#FFE0CC") => {
    const box = el("div", "abs"); box.style.width = box.style.height = size + "px";
    box.innerHTML = '<svg viewBox="0 0 100 100" width="' + size + '" height="' + size + '" style="overflow:visible">' +
      '<path class="l" d="M47.5 19.3 L47.5 55.4 L34 86 H16 Z" fill="' + left + '"/>' +
      '<path class="r" d="M52.5 19.3 L84 86 H66 L52.5 55.4 Z" fill="' + right + '"/></svg>';
    box.l = box.querySelector(".l"); box.r = box.querySelector(".r"); return box;
  };
  // The closing card: the coral ground opens from the center, the halves slide in, the name rises.
  window.endCard = (t0, { tagline = "Ta vie, en widgets.", cta = "Bientôt sur l'App Store" } = {}) => {
    const g = ground("coral"); g.style.clipPath = "circle(0px at 50% 50%)";
    const m = mark(330); const name = el("div", "abs title", stage, "Ardane"); name.style.cssText += ";color:#fff;font-size:150px;letter-spacing:-5px;width:" + W + "px;text-align:center";
    const tag = el("div", "abs", stage, tagline); tag.style.cssText += ";color:rgba(255,255,255,.9);font-family:TextM;font-size:46px;width:" + W + "px;text-align:center";
    const pill = el("div", "abs", stage, cta); pill.style.cssText += ";color:#D9246A;background:#fff;font-family:Text;font-size:36px;padding:24px 46px;border-radius:999px;left:50%;box-shadow:0 20px 40px rgba(80,10,30,.25)";
    return (t) => {
      const on = t >= t0 - 0.01;
      [g, m, name, tag, pill].forEach(e => e.style.display = on ? "block" : "none");
      if (!on) return;
      const r = ease.inOut(seg(t, t0, t0 + 0.8)) * 1500; g.style.clipPath = "circle(" + r + "px at 50% 46%)";
      const kl = ease.back(seg(t, t0 + 0.35, t0 + 1.05)), kr = ease.back(seg(t, t0 + 0.5, t0 + 1.2));
      tf(m, { x: W / 2 - 165, y: 560, s: lerp(0.9, 1, ease.out(seg(t, t0 + 1.2, t0 + 4))) });
      m.l.setAttribute("transform", "translate(" + (1 - kl) * -90 + " 0)"); m.l.style.opacity = seg(t, t0 + 0.35, t0 + 0.6);
      m.r.setAttribute("transform", "translate(" + (1 - kr) * 90 + " 0)"); m.r.style.opacity = seg(t, t0 + 0.5, t0 + 0.75);
      const kn = ease.expo(seg(t, t0 + 1.0, t0 + 1.8)); tf(name, { y: 930 + (1 - kn) * 60, o: kn });
      const kt = ease.out(seg(t, t0 + 1.5, t0 + 2.2)); tf(tag, { y: 1115 + (1 - kt) * 30, o: kt });
      const kp = ease.back(seg(t, t0 + 2.0, t0 + 2.7)); pill.style.opacity = seg(t, t0 + 2.0, t0 + 2.3); pill.style.transform = "translate(-50%," + (1290 + (1 - kp) * 40) + "px) scale(" + lerp(0.9, 1, kp) + ")";
    };
  };
  // A cut between two grounds: the new one slides up over the old one.
  window.wipe = (kind, t0, d = 0.55) => { const g = ground(kind); return (t) => { const k = ease.inOut(seg(t, t0, t0 + d)); g.style.display = t < t0 ? "none" : "block"; g.style.clipPath = "inset(" + (1 - k) * 100 + "% 0 0 0)"; }; };
}

// A phone that plays a recording (or shows a still) and moves through keyframes.
function phoneShot() { /* defined in films below */ }

const B = 2.4; // a bar

module.exports = { common,

  // ---------------------------------------------------------------- 1. Main film, 40 s
  main: { duration: 40, music: { sections: [[2, 0], [2, 1], [4, 3], [4, 4], [2, 2], [2, 0]], impact: 33.6 },
    sfx: [["lock", 0.35], ["chime", 1.7], ["whoosh", 4.55], ["snap", 5.7], ["tap", 6.5], ["tap", 8.3], ["whoosh", 9.35], ["snap", 10.4], ["tap", 11.3], ["tap", 12.6], ["whoosh", 14.15], ["whoosh", 18.95], ["snap", 20.0], ["whoosh", 23.75], ["snap", 24.4], ["snap", 24.7], ["snap", 25.0], ["whoosh", 28.55], ["whoosh", 30.95], ["chime", 35.0]],
    build: function () {
      const B = 2.4;
      // 1. Hook: the Lock Screen lights up in the dark.
      const g0 = ground("night");
      const p0 = phone(600); still(p0, "lock");
      const veil = el("div", "abs"); veil.style.cssText += ";width:100%;height:100%;background:#000";
      p0.querySelector(".screen").appendChild(veil);
      const h0 = headline(null, ["Ta journée.", "En un coup d'œil."], { color: "#fff", align: "center", x: 60, y: 200 });
      // 2. Sport.
      const w1 = wipe("cream", 2 * B - 0.25);
      const p1 = phone(560); const live = piece("live", 720);
      const h1 = headline("Sport", ["Chaque série", "compte."], { accent: "#E5484D" });
      // 3. Nutrition.
      const p2 = phone(560); const macros = piece("widget-macros-medium-light", 520); const ring = piece("widget-caloriesLeft-small-light", 300);
      const h2 = headline("Nutrition", ["Tes macros,", "en deux gestes."], { accent: "#F08A24" });
      // 4. Au quotidien.
      const p3 = phone(580);
      const h3 = headline("Au quotidien", ["Toute ta journée,", "sur un écran."], { accent: "#3366FF" });
      // 5. Studio.
      const p4 = phone(560); const s1 = piece("widget-nextSet-small-neon", 280), s2 = piece("widget-caloriesLeft-small-luxury", 280), s3 = piece("widget-habitStreak-small-aurora", 280);
      const h4 = headline("Studio", ["Des widgets", "à ton image."], { accent: "#8A3CFF" });
      // 6. Home Screens.
      const homes = ["home-aurore", "home-jade", "home-ocean"].map(n => { const p = phone(430); still(p, n); return p; });
      const h5 = headline("Écrans d'accueil", ["Ton iPhone,", "réinventé."], { accent: "#D9246A" });
      // 7. Budget, then icons.
      const p6 = phone(560); const h6 = headline("Budget", ["Ton argent,", "enfin clair."], { accent: "#1E9E75" });
      const p7 = phone(560); const h7 = headline("Jusqu'à l'icône", ["Ardane,", "à ton style."], { accent: "#D9246A" });
      const end = endCard(14 * B);

      window.draw = (t) => {
        // 1
        const o0 = 1 - seg(t, 2 * B - 0.2, 2 * B + 0.3);
        g0.style.display = t < 2 * B + 0.4 ? "block" : "none";
        const k0 = ease.out(seg(t, 0, 3.6));
        tf(p0, { x: W / 2 - 300, y: lerp(820, 640, k0), z: lerp(-500, 0, k0), rx: lerp(22, 6, k0), ry: lerp(-24, -8, k0), rz: lerp(-4, 0, k0), o: o0 });
        veil.style.opacity = 1 - seg(t, 0.35, 0.9); sweep(p0, t, 1.0, 1.6);
        h0.draw(t, 0.6, 2 * B);
        // 2
        w1(t);
        const a1 = 2 * B, b1 = 4 * B;
        if (t > a1 - 0.3 && t < b1 + 0.3) setImg(p1.img, cut("fitness.main", t - a1));
        const k1 = ease.out(seg(t, a1, a1 + 1.2)), x1 = ease.in(seg(t, b1 - 0.35, b1));
        tf(p1, { x: lerp(560, 420, k1) - x1 * 700, y: 640, ry: lerp(-24, -12, k1), rz: 2, o: win(t, a1, b1 + 0.1, 0.3, 0.3) });
        const kl = ease.back(seg(t, a1 + 0.8, a1 + 1.5));
        tf(live, { x: lerp(-760, 40, kl) - x1 * 900, y: 1330, rz: -3, s: 1, o: win(t, a1 + 0.8, b1 + 0.1, 0.2, 0.3) });
        h1.draw(t, a1 + 0.25, b1);
        // 3
        const a2 = 4 * B, b2 = 6 * B;
        if (t > a2 - 0.3 && t < b2 + 0.3) setImg(p2.img, cut("nutrition.main", t - a2));
        const k2 = ease.out(seg(t, a2, a2 + 1.2)), x2 = ease.in(seg(t, b2 - 0.35, b2));
        tf(p2, { x: lerp(-200, 90, k2) - x2 * 700, y: 640, ry: lerp(24, 12, k2), rz: -2, o: win(t, a2, b2 + 0.1, 0.3, 0.3) });
        const km = ease.back(seg(t, a2 + 0.9, a2 + 1.6)), kr = ease.back(seg(t, a2 + 1.2, a2 + 1.9));
        tf(macros, { x: lerp(1100, 520, km) - x2 * 900, y: 1150, rz: 3, o: win(t, a2 + 0.9, b2 + 0.1, 0.2, 0.3) });
        tf(ring, { x: lerp(1100, 700, kr) - x2 * 900, y: 760, rz: -4, o: win(t, a2 + 1.2, b2 + 0.1, 0.2, 0.3) });
        h2.draw(t, a2 + 0.25, b2);
        // 4
        const a3 = 6 * B, b3 = 8 * B;
        if (t > a3 - 0.3 && t < b3 + 0.3) setImg(p3.img, cut("quotidien.main", t - a3));
        const k3 = ease.out(seg(t, a3, a3 + 1.0)), x3 = ease.in(seg(t, b3 - 0.35, b3));
        tf(p3, { x: W / 2 - 290 - x3 * 800, y: lerp(900, 620, k3), rx: lerp(14, 0, k3), o: win(t, a3, b3 + 0.1, 0.3, 0.3) });
        h3.draw(t, a3 + 0.25, b3);
        // 5
        const a4 = 8 * B, b4 = 10 * B;
        if (t > a4 - 0.3 && t < b4 + 0.3) setImg(p4.img, cut("studio.main", t - a4));
        const k4 = ease.out(seg(t, a4, a4 + 1.2)), x4 = ease.in(seg(t, b4 - 0.35, b4));
        tf(p4, { x: lerp(620, 470, k4) - x4 * 800, y: 640, ry: lerp(-22, -10, k4), o: win(t, a4, b4 + 0.1, 0.3, 0.3) });
        [s1, s2, s3].forEach((s, i) => { const k = ease.back(seg(t, a4 + 0.8 + i * 0.25, a4 + 1.5 + i * 0.25)); const bob = Math.sin((t - a4) * 1.6 + i) * 10;
          tf(s, { x: lerp(-320, [70, 150, 40][i], k) - x4 * 900, y: [700, 1040, 1380][i] + bob, rz: [-6, 4, -3][i], o: win(t, a4 + 0.8 + i * 0.25, b4 + 0.1, 0.2, 0.3) }); });
        h4.draw(t, a4 + 0.25, b4);
        // 6
        const a5 = 10 * B, b5 = 12 * B;
        homes.forEach((p, i) => { const k = ease.back(seg(t, a5 + i * 0.3, a5 + 0.9 + i * 0.3)); const x5 = ease.in(seg(t, b5 - 0.35, b5));
          tf(p, { x: [80, 325, 570][i], y: lerp(1950, [780, 700, 780][i], k) + x5 * 1300, rz: [-7, 0, 7][i], z: i === 1 ? 60 : 0, o: win(t, a5, b5 + 0.1, 0.2, 0.3) }); });
        homes.forEach((p, i) => sweep(p, t, a5 + 1.4 + i * 0.2, 1.2));
        h5.draw(t, a5 + 0.25, b5);
        // 7
        const a6 = 12 * B, m6 = 13 * B, b6 = 14 * B;
        if (t > a6 - 0.3 && t < m6 + 0.3) setImg(p6.img, cut("finances.main", t - a6));
        const k6 = ease.out(seg(t, a6, a6 + 0.9)), x6 = ease.in(seg(t, m6 - 0.3, m6));
        tf(p6, { x: W / 2 - 280 - x6 * 800, y: lerp(900, 640, k6), o: win(t, a6, m6 + 0.1, 0.3, 0.3) });
        h6.draw(t, a6 + 0.2, m6);
        if (t > m6 - 0.3 && t < b6 + 0.3) setImg(p7.img, cut("icons.main", t - m6));
        const k7 = ease.out(seg(t, m6, m6 + 0.9));
        tf(p7, { x: lerp(1100, W / 2 - 280, k7), y: 640, ry: lerp(-30, 0, k7), o: win(t, m6, b6 + 0.6, 0.2, 0.4) });
        h7.draw(t, m6 + 0.2, b6 + 0.2);
        end(t);
      };
    } },

  // ---------------------------------------------------------------- 2. Short, 15 s
  short: { duration: 15, music: { sections: [[1, 1], [4, 3], [1, 0]], impact: 12.0 },
    sfx: [["lock", 0.25], ["whoosh", 2.15], ["snap", 3.0], ["tap", 3.3], ["whoosh", 4.55], ["tap", 5.5], ["whoosh", 6.95], ["snap", 7.5], ["snap", 7.8], ["snap", 8.1], ["whoosh", 9.35], ["chime", 13.4]],
    build: function () {
      const B = 2.4;
      const g0 = ground("night"); const p0 = phone(600); still(p0, "lock");
      const veil = el("div", "abs"); veil.style.cssText += ";width:100%;height:100%;background:#000"; p0.querySelector(".screen").appendChild(veil);
      const h0 = headline(null, ["Ta journée,", "en widgets."], { color: "#fff", align: "center", x: 60, y: 200 });
      const w1 = wipe("cream", B - 0.25);
      const p1 = phone(560); const live = piece("live", 720); const h1 = headline("Sport", ["Chaque série compte."], { accent: "#E5484D", size: 84 });
      const p2 = phone(560); const macros = piece("widget-macros-medium-light", 520); const h2 = headline("Nutrition", ["Tes macros, sans effort."], { accent: "#F08A24", size: 84 });
      const homes = ["home-aurore", "home-jade", "home-ocean"].map(n => { const p = phone(430); still(p, n); return p; });
      const h3 = headline("Écrans d'accueil", ["Ton iPhone, réinventé."], { accent: "#D9246A", size: 84 });
      const p4 = phone(560); const h4 = headline("Studio", ["À ton image."], { accent: "#8A3CFF", size: 84 });
      const end = endCard(5 * B);
      window.draw = (t) => {
        g0.style.display = t < B + 0.4 ? "block" : "none";
        const k0 = ease.out(seg(t, 0, 2.4));
        tf(p0, { x: W / 2 - 300, y: lerp(800, 640, k0), z: lerp(-400, 0, k0), rx: lerp(20, 6, k0), ry: lerp(-20, -8, k0), o: 1 - seg(t, B - 0.2, B + 0.3) });
        veil.style.opacity = 1 - seg(t, 0.25, 0.7); sweep(p0, t, 0.8, 1.3); h0.draw(t, 0.4, B);
        w1(t);
        const a1 = B, b1 = 2 * B;
        if (t > a1 - 0.3 && t < b1 + 0.3) setImg(p1.img, cut("fitness.short", t - a1));
        const k1 = ease.out(seg(t, a1, a1 + 1)), x1 = ease.in(seg(t, b1 - 0.3, b1));
        tf(p1, { x: lerp(560, 420, k1) - x1 * 700, y: 640, ry: lerp(-24, -12, k1), o: win(t, a1, b1 + 0.1, 0.25, 0.3) });
        tf(live, { x: lerp(-760, 40, ease.back(seg(t, a1 + 0.5, a1 + 1.1))) - x1 * 900, y: 1330, rz: -3, o: win(t, a1 + 0.5, b1 + 0.1, 0.2, 0.3) });
        h1.draw(t, a1 + 0.2, b1);
        const a2 = 2 * B, b2 = 3 * B;
        if (t > a2 - 0.3 && t < b2 + 0.3) setImg(p2.img, cut("nutrition.short", t - a2));
        const k2 = ease.out(seg(t, a2, a2 + 1)), x2 = ease.in(seg(t, b2 - 0.3, b2));
        tf(p2, { x: lerp(-200, 90, k2) - x2 * 700, y: 640, ry: lerp(24, 12, k2), o: win(t, a2, b2 + 0.1, 0.25, 0.3) });
        tf(macros, { x: lerp(1100, 520, ease.back(seg(t, a2 + 0.5, a2 + 1.1))) - x2 * 900, y: 1150, rz: 3, o: win(t, a2 + 0.5, b2 + 0.1, 0.2, 0.3) });
        h2.draw(t, a2 + 0.2, b2);
        const a3 = 3 * B, b3 = 4 * B;
        homes.forEach((p, i) => { const k = ease.back(seg(t, a3 + i * 0.25, a3 + 0.8 + i * 0.25)); const x3 = ease.in(seg(t, b3 - 0.3, b3));
          tf(p, { x: [80, 325, 570][i], y: lerp(1950, [780, 700, 780][i], k) + x3 * 1300, rz: [-7, 0, 7][i], o: win(t, a3, b3 + 0.1, 0.2, 0.3) }); });
        h3.draw(t, a3 + 0.2, b3);
        const a4 = 4 * B, b4 = 5 * B;
        if (t > a4 - 0.3 && t < b4 + 0.3) setImg(p4.img, cut("studio.short", t - a4));
        const k4 = ease.out(seg(t, a4, a4 + 0.9));
        tf(p4, { x: W / 2 - 280, y: lerp(900, 640, k4), o: win(t, a4, b4 + 0.6, 0.25, 0.4) });
        h4.draw(t, a4 + 0.2, b4 + 0.2);
        end(t);
      };
    } },

  // ---------------------------------------------------------------- 3. Very short, 8 s
  tiny: { duration: 8, music: { sections: [[1, 3], [1, 4], [1, 0]], impact: 4.8 },
    sfx: [["snap", 0.4], ["snap", 0.7], ["snap", 1.0], ["whoosh", 2.15], ["chime", 6.2]],
    build: function () {
      const B = 2.4;
      const g = ground("cream");
      const homes = ["home-aurore", "home-jade", "home-ocean"].map(n => { const p = phone(430); still(p, n); return p; });
      const h0 = headline(null, ["Ton iPhone,", "à ta façon."], { align: "center", x: 60, y: 200 });
      const p1 = phone(580);
      const end = endCard(2 * B, { tagline: "Ta vie, en widgets." });
      window.draw = (t) => {
        homes.forEach((p, i) => { const k = ease.back(seg(t, 0.2 + i * 0.3, 1.0 + i * 0.3)); const x = ease.in(seg(t, B - 0.3, B));
          tf(p, { x: [80, 325, 570][i], y: lerp(1950, [780, 700, 780][i], k) + x * 1300, rz: [-7, 0, 7][i], o: win(t, 0, B + 0.1, 0.1, 0.3) }); });
        h0.draw(t, 0.1, 2 * B);
        if (t > B - 0.3 && t < 2 * B + 0.3) setImg(p1.img, cut("studio.short", t - B));
        const k1 = ease.out(seg(t, B, B + 0.8));
        tf(p1, { x: W / 2 - 290, y: lerp(900, 620, k1), o: win(t, B, 2 * B + 0.6, 0.2, 0.4) });
        end(t);
      };
    } },

  // ---------------------------------------------------------------- 4. Fitness, 20 s
  fitness: { duration: 20, music: { sections: [[2, 2], [4, 4], [2, 0]], impact: 14.4 },
    sfx: [["lock", 0.3], ["snap", 2.8], ["whoosh", 4.55], ["tap", 9.2], ["tap", 11.0], ["whoosh", 11.8], ["snap", 12.5], ["snap", 12.75], ["chime", 15.8]],
    build: function () {
      const B = 2.4;
      const g0 = ground("gym"); const p0 = phone(600); still(p0, "lock");
      const veil = el("div", "abs"); veil.style.cssText += ";width:100%;height:100%;background:#000"; p0.querySelector(".screen").appendChild(veil);
      const live = piece("live", 900);
      const h0 = headline("Écran verrouillé", ["Série faite ?", "Un geste."], { color: "#fff", accent: "#FF6B57" });
      const w1 = wipe("cream", 2 * B - 0.25);
      const p1 = phone(580); const h1 = headline("Ta séance", ["Chaque série,", "chaque repos."], { accent: "#E5484D" });
      const p2 = phone(520); const next = piece("widget-nextSet-small-light", 330); const streak = piece("widget-todaysWorkout-medium-light", 560);
      const h2 = headline("Tes widgets", ["Ton programme,", "sous les yeux."], { accent: "#E5484D" });
      const end = endCard(6 * B, { tagline: "Ton sport, en widgets." });
      window.draw = (t) => {
        g0.style.display = t < 2 * B + 0.4 ? "block" : "none";
        const k0 = ease.out(seg(t, 0, 2.6));
        const zoom = ease.inOut(seg(t, 2.2, 4.2));
        tf(p0, { x: W / 2 - 300, y: lerp(820, 640, k0) - zoom * 120, z: lerp(-400, 0, k0), rx: lerp(18, 4, k0), ry: lerp(-18, -6, k0), o: 1 - seg(t, 2 * B - 0.2, 2 * B + 0.2) - zoom * 0.55 });
        veil.style.opacity = 1 - seg(t, 0.3, 0.8); sweep(p0, t, 0.9, 1.4);
        tf(live, { x: W / 2 - 450, y: lerp(1500, 1180, ease.back(seg(t, 2.3, 3.2))), s: lerp(0.9, 1, zoom), o: win(t, 2.3, 2 * B + 0.2, 0.25, 0.3) });
        h0.draw(t, 0.5, 2 * B);
        w1(t);
        const a1 = 2 * B, b1 = 5 * B;
        if (t > a1 - 0.3 && t < b1 + 0.3) setImg(p1.img, cut("fitness.film", t - a1));
        const k1 = ease.out(seg(t, a1, a1 + 1.2)), x1 = ease.in(seg(t, b1 - 0.35, b1));
        tf(p1, { x: W / 2 - 290 - x1 * 800, y: lerp(900, 620, k1), rx: lerp(12, 0, k1), o: win(t, a1, b1 + 0.1, 0.3, 0.3) });
        h1.draw(t, a1 + 0.25, b1);
        const a2 = 5 * B, b2 = 6 * B;
        if (t > a2 - 0.3 && t < b2 + 0.3) setImg(p2.img, clip("fitness", 0, 22.0));
        const k2 = ease.out(seg(t, a2, a2 + 0.9));
        tf(p2, { x: lerp(1100, 530, k2), y: 640, ry: -14, o: win(t, a2, b2 + 0.4, 0.2, 0.4) });
        tf(next, { x: lerp(-400, 50, ease.back(seg(t, a2 + 0.4, a2 + 1.0))), y: 700, rz: -5, o: win(t, a2 + 0.4, b2 + 0.4, 0.2, 0.4) });
        tf(streak, { x: lerp(-700, 40, ease.back(seg(t, a2 + 0.6, a2 + 1.2))), y: 1420, rz: 3, o: win(t, a2 + 0.6, b2 + 0.4, 0.2, 0.4) });
        h2.draw(t, a2 + 0.2, b2 + 0.2);
        end(t);
      };
    } },

  // ---------------------------------------------------------------- 5. Nutrition, 20 s
  nutrition: { duration: 20, music: { sections: [[2, 1], [4, 3], [2, 0]], impact: 14.4 },
    sfx: [["whoosh", 0.2], ["tap", 2.6], ["chime", 2.95], ["whoosh", 4.55], ["tap", 6.9], ["tap", 7.7], ["tap", 9.0], ["whoosh", 11.8], ["snap", 12.6], ["snap", 12.85], ["chime", 15.8]],
    build: function () {
      const B = 2.4;
      // 1. A packaged product's barcode, and the scanner's aiming square locking on it (a drawing,
      // not the camera: the real scanner reads EAN/UPC barcodes of packaged foods).
      const g0 = ground("night");
      const label = el("div", "abs"); label.style.cssText += ";width:640px;height:420px;border-radius:36px;background:#FBF8F3;box-shadow:0 40px 80px rgba(0,0,0,.45)";
      const bars = [...Array(46)].map((_, i) => '<i style="display:inline-block;height:210px;margin-right:' + (2 + (i * 7) % 5) + 'px;width:' + (2 + (i * 13) % 6) + 'px;background:#141214"></i>').join("");
      label.innerHTML = '<div style="position:absolute;left:70px;top:70px;font-family:Text;font-size:28px;color:#6B6460;letter-spacing:2px">PRODUIT EMBALLÉ</div>' +
        '<div style="position:absolute;left:70px;top:130px;white-space:nowrap">' + bars + '</div>' +
        '<div style="position:absolute;left:70px;top:350px;font-family:TextM;font-size:30px;color:#3A3532;letter-spacing:10px">3 017620 422003</div>';
      const frame = el("div", "abs"); frame.style.cssText += ";width:560px;height:340px";
      frame.innerHTML = ['left:0;top:0;border-width:10px 0 0 10px;border-radius:40px 0 0 0', 'right:0;top:0;border-width:10px 10px 0 0;border-radius:0 40px 0 0', 'left:0;bottom:0;border-width:0 0 10px 10px;border-radius:0 0 0 40px', 'right:0;bottom:0;border-width:0 10px 10px 0;border-radius:0 0 40px 0']
        .map(s => '<i style="position:absolute;width:90px;height:90px;border-style:solid;border-color:#FF7A59;' + s + '"></i>').join("") +
        '<b style="position:absolute;left:30px;right:30px;height:4px;background:#FF7A59;box-shadow:0 0 24px #FF7A59;top:50%"></b>';
      const scanLine = frame.querySelector("b");
      const h0 = headline("Scan", ["Un code-barres,", "et c'est noté."], { color: "#fff", accent: "#FF9A3D" });
      const w1 = wipe("cream", 2 * B - 0.25);
      const p1 = phone(580); const h1 = headline("Ton repas", ["Tes calories,", "en deux gestes."], { accent: "#F08A24" });
      const p2 = phone(520); const macros = piece("widget-macros-medium-light", 540); const chip = piece("chip", 560);
      const h2 = headline("Tes widgets", ["Tes macros,", "d'un regard."], { accent: "#F08A24" });
      const end = endCard(6 * B, { tagline: "Ta nutrition, en widgets." });
      window.draw = (t) => {
        g0.style.display = t < 2 * B + 0.4 ? "block" : "none";
        const kl = ease.out(seg(t, 0, 1.4)); const o0 = 1 - seg(t, 2 * B - 0.25, 2 * B + 0.1);
        tf(label, { x: W / 2 - 320, y: lerp(1300, 980, kl), rx: lerp(30, 8, kl), rz: lerp(-6, -2, kl), o: kl * o0 });
        const kf = ease.back(seg(t, 1.3, 2.0)); const lock = seg(t, 2.6, 2.75);
        tf(frame, { x: W / 2 - 280, y: 1020, s: lerp(1.4, 1, kf) * (1 - lock * 0.04), o: seg(t, 1.3, 1.6) * o0 });
        scanLine.style.top = (50 + Math.sin(t * 5) * 38 * (1 - lock)) + "%"; scanLine.style.opacity = 1 - lock * 0.7;
        h0.draw(t, 0.4, 2 * B);
        w1(t);
        const a1 = 2 * B, b1 = 5 * B;
        if (t > a1 - 0.3 && t < b1 + 0.3) setImg(p1.img, cut("nutrition.film", t - a1));
        const k1 = ease.out(seg(t, a1, a1 + 1.2)), x1 = ease.in(seg(t, b1 - 0.35, b1));
        tf(p1, { x: W / 2 - 290 - x1 * 800, y: lerp(900, 620, k1), rx: lerp(12, 0, k1), o: win(t, a1, b1 + 0.1, 0.3, 0.3) });
        h1.draw(t, a1 + 0.25, b1);
        const a2 = 5 * B, b2 = 6 * B;
        if (t > a2 - 0.3 && t < b2 + 0.3) still(p2, "lock-plain");
        const k2 = ease.out(seg(t, a2, a2 + 0.9));
        tf(p2, { x: lerp(1100, 470, k2), y: 680, ry: -14, o: win(t, a2, b2 + 0.4, 0.2, 0.4) });
        tf(macros, { x: lerp(-600, 40, ease.back(seg(t, a2 + 0.4, a2 + 1.0))), y: 1260, rz: -4, o: win(t, a2 + 0.4, b2 + 0.4, 0.2, 0.4) });
        tf(chip, { x: lerp(-600, 60, ease.back(seg(t, a2 + 0.6, a2 + 1.2))), y: 820, rz: 3, o: win(t, a2 + 0.6, b2 + 0.4, 0.2, 0.4) });
        h2.draw(t, a2 + 0.2, b2 + 0.2);
        end(t);
      };
    } },
};
