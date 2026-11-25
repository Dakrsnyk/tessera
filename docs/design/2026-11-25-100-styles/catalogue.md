# Bibliothèque de 100 styles visuels — catalogue (2026-11-25)

Demande du PDG du 2026-11-25 (voir `docs/memoire/Demandes.md`). Document de conception avant le code : rien n'est encore dans l'app.

## 1. Constat sur l'existant

- `Shared/Theme/Theme.swift` : `ThemeID` compte une cinquantaine de thèmes ; chacun est un `WidgetTheme` (fond `ThemeBackground`, couleurs `ThemeColor`, `fontDesign`, graisses, majuscules) et un `preset: StyleOptions` (`Shared/Model/WidgetStyle.swift`).
- `StyleOptions` sait déjà beaucoup : texture (none, grain, paper, dots, grid, lines, diagonal, noise, stars, snow, waves, web, leaves), bord (solid, dashed, dotted, double, glow, gradient), relief (soft, strong, glow, floating, embossed), forme (rounded, soft, square, capsule, panel), disposition (vertical, horizontal, minimal, centered, split, data, list, progress, graph, cards), icônes (plain, circle, square, outline, none), graphiques, densité, échelles de texte, interlettrage, casse, police libre (`fontName`, ~120 polices embarquées dans `Shared/Fonts`).
- **Pourquoi ça se répète** (captures du PDG) : la plupart des thèmes ne changent que les couleurs et gardent `preset` vide (disposition `auto`, aucune texture, aucun bord, relief nul, police système). Sur « Reste du mois », Glass, Midnight, Ocean, Forest, Sunset, Cyber, Luxury, Minimal Black et Pure White ont tous la même mise en page : seule la couleur change. Dans l'onglet Style, la couleur du thème choisi recouvre tout (« Sombre », « Verre », « Aurore »… sortent tous bleu nuit).

## 2. Règle de différence (contrôlée par un test)

Deux styles sont différents s'ils diffèrent sur **au moins 3 des 7 axes** : (1) famille de fond (uni clair, uni sombre, dégradé, verre, motif/texture), (2) police, (3) disposition, (4) bord, (5) relief, (6) forme, (7) traitement des libellés (casse, interlettrage, graisse). La couleur seule ne compte jamais. Un test `StyleLibraryTests` calculera la distance entre chaque paire des 100 et échouera sous 3.

Lisibilité : contraste texte/fond ≥ 4,5:1 (chiffre principal ≥ 3:1), calculé sur les couleurs résolues ; police décorative seulement sur les titres et grands chiffres, la police lisible du style reste sur les lignes de détail.

## 3. Ce qu'il faut ajouter au moteur (avant les 100)

Les axes existants suffisent pour environ 70 styles. Pour les 30 autres (pixel, rétro, illustration, horlogerie), il manque :
1. **Textures** : `scanlines` (CRT), `halftone` (trame BD), `pixels` (damier 8 bits), `guilloche` (cadran de montre), `marble` (marbre), `terrazzo`, `linen` (toile), `topo` (courbes de niveau), `brushed` (métal brossé), `sunburst` (cadran rayonnant).
2. **Bords** : `pixel` (créneaux 8 bits), `ticket` (encoches), `stitched` (couture), `bevel` (biseau Windows 95), `inset` (cadre intérieur fin, horlogerie).
3. **Relief** : `hardShadow` (ombre pleine décalée, néo-brutalisme), `longShadow`.
4. **Libellés** : `titleCase .smallCaps`, `labelStyle .tag` (étiquette pleine), `.underline`.
5. **Fond** : `ThemeBackground.pattern(base, motif)` pour un motif dessiné en code (pas d'image : poids de l'app), `.duotone(a, b, angle)`.
Tout est dessiné en SwiftUI dans `Shared/Render` (compilé aussi dans l'extension widget, mémoire du widget limitée : motifs en `Canvas`, jamais d'image plein cadre).

## 4. Les 100 styles

Colonnes : fond · texte / accent · police (titre ; détail) · texture · bord · relief · forme · disposition · libellés. « Sys » = police système (SF), « SysR » = SF Rounded, « SysS » = New York (serif système). ★ = gratuit (10 au total, au moins un par famille).

### A. Moderne, minimal, épuré
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 ★ | Blanc | uni FFFFFF | 111111 / accent | Sys | — | — | soft | rounded | auto | Majuscules fines |
| 2 | Papier Suisse | uni F4F1EA | 1A1A1A / E4002B | Sys, grand chiffre noir | grid 4 % | — | — | square | split | Minuscules, interlettrage serré |
| 3 | Gris Galet | uni E9EAEC | 2B2D31 / 5B6472 | SysR | — | solid 1 pt C9CCD1 | — | soft | centered | Normal |
| 4 | Encre | uni 0E0E0E | F2F2F2 / F2F2F2 | Sys ultra-fin (ultraLight) | — | — | — | rounded | minimal | Aucun titre |
| 5 | Nordique | uni F7F7F5 | 2E3440 / 88C0D0 | Raleway | linen 5 % | — | soft | soft | list | Petites capitales |
| 6 | Bauhaus | uni F2E8D5 | 111111 / D7263D, 1B4DE4, F4C20D | Josefin Sans gras | — | solid 2 pt noir | — | square | cards (cartes primaires) | Majuscules |
| 7 | Cristal | verre clair | 1C1C1E / accent | Sys | — | gradient blanc 40 % | floating | rounded | auto | Normal |
| 8 | Monoline | uni FFFFFF | 000000 / 000000 | Space Mono | — | solid 1 pt noir | — | square | data | Minuscules |
| 9 | Pierre | uni D8D2C8 | 3A342C / 8A6F55 | Marcellus | noise 6 % | — | embossed | soft | centered | Petites capitales |
| 10 | Aube | dégradé FDFCFB→E2D1C3 | 3D2C29 / C97B63 | Poppins | — | — | soft | capsule | horizontal | Normal |

### B. Dark, futuriste, cyberpunk
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 11 ★ | Nuit | uni 0B0B0F | F5F5F7 / accent | Sys | — | — | — | rounded | auto | Majuscules fines |
| 12 | Néon Tokyo | uni 0A0014 | FFFFFF / FF2BD6 + 00F0FF | Audiowide | scanlines 8 % | glow magenta | glow | square | split | Majuscules espacées |
| 13 | Terminal | uni 001100 | 33FF66 / 33FF66 | Space Mono | scanlines 12 % | dashed vert | — | square | list | Minuscules, préfixe « > » |
| 14 | HUD | uni 05121C | 9FE8FF / 00D1FF | Orbitron | grid 10 % cyan | bevel cyan (coins coupés) | glow | panel | data | Majuscules espacées |
| 15 | Carbone | uni 151515 | E6E6E6 / FF3B30 | Oswald | diagonal (tissage carbone) | — | strong | square | progress | Majuscules |
| 16 | Hologramme | dégradé 2B1055→7597DE→A9F1DF | FFFFFF / FFFFFF | Sys | noise 4 % | gradient irisé | floating | rounded | centered | Normal |
| 17 | Synthwave | dégradé 2D0B4E→F72585 + soleil rayé | FFE6FF / FFB800 | Monoton (titre) ; Sys | sunburst | — | glow | soft | horizontal | Majuscules |
| 18 | Matrice | uni 000000 | 00FF41 / 00FF41 | Space Mono | colonnes de glyphes (pattern) | — | — | square | minimal | Aucun titre |
| 19 | Chrome | dégradé métal C0C0C0→6E6E6E→E8E8E8 | 111111 / 111111 | Orbitron | brushed | double gris | embossed | rounded | centered | Majuscules |
| 20 | Vide Spatial | uni 03030A | DDE3FF / 7C83FF | Sys fin | stars | — | — | capsule | graph | Normal |

### C. Luxe, horlogerie, premium
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 21 | Cadran Ardoise | uni 1E2328 | E9E6DF / C9A86A | Cinzel ; Sys | sunburst 10 % | inset or fin | — | rounded | centered (chiffre en compteur) | Petites capitales |
| 22 | Guilloché | uni 0F2A44 | F2EBDD / D4AF37 | Bodoni Moda | guilloche | double or | embossed | soft | centered | Petites capitales |
| 23 | Plongée | uni 0B3B2E | F4F4F4 / 2BD29A | Oswald (index de lunette) | — | solid 3 pt acier | strong | capsule | progress (anneau de lunette) | Majuscules |
| 24 | Or Rose | dégradé F7E7DC→E8C3B0 | 4A2C2A / B76E79 | Italiana | brushed 6 % | inset B76E79 | soft | rounded | centered | Petites capitales |
| 25 | Écrin | uni 101010 | F5F0E6 / C5A572 | Playfair Display | — | inset or | floating | square | split | Majuscules espacées |
| 26 | Platine | dégradé F1F1F1→CFCFCF | 202020 / 707070 | DM Serif Display | brushed | solid 1 pt A0A0A0 | embossed | rounded | auto | Normal |
| 27 | Champagne | uni F6EEDC | 3B2F1E / B8925A | Lora italique | linen | — | soft | soft | list | Italique fin |
| 28 | Velours | uni 2B0A14 | F3E3E8 / D9A441 | Libre Baskerville | noise 8 % | — | strong | rounded | centered | Petites capitales |
| 29 | Marbre Noir | motif marbre 111/2A2A2A | FFFFFF / D4AF37 | Cinzel | marble | solid 1 pt or | — | square | centered | Majuscules |
| 30 | Chronographe | uni F2F0EB | 1A1A1A / C8102E | Sys condensé + sous-compteurs | sunburst 4 % | inset noir | — | rounded | data (3 sous-cadrans) | Majuscules |

### D. Riche, élégant, sophistiqué
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 31 ★ | Ivoire | uni FBF8F1 | 2A2420 / 8C6A43 | SysS | — | — | soft | rounded | auto | Normal |
| 32 | Émeraude | uni 0F3D2E | F1EBDD / D4B06A | Playfair Display | linen 6 % | inset or | — | soft | split | Petites capitales |
| 33 | Bordeaux | uni 4A0E1C | F7E9E4 / E8B4A0 | Lora | — | — | strong | rounded | list | Italique |
| 34 | Saphir | dégradé 0B1F4B→1E3A8A | EEF2FF / C7D2FE | DM Serif Display | — | gradient argent | floating | rounded | centered | Normal |
| 35 | Art déco | uni 0D0D0D | F0E6D2 / D4AF37 | Limelight | motif éventail (pattern) | double or | — | square | centered | Majuscules espacées |
| 36 | Bibliothèque | uni 3A2A1C | F3E7D3 / C9A15B | Libre Baskerville | paper | stitched cuir | embossed | soft | list | Petites capitales |
| 37 | Opéra | uni 1A0507 | FFF0E8 / C8102E | Bodoni Moda italique | — | — | glow rouge | rounded | centered | Italique |
| 38 | Cachemire | uni E9DCCF | 4B3A2F / 9C6B4E | Marcellus | linen | — | soft | capsule | horizontal | Petites capitales |
| 39 | Calligraphe | uni FAF6EE | 222222 / 7A1E2B | Pinyon Script (titre) ; Lora | paper 6 % | — | — | soft | centered | Titre en script |
| 40 | Galerie | uni FFFFFF | 111111 / 111111 | Gloock | — | solid 8 pt blanc + 1 pt noir (passe-partout) | floating | square | minimal | Légende sous le chiffre |

### E. Vintage, rétro, années 70-80-90
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 41 ★ | Rétro 70 | uni F3E3C3 | 4A2C17 / E36414 + F2A33A | Shrikhand | — | — | — | capsule | horizontal (bandes orange/brun) | Normal |
| 42 | Windows 95 | uni C0C0C0 | 000000 / 000080 | Sys bitmap → Space Mono | — | bevel gris | — | square | list (barre de titre bleue) | Normal |
| 43 | Machine à écrire | uni F4EFE1 | 2B2B2B / A3201D | Special Elite | paper | — | — | square | list | Minuscules |
| 44 | Polaroid | uni FFFFFF, cadre bas épais | 222222 / accent | Permanent Marker (légende) | — | solid 10 pt blanc | floating | square | minimal (chiffre au centre, légende manuscrite) | Manuscrit |
| 45 | Jukebox | dégradé B31217→E52D27 | FFF4D6 / FFD23F | Pacifico | sunburst | double crème | glow | capsule | centered | Normal |
| 46 | VHS | uni 101010 | F2F2F2 / FF3B3B, 2BD9FE | Space Mono | scanlines + noise | — | — | square | split (bandes RGB décalées) | Majuscules, « PLAY ▶ » |
| 47 | Memphis | uni FFF5E1 | 1D1D1D / FF5E9C, 2EC4B6, FFD23F | Bungee | motif confettis géométriques | solid 2 pt noir | hardShadow noir | square | cards | Majuscules |
| 48 | Ticket de cinéma | uni F2D7A6 | 5A1F14 / 5A1F14 | Bebas Neue | paper | ticket | — | panel | horizontal (talon détachable) | Majuscules |
| 49 | Diner 50 | uni F7F3E8 + damier | C1121F / 1D3557 | Righteous | damier rouge/blanc en bas | — | soft | capsule | centered | Normal |
| 50 | Cassette | uni 2A2A2A | F2E6C9 / F25C05 | Oswald | — | solid 2 pt F25C05 | — | rounded | progress (deux bobines) | Majuscules |

### F. Rose, pastel, doux
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 51 ★ | Sakura | uni FCE8EE | 5B2A3C / D6457A | Quicksand | motif pétales | — | soft | capsule | progress (anneau) | Normal |
| 52 | Barbe à papa | dégradé FFD1E8→C9E7FF | 4A3B5C / A06CD5 | Fredoka | — | — | floating | capsule | centered | Normal |
| 53 | Macaron | uni F7E1D7 | 4E3B31 / E58F9B, A8D5BA | Comfortaa | dots 8 % | stitched rose | — | soft | cards (cartes pastel) | Normal |
| 54 | Lavande | uni EEE6F7 | 3E2F5B / 9B7EDE | Poiret One | — | dotted lavande | — | rounded | list | Minuscules |
| 55 | Pêche | dégradé FFE5D0→FFC9B5 | 5C3A2E / F2785C | Poppins | grain 5 % | — | soft | capsule | horizontal | Normal |
| 56 | Kawaii | uni FFF0F5 | 4A2E3D / FF7AB6 | Chewy | dots | solid 3 pt FF7AB6 | hardShadow rose | capsule | centered (visage ˆ‿ˆ sur l'anneau) | Normal |
| 57 | Aquarelle | motif lavis F8EEF2/E5F1F8 | 3F3A4A / C77DA0 | Handlee | paper + taches (pattern) | — | — | soft | auto | Manuscrit |
| 58 | Menthe | uni E3F6EE | 1F4D3A / 3BB37D | SysR | — | — | soft | capsule | progress | Normal |
| 59 | Ballerine | uni F9EEF0 | 4A3438 / C9A0A6 | Ballet (titre) ; Raleway | — | double rose fin | — | rounded | centered | Titre en script |
| 60 | Nuage | uni F3F6FB | 46546B / 8FA9D8 | SysR | — | — | floating (très diffus) | capsule | minimal | Normal |

### G. 2D, illustration, univers graphiques
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 61 | Bande dessinée | uni FFFFFF | 111111 / FFD400, E10600 | Bangers | halftone | solid 3 pt noir | hardShadow | square | split (case + bulle) | Majuscules |
| 62 | Carnet de croquis | uni FDFBF6 | 2B2B2B / 2B2B2B | Architects Daughter | grid (papier quadrillé) | dashed crayon | — | soft | list | Manuscrit |
| 63 | Papier découpé | uni F5EBDD | 2D2A26 / E07A5F, 3D405B, 81B29A | Fredoka | — | — | strong (couches superposées) | soft | cards | Normal |
| 64 | Risographie | uni F6F1E7 | 1D3557 / FF4F79 (deux encres décalées) | Archivo Black | grain 15 % | — | — | square | split | Majuscules |
| 65 | Craie | uni 2F3B35 | F2F2EE / F2E394 | Gloria Hallelujah | chalk (noise) | dashed craie | — | square | list | Manuscrit |
| 66 | Isométrique | uni EEF1F6 | 1F2937 / 4F7CFF | Poppins | grid isométrique (pattern) | — | strong | square | graph (barres en volume) | Normal |
| 67 | Flat | uni 2EC4B6 | FFFFFF / FFE66D | Poppins gras | — | — | longShadow | square | centered | Majuscules |
| 68 | Ligne claire | uni FBF7EE | 1A1A1A / 1E88E5 | Patrick Hand | — | solid 1,5 pt noir | — | rounded | horizontal | Normal |
| 69 | Pop Art | uni FFDD00 | 111111 / E4002B, 0057FF | Anton | halftone rouge | solid 4 pt noir | hardShadow | square | centered | Majuscules |
| 70 | Origami | dégradé facettes F4F4F4/E2E2E2 | 2B2B2B / D7263D | Josefin Sans | diagonal (plis) | — | soft | square | split en diagonale | Majuscules fines |

### H. Jeu vidéo, gaming, pixel art
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 71 ★ | 8 bits | uni 1D2B53 | FFF1E8 / FF004D, FFEC27 | Press Start 2P | pixels | pixel | — | square | progress (barre de vie en cœurs) | Majuscules |
| 72 | Game Boy | uni 9BBC0F | 0F380F / 306230 | Press Start 2P | pixels 6 % | pixel 0F380F | — | square | list | Majuscules |
| 73 | Arcade | uni 000000 | FFFFFF / FFE600, FF2D95 | Press Start 2P | scanlines | glow jaune | glow | square | data (« HI-SCORE ») | Majuscules |
| 74 | RPG | uni 1B1B3A | F5F5F5 / F2C14E | Pirata One (titre) ; Sys | — | double blanc (boîte de dialogue) | — | rounded | list (menu à curseur ▶) | Majuscules |
| 75 | Console néon | dégradé 0F0C29→302B63 | FFFFFF / 00F5D4 | Orbitron | grid | gradient violet/cyan | glow | rounded | split (jauges RGB) | Majuscules |
| 76 | Esport | uni 0D0D0D | FFFFFF / FF4655 | Bebas Neue | diagonal rouge 10 % | — | strong | panel (coins coupés) | data | Majuscules italiques |
| 77 | Voxel | uni 7EC850 (herbe) / 8B5A2B (terre) | FFFFFF / FFFFFF | Press Start 2P | pixels | pixel brun | strong | square | cards (blocs) | Majuscules |
| 78 | Quête | uni EFE2C4 (parchemin) | 3B2412 / 8A1C1C | Almendra | paper + taches | double brun | — | soft | list (objectifs ✓) | Petites capitales |
| 79 | Retro Wave Racer | dégradé 000000→3A0CA3 + grille au sol | FFFFFF / F72585 | Audiowide | grid en perspective (pattern) | — | glow | square | progress (compteur de vitesse) | Majuscules |
| 80 | Interface MMO | uni 23262E | E6E6E6 / 4CC9F0, F9C74F | Sys condensé | — | bevel sombre | strong | panel | cards (inventaire) | Majuscules petites |

### I. Nature, architecture, art, photographie
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 81 ★ | Forêt | uni 1E3A2B | EEF3E8 / A3C585 | Lora | leaves 8 % | — | — | soft | auto | Normal |
| 82 | Topographie | uni F3EFE6 | 2F3B2F / C0703C | Josefin Slab | topo | — | — | rounded | graph | Majuscules fines |
| 83 | Océan profond | dégradé 001F3F→0074D9 | E6F6FF / 7FDBFF | SysR | waves | — | soft | capsule | progress (niveau d'eau) | Normal |
| 84 | Désert | dégradé F4D6A0→D98E4C | 4A2511 / 8C3B12 | Oswald | grain 12 % | — | — | soft | horizontal (dunes) | Majuscules |
| 85 | Herbier | uni F5F1E6 | 2E3B2A / 6B8F4E | Courgette (titre) ; Lora | paper | stitched vert | — | soft | split (planche + étiquette) | Étiquette d'herbier |
| 86 | Béton brut | uni 9A9A96 | 111111 / 111111 | Archivo Black | noise 14 % | — | — | square | data | Majuscules |
| 87 | Plan d'architecte | uni 0B3D91 | FFFFFF / FFFFFF | Space Mono fin | grid 15 % | solid 1 pt blanc + cotes | — | square | data (cotes et repères) | Majuscules fines |
| 88 | Terrazzo | motif terrazzo F4F0EA | 2A2A2A / E07A5F | Poppins | terrazzo | — | soft | rounded | centered | Normal |
| 89 | Pellicule | uni 111111 | F2F2F2 / FFB000 | Courier Prime | grain 18 % | perforations (pattern) | — | square | horizontal (bande de film) | Majuscules, n° d'image |
| 90 | Musée | uni EDEAE3 | 1A1A1A / 8B0000 | Cinzel | — | solid 12 pt doré (cadre de tableau) | strong | square | centered (cartel) | Cartel |

### J. Industriel, brutaliste, éditorial, expérimental
| # | Nom | Fond | Texte / accent | Police | Texture | Bord | Relief | Forme | Disposition | Libellés |
|---|---|---|---|---|---|---|---|---|---|---|
| 91 ★ | Brutal | uni FFFFFF | 000000 / 0000FF | Archivo Black | — | solid 3 pt noir | hardShadow noir | square | split | Majuscules |
| 92 | Une de journal | uni F4F1E8 | 111111 / 111111 | Unifraktur Cook (titre) ; Libre Baskerville | paper | double noir (filets) | — | square | list (colonnes) | Titre gothique |
| 93 | Magazine | uni FFFFFF | 111111 / FF3B30 | DM Serif Display chiffre géant | — | — | — | square | minimal (chiffre plein cadre) | Majuscules minuscules |
| 94 | Signalétique | uni FFD200 | 111111 / 111111 | Oswald | diagonal noir (rayures de chantier) en bas | — | — | square | horizontal | Majuscules |
| 95 | Usine | uni 3A3F44 | F0F0F0 / F2A900 | Bebas Neue | brushed | rivets (pattern) + solid acier | embossed | square | data | Majuscules pochoir |
| 96 | Suisse international | uni E30613 | FFFFFF / FFFFFF | Sys gras, grille stricte | — | — | — | square | split asymétrique | Minuscules |
| 97 | Typographique | uni F0EEE9 | 111111 / 111111 | Abril Fatface, chiffre en contour | — | — | — | square | minimal | Aucun titre |
| 98 | Glitch | uni 0A0A0A | FFFFFF / FF0055 + 00FFF0 | Space Mono | scanlines + noise | — | — | square | split (texte dédoublé RGB) | Majuscules |
| 99 | Duotone | duotone 1C1C6B→FF5E5B | FFFFFF / FFFFFF | Anton | halftone 10 % | — | — | rounded | centered | Majuscules |
| 100 | Fiche technique | uni FFFFFF | 111111 / FF5F00 | Space Mono | grid 5 % | solid 1 pt noir, numéros de champs | — | square | data (champs numérotés 01, 02…) | Minuscules |

## 5. Intégration prévue

- Nouveau type `StyleLook` (identité complète : thème + `StyleOptions` + police + libellés), catalogue `StyleLibrary` de 100 entrées avec `family` interne (A…J, jamais affichée), nom, accroche, gratuit/Premium.
- **Thème** (onglet Thème du Studio) = la bibliothèque des 100, aperçus rendus avec les vraies données du widget (comme aujourd'hui), triés par famille sans titre de section. Les anciens `ThemeID` restent lisibles (raw values persistées) : chacun est rattaché au style le plus proche, les widgets enregistrés gardent leur rendu.
- **Style** (onglet Style) = la composition seule (disposition, forme…) qui ne repeint plus tout dans la couleur du thème : chaque vignette montre sa vraie différence.
- La couleur principale choisie dans « Couleurs » reste possible mais ne remplace plus l'identité : elle teinte l'accent seulement (sauf choix explicite « repeindre tout »).
- Vérification : test de distance (§2), test de contraste, test de rendu des 100 × 3 tailles (petit, moyen, grand) + écran verrouillé sans plantage, planche de captures `[store]` des 100 sur « Reste du mois » et « Séance du jour » pour l'œil du PDG avant le build interne.

## 6. Lots de travail (dès la remise à zéro de la limite, 2026-11-26)

1. Moteur : textures, bords, reliefs, libellés et fonds manquants (§3), avec tests.
2. `StyleLibrary` (100 entrées) + test de distance + test de contraste.
3. Studio : onglet Thème sur la bibliothèque, onglet Style sans recoloration, migration des anciens thèmes.
4. Traductions des 100 noms et accroches (6 langues, lots `l10n/parts`).
5. Captures `[store]` des 100, relecture `code-reviewer`, `[check]` puis build interne.
