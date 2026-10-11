# Ardane — translation brief

Ardane is an iPhone app of customizable widgets (Home Screen, Lock Screen) with mini-apps
(Nutrition, Fitness, Planning, Studies, Finances, Business, Travel, Car, Weather), a widget editor
(« Studio »), a Store of ready-made widgets and setups, and a Premium subscription.
The source language is French (Québec/France). Target languages and codes:
en (English, US), es (Spanish, neutral Latin American), de (German), it (Italian),
pt-BR (Brazilian Portuguese), ja (Japanese).

## Tone
- Friendly, short, direct, like Apple's own apps. French uses « tu »: use the informal register —
  en "you" (casual), es "tú", de "du", it "tu", pt-BR "você", ja friendly polite (です/ます, no keigo
  excess, short UI labels in plain nouns).
- UI labels must stay SHORT (widgets and buttons are small). Never longer than needed; German may
  use common short forms. Keep sentence case like the French (capital only at the start).
- Follow each language's typography: no space before « : ; ! ? » outside French; quotes: en “ ”,
  es « » or “ ”, de „ “, it « », pt-BR “ ”, ja 「 」. Keep « · » separators,
  arrows, emoji, symbols (× – — … › ½) as they are.

## Format rules (critical — the app crashes or shows garbage otherwise)
- `%@` is a value inserted at run time. A translation MUST contain exactly as many placeholders as
  the key (the `placeholders` field). To change the order, number them: `%2$@ … %1$@` (then number
  ALL of them). Never translate, drop or add a placeholder.
- In keys that have placeholders, a literal percent sign is written `%%`: keep it `%%`.
  In keys without placeholders, `%` is plain text.
- Keep leading/trailing spaces exactly (a key " verres" → " glasses"). Keep `\n` line breaks.
- Text between ** ** is bold markdown: keep the ** around the translated part.
- If a key is a proper noun, a brand, a unit or a code (Ardane, Premium, Open Food Facts, SEC, kcal, kg,
  km, MRR, iCloud+, IGA, Costco…), keep it unchanged (translate only the generic words around it).
- Word fragments built by code: when the key is a single word used with a number
  (e.g. `Fmt.plural(n, "jour", "jours")`), translate the singular key as singular and the plural key
  as plural. Japanese has no plural: use the same word for both.

## Product vocabulary (use these exact terms)
| French | en | es | de | it | pt-BR | ja |
|---|---|---|---|---|---|---|
| Mon Quotidien | My Day | Mi día | Mein Tag | La mia giornata | Meu dia | マイデイ |
| Mes informations | My info | Mis datos | Meine Infos | Le mie info | Minhas informações | マイ情報 |
| Mes données | My data | Mis datos | Meine Daten | I miei dati | Meus dados | マイデータ |
| Mes widgets | My widgets | Mis widgets | Meine Widgets | I miei widget | Meus widgets | マイウィジェット |
| Accueil (tab) | Home | Inicio | Home | Home | Início | ホーム |
| Créer (tab) | Create | Crear | Erstellen | Crea | Criar | 作成 |
| Store | Store | Tienda | Store | Store | Loja | ストア |
| Studio | Studio | Studio | Studio | Studio | Studio | スタジオ |
| widget | widget | widget | Widget | widget | widget | ウィジェット |
| mini-app | mini-app | miniapp | Mini-App | mini-app | miniapp | ミニアプリ |
| espace (Créer › espace) | space | espacio | Bereich | spazio | espaço | スペース |
| écran d'accueil | Home Screen | pantalla de inicio | Home-Bildschirm | schermata Home | Tela de Início | ホーム画面 |
| écran verrouillé | Lock Screen | pantalla bloqueada | Sperrbildschirm | schermata di blocco | Tela Bloqueada | ロック画面 |
| Live Activity / séance en direct | Live Activity | Actividad en vivo | Live-Aktivität | Attività Live | Atividade ao Vivo | ライブアクティビティ |
| interactif (badge) | Interactive | Interactivo | Interaktiv | Interattivo | Interativo | インタラクティブ |
| Thème (Studio) | Theme | Tema | Thema | Tema | Tema | テーマ |
| Style (Studio) | Style | Estilo | Stil | Stile | Estilo | スタイル |
| Combiné (widget) | Combo | Combinado | Kombi | Combinato | Combinado | コンボ |
| Pack | Pack | Pack | Paket | Pack | Pacote | パック |
| Ardane Premium | Ardane Premium | (same everywhere) | | | | |
| séance (sport) | workout | entrenamiento | Training | allenamento | treino | ワークアウト |
| série (sets of an exercise) | set | serie | Satz | serie | série | セット |
| série (days in a row: habits, tracking) | streak | racha | Serie | serie | sequência | 連続記録 |
| repos (between sets) | rest | descanso | Pause | recupero | descanso | 休憩 |
| répétitions | reps | repeticiones | Wiederholungen | ripetizioni | repetições | 回 |
| programme d'entraînement | training program | programa de entrenamiento | Trainingsplan | programma di allenamento | programa de treino | トレーニングプログラム |
| Top 3 du jour | Today's top 3 | Top 3 del día | Top 3 des Tages | Top 3 di oggi | Top 3 do dia | 今日のトップ3 |
| tâches | tasks | tareas | Aufgaben | attività | tarefas | タスク |
| habitudes | habits | hábitos | Gewohnheiten | abitudini | hábitos | 習慣 |
| échéance | deadline / due date | vencimiento | Fälligkeit | scadenza | prazo | 期限 |
| objectif | goal | objetivo | Ziel | obiettivo | meta | 目標 |
| chiffre d'affaires | revenue | ingresos | Umsatz | fatturato | faturamento | 売上 |
| Mes paramètres | My settings | Mis ajustes | Meine Einstellungen | Le mie impostazioni | Meus ajustes | マイ設定 |
| Réglages (app settings) | Settings | Ajustes | Einstellungen | Impostazioni | Ajustes | 設定 |

## Domain notes
- Foods: use the everyday name in the target country (en US/Canada, es Latin America, pt-BR Brazil).
  Québec words: « croustilles » = chips (crisps), « beigne » = donut, « gruau » = oatmeal,
  « melon d'eau » = watermelon, « pointe » (de pizza) = slice, « yogourt » = yogurt, « rôtie » = toast,
  « c. à soupe » = tbsp, « c. à thé » = tsp.
- Exercises: use the names gyms use in that language (en "Bench press", de "Bankdrücken",
  es "Press de banca", it "Panca piana", pt-BR "Supino reto", ja "ベンチプレス").
  Muscle names: standard anatomy terms used in gyms.
- Sample data (people, places, course names) is demo content: localize generic words, keep names.
- Money: amounts are formatted by code; « $ » inside a key stays.
- Dates and numbers come formatted from code; never add dates.
- « J-3 » is a countdown (en "3 days left" style is too long: use "D-3" in en/es/pt/it/de, "あと3日"→ keep short "D-3" in ja too).
