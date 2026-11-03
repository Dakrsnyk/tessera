-- Ardane food pack, schema version 1. Read-only in the app (SQLITE_OPEN_READONLY), built by scripts/food_db/build.py.
--
-- Identifiers of the app (FoodItem.id): `cnf.<Food_Code>` for the Canadian Nutrient File 2026 (food.id = Food_Code,
-- below 100000) and `usda.<NDB>` for SR Legacy foods without a Canadian equivalent (food.id = 100000 + NDB).
-- A value that is not in `nutrient_value` is UNKNOWN: there is never a zero standing for « no data ».

CREATE TABLE pack_meta(
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
) WITHOUT ROWID;

-- The files the pack is built from (URL, date, SHA-256, licence), copied from sources.lock.json.
CREATE TABLE source(
    id          INTEGER PRIMARY KEY,
    code        TEXT NOT NULL,
    name        TEXT NOT NULL,
    url         TEXT,
    sha256      TEXT,
    downloaded  TEXT,
    license     TEXT NOT NULL,
    license_url TEXT
);

CREATE TABLE food_group(
    id      INTEGER PRIMARY KEY,   -- Canadian group (1…23); USDA category + 100
    name_en TEXT NOT NULL,
    name_fr TEXT
);

-- Food_Source of the Canadian file (where the profile comes from).
CREATE TABLE food_origin(
    code     INTEGER PRIMARY KEY,
    label_en TEXT NOT NULL,
    label_fr TEXT
);

CREATE TABLE food(
    id      INTEGER PRIMARY KEY,
    source  INTEGER NOT NULL,      -- source.id
    name_fr TEXT,                  -- NULL when the source has none (never translated automatically)
    name_en TEXT NOT NULL,
    alt_fr  TEXT,                  -- alternate names and keywords of the source
    alt_en  TEXT,
    grp     INTEGER NOT NULL,      -- food_group.id
    origin  INTEGER,               -- food_origin.code (Canadian file only)
    ndb     TEXT,                  -- USDA NDB code without leading zeros
    prep    INTEGER NOT NULL,      -- 0 not stated, 1 raw, 2 cooked, 3 processed or preserved (deduced from the names)
    qc      INTEGER NOT NULL       -- bit flags: 1 energy, 2 macros over 100 g, 4 fibre over carbs, 8 sugars over carbs, 16 saturated over fat
);

CREATE TABLE nutrient(
    id       INTEGER PRIMARY KEY,  -- Nutrient_Code of the Canadian file (= USDA nutrient number); 10001+ derived by Ardane
    symbol   TEXT,
    tag      TEXT,                 -- INFOODS tagname
    unit     TEXT NOT NULL,        -- g, mg, µg, kcal, kJ, mg NE
    name_en  TEXT NOT NULL,
    name_fr  TEXT,
    decimals INTEGER NOT NULL      -- Nutrient_Decimals: decimals to show; the value itself is stored as published
);

-- One row per known value, per 100 g of edible portion. prov packs the provenance in one integer (NULL: none known):
-- bits 0-6 = source code + 1 (Nutrient_Source_Code for the Canadian file, derivation_id for SR Legacy, see prov_code;
-- 0: none), bits 7-18 = number of observations (0: none), bits 19 and up = standard error x 10000 (0: none).
CREATE TABLE nutrient_value(
    food_id     INTEGER NOT NULL,
    nutrient_id INTEGER NOT NULL,
    value       REAL NOT NULL,
    prov        INTEGER,
    PRIMARY KEY(food_id, nutrient_id)
) WITHOUT ROWID;

CREATE TABLE prov_code(
    source   INTEGER NOT NULL,     -- source.id
    code     INTEGER NOT NULL,
    class    INTEGER NOT NULL,     -- 1 analytical, 2 calculated, 3 imputed, 4 assumed zero, 5 taken from USDA, 6 label or industry, 7 literature or other, 8 provisional, 9 international database, 10 derived by Ardane
    label_en TEXT NOT NULL,
    label_fr TEXT,
    PRIMARY KEY(source, code)
) WITHOUT ROWID;

-- Names of measures (« 250 ml », « 1 medium », « 1 cup, chopped »); ml is set when the measure is a volume.
CREATE TABLE measure(
    id       INTEGER PRIMARY KEY,
    label_en TEXT NOT NULL,
    label_fr TEXT,
    ml       REAL
);

-- kind: 6 household measure, 3 refuse (inedible part, as published), 9 other conversion of the Canadian file
-- (amount to make 250 ml…). pos: order of the file. preferred: 1 on the serving the app proposes by default.
CREATE TABLE portion(
    food_id    INTEGER NOT NULL,
    measure_id INTEGER NOT NULL,
    grams      REAL NOT NULL,
    kind       INTEGER NOT NULL,
    pos        INTEGER NOT NULL,
    preferred  INTEGER,
    PRIMARY KEY(food_id, measure_id)
) WITHOUT ROWID;

-- Apparent density derived from a household measure written in volume: g_per_ml = portion.grams / measure.ml,
-- kept between 0.2 and 2.0. kind: 1 plain measure, 2 pieces (air between them), 3 dense (mashed, melted, packed),
-- 4 contents of a container (true density).
CREATE TABLE density(
    food_id    INTEGER NOT NULL,
    measure_id INTEGER NOT NULL,
    g_per_ml   REAL NOT NULL,
    kind       INTEGER NOT NULL,
    PRIMARY KEY(food_id, measure_id)
) WITHOUT ROWID;

-- USDA cooking yield of a cooked food (percent of the raw weight, as published). raw_id: the raw food, when found.
CREATE TABLE prep_link(
    cooked_id INTEGER NOT NULL,
    raw_id    INTEGER,
    method    TEXT NOT NULL,
    percent   REAL NOT NULL,
    n         INTEGER,
    sd        REAL,
    minimum   REAL,
    maximum   REAL,
    moisture  REAL,                -- moisture gain or loss, %
    fat       REAL,                -- fat gain or loss, %
    source    INTEGER NOT NULL
);
CREATE INDEX prep_link_cooked ON prep_link(cooked_id);

-- Former identifiers (cnf.<FoodID 2015>) that are not the current one. how: 1 FoodCode 2015, 2 exact English name.
CREATE TABLE alias(
    old     TEXT PRIMARY KEY,
    food_id INTEGER NOT NULL,
    how     INTEGER NOT NULL
) WITHOUT ROWID;

-- Words of the names (normalized, see common.normalize). flags: 1 French name, 2 English name, 4 French alternate, 8 English alternate.
CREATE TABLE word(
    term    TEXT NOT NULL,
    food_id INTEGER NOT NULL,
    flags   INTEGER NOT NULL,
    PRIMARY KEY(term, food_id)
) WITHOUT ROWID;
