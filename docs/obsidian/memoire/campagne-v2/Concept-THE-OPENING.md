---
tags: [ardane, memoire]
---

# THE OPENING — Ardane campaign creative direction (Apple product-film angle)

Angle: restraint and precision. A black void, one warm line of light, the iPhone treated as a sculpted object, a slow and confident camera, one idea per shot, type used as architecture. The vertical gap between the two halves of Ardane's « A » becomes the light, the transition and the sound of the whole campaign.

Sources: `brief/brief.md` (requirements) and `brief/facts.md` (what really exists). Fluidity rules come from `audit/R-framerate.json`. Data quirks come from the domain audits `audit/R-*.json`. Store setup ids and widget kinds were checked in `App/Screens/Explore/HomeSetups.swift` and `audit/kinds.tsv`.

---

## 0. Why the previous films felt amateur, and what replaces each fault

| Previous film (`ad/out/*`) | Effect on the viewer | This direction |
|---|---|---|
| Cream or tinted backgrounds, a flat phone at the bottom, a French headline at the top, the same layout in every shot | Reads as App Store screenshots in a slideshow, not a film | A black void and one light source. Every shot has its own composition across 3 to 5 depth planes. |
| The UI shown at about 1/3 scale inside the phone | Nobody can read it on a phone | Whatever the VO names leaves the phone and is shown at readable size (see the minimum sizes in 2.5) |
| Simulator recordings at 8–14 fps, resampled to 30 fps by nearest neighbour, ×1.4 playback, jumps inside a still phone, no motion blur | Stutter, frozen screens, a strobe effect | 60 fps CFR on an integer frame timeline. UI motion is rebuilt from real stills with iOS curves at 1× speed. Motion blur comes from sub-frame accumulation. No cut ever happens inside a still phone. |
| Type that just fades in, in French | Feels like a template | English supers that are built out of the seam (2.6), one at a time, always staged |
| Each shot is a separate idea | Nothing connects; nothing to remember | One device, the line, joins every shot and is itself the logo |
| The logo appears only at the end | No brand recall during the film | The gap of the « A » is on screen the whole time: as a light, as each transition, and in the sound logo |
| A generic music bed | Nothing lands | Original score at 120 BPM. Hits sit on frame-exact events, and the countdown ticks fall on the beat. |

---

## 1. Concept

**Name: THE OPENING**

**One sentence:** In a black void, a single vertical line of light (the gap in Ardane's « A ») opens the iPhone. Each essential of your day steps out through it, into the light and at a size you can read, then goes back home. At the end the line closes and becomes the logo.

**The thought behind it.** The « A » is two halves with a space between them. The white half is your day; the peach half is you. Ardane is the space between them, the place where the light comes through. So every transition in the campaign is that space opening, and the phone is where it opens.

**Tagline options (English)**
1. **Life's essentials, designed around you.** (primary end line)
2. **Your day, in your light.**
3. **Make room for what matters.**

**Why it is distinctive for Ardane**
- **The device is the logo.** Every transition replays the gap of the « A », so the brand is present for 58 seconds without showing a logo. Competitors cannot use this asset.
- **It shows what the product actually is.** Ardane's essentials live outside the app, on the Home Screen and the Lock Screen. The line marks the border between the app and your phone, and the film's main action is crossing it.
- **It fixes readability by design.** Features always come out toward the viewer at readable scale, so the tiny-screen problem is solved by the concept rather than patched.
- **It stays honest.** The light frames real pixels and never draws UI. State changes happen as a light blade passing between two real captures.
- **It can be built.** A line, masks, glows and planes in depth, plus one procedural phone. No hands, no people, no photoreal food. This fits CPU rendering.
- **It stands apart.** A black void with one warm light is the opposite of the pastel, cream and gradient look of habit-app ads, including our own previous films.

---

## 2. Visual identity

### 2.1 Palette
| Role | Hex | Use |
|---|---|---|
| Void | `#000000` | Base of every frame. Add 1.2 % monochrome grain to every frame to prevent banding. |
| Lifted void | `#07070A` | A radial behind the phone, 900 px, 6 % |
| Floor | `#0C0C0F` | Glossy plane with a 22 % blurred reflection |
| Plinth | `#1C1C1F` | Pedestals for the exercise demos and the product |
| Titanium | `#8A8781` base · `#CFCAC2` highlight · `#3B3936` shadow | Phone rails |
| Seam core | `#FFFFFF` | 2 px core of the line |
| Seam warm | `#FFF4EC` | Key light colour (5200 K) |
| Peach | `#FFE0CC` | Inner glow of the seam; right half of the « A » |
| Coral | `#FF7A59` | Outer bloom of the seam (≤ 25 %) |
| Raspberry | `#D9246A` | Far bloom of the seam (≤ 8 %) |
| Type primary | `#F5F5F7` | Supers |
| Type secondary | `#A1A1A6` | Eyebrows, tagline |
| Type tertiary | `#6E6E73` | Rare: legal line |
| Hairline | `#FFFFFF` at 35–40 % | Callout leaders, exploded-view guides |
| Daylight pool (Nutrition) | `#F2F2F4` falling off to `#000000` | The only bright surface in the campaign |

**Colour rule:** the environment has no colour. Colour comes only from the real UI and from the seam. The ambient tint of a shot is the average colour of the foreground widget, desaturated 40 %, at most 6 % spill. Examples: Fitness red `#E5484D`, Nutrition accent `#2F8F7A`. Sample the tint from the final capture, never pick it by hand.

### 2.2 Light design
- **Key light, "the Seam":** a tall vertical strip softbox in warm white, 30° camera-left. On titanium it draws one vertical highlight line, which echoes the « A ». Every phone reflection is a vertical line. We never use a diagonal flare.
- **Top strip:** narrow, cool (6500 K), 20 %. It draws a fine line on the top rail.
- **Practical:** the screen is the second light source. Its glow spills onto the floor reflection and, faintly, onto the underside of a lifted widget.
- **Light sweep:** a vertical band at 18 % crosses the phone glass left to right in 30 frames, used only at reveals and always on a beat.
- **Bloom:** threshold 0.85, radius 24 px, intensity 0.35. It is applied to the seam and the metal highlights only, with UI pixels masked out.
- **Screen pixels are never graded.** The screen and the lifted UI are rendered in their own pass and composited untouched (sRGB, no tone mapping). Only the glass reflection layer sits on top, at ≤ 8 %.

### 2.3 Materials
- **Titanium rails:** three.js `MeshPhysicalMaterial`: metalness 1, roughness 0.32, anisotropy 0.6. The environment map is a procedural studio (two vertical emissive strips and one top strip on black, rendered once into a cube map), so every reflection reads as a vertical line.
- **Front glass:** no transmission (too expensive on CPU). Instead, an additive reflection layer (a soft vertical streak texture) at 6–10 % plus a Fresnel rim of 1 px.
- **Back glass:** frosted `#2A2926`, roughness 0.6. It is only glimpsed during the edge-on turns.
- **Screen:** an emissive plane with the real PNG. The simctl captures already contain the black Dynamic Island area (`audit/R-personalization.json` §3), so the phone model does not draw a second one. Crop the last 2 pixel rows of captures (2620–2621).
- **Lifted widget:** the real PNG, unaltered, plus a 1 px inner highlight on the top edge (white 14 %) and a contact shadow on the plane behind it (y +30 px, blur 60 px, black 50 %, fading as distance grows). We never add blur, glass or texture to a widget's own background: that would change its real style.
- **Floor:** black mirror. The reflection is a vertical flip, blurred 12 px, fading from 35 % to 0 over 300 px, at 22 % opacity.
- **Product prop (Nutrition):** a matte white tub (lathe geometry), roughness 0.55. The label reads "GREEK YOGURT 0%" in Inter with a fictional EAN-13. No real brand.

### 2.4 Depth layering rules
| Plane | Content | Focus and treatment |
|---|---|---|
| L0 void | Black, radial lift, grain | Never in focus |
| L1 atmosphere | Strata slats or the constellation of real widgets | Blur 10–14 px, 25–40 % luminance |
| L2 phone | The hero object, z = 0 | Sharp except while a widget is lifted: then blur 8 px and dim to 55 % |
| L3 lifted UI | Widget, pane, Live Activity, demo figure (z +300 to +900) | Sharp and still while it is being read |
| L4 type | Supers, callouts | Always sharp, in its own screen-space plane, never overlapping UI data |
| L5 light | Seam, sweep, a few dust motes (max 12) | Additive |

- At most **three sharp elements** on screen. Only **one plane in focus**. A focus pull takes 18–24 frames.
- Depth of field is approximated per plane with a Gaussian blur. The maximum is 14 px at 1080 px width; bokeh shapes appear only on L1.
- Parallax: L1 moves at 0.3× and L3 at 1.2× of the phone's screen-space motion.

### 2.5 Readability rules (non-negotiable)
- When the VO names a feature, its UI is either **lifted** or framed **macro** on the phone, and it stays **sharp and still for at least 1.2 s**. Drift is allowed only below 4 px/s.
- Minimum sizes on the 1080×1920 master:
  - App screen pane: at least 880 px wide (≈ 2.24 px/pt, so 17 pt body text ≈ 38 px).
  - Medium widget: at least 940 px wide.
  - Small widget: at least 560 px wide.
  - Live Activity: at least 1000 px wide.
  - Smallest relevant label: at least 28 px tall.
- Sources: widgets rendered at 4×, screens at 3× (simctl 1206 px), pre-scaled with Lanczos to the size they are shown at. If a layer is shown above 1.0× of its source, re-render the source; never upscale.
- Social safe zone (9:16): supers and CTA stay inside x 90–990 and y 250–1420. Keep clear of the bottom 400 px and the right 140 px.

### 2.6 Typography system
Fonts: Inter, using the 32 optical size (the Display cut) for supers and the text cut for small labels. All type is English. The UI stays French.

| Style | Spec | Use |
|---|---|---|
| H0 hero word | Inter Display Bold 132 px, tracking −0.03 em | "Money." "Week." "Habits." "Make it yours." |
| H1 super | Inter Display SemiBold 88 px, line-height 1.04, tracking −0.02 em, max width 860 px, max 2 lines | "Designed around you." etc. |
| Eyebrow / callout | Inter SemiBold 25 px, caps, tracking +0.14 em, `#A1A1A6`; hairline leader 1.5 px at 40 % ending in a 7 px dot on the UI target | English labels for French UI ("SET DONE", "SCANNER") |
| Wordmark | Inter Display SemiBold 120 px, −0.02 em | End card |
| Tagline | Inter Regular 40 px, `#A1A1A6` | End card |
| CTA | Inter Medium 32 px in a hairline capsule (1.5 px, height 76 px, radius 38 px) | "Coming soon to the App Store" |

**Type as architecture:**
- Every super is centred on the seam axis (x = 540).
- Eyebrows hang off hairlines that connect to real UI points; they are never free-floating.
- Exploded-view guides join the corners of the layers like an architectural drawing.

**Motion of type, "Split from the seam":**
- A 2 px line flashes at x = 540 for 8 frames.
- The line of text opens from the centre: the left half slides from +40 px to 0 and the right half from −40 px to 0, behind a mask widening from the axis. This takes 24 frames on `cubic-bezier(0.16, 1, 0.3, 1)`, with opacity 0→1 over the first 10 frames.
- Exit is either the reverse (halves close into the seam, 18 frames, ease-in) or a 12-frame fade with a 6 px blur. Never both.
- Hero words (S6) cut in on the beat with a 6-frame opacity and blur rack.
- Never: typewriter effects, per-letter bounce, 3D extruded type, or text scaled above 1.0 (it softens). Type is rendered at 2× and downsampled.

### 2.7 Camera language
- **Lenses** (vertical FOV on a 36 mm vertical gate): 85 mm = 23.9° (default hero), 50 mm = 39.6° (wides: S2 strata, S7 gather), 135 mm = 15.2° (macro: Lock Screen, Scanner pill, habit check).
- **Moves:**
  - Dolly-in at most 4 % scale per second in calm sections and 8 % in Fitness.
  - Orbit at most 30° per 2 s. Roll at most 2°.
  - Arrivals use `cubic-bezier(0.25, 0.1, 0, 1)`; transfers use `cubic-bezier(0.65, 0, 0.35, 1)`. Every move has a long tail. Nothing starts or stops dead.
- **Speed:** large elements peak at 2,400 px/s on screen. Exits take 0.5–0.7 s ease-in-out, never a 0.35 s ease-in.
- **Motion blur:** 8 sub-frames on a 180° shutter, used whenever displacement exceeds 16 px per frame. Implemented with Remotion `CameraMotionBlur` (samples 8) on flagged ranges only, to keep CPU time down.
- **Cuts:** a cut happens only at a seam event, or hidden inside a camera move. Never inside a still phone, and the UI never changes while the camera is static unless a designed transition carries the change.

### 2.8 Signature devices (the grammar; each has one meaning)
| Device | Meaning | Mechanics (60 fps) |
|---|---|---|
| **The Line** | Beginning, ending, breath | The phone seen exactly edge-on is a vertical line of light: the rail catches the Seam key. Turning it face-on reveals the phone; turning it edge-on closes a chapter. It opens the film, links Fitness to the Lock Screen, and becomes the logo. |
| **Lift / Dock** | "This is the feature" | f0–6: a 2 px blade draws down the left edge of the widget on the glass. f6–18: the blade crosses the widget, which takes a +8 % exposure lift and a top rim. f12–48: the widget detaches to z +600…+900 on a slight arc (rises 40 px, settles), `(0.3,0,0.1,1)`, with motion blur, and its shadow on the glass grows and fades. Behind it, the empty slot glows as a "socket" (peach inner glow 18 %) while the phone blurs to 8 px and dims to 55 % over 24 frames. Readable hold ≥ 72 frames. Dock is the reverse in 30 frames: the socket flashes 30 % for 4 frames on contact, then the blade seals right to left. |
| **Blade** | "Something changed" (always between two real captures) | A vertical light blade (2 px core, 24 px peach glow, 140 px coral bloom at 12 %) crosses the element in 18–24 frames. Behind it is the new real state, ahead of it the old one. The SFX pans with the blade's x position. This replaces every fake count-up, filling ring or highlight. |
| **Split** | Chapter change | The frame splits at x = 540. The two halves slide apart like the halves of the « A », falling back 200 px in z and blurring 0→12 px; the next scene is revealed in the widening gap. 30 frames, `(0.7,0,0.2,1)`, seam glow on both inner edges. Used four times only: S4→S5, the quantity sheet → numbers cut inside S5, S5→S6, S6→S7. |
| **Strata** | Choice and personalisation | The void fills with tall vertical slats of real wallpapers (220–300 px wide, full height) on 3 depth rows, sliding vertically at 60 / 110 / 180 px/s. When one aligns behind the phone, the universe changes. |
| **Close** | The brand | The edge-on line holds at the centre. The white left half and the peach right half of the « A » grow out of it, and the coral→raspberry gradient blooms only inside and behind the gap. |

**Sound logo (paired with Close and Lift):** two notes separated by a precise silence, the gap: D5 · eighth rest · A5. It is played on the FM glass voice.

### 2.9 What we never do
- Cream, beige or pastel backgrounds; flat 2D mockups; slideshows with a headline on top and a phone below.
- A zoom on a flat screenshot with no phone or depth context.
- Bounce or elastic overshoot, spinning phones, whip pans, glitch, RGB split, confetti, emoji, lens flares other than the seam, diagonal light sweeps.
- More than one super at a time; type over UI data; French supers.
- UI shown below the sizes in 2.5 while the VO talks about it.
- UI played faster or slower than 1×; frame interpolation of UI (no minterpolate or optical flow on text); a frozen screen during a "live" moment. A countdown frozen on screen counts.
- Invented UI states (count-ups, rings filling, highlights the app does not draw, a scan beep the app does not make).
- Dynamic Island close-ups: only a drawn facsimile of the compact form exists, and the expanded form has never been rendered.
- A path from the Lock Screen to the scanner. Bank logos, "sync", receipts or auto-categorisation. Meal-photo AI. A font picker. Weather or steps as features. Apple Watch, iPad.
- Implying that the app sets the iOS wallpaper in one tap: universes are shown as outcomes, never as an "Apply → instant wallpaper" action.
- « 6 / 3 séances », fractional loads in focus (59,4 kg…), the « Ta soirée » greeting under a 9:41 status bar, Money numbers from the app and from widgets in the same sequence (1 521 $ vs 1 631 $).
- An App Store badge before launch.

---

## 3. Sound

### 3.1 Score: "Seam", 120 BPM, D minor → D major
- **Why 120 BPM:** a beat is 0.5 s (30 frames) and a bar is 2.0 s (120 frames). Every event lands on integer frames. The real 1 Hz rest countdown falls exactly on beats 1 and 3, so the app's own timer becomes part of the music.
- **Feel:** half-time (60 BPM feel) in contemplative sections, full-time in Fitness and the S6 run.
- **Length:** 29 bars = 58.0 s = 3480 frames. Bar *n* starts at frame (n−1)×120.

| Bars | Time | Section | Harmony | Layers | Hit points (frame) |
|---|---|---|---|---|---|
| 1–3 | 0–6 s | A "Void" | D pedal → Dm(add9) | Sub drone D1, air bed, FM glass ping; half-time sub pulse from bar 2; pad swell bar 3 | f6 line ignites (glass D6) · f120 screen wake (swell) |
| 4–8 | 6–16 s | B "Strata" | Dm9 · Bbmaj7 · Fmaj7/A · Cadd9 · Dm9→A7sus4 | Pad, 8th-note pluck arp whose **timbre changes with each universe** (Aurora = soft FM, Space = sine bell, Paper = felt pluck, Neon = supersaw, Minimal = pure square, Sunset = warm FM). Same notes, re-voiced, like the same widget re-styled. No kick. | f360 exploded view (stereo split) · f540/600/660/720/780 universe blades · f840 dock · f900–959 2-beat riser |
| 9–13 | 16–26 s | C "Pulse" | Dm9 · Bbmaj7 · Gm9 · A7sus4 · Dm9 | Kick on 1 & 3, snap on 2 & 4, 16th hats, octave bass, sidechained pad | f960 lift (drums in) · f1110 widget→pane · f1290 library · f1410 figure steps out (hit) · f1500 triptych |
| 14–16 | 26–32 s | D "Break" | Bbmaj7 (filtered) · Bbmaj7 · A7sus4 | Drums out; sub plus soft ticks on every countdown second (f1560, f1620, f1680 … f1800) | f1830 **Set done** (haptic thump + glass) · f1860–1919 riser · f1918 1-frame suck |
| 17–21 | 32–42 s | E "Daylight" | Fmaj9 · C/E · Dm9 · Bbmaj7(#11) · Csus4→C | Lighter groove (rim instead of snap), brighter arp, bell motif | f1920 light snaps on · f2070 Scanner tap · f2100 app opens · f2190 barcode settles (glass) · f2310 Save tap · f2370 before→after blade |
| 22–24 | 42–48 s | F "Run" | Dm9 · Bbmaj7 · Csus4 | Full groove, 16th hats, three accents | f2520 Money · f2640 Week (swipe at f2700) · f2760 Habits (check at f2790) |
| 25–29 | 48–58 s | G "Gather → Logo" | Bbmaj9 · Gm9→A7sus4 · **Bbmaj9 (hit)** · **D(add9) (Picardy)** · ring-out | Pad opens, noise riser 50–52 s, reverse swell; final chord; sound logo | f3120 **MERGE (peak)** · f3180 edge turn · f3240 logo, D major, sound logo D5·rest·A5 · f3300 CTA bell · silent from f3470 |

### 3.2 Instruments (synthesised in code, 48 kHz)
- **Sub:** sine D1 (36.71 Hz) with the 2nd harmonic at −12 dB, LP 120 Hz, slow attack. Mono below 120 Hz.
- **Air bed:** pink noise, band-pass 6–12 kHz, −36 dBFS, slow LFO on the cutoff.
- **Pad:** 6 saws detuned ±7 cents plus a sine an octave up, LP 1.8 kHz, chorus. FDN reverb 4.5 s, 30 % wet. Attack 1.5 s. Sidechained from the kick by −4 dB in C/F.
- **Pluck arp:** 8th notes, envelope A 2 ms / D 180 ms / S 0, LP envelope 3 kHz→600 Hz. Ping-pong delay 3/16 (0.375 s), 25 % feedback. Timbre per universe as in 3.1.
- **FM glass (signature):** 2-operator FM, ratio 1:3.5, index 4→0 over 1.2 s. Used for the line ignition, recognitions and the sound logo.
- **Kick:** sine with a 150→48 Hz pitch envelope over 60 ms, decay 380 ms, plus a 3 kHz click of 4 ms.
- **Snap:** three bursts of band-passed noise (1.2 kHz, Q 1.2), 10 ms apart, plus a 120 ms tail.
- **Hats:** high-passed noise at 8 kHz, 25 ms, 16ths with velocities 1.0 / 0.45 / 0.7 / 0.45.
- **Bass:** saw plus sub, LP 400 Hz, 8th-note octaves on the chord root, sidechained −6 dB.
- **Riser:** white noise band-pass sweeping 400 Hz→8 kHz over 2 bars, plus a saw gliding D3→D5 at −18 dB. It ends in a one-beat "suck" (cut to silence) before the hit.
- **Impact:** sub drop 60→30 Hz over 1.5 s, a noise burst LP 2 kHz decaying over 0.8 s, and an FM glass chord (D5-A5-F#6 at the logo).

### 3.3 SFX palette (all synthesised; max one SFX per beat)
| SFX | Recipe | Where |
|---|---|---|
| Line ignite | FM glass D6 + air whoosh (band-pass noise 3→8 kHz, 0.8 s) | f6, Line events |
| Split | Two noise bursts moving outward L/R (0.4 s), mono-safe | Exploded view, Split transitions |
| Lift "air pull" | Reversed reverb swell 0.35 s, then a 55 Hz thump of 40 ms at the stop | Each Lift |
| Dock "glass click" | 2 kHz sine burst of 15 ms + 70 Hz thump of 40 ms, −18 dBFS | Each Dock |
| Blade shimmer | Filtered noise sweep whose pan follows the blade's x | Each Blade |
| Tap pulse | 150 Hz sine of 25 ms + 4 kHz click at −24 dB (haptic-like) | Set done, Scanner, Save, habit check |
| Countdown tick | FM wood (ratio 1:1.4, 30 ms), A5, −24 dBFS | Each real second of the Live Activity |
| Recognition | FM glass A5. Not a beep: the app makes no scan sound. | Barcode settles |
| Light on | Low "thock" (sine 90 Hz, 60 ms) + bright air | Daylight pool in S5 |
| Page swipe | Short air whoosh 0.3 s | Planning week swipe |

### 3.4 Mix rules
- VO dialogue at −16 LUFS short-term. Music bed at −24 to −22 LUFS under the VO.
- Sidechain ducking of the music from the VO: −6 dB (only −3 dB in the S4 break), attack 30 ms, release 250 ms, 10 ms look-ahead.
- A dynamic EQ dip of −2.5 dB at 2–4 kHz on music while the VO speaks.
- VO chain: high-pass 90 Hz, +1.5 dB at 3 kHz, de-ess, 3:1 compression. Plate reverb 0.9 s at 6 % ("slightly cinematic").
- SFX peaks at most −12 dBFS (hits) and around −24 dBFS for UI ticks.
- One designed near-silence for music only: 200 ms before the Set done tap (30.30–30.50 s).
- Master: −14 LUFS integrated, true peak −1 dBTP, LRA ≤ 8. Check mono fold-down. 48 kHz / 24-bit, AAC 320 kbps in the exports.

---

## 4. VO

### 4.1 Voice character and generation
- **Character:** a woman in her early 30s, neutral American. Close-mic, warm, unhurried, certain. Think of a designer explaining her work to one person, not an announcer. She smiles with the voice on "yours" and never pushes. Each sentence lands on the downbeat of its visual reveal.
- **Tool:** Kokoro-82M, already set up in `tools/` (`scripts/tts_kokoro.py`, `tts_variant.py`).
  - Main voice `af_heart` (grade A). Alternative `af_bella` (A−, brighter; use it for the Fitness film).
  - `speed=0.95`.
- **Pronunciation of « Ardane » (ar-DAHN).** Respelling: *Ar-DAHN*. Kokoro/misaki inline override: `[Ardane](/ɑɹdˈɑn/)`.
  - The default G2P says "AR-dane" (`ˈɑɹdAn`).
  - The `fr` variant `/ɑɹdˈɑn/` was already tested: ASR heard "Ardaan" / "Ardhan", which is the target (`tools/voices/variants/asr_small.en.json`).
  - Do not use the `stress2` variant: it heard "Ardaine".
- **Chunking.** Kokoro is weak on utterances under about 15 tokens, so lines are synthesised in groups and then cut at silences: A = V1+V2, B = V3+V4, C = V5+V6, D = V7+V8, E = V9–V11, F = V12–V14, G = V15, H = V16+V17. Each line is then placed on its timecode. Time-stretch at most ±4 %, no pitch shift.
- **QC:** ASR check, with WER excluding the brand = 0.

### 4.2 Main film script: 94 words over 58 s (≈ 2.4–2.5 words/s within each line, with breathing room between lines)

| # | In–out (s) | Line (Kokoro text) | Intention | Visual sync |
|---|---|---|---|---|
| V1 | 0.60–3.40 | Every day runs on a few essentials. | Quiet observation, almost private | Line becomes a phone |
| V2 | 3.90–6.80 | They deserve an interface designed around you. | Warm conviction; light lift on "you" | Super "Designed around you." at 4.20 |
| V3 | 8.00–10.40 | Start with a world you love. | Invitation, a smile | Strata begins; first universe change at 9.00 |
| V4 | 11.00–12.30 | Every widget follows. | Small, certain, a little delighted | Blade restyles the widgets at 11.00 and 12.00 |
| — | 12.30–16.40 | (silence: let the visuals breathe) | | "Make it yours." at 14.00 |
| V5 | 16.40–20.00 | When you train, it keeps track of every set. | More drive, matches the kick | Next-set widget lifts, session pane |
| V6 | 21.60–24.80 | And shows you every exercise, move by move. | Precise; slight slow-down on "move by move" | Library → figure steps out at 23.50 |
| V7 | 26.20–29.40 | Your rest counts down on your Lock Screen. | Hushed, the break: closer to the mic | Live Activity ticking |
| V8 | 29.80–31.80 | Set done? Tap it — right there. | Playful question; "Tap" lands on f1830 (30.50) | Tap pulse on « Série faite » |
| V9 | 32.20–34.20 | Food is just as simple. | Bright, open | Daylight pool, tub |
| V10 | 35.00–37.00 | Scan a barcode, or search… | Easy, conversational | Scanner chrome, barcode settles at 36.50 |
| V11 | 38.80–41.60 | …and see exactly what's left for today. | Clear; weight on "exactly" | Blade 1 122→1 019 at 39.50 |
| V12 | 42.20–42.90 | Your money. | Quick, on the beat | Money hit at 42.00 |
| V13 | 44.20–44.80 | Your week. | Quick | Week hit at 44.00 |
| V14 | 46.10–47.60 | The habits you're building. | Softer, proud | Habit check at 46.50 |
| V15 | 48.40–51.60 | Everything, in one place that feels like yours. | Emotional peak, slower, lands just before the hit | Gather; merge hit at 52.00 |
| V16 | 54.20–54.90 | `[Ardane](/ɑɹdˈɑn/).` | Name, said simply, with no hype | Logo forms at 54.00 |
| V17 | 55.20–57.60 | Coming soon to the App Store. | Calm, confident close | End card |

**Launch-day alternative for V17:** "Now on the App Store." The end card then uses the official Apple badge, following Apple's marketing guidelines.

---

## 5. Main film: "The Opening", 58.0 s, 1080×1920, 60 fps

### 5.1 Casting the real assets (decided once, reused everywhere)
- **Hero Home Screen.** An iOS Home Screen made only of real Ardane widgets on a real Ardane wallpaper (what a user builds themselves). Grid of three widget bands:
  - Band 1: `macros` Medium, with the « Scanner » pill.
  - Band 2: `nextSet` Medium, with « Série faite ».
  - Band 3: `budgetLeft` Small and `priorities` Small (« Top 3 du jour »).
  - The dock icons come from the Store setup that owns the wallpaper.

  Two looks:
  - **Aurora:** aurora wallpaper, Aurora style, Store setup `aurore` dock icons. Used in S1 and at the start of S2.
  - **Sunset:** sunset wallpaper, Sunset theme, Store setup `crepuscule` dock icons. Used from the end of S2 to the end.

  The colour arc of the film is therefore pre-dawn → sunset → the coral logo.

  How to get it: preferably add a custom "hero" setup to the DEBUG export, so the app's own Home renderer produces exact iOS grid metrics. Fallback: composite the wallpaper alone and the widget PNGs at the HomeSetup grid positions.
- **App screens:** Dark appearance (they sit in the void). This covers the live session (before and after Set done), the exercise library (tall scroll capture), the exercise detail « Développé couché », the Nutrition home (before and after), the quantity sheet, the search sheet, Planning this week and next week, and Habits before and after the check. The scanner chrome comes with its camera area empty.
- **Fitness data:** a Thursday CI capture: « Haut du corps · Développé couché · 8 × 60 kg », and « 3/3 séances » if a week view is ever shown. Callouts are read off the final capture, never typed from memory.
- **Live Activity:** coral style (`-screenshotStyle coral`), transparent background. One frame per second of the rest countdown, plus the after-Set-done frame.
- **Exercise demos:** 60 fps transparent, in the app's **dark** demo scheme: ink `#F1F2F4`, muscles in the accent colour lightened 12 %, background `#1A1B1E` removed. Use the 3/4 view for barbell lifts (in profile the plate hides the head). Planned set: bench press, back squat and deadlift (main film), plus overhead press (variants). If the four exported exercises differ, substitute with what exists; never invent one.
- **Widgets per style** (for S2 and S7): `macros` M, `nextSet` M, `budgetLeft` S and `priorities` S, each in Aurora, Space, Paper, Neon, Minimal and the Sunset theme. That is 24 renders at 4×. Also `spendingByCategory` M (Sunset) and `habitStreak` S (Aurora, « 12 jours »).
- **Constellation (S7, background only):** about 40 real gallery renders of other kinds (hydration, quickFood, upNext, workout week, studies, travel…).

### 5.2 Shot list
Layers are given as BG / Mid / Phone / FG / Type. TC is in seconds, with frames at 60 fps.

| # | TC in–out · frames | Depth layers | Real asset(s) | Camera | Widget out → back | On-screen type (EN) | VO | SFX · music | Transition out |
|---|---|---|---|---|---|---|---|---|---|
| **S1 · HOOK** | | | | | | | | | |
| 1 | 0.00–2.00 · f0–119 | BG void + grain / Mid floor / Phone edge-on (yaw 90°) turning to 35°; screen off (black glass reflecting the strip) / FG – / Type – | Phone body only. On f0 the line is already at 15 %, so the first frame (thumbnail) is not black. | 85 mm; orbit 90°→35° plus a 6 % dolly back over 110 frames | – | – | V1 | f6 FM glass D6 + air; sub drone rises | Continuous |
| 2 | 2.00–4.00 · f120–239 | BG void, radial lift / Mid floor reflection of the screen glow / Phone frontal / FG – / Type – | Hero Home **Aurora** | Orbit 35°→0°, push-in 4 %/s | "Breath": each of the 4 widgets lifts 40 px in z and settles (stagger 12 frames, 30 frames each); vertical light sweep on the glass at f180 | – | V1 → V2 starts 3.90 | Screen wake swell; pad bar 2 | Continuous |
| 3 | 4.00–6.00 · f240–359 | Phone fills 92 % of the height / Type plane in front, lower third | Hero Home Aurora | Push-in to 1.10×, rising 30 px | – | **"Designed around you."** (4.20–5.90, split from the seam) | V2 | Half-time sub pulse | Continuous orbit into the exploded view |
| **S2 · AN INTERFACE THAT LOOKS LIKE YOU** | | | | | | | | | |
| 4 | 6.00–8.50 · f360–509 | BG void / Mid wallpaper plane (inside the phone) / Phone at 3/4 / FG icon plane +180 and widget plane +420 / Type eyebrows on hairline guides | Hero Home Aurora split into its real layers: wallpaper alone, the 4 widget PNGs, dock icons | 50 mm; orbit to yaw −28°, pitch +8°, dolly back | **Exploded view.** The planes separate along z over 36 frames `(0.3,0,0.1,1)` with motion blur. Hairlines join their corners. | Eyebrows "WALLPAPER · WIDGETS · ICONS" (7.00–8.40) | V2 tail · V3 | f360 Split SFX; arp enters | Continuous |
| 5 | 8.50–13.00 · f510–779 | BG **Strata**: 9 real wallpaper slats on 3 rows (far row blurred 10 px at 40 %) / exploded phone / FG widget plane / Type – | Wallpapers: midnight (starry), paper, synthwave, graphite, sunset, plus passing dunes, ocean, nebula, topography. The same 4 widgets in Space, Paper, Neon, Minimal and Sunset. Dock icons of the matching Store setups (`espace`, `etudes`, `neon`, `graphite`, `crepuscule`). | Slow orbit yaw −28°→−12°, 50 mm | On 9.00 / 10.00 / 11.00 / 12.00 / 13.00 a slat glides into register behind the wallpaper plane. A **Blade** crosses the planes front to back in 18 frames: the wallpaper, the widgets (same kinds and data, new style) and the icons change together. Order: Space (dark) → Paper (light, minimal) → Neon (colourful) → Minimal (graphite) → **Sunset** (final). | – | V3 · V4 | Blade shimmer on each change; the arp changes timbre per universe | Continuous |
| 6 | 13.00–16.00 · f780–959 | BG: slats fold behind the phone like a closing blind and fade to the void / Phone frontal / Type below the phone | Hero Home **Sunset** | Orbit back to 0°, gentle push | Planes collapse into the phone at 14.00 (30 frames, all at once) | **"Make it yours."** (H0, 14.00–15.80) | (silence) | f840 dock click + thump; riser 15–16 | **Lift** on the downbeat at 16.00 |
| **S3 · FITNESS, BEYOND THE WIDGET** | | | | | | | | | |
| 7 | 16.00–18.50 · f960–1109 | BG void + red ambient 6 % / Phone pushed to z −400, blur 8, dim 55 % / FG `nextSet` M at 960 px / Type callout | `nextSet` M (Sunset): « Prochaine série · Série 3/4 · 8 × 60 kg · Série faite », as captured | 85 mm, small dolly toward the widget, 2° yaw drift | **Lift** from its slot; a socket glow stays in the phone | Callout "NEXT SET" (16.80–18.30) | V5 | f960 drums in; air pull + landing thump | **Blade** turns the widget into a pane |
| 8 | 18.50–21.50 · f1110–1289 | BG void / Phone far (blur 12, dim 40 %) / FG floating pane, live session (dark), 900 px wide / Type callouts | Live session, before Set done: routine and timer, « 2/14 séries », « Série 3 sur 4 · Développé couché », steppers, rest, exercise list with done-set chips | Camera tilts down the pane: a virtual pan of 0→1200 px over 150 frames, `(0.45,0,0.2,1)`. The « La dernière fois 59,4 kg » line passes inside the motion-blurred part of the move and never in the sharp hold. The rest timer is never held in focus (it would be frozen). | The blade crosses the widget and its rounded rect grows over 24 frames into the pane, cross-dissolving inside the blade | "SET 3 OF 4" (19.00–20.40) · "WORKOUT PROGRESS" pinned to the chips (20.20–21.40) | V5 tail | Hats, bass | **Blade** to the library |
| 9 | 21.50–23.50 · f1290–1409 | Same layers | Exercise library (tall stitched capture) → exercise detail « Développé couché » | Locked camera. Inside the pane: a 60 fps virtual scroll with UIScrollView deceleration (0.998/ms) lands on the bench-press row, then an iOS push (≈ 0.5 s, critically damped spring; old screen shifted 30 % and dimmed) to the detail. | – | Eyebrow "EXERCISE LIBRARY" (21.70–23.00) | V6 | Soft swipe on the push | **Lift** of the figure |
| 10 | 23.50–26.00 · f1410–1559 | BG void + floor reflection / Mid detail pane recedes (z −600, blur 10) / FG bench-press figure (dark scheme, 3/4 view) about 1500 px wide on a lit plinth; from 25.00, back squat and deadlift on plinths at z −300 and −600 / Type super | Exercise demos, 60 fps, transparent, played at 1× | Push-in on the upper body during the press, then pull back and truck right to reveal the triptych at 25.00 | The figure steps out of its demo card: the card's dark background dissolves into the void as the figure scales 1→3.2 along z | **"163 exercises. Each one animated."** (24.60–25.90) | V6 tail | f1410 hit (sub + glass). Accents sit on the demo's real phase changes; music follows the demo, never the reverse. | **Line**: the three plinths slide together and compress into a vertical line at 26.00 |
| **S4 · THE LOCK SCREEN: ACT INSTANTLY** | | | | | | | | | |
| 11 | 26.00–27.50 · f1560–1649 | BG void / Phone lying back at 60°, macro / Lock Screen wakes / FG – | Lock Screen on the sunset wallpaper (bold clock; lock widgets from real accessory renders) with the Live Activity rest countdown. Fallback: the Store Lock Screen of `jade`, which really carries `nextSet` and `caloriesLeft`. | 135 mm. The line from shot 10 becomes the rail; the camera glides along the glass from the clock (out of focus) to the Live Activity, with a 24-frame focus pull | – | – | V7 | **Break**: drums out. A tick every 60 frames from f1560, one per real countdown frame. | Continuous |
| 12 | 27.50–31.00 · f1650–1859 | BG void / Mid Lock Screen out of focus (blur 10, dim 50 %) / FG Live Activity at 1000 px / Type callouts and super | Live Activity: per-second countdown frames, then the after-Set-done frame | Locked, micro push 2 % | **Lift** (horizontal). At 30.50 a light-ring pulse (18 frames) on « Série faite », then a **Blade** outward from the button over 12 frames to the real after-state (rest restarts, counter advances). | "REST" pinned to the countdown (27.80–29.60) · "SET DONE" pinned to the button (29.90–30.60) · super **"Without opening the app."** (30.80–31.90) | V8 ("Tap" on f1830) | Music near-silent 30.30–30.50; f1830 haptic thump + glass | Dock |
| 13 | 31.00–32.00 · f1860–1919 | The Live Activity docks back (24 frames) and the screen dims to sleep | Same | Camera lifts away | **Dock** | – | – | Riser; 1-frame suck at f1918 | **Split** at the centre, revealing the daylight pool |
| **S5 · NUTRITION: UNDERSTAND WHAT YOU EAT** | | | | | | | | | |
| 14 | 32.00–33.50 · f1920–2009 | BG void with a top softbox pool on the glossy floor (the brightest image of the film) / FG product turning 40° / Type – | Prop (not UI): the unbranded "GREEK YOGURT 0%" tub with its barcode | 85 mm, slow dolly-in; light snaps on at f1920 | – | – | V9 | Light-on thock; major lift (Fmaj9) | Continuous |
| 15 | 33.50–35.00 · f2010–2099 | BG pool / Mid tub out of focus / Phone slides in from the right, frontal | Lock Screen → iOS unlock slide-up (27 frames) → hero Home **Sunset**; `macros` M with its « Scanner » pill | Phone enters over 40 frames; push to 135 mm on the pill (pill text ≈ 44 px) | No lift: the macro framing makes it readable. Tap pulse on the pill at 34.50. | Callout "SCANNER" (34.00–34.90) | V9 tail | f2070 tap | iOS app-open zoom from the widget's rect (0.45 s) |
| 16 | 35.00–37.00 · f2100–2219 | BG pool / Phone frontal; screen = the scanner / FG – | The real flow: the « Ajouter un aliment » sheet, then the camera sheet slides over it (two real stills, iOS sheet springs, 0.7 s in total). Then the scanner chrome: « Scanner un aliment », « Annuler », ScanFrame, « Place le code-barres dans le carré », « Chercher ou créer l'aliment ». The empty camera area is filled with **the same tub rendered from the phone's camera position** in the same 3D scene. | Camera dollies toward the phone. Inside the camera area the tub drifts as the phone would move, and the barcode settles in the square at 36.50. | – | – | V10 | Low focus hum; f2190 FM glass A5 (no beep) | **Lift** of the sheet |
| 17 | 37.00–39.00 · f2220–2339 | BG void / Phone behind, dimmed / FG quantity sheet pane 940 px wide | Quantity sheet (dark): « Yogourt grec nature 0 % », « ¾ tasse = 175 g », 103 kcal, P 17,5 g, « Après ajout, il te restera 1 019 kcal ». This is the real sheet reached by search, and also opened directly by a barcode already saved in My foods. | Slow push 2 % | The sheet rises (iOS spring 0.5 s), then lifts to z +500. Tap pulse on « Enregistrer » at 38.50. | – | V11 starts 38.80 | f2310 tap | **Split** to the numbers (a cut, not a navigation claim) |
| 18 | 39.00–42.00 · f2340–2519 | BG void / FG composition: four real crops of the Nutrition home in a staggered depth stack (ring 520 px at the front left; Protéines, Glucides and Lipides rows 900 px wide stepping back) / Type eyebrows on hairlines | Nutrition home BEFORE (1 122 kcal restantes; 89/130 · 144/250 · 16/70) → AFTER (1 019; 107/130 · 150/250 · 17/70), values read off the PNGs | Slow orbit yaw 10°→−6° | The crops lift off the screen as one plate and fan into depth over 30 frames; a **Blade** from the left at 39.50 changes all four from before to after | "CALORIES LEFT · PROTEIN · CARBS · FAT" (39.60–41.60) | V11 | f2370 blade shimmer; bell motif | **Split** at 42.00 |
| **S6 · MONEY, PLANNING AND OTHER ESSENTIALS** | | | | | | | | | |
| 19 | 42.00–44.00 · f2520–2639 | BG void with a horizontal light line at y = 1100 (the seam laid flat: Money's own staging) / Phone at 3/4, low and behind / FG `budgetLeft` S rising; `spendingByCategory` M revealed below it / Type H0 | `budgetLeft` S (« Reste du mois », e.g. « 1 631 $ · soit 78 $ par jour », as captured) and `spendingByCategory` M, both Sunset and **from the same CI run**. No app numbers in this sequence. | 85 mm, slow crane up | `budgetLeft` rises vertically out of the phone (a lift upward, not toward the camera); a horizontal blade reveals `spendingByCategory` left to right along the light line (a mask reveal of a still, not animated values) | **"Money."** (42.00–43.80) | V12 | f2520 hit; ledger sweep panned L→R | Camera tilts to top-down |
| 20 | 44.00–46.00 · f2640–2759 | BG void / FG the Planning week table lying flat like an architectural plan under a raking light / Type H0 | Planning **this week** and **next week** (dark): coloured blocks, today line | Tilt from 30° to 90° top-down over 36 frames, then hold | At 45.00 a horizontal page swipe this week → next week, rebuilt from the two real stills with the iOS paging curve (0.35 s); the blade marks the page edge | **"Week."** (44.00–45.80) | V13 | f2640 hit; f2700 swipe | Macro push |
| 21 | 46.00–48.00 · f2760–2879 | BG void / FG macro on one habit's check circle, then a pull back / Type H0 | Habits before and after the check (dark), then `habitStreak` S (Aurora, « 12 jours ») | 135 mm macro, pulling back to 85 mm | At 46.50 a tap pulse and a radial blade from the circle reveal the after-state; `habitStreak` slides in from the right into the foreground | **"Habits."** (46.00–47.80) | V14 | f2760 hit; f2790 check tick | **Split** to the wide gather |
| **S7 · FINAL REVEAL** | | | | | | | | | |
| 22 | 48.00–52.00 · f2880–3119 | BG constellation of about 40 real widget renders at z −1500…−3000 (blur 14 px, 25 %, slow drift: breadth without a catalogue) / Phone frontal at the centre with 4 glowing sockets / FG the 4 hero widgets on an ellipse at z +300…+600, **each in a different style** (Aurora, Neon, Paper, Space) / Type – | Gallery renders; hero widgets in 4 styles | 50 mm, orbit yaw +12°→−12° | Gather: the widgets glide to their places around the phone | – | V15 | Pad opens; noise riser 50–52; suck at 51.75 | Continuous |
| 23 | 52.00–53.00 · f3120–3179 | Phone at the centre; the constellation streaks into the screen (motion-blurred) | Hero Home Sunset (final) | Locked, micro push | **Merge:** the 4 widgets dock (stagger 4 frames, 30 frames each); each **blades into the Sunset theme** as it docks: one interface, one design. Light sweep across the glass. Clean final Home held for 0.6 s. | – | – | **f3120 PEAK**: sub drop + glass chord + clicks | Continuous |
| 24 | 53.00–55.00 · f3180–3299 | Phone turns edge-on and becomes the vertical line; the halves of the « A » grow from it | Logo vector | Yaw 0°→90°, dolly in 10 % | – | – | V16 at 54.20 | f3240 D(add9) chord + sound logo D5 · rest · A5 | **Close** |
| 25 | 55.00–58.00 · f3300–3479 | End card: void; logo (white and peach halves, coral→raspberry glow only in the gap) at y ≈ 700, 300 px; wordmark; tagline; CTA at y ≈ 1250 | Logo | Locked | – | **Ardane** · "Life's essentials, designed around you." · "Coming soon to the App Store" | V17 | f3300 bell; tail to silence at 57.8 | End (hold) |

### 5.3 Brief mapping and honesty checks
- **S1–S7 of the brief** map to shots 1–3, 4–6, 7–10, 11–13, 14–18, 19–21 and 22–25.
  - S2 shows universes at once, moving, overlapping, aligning and transforming, never as a static gallery.
  - S3 covers the set counter, progress, library and demos.
  - S4 covers the rest countdown, progress and Set done from the Lock Screen.
  - S5 goes food first → iPhone → the real scanner UI → lifted numbers.
- **Path to the scanner:** Lock Screen → *visible* unlock → Home Screen → the « Scanner » pill of the Medium `macros` widget → app opens on the scanner. The Lock Screen never leads straight to the scanner.
- **After Save,** the app returns to the tab that was open. It does not navigate to Nutrition. That is why shot 18 is introduced by a Split (a designed chapter cut), not by a fake push.
- **Every state change** (1 122→1 019, Set done, habit check, next week) is a Blade between two real captures. Nothing counts up and no ring fills.
- **No Dynamic Island.** No bank, no weather, no steps, no font picker. No « 6 / 3 séances », and no fractional load in focus.
- **Money:** widget numbers only, all from one run.
- **The scan claim is limited to barcodes**, in the VO ("Scan a barcode") and in the image (a packaged product).
- **"Without opening the app"** is exactly what the Live Activity App Intents do. We do not claim "without unlocking".

---

## 6. The other films (each has its own single idea; none is a cut-down)

### 6.1 30 s: "Three Openings"
- **Idea:** open one widget and a whole part of your life opens with it: style, training, food.
- **Format:** 120 BPM, 15 bars. Direct narration with sentences carrying a feature each.
- **Structure:**
  - 0–3 s, hook: the Line → phone → hero Home Aurora.
  - 3–10 s, style: exploded view, then Strata with three universes on beats (6.5 Space · 7.5 Neon · 8.5 Sunset), then collapse at 9.5.
  - 10–17 s, Fitness: `nextSet` lifts, a Line cut to the Lock Screen macro, the Live Activity lifts, the countdown ticks on 13 / 14 / 15, Set done tap at 15.0 → after-state.
  - 17–24 s, Nutrition: Split to the daylight pool with the tub, unlock → Home, Scanner pill tap at 18.5, scanner with the tub settling at 20.0, sheet at 20.5–22.0, Split, blade 1 122→1 019 at 22.5, macro strips until 24.
  - 24–30 s: merge, edge turn, Close at 26.0, end card 27–30.
- **VO:**
  - V1 0.3–2.9 "Your day runs on a few essentials."
  - V2 3.2–5.4 "`[Ardane](/ɑɹdˈɑn/)` designs them around you."
  - V3 6.2–8.6 "Pick a world. Every widget follows."
  - V4 10.4–13.6 "Train, and it keeps track of every set —"
  - V5 13.9–17.0 "tap Set done right from your Lock Screen."
  - V6 18.0–22.0 "Scan a barcode, and see exactly what's left for today."
  - V7 26.2–28.9 "`[Ardane](/ɑɹdˈɑn/)`. Coming soon to the App Store."
- **End line:** "Life's essentials, designed around you." / "Coming soon to the App Store".

### 6.2 15 s: "One Screen"
- **Idea:** your whole day, on one screen (My Day). One continuous move, no feature cuts.
- **Format:** 120 BPM, groove from frame 0, 7.5 bars starting on a pickup.
- **Structure:**
  - 0.0–0.5 s: the Line ignites across a phone that is already lit, in macro at 135 mm on the top of My Day: the Nutrition card with its ring and « Scanner ».
  - 0.5–10.5 s: one continuous 60 fps virtual scroll of the tall stitched My Day capture, driven by three real flicks with UIScrollView physics, each released on a downbeat (2.0 / 5.0 / 8.0).
    - The camera stays macro, so the cards are about 980 px wide and readable on the phone itself, with no lift needed.
    - The seam stands still on the glass as a vertical specular line. Each card catches the light as it passes the centre.
    - Card order follows the real capture (ordered by time of day): Nutrition, today's workout, habits, « À ne pas oublier », Planning week, water, budget, Top 3.
  - 10.5–12.0 s: pull out to the whole phone, edge turn, the Line.
  - 12.0–15.0 s: Close, logo, CTA.
- **Supers:** none during the scroll (the UI is the image). End: "Your whole day. One screen."
- **VO** (order matches the chosen capture):
  - 1.0–5.6 "Your meals. Your workout. What's due. Your week." (one chunk, cut at the pauses onto the beats)
  - 7.2–10.0 "All of your day, on one screen."
  - 12.2–14.8 "`[Ardane](/ɑɹdˈɑn/)`. Coming soon to the App Store."
- **Rules:** use a capture without the « Ta soirée » greeting under 9:41 (or crop the greeting). No weather or steps cards exist anyway.

### 6.3 6–10 s: "The Line"
- **8 s version (with VO):**
  - 0.0: the Line ignites.
  - 0.4–3.0: the line opens into the two halves of the « A ». In the widening gap, a Home Screen changes universe on each beat (Aurora → Neon → Paper → Sunset) until the gap is phone-wide and the phone is whole.
  - 3.0–4.5: `macros` M lifts toward the camera, readable at 960 px.
  - 4.5–5.5: dock, edge turn.
  - 5.5–8.0: Close, logo, CTA.
  - VO 1.0–3.2 "Life's essentials, designed around you." · 5.6–7.9 "`[Ardane](/ɑɹdˈɑn/)`. Coming soon to the App Store."
  - Music: pad swell → sound logo D5 · rest · A5 at 5.5.
- **6 s bumper (sound-off first):**
  - The Line → Home Aurora blades to Sunset on one beat → edge → logo.
  - Supers carry it: "Designed around you." (1.0–3.0) → logo plus "Coming soon to the App Store" (3.8–6.0).
  - Sound logo only.

### 6.4 Fitness, 20 s: "Every Second Counts"
- **Idea:** the real Live Activity rest countdown is the metronome of the edit.
- **Format:** 120 BPM full-time from frame 0, with distorted sub, snare on 2 & 4, rimshot doubling the real ticks. Voice `af_bella`, speed 1.0.
- **Structure:**
  - 0–4 s, cold open: the Live Activity in macro, 1000 px wide. The real countdown runs 0:04 → 0:01, one frame per second, on the beats. Between ticks, Blade cuts to the four demo figures (bench press, back squat, deadlift, overhead press), one per second, each huge on its lit plinth at 1× speed.
  - 4–8 s: the real "ready" state at 4.0 (hit), then `nextSet` M lifts, then the live session pane: « 2/14 séries », « Série 3 sur 4 », done-set chips. In-app tap on « Série faite » at 7.0 → real after-state, rest restarts.
  - 8–12 s: the Line → Lock Screen macro → the Live Activity lifts; Set done tap from the Lock Screen at 10.5.
  - 12–16 s: the demo up close with camera moves on the bar path (light only, no drawn trajectory), then the library scroll at 60 fps.
  - 16–20 s: week rings (crop to the rings, or a Thursday capture showing « 3/3 »), then edge → logo.
- **VO:**
  - 0.3–2.5 "Rest, counted to the second."
  - 4.3–6.7 "Every set, tracked as you lift."
  - 8.3–11.8 "Set done? Tap it right on your Lock Screen."
  - 12.3–15.3 "And every exercise, shown move by move."
  - 17.0–19.6 "`[Ardane](/ɑɹdˈɑn/)`. Coming soon to the App Store."
- **Supers:** "Without opening the app." (10.7–11.9) · end super **"Every set. Every second."**
- **Never:** Dynamic Island, « 6 / 3 », fractional records in focus (the « 100 kg × 5 » deadlift record line is fine).

### 6.5 Nutrition, 20 s: "Know What's Left"
- **Idea:** precision in daylight. The black void is lit by one big top softbox: a bright white plinth (`#F2F2F4`) falling off to black at the frame edges. Brighter, yet still the same world.
- **Look:** app screens in **Light** appearance; widgets in the Pure White theme or Light style.
- **Music:** 120 BPM in F major, FM marimba pluck (ratio 1:4, short), soft claps, no distortion, airy hats.
- **Structure:**
  - 0–3 s: light-on hit at 0.0 on the tub; it turns to show the barcode. The phone slides in from overhead (top-down camera); its Home Screen shows `macros` M (Light).
  - 3–5 s: Scanner pill tap at 3.0 (macro) → app opens → scanner chrome. The camera area shows the same tub from the phone's position; the barcode settles at 4.5.
  - 5–8 s: the quantity sheet (Light) lifts, readable. At 6.0 the real search sheet with suggestions slides in behind it ("or search"). « Enregistrer » tap at 7.5.
  - 8–13 s: Split. Blade 1 122→1 019 at 8.5. The ring plus the Protéines, Glucides and Lipides strips fan into depth with English eyebrows.
  - 13–17 s: `quickFood` widget (« Yogourt / Banane / Café » buttons) lifts as a still, readable at 940 px. No tap: we have no after-state render.
  - 17–20 s: logo, CTA.
- **VO:**
  - 3.1–4.4 "Scan a barcode."
  - 5.6–6.7 "Or just search."
  - 8.6–12.4 "See calories, protein, carbs and fat — at a glance."
  - 13.2–16.4 "And log your usuals straight from your Home Screen."
  - 17.2–19.8 "`[Ardane](/ɑɹdˈɑn/)`. Coming soon to the App Store."
  - Lines 1 and 2 are synthesised as one chunk.
- **End super:** **"Know what's left."**

### 6.6 Personalisation, 24 s: "Build Your World"
- **Idea:** from a bare wallpaper to a complete personal universe, and then every universe at once.
- **Music:** 120 BPM, arp-led. The same melody is re-voiced in a new timbre for each universe.
- **Structure:**
  - 0–2 s: a phone showing only the midnight (starry) wallpaper; the Line ignites across the glass.
  - 2–6 s: real widgets (Space style) fall in from the void one by one onto the iOS grid. Dock clicks at 2.5 / 3.0 / 3.5 / 4.0; the dock icons fade in.
  - 6–10 s: Strata. The universe changes on every beat (8 universes, all from real Store setups and wallpapers: `aurore`, `neon`, `etudes`, `graphite`, `topographie`, `vagues`, `seventies`, `crepuscule`). Wallpaper, widgets and icons change together through Blades. Each change is an outcome, never an "Apply" tap.
  - 10–14 s: `macros` M lifts and cycles styles on the beats, same data in each: Glass → Neon → Paper → Luxury → Liquid Glass → Blueprint → Terminal → Sunset.
  - 14–17 s: the matching real Store Lock Screen slides in beside the Home. The app icon goes Coral → Classic Glass → a glass colour (real icons) through Blades.
  - 17–21 s: pull back to five phones in a row at different depths (real Store Homes `aurore`, `neon`, `etudes`, `crepuscule`, `vagues`). They slide together through the seam into one, Sunset.
  - 21–24 s: Close, logo, CTA.
- **Supers:** "57 styles" (10.2–11.8) · "23 ready-made Home Screens" (17.2–18.8) · end **"Make it yours."**
- **VO:**
  - 0.3–2.5 "Start with a world you love."
  - 6.2–8.4 "Every widget follows your style —"
  - 14.2–17.0 "down to your Lock Screen, and even the app icon."
  - 18.6–20.2 "Make it yours."
  - 21.2–23.8 "`[Ardane](/ɑɹdˈɑn/)`. Coming soon to the App Store."
- **Never:** a font, layout or shape picker. Fonts change only with a style. No claim that the wallpaper is set automatically.

### 6.7 Other ratios (recomposed, not cropped)
- **4:5 (1080×1350, feeds):** the phone at 0.8×; widgets lift into the lower half in front of the phone; supers above the phone, centred on the seam; readability minimums unchanged.
- **16:9 (1920×1080, YouTube / pre-roll):** the seam stays the centre axis at x = 960. The phone sits in the left half (x ≈ 640) and lifted UI lands in the right half (x ≈ 1340), giving side-by-side depth. Supers go on the right third. Strata slats become 16 across.
- **1:1:** only if a platform asks; built like 4:5.

---

## 7. Production notes (so the direction can be built as written)
- **Engine:**
  - Remotion handles the timeline, type and 2.5D planes.
  - `@remotion/three` renders the phone body only where it must be convincing: shots 1–2, 4–5, 11, 23–24 and the S5 product/phone scene, which also feeds the scanner's camera area.
  - All lifted UI planes are textured quads.
  - Bloom and grain are a 2D post pass.
- **CPU budget:**
  - Motion blur is on flagged ranges only (displacement > 16 px/frame).
  - Static plates (void, floor, plinths) are pre-rendered.
  - Demo frames and countdown frames are preloaded, and decode() is awaited before each capture.
  - Chunks render in parallel with concurrency 3–4.
- **Timeline:**
  - Integer frames only: event frame = bar×120 + beat×30 + offset.
  - UI at 1× only. Scrolls use real UIScrollView deceleration. Pushes and sheets use iOS springs.
  - No `floor(t*fps)` on float time.
- **Assets still to request** (DEBUG export or CI). These are flagged honestly; nothing is shown until it exists:
  - The custom hero Home (or the composite fallback).
  - The Lock Screen with chosen accessories on the sunset wallpaper (only partly supported today; fallback is the `jade` Store Lock Screen).
  - The Live Activity in coral: per-second, after-Set-done and ready frames.
  - Dark-scheme demo frames for the four lifts.
  - The 24 style renders.
  - Dark captures of the live session, library and detail.
  - The tall stitched scrolls for the library and My Day.
- **Encoding and QC** (from `audit/R-framerate.json`):
  - Lossless PNG or RGB piped to ffmpeg.
  - libx264 High, `-r 60`, yuv420p, BT.709 tags, `-g 120`, CRF ≤ 16, `+faststart`.
  - Frame count must be exactly duration × 60.
  - Automated QC: zero repeated frames in any window where on-screen UI is moving (a ticking countdown counts as a hold); no visible join inside a still shot; a table of peak displacement per frame; ASR on the VO; −14 LUFS / −1 dBTP.
  - Review on a phone using the MP4, never a 10 fps GIF.
