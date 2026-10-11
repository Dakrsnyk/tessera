// Ardane campaign renderer: each film is a timeline of shots drawn in HTML/CSS (1080 × 1920, 30 fps),
// captured frame by frame by Chromium, then encoded by ffmpeg with the music and sound effects.
//
//   node engine.js <film> <assets dir> <out dir> [--preview N]   (needs Playwright and Chromium)
//
// Real screens only: phone screens show the app's own recordings (frames extracted from the CI
// videos, which carry the Dynamic Island) or its own drawings (lock screen, Home Screens, widgets), never an invented interface.
const fs = require("fs");
const path = require("path");
const { chromium } = require(process.env.PLAYWRIGHT || "playwright");

const W = 1080, H = 1920, FPS = 30;
const [film, assets, out, flag, flagValue] = process.argv.slice(2);
const preview = flag === "--preview" ? Number(flagValue) : null;
const FILMS = require("./films.js");
const spec = FILMS[film];
if (!spec) throw new Error("unknown film " + film);

const font = (f) => "file:///usr/share/fonts/opentype/inter/" + f;
const page = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Disp;src:url(${font("InterDisplay-Bold.otf")})}
@font-face{font-family:DispX;src:url(${font("InterDisplay-ExtraBold.otf")})}
@font-face{font-family:Text;src:url(${font("Inter-SemiBold.otf")})}
@font-face{font-family:TextM;src:url(${font("Inter-Medium.otf")})}
html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:#000}
#stage{position:relative;width:${W}px;height:${H}px;overflow:hidden;perspective:2600px}
.layer{position:absolute;inset:0}
.abs{position:absolute;left:0;top:0;transform-origin:50% 50%;will-change:transform,opacity}
.phone{transform-style:preserve-3d}
.phone .body{position:absolute;inset:0;border-radius:15.5%/7.1%;background:linear-gradient(145deg,#4a4d54,#17181b 40%,#2b2d31);padding:2.1%;box-sizing:border-box;
  box-shadow:0 60px 120px rgba(20,16,24,.35),0 18px 40px rgba(20,16,24,.25),inset 0 0 0 2px rgba(255,255,255,.12)}
.phone .screen{position:relative;width:100%;height:100%;border-radius:13.6%/6.3%;overflow:hidden;background:#000}
.phone .screen img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.phone .island{position:absolute;top:1.55%;left:50%;width:31%;height:3.55%;margin-left:-15.5%;border-radius:999px;background:#000}
.phone .glare{position:absolute;inset:0;border-radius:13.6%/6.3%;background:linear-gradient(115deg,transparent 35%,rgba(255,255,255,.16) 47%,transparent 60%);mix-blend-mode:screen}
.eyebrow{font-family:Text;font-size:30px;letter-spacing:6px;text-transform:uppercase}
.title{font-family:Disp;font-size:96px;line-height:1.02;letter-spacing:-3px;white-space:pre}
.line{display:block;overflow:hidden;padding-bottom:.08em}
.line>span{display:inline-block}
.card{border-radius:42px;overflow:hidden}
</style></head><body><div id="stage"></div>
<script>
const W=${W},H=${H};
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
const seg=(t,a,b)=>clamp((t-a)/(b-a));
const ease={out:x=>1-Math.pow(1-x,3),in:x=>x*x*x,inOut:x=>x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2,
  expo:x=>x===1?1:1-Math.pow(2,-10*x),back:x=>{const c=1.4;return 1+(c+1)*Math.pow(x-1,3)+c*Math.pow(x-1,2)},
  soft:x=>1-Math.pow(1-x,2)};
const lerp=(a,b,x)=>a+(b-a)*x;
const stage=document.getElementById('stage');
const el=(tag,cls,parent=stage,html='')=>{const e=document.createElement(tag);if(cls)e.className=cls;e.innerHTML=html;parent.appendChild(e);return e};
window.__waits=[];
function setImg(img,src){if(img.dataset.src===src)return;img.dataset.src=src;img.src=src;window.__waits.push(img.decode().catch(()=>{}))}
function tf(e,{x=0,y=0,z=0,s=1,rx=0,ry=0,rz=0,o=1,blur=0}){e.style.transform='translate3d('+x+'px,'+y+'px,'+z+'px) rotateX('+rx+'deg) rotateY('+ry+'deg) rotateZ('+rz+'deg) scale('+s+')';e.style.opacity=o;e.style.filter=blur>0.05?'blur('+blur+'px)':'none';e.style.display=o<=0.001?'none':'block'}
function phone(w){const p=el('div','abs phone');p.style.width=w+'px';p.style.height=(w*2.1248)+'px';
  p.innerHTML='<div class="body"><div class="screen"><img><div class="glare"></div></div></div>';p.img=p.querySelector('img');p.glare=p.querySelector('.glare');p.w=w;p.h=w*2.1248;return p}
function text(cls,lines,color,align='left'){const t=el('div','abs');t.style.color=color;t.style.textAlign=align;
  t.innerHTML=lines.map(l=>'<div class="'+cls+'"><span class="line"><span>'+l+'</span></span></div>').join('');t.spans=[...t.querySelectorAll('.line>span')];return t}
function reveal(t,x,stagger=.12){t.spans.forEach((s,i)=>{const k=ease.expo(clamp(x*1.0-i*stagger,0,1)/1);s.style.transform='translateY('+((1-k)*110)+'%)'})}
</script></body></html>`;

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || "/opt/pw-browsers/chromium", args: ["--disable-web-security", "--allow-file-access-from-files"] });
  const p = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const file = path.resolve(out, "page.html");
  fs.writeFileSync(file, page);
  await p.goto("file://" + file);
  await p.evaluate(() => document.fonts.ready);
  // The film builds its elements once, then draws any time t.
  const infoFile = path.join(assets, "clips.json");
  const info = fs.existsSync(infoFile) ? JSON.parse(fs.readFileSync(infoFile, "utf8")) : { counts: {}, start: {} };
  await p.evaluate(`window.ASSETS=${JSON.stringify("file://" + path.resolve(assets) + "/")};window.CLIPS=${JSON.stringify(info.counts)};window.START=${JSON.stringify(info.start)};(${FILMS.common.toString()})();(${spec.build.toString()})();`);
  const frames = Math.round(spec.duration * FPS);
  const list = preview != null ? [Math.round(preview * FPS)] : [...Array(frames).keys()];
  for (const f of list) {
    const t = f / FPS;
    await p.evaluate(async (t) => { window.__waits = []; window.draw(t); await Promise.all(window.__waits); }, t);
    if (preview != null) await p.screenshot({ path: path.join(out, `preview-${String(preview).replace(".", "_")}.png`) });
    else await p.screenshot({ path: path.join(out, `f${String(f).padStart(5, "0")}.jpg`), type: "jpeg", quality: 95 });
    if (f % 60 === 0) process.stdout.write(`${film} ${t.toFixed(1)}s\n`);
  }
  await browser.close();
})();
