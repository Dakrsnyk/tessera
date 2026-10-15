---
tags: [ardane, memoire]
---

# Ardane — what really exists (verified in the code, audit of 2026-10-11)

App: Ardane (iOS 17, SwiftUI). Widgets + mini-apps for the essentials of daily life. UI language of the captures:
French (the ad narration is in English; on-screen UI stays French — keep typography/captions in English).
Brand: logo = an « A » made of two halves split by a vertical gap (left half white, right half peach #FFE0CC) on a
coral→raspberry gradient #FF7A59→#D9246A. Name « Ardane ». Not yet on the App Store (no official badge; say
« Coming soon to the App Store » or a neutral « Download Ardane » end card — decide).

## Personalization (strongest visual material)
- 103 widget types, sizes Small / Medium / Large + Lock Screen (circular, rectangular, inline).
- Studio: 57 widget « styles » (e.g. Minimal, Light, Dark, Glass, Aurora, Neon, Luxury, Liquid Glass, Paper, Space,
  Ocean, Synthwave, Editorial, Matte Black, Blossom, Retro, Terminal, Blueprint, Dune, Glacier, Mars…),
  16 complete « themes » (Midnight, Pure White, Ocean, Forest, Sunset, Cyber, Luxury, Glass, Sakura…),
  14 colour palettes, 8 main colours + free colour, backgrounds (colour, gradient, glass, photo), 13 textures,
  7 borders. Fonts/layout are NOT separately editable (only via style).
- Store: 23 ready-made Home Screens (each = wallpaper + matching widgets + matching icons + a Lock Screen), 18
  wallpapers drawn in code (starry night, aurora, topography, retro neon, dunes, jade mosaic, nebula, ocean,
  pine forest, sunset, terrazzo, seventies arcs…), 34 packs, 72 combos, 12 collections.
- 19 app icons (Coral default, Classic, Classic Glass black/cyan, 16 glass colours).
- Mon Quotidien (« My Day ») home: one screen with Nutrition, today's workout, habits, « À ne pas oublier » (bills/
  tasks), Planning week table, water, budget, top 3 — ordered by time of day.

## Fitness (real)
- Live workout screen: routine name + timer, « 2/14 séries », « Série 3 sur 4 · Développé couché », last time
  « 59,4 kg × 8 », reps and load steppers, rest countdown (e.g. 0:55) with pause/skip, big red « Série faite » (Set
  done) button, list of exercises with done-set chips. Tap Set done → next set, rest restarts.
- Rest timer visible everywhere: app, My Day card, widgets, Live Activity.
- Live Activity on the Lock Screen + Dynamic Island: routine, exercise, « Série 3/4 · 8 × 60 kg », Rest countdown,
  progress bar, buttons Pause / Skip / Set done that WORK from the Lock Screen (App Intents) without opening the app.
- Widgets: next set (with Set done button), today's workout (with Set done), week rings, streak…
- Exercise library: 163 exercises, each with an animated 3D-looking stick-figure demonstration on the equipment
  (barbell, bench, pull-up bar, kettlebell, rower…), phases labels (e.g. « Arms extended → Lower → Bar on lower
  chest → Press »), profile / 3-4 views, technique, performance history.
- Week view with rings, records (estimated 1RM), programme, history, catch-up sessions, estimated calories.
- Demo data (CI captures): Upper body « Haut du corps »: bench press 4×8 at 60 kg, pull-ups; volume numbers.
  Avoid showing « 6 / 3 séances » (demo quirk) and fractional loads close-up.

## Nutrition (real)
- Nutrition home: ring « 1 122 kcal restantes » (goal 2 200), Protein 89/130 g, Carbs 144/250 g, Fat 16/70 g,
  meals (Breakfast 459 kcal, Lunch 516, Dinner nothing yet, Snack 103), an idea card, week chart.
- Add food in two taps: search sheet with suggestions → quantity sheet (Greek yogurt 0 %, ¾ cup = 175 g, 103 kcal,
  17.5 g protein, « after adding, X kcal left ») → Save → ring updates to 1 019 kcal left, protein 107/130.
- Barcode scanner (device camera): aiming square (ScanFrame) « Place le code-barres dans le carré »; reads EAN/UPC of
  packaged foods; looks up Open Food Facts (brand, per-100 g values) or the user's saved foods; unknown product →
  create it. Canadian Nutrient File database (5 596 foods) built in.
- One-tap path to the scanner: the « Scanner » pill on MEDIUM/LARGE Home Screen Nutrition widgets (opens the app
  straight on the scanner), and the « Scanner » button of My Day. NOT from the Lock Screen (Lock Screen widgets
  only open the Nutrition mini-app). Do not claim Lock Screen scanning.
- Widgets: calories left (ring), macros (with Scanner pill on medium), protein left, meals today, week, streak,
  next meal, quick add (Yogurt / Banana / Coffee buttons that log food from the widget without opening the app).
- Lock Screen widgets: calories gauge, macros bars, protein left (display only).

## Money (real, manual entry — NO bank connection)
- Balance chart Month / 3 months / Year with rolling number, « Left this month », income / expenses / balance,
  category bars vs limits, upcoming bills (14 days), savings goals, transactions, categories ring, net worth.
- Widgets: budget left, spending by category, money dashboard, quick expense (interactive).
- Never imply bank sync, receipts scanning or automatic categorisation.

## Planning, habits, more (real)
- Week timetable (coloured blocks, today line, swipe for next week), day agenda, Top 3, tasks with repeat, month,
  projects, focus timer (15–90 min), studies (courses, exams).
- Habits: daily habits with check circle, 7-day squares, streak (« 12 days »), reminders.
- Water in glasses (+1 glass widget). Smart reminders (workout at 18:00 if not started, meals at 20:00, bills the day
  before). Calendar is read-only.
- Other mini-apps exist (Business, Travel, Car, Studies) — secondary.

## Not to show / not to claim
- No Lock Screen → scanner path; no bank sync; no weather on My Day; no step count in captures; no Apple Watch, no iPad;
  no AI photo-of-meal recognition (removed); no font picker.

## Real assets the film can use (lossless PNG from the app, captured by CI)
- Any widget above, in any style/theme/palette, on transparent background (3–4× resolution).
- Each Store Home Screen as a whole, its wallpaper alone, its widgets one by one (to « lift » them out), its Lock Screen.
- Live Activity in real states (rest countdown frames second by second, after Set done, paused, ready).
- Exercise demonstrations rendered frame by frame at 60 fps (transparent), 4 barbell/gym exercises.
- Full screens (PNG) of: My Day, Nutrition (before/after adding food, search sheet, quantity sheet), scanner chrome
  (ScanFrame) with an empty camera area, Fitness home, live session (before/after Set done), exercise library,
  exercise detail, programme, progress, Money (month / 3 months / year, categories, bills, savings), Planning (this
  week / next week), Habits (before/after check), Store, Home Screen setups, Studio (styles, themes, palettes), icons.
- Tall scroll captures stitched from slices (for perfectly smooth 60 fps virtual scrolling).
- The motion design may add depth, light, reflections, graphics, transitions, typography — never fake UI.
