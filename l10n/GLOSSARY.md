# Tessera — translation brief

Tessera is an iPhone app of customizable widgets (Home Screen, Lock Screen) with mini-apps
(Nutrition, Fitness, Planning, Studies, Finances, Business, Travel, Car, Weather), a widget editor
(« Studio »), a Store of ready-made widgets and setups, and a Premium subscription.
The source language is French (Québec/France). Target languages and codes:
en (English, US), es (Spanish, neutral Latin American), de (German), it (Italian),
pt-BR (Brazilian Portuguese), ja (Japanese), zh-Hans (Simplified Chinese), ko (Korean).

## Tone
- Friendly, short, direct, like Apple's own apps. French uses « tu »: use the informal register —
  en "you" (casual), es "tú", de "du", it "tu", pt-BR "você", ja friendly polite (です/ます, no keigo
  excess, short UI labels in plain nouns), zh-Hans "你", ko friendly 해요체 (labels as plain nouns).
- UI labels must stay SHORT (widgets and buttons are small). Never longer than needed; German may
  use common short forms. Keep sentence case like the French (capital only at the start).
- Follow each language's typography: no space before « : ; ! ? » outside French; quotes: en “ ”,
  es « » or “ ”, de „ “, it « », pt-BR “ ”, ja 「 」, zh-Hans “ ”, ko ‘ ’ or “ ”. Keep « · » separators,
  arrows, emoji, symbols (× – — … › ½) as they are.

## Format rules (critical — the app crashes or shows garbage otherwise)
- `%@` is a value inserted at run time. A translation MUST contain exactly as many placeholders as
  the key (the `placeholders` field). To change the order, number them: `%2$@ … %1$@` (then number
  ALL of them). Never translate, drop or add a placeholder.
- In keys that have placeholders, a literal percent sign is written `%%`: keep it `%%`.
  In keys without placeholders, `%` is plain text.
- Keep leading/trailing spaces exactly (a key " verres" → " glasses"). Keep `\n` line breaks.
- Text between ** ** is bold markdown: keep the ** around the translated part.
- If a key is a proper noun, a brand, a unit or a code (Tessera, Premium, Open Food Facts, SEC, kcal, kg,
  km, MRR, iCloud+, IGA, Costco…), keep it unchanged (translate only the generic words around it).
- Word fragments built by code: when the key is a single word used with a number
  (e.g. `Fmt.plural(n, "jour", "jours")`), translate the singular key as singular and the plural key
  as plural. Languages without plural (ja, zh-Hans, ko) use the same word for both.

## Product vocabulary (use these exact terms)
| French | en | es | de | it | pt-BR | ja | zh-Hans | ko |
|---|---|---|---|---|---|---|---|---|
| Mon Quotidien | My Day | Mi día | Mein Tag | La mia giornata | Meu dia | マイデイ | 我的一天 | 나의 하루 |
| Mes informations | My info | Mis datos | Meine Infos | Le mie info | Minhas informações | マイ情報 | 我的信息 | 내 정보 |
| Mes données | My data | Mis datos | Meine Daten | I miei dati | Meus dados | マイデータ | 我的数据 | 내 데이터 |
| Mes widgets | My widgets | Mis widgets | Meine Widgets | I miei widget | Meus widgets | マイウィジェット | 我的小组件 | 내 위젯 |
| Accueil (tab) | Home | Inicio | Home | Home | Início | ホーム | 首页 | 홈 |
| Créer (tab) | Create | Crear | Erstellen | Crea | Criar | 作成 | 创建 | 만들기 |
| Store | Store | Tienda | Store | Store | Loja | ストア | 商店 | 스토어 |
| Studio | Studio | Studio | Studio | Studio | Studio | スタジオ | 工作室 | 스튜디오 |
| widget | widget | widget | Widget | widget | widget | ウィジェット | 小组件 | 위젯 |
| mini-app | mini-app | miniapp | Mini-App | mini-app | miniapp | ミニアプリ | 小应用 | 미니 앱 |
| espace (Créer › espace) | space | espacio | Bereich | spazio | espaço | スペース | 空间 | 공간 |
| écran d'accueil | Home Screen | pantalla de inicio | Home-Bildschirm | schermata Home | Tela de Início | ホーム画面 | 主屏幕 | 홈 화면 |
| écran verrouillé | Lock Screen | pantalla bloqueada | Sperrbildschirm | schermata di blocco | Tela Bloqueada | ロック画面 | 锁定屏幕 | 잠금 화면 |
| Live Activity / séance en direct | Live Activity | Actividad en vivo | Live-Aktivität | Attività Live | Atividade ao Vivo | ライブアクティビティ | 实时活动 | 실시간 현황 |
| interactif (badge) | Interactive | Interactivo | Interaktiv | Interattivo | Interativo | インタラクティブ | 可交互 | 인터랙티브 |
| Thème (Studio) | Theme | Tema | Thema | Tema | Tema | テーマ | 主题 | 테마 |
| Style (Studio) | Style | Estilo | Stil | Stile | Estilo | スタイル | 样式 | 스타일 |
| Combiné (widget) | Combo | Combinado | Kombi | Combinato | Combinado | コンボ | 组合 | 콤보 |
| Pack | Pack | Pack | Paket | Pack | Pacote | パック | 套装 | 팩 |
| Tessera Premium | Tessera Premium | (same everywhere) | | | | | | |
| séance (sport) | workout | entrenamiento | Training | allenamento | treino | ワークアウト | 训练 | 운동 |
| série (sets of an exercise) | set | serie | Satz | serie | série | セット | 组 | 세트 |
| série (days in a row: habits, tracking) | streak | racha | Serie | serie | sequência | 連続記録 | 连续 | 연속 기록 |
| repos (between sets) | rest | descanso | Pause | recupero | descanso | 休憩 | 休息 | 휴식 |
| répétitions | reps | repeticiones | Wiederholungen | ripetizioni | repetições | 回 | 次 | 회 |
| programme d'entraînement | training program | programa de entrenamiento | Trainingsplan | programma di allenamento | programa de treino | トレーニングプログラム | 训练计划 | 운동 프로그램 |
| Top 3 du jour | Today's top 3 | Top 3 del día | Top 3 des Tages | Top 3 di oggi | Top 3 do dia | 今日のトップ3 | 今日三件事 | 오늘의 Top 3 |
| tâches | tasks | tareas | Aufgaben | attività | tarefas | タスク | 任务 | 할 일 |
| habitudes | habits | hábitos | Gewohnheiten | abitudini | hábitos | 習慣 | 习惯 | 습관 |
| échéance | deadline / due date | vencimiento | Fälligkeit | scadenza | prazo | 期限 | 截止日期 | 마감 |
| objectif | goal | objetivo | Ziel | obiettivo | meta | 目標 | 目标 | 목표 |
| chiffre d'affaires | revenue | ingresos | Umsatz | fatturato | faturamento | 売上 | 营业额 | 매출 |
| Mes paramètres | My settings | Mis ajustes | Meine Einstellungen | Le mie impostazioni | Meus ajustes | マイ設定 | 我的设置 | 내 설정 |
| Réglages (app settings) | Settings | Ajustes | Einstellungen | Impostazioni | Ajustes | 設定 | 设置 | 설정 |

## Domain notes
- Foods: use the everyday name in the target country (en US/Canada, es Latin America, pt-BR Brazil).
  Québec words: « croustilles » = chips (crisps), « beigne » = donut, « gruau » = oatmeal,
  « melon d'eau » = watermelon, « pointe » (de pizza) = slice, « yogourt » = yogurt, « rôtie » = toast,
  « c. à soupe » = tbsp, « c. à thé » = tsp.
- Exercises: use the names gyms use in that language (en "Bench press", de "Bankdrücken",
  es "Press de banca", it "Panca piana", pt-BR "Supino reto", ja "ベンチプレス", zh "卧推", ko "벤치 프레스").
  Muscle names: standard anatomy terms used in gyms.
- Sample data (people, places, course names) is demo content: localize generic words, keep names.
- Money: amounts are formatted by code; « $ » inside a key stays.
- Dates and numbers come formatted from code; never add dates.
- « J-3 » is a countdown (en "3 days left" style is too long: use "D-3" in en/es/pt/it/de, "あと3日"→ keep short "D-3" in ja/zh/ko too).
