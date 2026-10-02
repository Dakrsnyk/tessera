import Foundation

// MARK: - Vocabulary

enum Muscle: String, Codable, CaseIterable, Identifiable {
    case chest, back, traps, lowerBack, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves, abs, obliques, fullBody, heart
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: tr("Pectoraux")
        case .back: tr("Dos")
        case .traps: tr("Trapèzes")
        case .lowerBack: tr("Lombaires")
        case .shoulders: tr("Épaules")
        case .biceps: tr("Biceps")
        case .triceps: tr("Triceps")
        case .forearms: tr("Avant-bras")
        case .quads: tr("Quadriceps")
        case .hamstrings: tr("Ischio-jambiers")
        case .glutes: tr("Fessiers")
        case .calves: tr("Mollets")
        case .abs: tr("Abdominaux")
        case .obliques: tr("Obliques")
        case .fullBody: tr("Corps entier")
        case .heart: tr("Cardio")
        }
    }
}

/// The groups offered as filters: close muscles together, as people search them.
enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, quads, hamstrings, glutes, calves, abs, lowerBack, fullBody
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: tr("Pectoraux")
        case .back: tr("Dos")
        case .shoulders: tr("Épaules")
        case .biceps: tr("Biceps")
        case .triceps: tr("Triceps")
        case .forearms: tr("Avant-bras")
        case .quads: tr("Quadriceps")
        case .hamstrings: tr("Ischio-jambiers")
        case .glutes: tr("Fessiers")
        case .calves: tr("Mollets")
        case .abs: tr("Abdominaux")
        case .lowerBack: tr("Lombaires")
        case .fullBody: tr("Full body")
        }
    }

    var muscles: Set<Muscle> {
        switch self {
        case .chest: [.chest]
        case .back: [.back, .traps]
        case .shoulders: [.shoulders]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearms]
        case .quads: [.quads]
        case .hamstrings: [.hamstrings]
        case .glutes: [.glutes]
        case .calves: [.calves]
        case .abs: [.abs, .obliques]
        case .lowerBack: [.lowerBack]
        case .fullBody: [.fullBody]
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case bodyweight, dumbbells, barbell, machine, cable, kettlebell, band, bench, pullUpBar, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyweight: tr("Poids du corps")
        case .dumbbells: tr("Haltères")
        case .barbell: tr("Barre")
        case .machine: tr("Machine")
        case .cable: tr("Poulie")
        case .kettlebell: tr("Kettlebell")
        case .band: tr("Élastique")
        case .bench: tr("Banc")
        case .pullUpBar: tr("Barre de traction")
        case .other: tr("Autre")
        }
    }

    var symbol: String {
        switch self {
        case .bodyweight: "figure.stand"
        case .dumbbells: "dumbbell.fill"
        case .barbell: "figure.strengthtraining.traditional"
        case .machine: "gearshape.fill"
        case .cable: "cable.connector"
        case .kettlebell: "figure.strengthtraining.functional"
        case .band: "circle.dashed"
        case .bench: "rectangle.fill"
        case .pullUpBar: "figure.climbing"
        case .other: "ellipsis.circle"
        }
    }
}

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case strength, cardio, mobility, stretching
    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: tr("Musculation")
        case .cardio: tr("Cardio")
        case .mobility: tr("Mobilité")
        case .stretching: tr("Étirement")
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: tr("Débutant")
        case .intermediate: tr("Intermédiaire")
        case .advanced: tr("Avancé")
        }
    }
}

/// How the body moves: decides the animated demonstration and the general technique.
enum MovementPattern: String, CaseIterable {
    case benchPress, pushUp, dip, verticalPush, horizontalPull, verticalPull, seatedRow, pullover
    case squat, hinge, lunge, legPress, legExtension, legCurl, bridge, legKickback, calfRaise
    case curl, tricepsExtension, overheadExtension, lyingExtension, lateralRaise, frontRaise, fly, uprightRow, shrug
    case crunch, plank, legRaise, rotation, superman, mountainClimber, carry
    case run, cycle, rowing, jump, armCircles, stretchFold, stretchStand, generic
}

// MARK: - An exercise

struct ExerciseInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let primary: [Muscle]
    let secondary: [Muscle]
    let equipment: [Equipment]
    let type: ExerciseType
    let difficulty: Difficulty
    let pattern: MovementPattern
    /// Advice specific to this exercise, added to the technique of its movement.
    let cues: [String]

    /// Its own technique when its movement differs from its family's, the family's otherwise.
    var technique: ExerciseTechnique { ExerciseLibrary.technique(for: id) ?? ExerciseTechnique.technique(for: pattern) }

    /// "Pectoraux · Barre, banc"
    var summary: String {
        let muscles = primary.map(\.title).joined(separator: ", ")
        let tools = equipment.map(\.title).joined(separator: ", ").lowercasedFirstLetter
        return "\(muscles) · \(tools)"
    }
}

/// The technique common to a movement: position, execution, breathing, what to watch and what to
/// avoid. Written to be safe and general; each exercise adds its own cues.
struct ExerciseTechnique: Hashable {
    let start: String
    let steps: [String]
    let range: String
    let breathing: String
    let tips: [String]
    let mistakes: [String]

    static func technique(for pattern: MovementPattern) -> ExerciseTechnique {
        switch pattern {
        case .benchPress:
            ExerciseTechnique(
                start: tr("Allongé sur le banc, yeux sous la charge, pieds à plat au sol, omoplates serrées et abaissées."),
                steps: [tr("Saisis la charge un peu plus large que les épaules."), tr("Descends lentement vers le bas de la poitrine, coudes à environ 45° du corps."), tr("Pousse jusqu'aux bras tendus, sans verrouiller brutalement les coudes.")],
                range: tr("Descends jusqu'à effleurer la poitrine, sans rebond."),
                breathing: tr("Inspire en descendant, expire en poussant."),
                tips: [tr("Garde les fesses sur le banc et les pieds ancrés."), tr("Poignets droits, au-dessus des coudes.")],
                mistakes: [tr("Coudes écartés à 90°, qui chargent les épaules."), tr("Rebondir sur la poitrine."), tr("Décoller les fesses du banc."), tr("Charger lourd sans pareur ni sécurités.")]
            )
        case .pushUp:
            ExerciseTechnique(
                start: tr("Mains au sol un peu plus larges que les épaules, corps gainé en ligne droite des talons à la tête."),
                steps: [tr("Descends la poitrine vers le sol, coudes à environ 45° du corps."), tr("Pousse le sol pour remonter jusqu'aux bras tendus.")],
                range: tr("La poitrine arrive à quelques centimètres du sol."),
                breathing: tr("Inspire en descendant, expire en remontant."),
                tips: [tr("Serre les fessiers et le ventre tout le long."), tr("Regarde le sol un peu devant tes mains.")],
                mistakes: [tr("Hanches qui s'affaissent ou montent trop."), tr("Tête qui avance avant le buste."), tr("Amplitude trop courte.")]
            )
        case .dip:
            ExerciseTechnique(
                start: tr("En appui sur les barres (ou les mains sur un banc derrière toi), bras tendus, épaules basses."),
                steps: [tr("Plie les coudes pour descendre le corps."), tr("Remonte en poussant jusqu'aux bras tendus.")],
                range: tr("Descends jusqu'aux coudes à environ 90°, sans douleur aux épaules."),
                breathing: tr("Inspire en descendant, expire en remontant."),
                tips: [tr("Buste droit pour les triceps, légèrement penché pour les pectoraux."), tr("Garde les épaules loin des oreilles.")],
                mistakes: [tr("Descendre trop bas au détriment des épaules."), tr("Épaules qui montent."), tr("Balancer les jambes.")]
            )
        case .verticalPush:
            ExerciseTechnique(
                start: tr("Debout (ou assis), charge à hauteur des épaules, ventre et fessiers gainés."),
                steps: [tr("Pousse la charge au-dessus de la tête jusqu'aux bras tendus."), tr("La tête passe légèrement vers l'avant une fois la charge au-dessus."), tr("Redescends sous contrôle jusqu'aux épaules.")],
                range: tr("Des épaules jusqu'aux bras tendus, charge au-dessus du milieu du pied."),
                breathing: tr("Inspire en bas, expire en poussant."),
                tips: [tr("Coudes légèrement devant la charge au départ."), tr("Garde les côtes basses.")],
                mistakes: [tr("Cambrer fortement le bas du dos."), tr("Pousser la charge vers l'avant."), tr("Plier les genoux pour tricher.")]
            )
        case .horizontalPull:
            ExerciseTechnique(
                start: tr("Buste penché à environ 45°, dos droit, genoux légèrement fléchis, bras tendus sous les épaules."),
                steps: [tr("Tire la charge vers le bas du ventre en serrant les omoplates."), tr("Marque une courte pause."), tr("Redescends lentement jusqu'aux bras tendus.")],
                range: tr("Des bras tendus jusqu'à la charge contre le ventre."),
                breathing: tr("Expire en tirant, inspire en redescendant."),
                tips: [tr("Pense à tirer avec les coudes, pas avec les mains."), tr("Garde la nuque dans l'alignement du dos.")],
                mistakes: [tr("Dos rond."), tr("Redresser le buste pour donner de l'élan."), tr("Hausser les épaules.")]
            )
        case .verticalPull:
            ExerciseTechnique(
                start: tr("Suspendu à la barre (ou assis à la poulie), mains un peu plus larges que les épaules, bras tendus."),
                steps: [tr("Abaisse d'abord les épaules, puis tire les coudes vers le bas et l'arrière."), tr("Monte jusqu'au menton au-dessus de la barre (ou la barre au haut de la poitrine)."), tr("Redescends lentement jusqu'aux bras tendus.")],
                range: tr("Bras tendus en bas, menton au-dessus de la barre en haut."),
                breathing: tr("Expire en tirant, inspire en redescendant."),
                tips: [tr("Poitrine vers la barre."), tr("Jambes calmes, sans balancer.")],
                mistakes: [tr("Élan des jambes."), tr("Amplitude partielle."), tr("Épaules qui montent vers les oreilles.")]
            )
        case .seatedRow:
            ExerciseTechnique(
                start: tr("Assis, pieds calés, dos droit, bras tendus vers la poignée."),
                steps: [tr("Tire la poignée vers le ventre en serrant les omoplates."), tr("Reviens bras tendus en laissant les omoplates s'écarter, sans arrondir le dos.")],
                range: tr("Des bras tendus jusqu'à la poignée contre le ventre."),
                breathing: tr("Expire en tirant, inspire en revenant."),
                tips: [tr("Garde le buste presque immobile."), tr("Coudes près du corps pour le milieu du dos.")],
                mistakes: [tr("Basculer le buste d'avant en arrière."), tr("Hausser les épaules."), tr("Arrondir le dos au retour.")]
            )
        case .pullover:
            ExerciseTechnique(
                start: tr("Bras presque tendus au-dessus de la tête (debout face à la poulie, ou allongé en travers d'un banc)."),
                steps: [tr("Abaisse les bras en arc de cercle jusqu'aux hanches (ou au-dessus de la poitrine)."), tr("Reviens lentement en gardant les coudes fixes.")],
                range: tr("Tant que les épaules restent confortables."),
                breathing: tr("Expire en abaissant, inspire en revenant."),
                tips: [tr("Coudes légèrement fléchis et immobiles."), tr("Gaine le ventre pour ne pas cambrer.")],
                mistakes: [tr("Plier les coudes (ça devient un triceps)."), tr("Cambrer le dos."), tr("Aller trop loin derrière la tête.")]
            )
        case .squat:
            ExerciseTechnique(
                start: tr("Debout, pieds largeur d'épaules, pointes légèrement ouvertes, charge stable."),
                steps: [tr("Inspire et gaine le ventre."), tr("Pousse les hanches vers l'arrière et plie les genoux dans l'axe des pieds."), tr("Remonte en poussant dans tout le pied.")],
                range: tr("Au moins jusqu'aux cuisses parallèles au sol si ta mobilité le permet, dos neutre."),
                breathing: tr("Inspire avant de descendre, expire en remontant."),
                tips: [tr("Genoux dans la direction des orteils."), tr("Poids réparti sur tout le pied.")],
                mistakes: [tr("Genoux qui rentrent vers l'intérieur."), tr("Talons qui décollent."), tr("Dos qui s'arrondit en bas.")]
            )
        case .hinge:
            ExerciseTechnique(
                start: tr("Debout, pieds largeur de hanches, charge près des jambes, dos neutre."),
                steps: [tr("Pousse les hanches vers l'arrière en gardant la charge collée aux jambes."), tr("Descends jusqu'à l'étirement des ischio-jambiers (ou la charge au sol)."), tr("Remonte en poussant les hanches vers l'avant.")],
                range: tr("Tant que le dos reste droit : c'est la hanche qui bouge, pas le dos."),
                breathing: tr("Inspire et gaine en haut, expire en remontant."),
                tips: [tr("Genoux légèrement fléchis."), tr("Serre les fessiers en haut, sans te pencher en arrière.")],
                mistakes: [tr("Dos rond."), tr("Charge qui s'éloigne des jambes."), tr("Cambrer en fin de mouvement.")]
            )
        case .lunge:
            ExerciseTechnique(
                start: tr("Debout, pieds largeur de hanches, buste droit."),
                steps: [tr("Fais un grand pas (en avant, en arrière ou sur le banc)."), tr("Descends jusqu'aux deux genoux pliés à environ 90°."), tr("Pousse sur le pied avant pour revenir.")],
                range: tr("Le genou arrière approche le sol sans le toucher."),
                breathing: tr("Inspire en descendant, expire en remontant."),
                tips: [tr("Genou avant dans l'axe du pied."), tr("Buste droit, regard devant.")],
                mistakes: [tr("Genou avant qui rentre."), tr("Pas trop court."), tr("Buste qui plonge vers l'avant.")]
            )
        case .legPress:
            ExerciseTechnique(
                start: tr("Assis dans la machine, dos plaqué au dossier, pieds largeur de hanches sur la plateforme."),
                steps: [tr("Déverrouille la plateforme."), tr("Plie les genoux vers la poitrine."), tr("Pousse jusqu'aux jambes presque tendues.")],
                range: tr("Tant que le bas du dos reste collé au dossier."),
                breathing: tr("Inspire en descendant, expire en poussant."),
                tips: [tr("Pousse dans les talons et le milieu du pied.")],
                mistakes: [tr("Verrouiller les genoux en haut."), tr("Bassin qui décolle en bas."), tr("Genoux qui rentrent.")]
            )
        case .legExtension:
            ExerciseTechnique(
                start: tr("Assis, dos contre le dossier, rouleau sur le bas des tibias."),
                steps: [tr("Tends les jambes."), tr("Marque une seconde en haut."), tr("Redescends lentement.")],
                range: tr("Jusqu'aux jambes tendues."),
                breathing: tr("Expire en tendant, inspire en redescendant."),
                tips: [tr("Tiens les poignées pour rester assis.")],
                mistakes: [tr("Donner de l'élan."), tr("Décoller les fesses du siège.")]
            )
        case .legCurl:
            ExerciseTechnique(
                start: tr("Allongé ou assis dans la machine, rouleau au-dessus des talons."),
                steps: [tr("Plie les genoux au maximum."), tr("Redescends lentement.")],
                range: tr("Des jambes tendues jusqu'à la flexion complète."),
                breathing: tr("Expire en pliant, inspire en revenant."),
                tips: [tr("Garde les hanches collées au banc.")],
                mistakes: [tr("Hanches qui décollent."), tr("Élan."), tr("Descente trop rapide.")]
            )
        case .bridge:
            ExerciseTechnique(
                start: tr("Dos au sol (ou le haut du dos sur un banc), genoux pliés, pieds à plat largeur de hanches."),
                steps: [tr("Pousse dans les talons pour monter les hanches."), tr("Serre les fessiers en haut, épaules-hanches-genoux alignés."), tr("Redescends sous contrôle.")],
                range: tr("Jusqu'à l'alignement du buste et des cuisses, pas au-delà."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Menton rentré, regard devant toi en haut.")],
                mistakes: [tr("Cambrer le bas du dos en haut."), tr("Pousser sur la pointe des pieds.")]
            )
        case .legKickback:
            ExerciseTechnique(
                start: tr("À quatre pattes (ou debout face à la poulie), dos plat, ventre gainé."),
                steps: [tr("Pousse une jambe vers l'arrière en contractant le fessier."), tr("Reviens lentement sans poser le genou.")],
                range: tr("Jusqu'à la cuisse dans l'alignement du dos."),
                breathing: tr("Expire en poussant, inspire en revenant."),
                tips: [tr("Le bassin reste face au sol.")],
                mistakes: [tr("Cambrer le dos pour monter plus haut."), tr("Tourner le bassin.")]
            )
        case .calfRaise:
            ExerciseTechnique(
                start: tr("Debout, l'avant du pied sur une marche ou au sol, jambes tendues."),
                steps: [tr("Monte sur la pointe des pieds le plus haut possible."), tr("Tiens une seconde."), tr("Redescends lentement, sous l'horizontale si tu es sur une marche.")],
                range: tr("Du talon bas jusqu'à la pointe haute."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Garde les genoux droits sans les verrouiller.")],
                mistakes: ["Rebondir.", tr("Amplitude trop courte.")]
            )
        case .curl:
            ExerciseTechnique(
                start: tr("Debout, bras tendus, coudes près du buste."),
                steps: [tr("Plie les coudes pour monter la charge vers les épaules."), tr("Serre en haut."), tr("Redescends lentement jusqu'aux bras tendus.")],
                range: tr("Des bras tendus jusqu'à la flexion complète."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Seuls les avant-bras bougent.")],
                mistakes: [tr("Balancer le buste."), tr("Coudes qui avancent."), tr("Descente trop rapide.")]
            )
        case .tricepsExtension:
            ExerciseTechnique(
                start: tr("Coudes fixes près du corps, avant-bras pliés, charge en main."),
                steps: [tr("Tends complètement les bras vers le bas (ou l'arrière)."), tr("Reviens lentement jusqu'aux avant-bras à l'horizontale.")],
                range: tr("Du coude plié à 90° jusqu'au bras tendu."),
                breathing: tr("Expire en tendant, inspire en revenant."),
                tips: [tr("Coudes collés au corps, épaules basses.")],
                mistakes: [tr("Coudes qui s'écartent ou avancent."), tr("Pencher le buste pour pousser.")]
            )
        case .overheadExtension:
            ExerciseTechnique(
                start: tr("Debout ou assis, charge tenue au-dessus de la tête, bras tendus."),
                steps: [tr("Plie les coudes pour descendre la charge derrière la tête."), tr("Tends de nouveau les bras.")],
                range: tr("Tant que les épaules restent confortables."),
                breathing: tr("Inspire en descendant, expire en tendant."),
                tips: [tr("Coudes vers le haut, proches de la tête."), tr("Gaine le ventre pour ne pas cambrer.")],
                mistakes: [tr("Coudes qui s'écartent."), tr("Cambrer le dos.")]
            )
        case .lyingExtension:
            ExerciseTechnique(
                start: tr("Allongé sur un banc, bras tendus au-dessus de la poitrine."),
                steps: [tr("Plie les coudes pour descendre la charge vers le front."), tr("Tends les bras pour revenir.")],
                range: tr("Jusqu'à la charge près du front, sans toucher."),
                breathing: tr("Inspire en descendant, expire en tendant."),
                tips: [tr("Les bras restent légèrement inclinés vers la tête.")],
                mistakes: [tr("Coudes qui s'ouvrent."), tr("Descendre trop vite près du visage.")]
            )
        case .lateralRaise:
            ExerciseTechnique(
                start: tr("Debout, charges le long du corps, coudes légèrement fléchis."),
                steps: [tr("Lève les bras sur les côtés jusqu'à hauteur des épaules."), tr("Redescends lentement.")],
                range: tr("Jusqu'aux bras à l'horizontale."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Mène avec les coudes."), tr("Léger buste vers l'avant.")],
                mistakes: [tr("Hausser les épaules."), tr("Donner de l'élan."), tr("Charge trop lourde.")]
            )
        case .frontRaise:
            ExerciseTechnique(
                start: tr("Debout, charge devant les cuisses, bras presque tendus."),
                steps: [tr("Lève les bras devant toi jusqu'à hauteur des épaules."), tr("Redescends lentement.")],
                range: tr("Jusqu'aux bras à l'horizontale."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Buste immobile.")],
                mistakes: [tr("Balancer le buste."), tr("Monter au-dessus des épaules.")]
            )
        case .fly:
            ExerciseTechnique(
                start: tr("Bras presque tendus devant la poitrine, coudes légèrement fléchis (allongé, assis ou à la poulie)."),
                steps: [tr("Ouvre les bras en arc de cercle jusqu'à l'étirement des pectoraux (ou de l'arrière des épaules pour l'oiseau)."), tr("Referme en gardant l'angle des coudes.")],
                range: tr("Tant que les épaules restent confortables."),
                breathing: tr("Inspire en ouvrant, expire en refermant."),
                tips: [tr("Imagine serrer un gros tronc d'arbre.")],
                mistakes: [tr("Plier et tendre les coudes pendant le mouvement."), tr("Descendre trop bas.")]
            )
        case .uprightRow:
            ExerciseTechnique(
                start: tr("Debout, charge devant les cuisses, mains largeur d'épaules."),
                steps: [tr("Monte la charge le long du corps jusqu'au bas de la poitrine, coudes vers l'extérieur."), tr("Redescends lentement.")],
                range: tr("Jusqu'aux coudes à hauteur des épaules, pas plus haut."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Une prise plus large ménage les épaules.")],
                mistakes: [tr("Monter les coudes au-dessus des épaules."), tr("Prise trop serrée.")]
            )
        case .shrug:
            ExerciseTechnique(
                start: tr("Debout, charge en main, bras tendus."),
                steps: [tr("Hausse les épaules vers les oreilles."), tr("Tiens une seconde."), tr("Redescends lentement.")],
                range: tr("Le plus haut possible, sans plier les bras."),
                breathing: tr("Expire en montant."),
                tips: [tr("Mouvement vertical, sans rouler les épaules.")],
                mistakes: [tr("Rouler les épaules."), tr("Plier les bras.")]
            )
        case .crunch:
            ExerciseTechnique(
                start: tr("Allongé sur le dos, genoux pliés, pieds au sol, mains aux tempes ou croisées sur la poitrine."),
                steps: [tr("Enroule le haut du dos pour décoller les omoplates."), tr("Redescends lentement.")],
                range: tr("Les omoplates décollent, le bas du dos reste au sol."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Regarde vers le haut, pas vers les genoux.")],
                mistakes: [tr("Tirer sur la nuque."), tr("Donner de l'élan.")]
            )
        case .plank:
            ExerciseTechnique(
                start: tr("En appui sur les avant-bras et la pointe des pieds, coudes sous les épaules."),
                steps: [tr("Gaine le ventre et serre les fessiers."), tr("Garde le corps aligné de la tête aux talons."), tr("Tiens la position le temps voulu.")],
                range: tr("Position fixe."),
                breathing: tr("Respire calmement, sans bloquer."),
                tips: [tr("Pousse le sol avec les avant-bras.")],
                mistakes: [tr("Hanches trop hautes ou affaissées."), tr("Retenir sa respiration.")]
            )
        case .legRaise:
            ExerciseTechnique(
                start: tr("Allongé sur le dos (ou suspendu à une barre), jambes tendues."),
                steps: [tr("Lève les jambes en gardant le bas du dos plaqué (ou jusqu'aux hanches à 90° suspendu)."), tr("Redescends lentement sans toucher le sol.")],
                range: tr("Jusqu'aux jambes verticales allongé."),
                breathing: tr("Expire en montant, inspire en redescendant."),
                tips: [tr("Mains sous les fesses si le dos se cambre.")],
                mistakes: [tr("Creuser le bas du dos."), tr("Balancer les jambes.")]
            )
        case .rotation:
            ExerciseTechnique(
                start: tr("Assis, genoux pliés, buste incliné en arrière (ou debout face à la poulie)."),
                steps: [tr("Tourne le buste d'un côté."), tr("Reviens au centre puis tourne de l'autre côté.")],
                range: tr("Rotation contrôlée, sans forcer."),
                breathing: tr("Expire à chaque rotation."),
                tips: [tr("C'est le buste qui tourne, pas seulement les bras.")],
                mistakes: [tr("Arrondir le dos."), tr("Aller trop vite.")]
            )
        case .superman:
            ExerciseTechnique(
                start: tr("Allongé sur le ventre, bras tendus devant."),
                steps: [tr("Décolle doucement les bras, la poitrine et les jambes."), tr("Tiens deux secondes."), tr("Redescends lentement.")],
                range: tr("Quelques centimètres suffisent."),
                breathing: tr("Expire en montant."),
                tips: [tr("Regard vers le sol, nuque longue.")],
                mistakes: [tr("Lever la tête vers l'avant."), tr("Monter trop haut en forçant.")]
            )
        case .mountainClimber:
            ExerciseTechnique(
                start: tr("En position de pompe, bras tendus, corps gainé."),
                steps: [tr("Ramène un genou vers la poitrine."), tr("Change de jambe rapidement, comme si tu courais.")],
                range: tr("Le genou vient sous la poitrine."),
                breathing: tr("Respire en rythme."),
                tips: [tr("Épaules au-dessus des mains.")],
                mistakes: [tr("Hanches qui montent."), tr("Rebondir sur les pieds.")]
            )
        case .carry:
            ExerciseTechnique(
                start: tr("Debout, une charge lourde dans chaque main."),
                steps: [tr("Marche à petits pas contrôlés."), tr("Garde le buste droit et les épaules basses.")],
                range: tr("Sur la distance ou le temps choisi."),
                breathing: tr("Respire régulièrement, sans bloquer."),
                tips: [tr("Serre fort les poignées.")],
                mistakes: [tr("Se pencher d'un côté."), tr("Hausser les épaules.")]
            )
        case .run:
            ExerciseTechnique(
                start: tr("Debout, buste droit, regard devant."),
                steps: [tr("Commence à allure facile quelques minutes."), tr("Garde une foulée souple et régulière."), tr("Accélère progressivement si tu veux.")],
                range: tr("Sur la durée ou la distance prévue."),
                breathing: tr("Respire régulièrement ; en endurance, tu dois pouvoir parler."),
                tips: [tr("Bras détendus, coudes à 90°.")],
                mistakes: [tr("Partir trop vite."), tr("Talonner lourdement.")]
            )
        case .cycle:
            ExerciseTechnique(
                start: tr("Assis sur le vélo, selle réglée pour une jambe presque tendue en bas."),
                steps: [tr("Pédale à cadence régulière."), tr("Ajuste la résistance selon ta séance.")],
                range: tr("Sur la durée prévue."),
                breathing: tr("Respire régulièrement."),
                tips: [tr("Haut du corps détendu.")],
                mistakes: [tr("Selle trop basse."), tr("Résistance trop forte qui te fait balancer.")]
            )
        case .rowing:
            ExerciseTechnique(
                start: tr("Assis, pieds sanglés, bras tendus, tibias verticaux."),
                steps: [tr("Pousse d'abord avec les jambes."), tr("Bascule légèrement le buste en arrière puis tire la poignée sous les côtes."), tr("Reviens dans l'ordre inverse : bras, buste, jambes.")],
                range: tr("Du tassé en avant jusqu'aux jambes tendues."),
                breathing: tr("Expire en tirant, inspire en revenant."),
                tips: [tr("Les jambes font l'essentiel du travail.")],
                mistakes: [tr("Tirer avec les bras en premier."), tr("Dos rond.")]
            )
        case .jump:
            ExerciseTechnique(
                start: tr("Debout, pieds largeur de hanches, genoux souples."),
                steps: [tr("Saute en poussant dans le sol."), tr("Reçois-toi sur l'avant du pied, genoux fléchis."), tr("Enchaîne à ton rythme.")],
                range: tr("Hauteur confortable."),
                breathing: tr("Respire en rythme."),
                tips: [tr("Atterrissage silencieux.")],
                mistakes: [tr("Genoux qui rentrent à la réception."), tr("Atterrir jambes tendues.")]
            )
        case .armCircles:
            ExerciseTechnique(
                start: tr("Debout, stable, bras le long du corps."),
                steps: [tr("Fais de grands cercles lents avec les bras."), tr("Change de sens après 8 à 12 tours.")],
                range: tr("Toute l'amplitude confortable."),
                breathing: tr("Respire calmement."),
                tips: [tr("Mouvements lents et contrôlés.")],
                mistakes: [tr("Aller trop vite."), tr("Forcer dans la douleur.")]
            )
        case .stretchFold:
            ExerciseTechnique(
                start: tr("Assis ou debout, jambes tendues sans verrouiller les genoux."),
                steps: [tr("Penche-toi vers l'avant depuis les hanches."), tr("Tiens 20 à 40 secondes en respirant lentement."), tr("Remonte doucement.")],
                range: tr("Jusqu'à une tension agréable, jamais une douleur."),
                breathing: tr("Respire lentement ; relâche un peu plus à chaque expiration."),
                tips: [tr("Dos le plus long possible.")],
                mistakes: [tr("Forcer jusqu'à la douleur."), tr("Faire des rebonds.")]
            )
        case .stretchStand:
            ExerciseTechnique(
                start: tr("Debout, en appui stable (un mur peut aider)."),
                steps: [tr("Mets-toi en position d'étirement."), tr("Tiens 20 à 40 secondes."), tr("Relâche doucement et change de côté.")],
                range: tr("Jusqu'à une tension agréable, jamais une douleur."),
                breathing: tr("Respire lentement."),
                tips: [tr("Épaules détendues.")],
                mistakes: [tr("Forcer jusqu'à la douleur."), tr("Faire des rebonds.")]
            )
        case .generic:
            ExerciseTechnique(
                start: tr("Installe-toi dans une position stable et confortable."),
                steps: [tr("Fais le mouvement lentement et sous contrôle."), tr("Reviens à la position de départ.")],
                range: tr("Toute l'amplitude confortable."),
                breathing: tr("Expire pendant l'effort, inspire en revenant."),
                tips: [tr("La qualité avant la charge.")],
                mistakes: [tr("Donner de l'élan."), tr("Forcer dans la douleur.")]
            )
        }
    }
}

extension String {
    var lowercasedFirstLetter: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}

// MARK: - The library

/// About 160 common exercises, by muscle, equipment, type and difficulty, each with its technique and a
/// schematic animated demonstration drawn by the app (no outside video, so no licence issue).
enum ExerciseLibrary {
    private static func x(_ id: String, _ name: String, _ primary: [Muscle], _ secondary: [Muscle], _ equipment: [Equipment],
                          _ type: ExerciseType, _ difficulty: Difficulty, _ pattern: MovementPattern,
                          aka: [String] = [], cues: [String] = []) -> ExerciseInfo {
        ExerciseInfo(id: id, name: name, aliases: aka, primary: primary, secondary: secondary, equipment: equipment,
                     type: type, difficulty: difficulty, pattern: pattern, cues: cues)
    }

    static let all: [ExerciseInfo] = chest + back + shoulders + arms + legs + core + fullBody + cardio + mobility + stretching

    private static let chest: [ExerciseInfo] = [
        x("bench-press", tr("Développé couché (barre)"), [.chest], [.triceps, .shoulders], [.barbell, .bench], .strength, .intermediate, .benchPress,
          aka: ["developpe couche", "bench press", "bench"], cues: [tr("Barre au-dessus des épaules en haut, au bas des pectoraux en bas.")]),
        x("db-bench", tr("Développé couché haltères"), [.chest], [.triceps, .shoulders], [.dumbbells, .bench], .strength, .beginner, .benchPress,
          aka: ["developpe couche", "dumbbell bench"], cues: [tr("Les haltères descendent sur les côtés de la poitrine.")]),
        x("incline-bench", tr("Développé incliné (barre)"), [.chest], [.shoulders, .triceps], [.barbell, .bench], .strength, .intermediate, .benchPress,
          aka: ["developpe incline", "incline bench"], cues: [tr("Banc incliné à 30-45° : la barre descend vers le haut de la poitrine.")]),
        x("incline-db", tr("Développé incliné haltères"), [.chest], [.shoulders, .triceps], [.dumbbells, .bench], .strength, .beginner, .benchPress,
          aka: ["developpe incline"], cues: [tr("Banc à 30-45°, haltères au niveau du haut de la poitrine.")]),
        x("decline-bench", tr("Développé décliné"), [.chest], [.triceps], [.barbell, .bench], .strength, .intermediate, .benchPress, aka: ["developpe decline"]),
        x("machine-chest-press", tr("Développé à la machine (chest press)"), [.chest], [.triceps, .shoulders], [.machine], .strength, .beginner, .benchPress,
          aka: ["chest press", "presse pectoraux"], cues: [tr("Règle le siège pour que les poignées arrivent au milieu de la poitrine.")]),
        x("close-grip-bench", tr("Développé couché prise serrée"), [.triceps], [.chest, .shoulders], [.barbell, .bench], .strength, .intermediate, .benchPress,
          aka: ["developpe serre", "close grip"], cues: [tr("Mains largeur d'épaules, coudes près du corps.")]),
        x("push-up", tr("Pompes"), [.chest], [.triceps, .shoulders, .abs], [.bodyweight], .strength, .beginner, .pushUp, aka: ["pompe", "push up", "push-up"]),
        x("knee-push-up", tr("Pompes sur les genoux"), [.chest], [.triceps, .shoulders], [.bodyweight], .strength, .beginner, .pushUp,
          aka: ["pompe genoux"], cues: [tr("Genoux au sol, corps aligné des genoux à la tête.")]),
        x("incline-push-up", tr("Pompes inclinées (mains surélevées)"), [.chest], [.triceps, .shoulders], [.bodyweight, .bench], .strength, .beginner, .pushUp,
          aka: ["pompe inclinee"], cues: [tr("Plus les mains sont hautes, plus c'est facile.")]),
        x("decline-push-up", tr("Pompes déclinées (pieds surélevés)"), [.chest], [.shoulders, .triceps], [.bodyweight, .bench], .strength, .intermediate, .pushUp,
          aka: ["pompe declinee"]),
        x("diamond-push-up", tr("Pompes diamant"), [.triceps], [.chest], [.bodyweight], .strength, .intermediate, .pushUp,
          aka: ["pompe diamant", "pompes serrees"], cues: [tr("Pouces et index se touchent sous la poitrine.")]),
        x("db-fly", tr("Écarté couché haltères"), [.chest], [.shoulders], [.dumbbells, .bench], .strength, .intermediate, .fly, aka: ["ecarte", "fly", "ecartes"]),
        x("cable-fly", tr("Écarté à la poulie (vis-à-vis)"), [.chest], [.shoulders], [.cable], .strength, .intermediate, .fly,
          aka: ["ecarte poulie", "cable crossover", "vis a vis"], cues: [tr("Un pied en avant pour la stabilité ; les mains se rejoignent devant la poitrine.")]),
        x("pec-deck", tr("Pec deck (butterfly)"), [.chest], [.shoulders], [.machine], .strength, .beginner, .fly, aka: ["butterfly", "pec deck", "ecarte machine"]),
        x("chest-dips", tr("Dips (pectoraux)"), [.chest], [.triceps, .shoulders], [.bodyweight], .strength, .intermediate, .dip,
          aka: ["dips"], cues: [tr("Buste légèrement penché vers l'avant, coudes un peu écartés.")]),
    ]

    private static let back: [ExerciseInfo] = [
        x("pull-up", tr("Tractions (pronation)"), [.back], [.biceps, .forearms], [.pullUpBar], .strength, .intermediate, .verticalPull,
          aka: ["traction", "pull up", "pull-up"]),
        x("chin-up", tr("Tractions supination (chin-up)"), [.back], [.biceps], [.pullUpBar], .strength, .intermediate, .verticalPull,
          aka: ["traction supination", "chin up"], cues: [tr("Paumes vers toi, mains largeur d'épaules.")]),
        x("assisted-pull-up", tr("Tractions assistées"), [.back], [.biceps], [.band, .machine], .strength, .beginner, .verticalPull,
          aka: ["traction assistee"], cues: [tr("L'élastique ou la machine allège une partie du poids du corps.")]),
        x("lat-pulldown", tr("Tirage vertical (poulie haute)"), [.back], [.biceps], [.cable], .strength, .beginner, .verticalPull,
          aka: ["tirage poitrine", "lat pulldown", "tirage vertical"], cues: [tr("Tire la barre vers le haut de la poitrine, pas derrière la nuque.")]),
        x("close-pulldown", tr("Tirage vertical prise serrée"), [.back], [.biceps], [.cable], .strength, .beginner, .verticalPull, aka: ["tirage serre"]),
        x("barbell-row", tr("Rowing barre"), [.back], [.biceps, .lowerBack], [.barbell], .strength, .intermediate, .horizontalPull,
          aka: ["rowing", "bent over row", "rowing buste penche"]),
        x("db-row", tr("Rowing haltère (un bras)"), [.back], [.biceps], [.dumbbells, .bench], .strength, .beginner, .horizontalPull,
          aka: ["rowing haltere", "one arm row"], cues: [tr("Genou et main en appui sur le banc, dos plat.")]),
        x("t-bar-row", tr("Rowing T-bar"), [.back], [.biceps, .lowerBack], [.barbell], .strength, .intermediate, .horizontalPull, aka: ["t bar"]),
        x("inverted-row", tr("Rowing inversé"), [.back], [.biceps], [.bodyweight], .strength, .beginner, .horizontalPull,
          aka: ["australian pull up", "traction horizontale"], cues: [tr("Sous une barre basse, corps gainé, tire la poitrine vers la barre.")]),
        x("seated-cable-row", tr("Tirage horizontal à la poulie"), [.back], [.biceps], [.cable], .strength, .beginner, .seatedRow,
          aka: ["tirage horizontal", "seated row", "rowing poulie"]),
        x("machine-row", tr("Rowing à la machine"), [.back], [.biceps], [.machine], .strength, .beginner, .seatedRow, aka: ["rowing machine assis"]),
        x("straight-arm-pulldown", tr("Pull-over à la poulie bras tendus"), [.back], [.triceps], [.cable], .strength, .intermediate, .pullover,
          aka: ["pullover poulie", "straight arm pulldown"]),
        x("db-pullover", tr("Pull-over haltère"), [.back, .chest], [.triceps], [.dumbbells, .bench], .strength, .intermediate, .pullover, aka: ["pullover"]),
        x("face-pull", tr("Face pull"), [.shoulders], [.back, .traps], [.cable], .strength, .beginner, .seatedRow,
          aka: ["face pull", "tirage visage"], cues: [tr("Corde à hauteur des yeux, tire vers le visage en ouvrant les coudes.")]),
        x("band-pull-apart", tr("Élastique écarté (pull-apart)"), [.shoulders], [.back], [.band], .strength, .beginner, .lateralRaise,
          aka: ["pull apart", "elastique"], cues: [tr("Bras tendus devant toi, écarte l'élastique jusqu'à la poitrine.")]),
        x("bb-shrug", tr("Haussements d'épaules (barre)"), [.traps], [.forearms], [.barbell], .strength, .beginner, .shrug, aka: ["shrug", "haussement"]),
        x("db-shrug", tr("Haussements d'épaules haltères"), [.traps], [.forearms], [.dumbbells], .strength, .beginner, .shrug, aka: ["shrug"]),
    ]

    private static let shoulders: [ExerciseInfo] = [
        x("ohp", tr("Développé militaire (barre)"), [.shoulders], [.triceps, .traps], [.barbell], .strength, .intermediate, .verticalPush,
          aka: ["developpe militaire", "overhead press", "military press", "ohp"]),
        x("db-shoulder-press", tr("Développé épaules haltères"), [.shoulders], [.triceps], [.dumbbells, .bench], .strength, .beginner, .verticalPush,
          aka: ["developpe epaules", "shoulder press"], cues: [tr("Assis, dos contre le dossier, haltères à hauteur des oreilles au départ.")]),
        x("arnold-press", tr("Développé Arnold"), [.shoulders], [.triceps], [.dumbbells], .strength, .intermediate, .verticalPush,
          aka: ["arnold"], cues: [tr("Paumes vers toi en bas, tourne-les vers l'avant en poussant.")]),
        x("machine-shoulder-press", tr("Développé épaules à la machine"), [.shoulders], [.triceps], [.machine], .strength, .beginner, .verticalPush, aka: ["presse epaules"]),
        x("kb-press", tr("Développé kettlebell"), [.shoulders], [.triceps, .abs], [.kettlebell], .strength, .intermediate, .verticalPush, aka: ["press kettlebell"]),
        x("pike-push-up", tr("Pompes piquées (pike)"), [.shoulders], [.triceps], [.bodyweight], .strength, .intermediate, .pushUp,
          aka: ["pike push up"], cues: [tr("Hanches hautes, tête vers le sol entre les mains.")]),
        x("handstand-push-up", tr("Pompes en équilibre (handstand)"), [.shoulders], [.triceps, .traps], [.bodyweight], .strength, .advanced, .verticalPush,
          aka: ["hspu", "handstand"], cues: [tr("Contre un mur, descends la tête vers le sol sous contrôle.")]),
        x("lateral-raise", tr("Élévations latérales"), [.shoulders], [.traps], [.dumbbells], .strength, .beginner, .lateralRaise,
          aka: ["elevation laterale", "lateral raise"]),
        x("cable-lateral", tr("Élévations latérales à la poulie"), [.shoulders], [.traps], [.cable], .strength, .intermediate, .lateralRaise, aka: ["elevation laterale poulie"]),
        x("front-raise", tr("Élévations frontales"), [.shoulders], [.chest], [.dumbbells], .strength, .beginner, .frontRaise, aka: ["elevation frontale", "front raise"]),
        x("rear-delt-fly", tr("Oiseau (buste penché)"), [.shoulders], [.back, .traps], [.dumbbells], .strength, .beginner, .horizontalPull,
          aka: ["oiseau", "rear delt", "elevation buste penche"], cues: [tr("Buste penché, ouvre les bras sur les côtés : c'est l'arrière de l'épaule qui travaille.")]),
        x("reverse-pec-deck", tr("Oiseau à la machine"), [.shoulders], [.back], [.machine], .strength, .beginner, .seatedRow, aka: ["reverse pec deck", "oiseau machine"]),
        x("upright-row", tr("Rowing menton"), [.shoulders], [.traps], [.barbell], .strength, .intermediate, .uprightRow, aka: ["upright row", "tirage menton"]),
    ]

    private static let arms: [ExerciseInfo] = [
        x("bb-curl", tr("Curl barre"), [.biceps], [.forearms], [.barbell], .strength, .beginner, .curl, aka: ["curl", "biceps curl"]),
        x("ez-curl", tr("Curl barre EZ"), [.biceps], [.forearms], [.barbell], .strength, .beginner, .curl, aka: ["curl ez"]),
        x("db-curl", tr("Curl haltères"), [.biceps], [.forearms], [.dumbbells], .strength, .beginner, .curl,
          aka: ["curl", "curl alterne"], cues: [tr("En alterné ou les deux bras ensemble, paumes vers le haut.")]),
        x("hammer-curl", tr("Curl marteau"), [.biceps], [.forearms], [.dumbbells], .strength, .beginner, .curl,
          aka: ["hammer", "curl prise neutre"], cues: [tr("Paumes face à face tout le long du mouvement.")]),
        x("incline-curl", tr("Curl incliné"), [.biceps], [], [.dumbbells, .bench], .strength, .intermediate, .curl, aka: ["curl incline"]),
        x("preacher-curl", tr("Curl au pupitre"), [.biceps], [.forearms], [.barbell, .machine], .strength, .intermediate, .curl,
          aka: ["larry scott", "preacher"], cues: [tr("Bras bien posés sur le pupitre ; ne tends pas brutalement en bas.")]),
        x("cable-curl", tr("Curl à la poulie"), [.biceps], [.forearms], [.cable], .strength, .beginner, .curl, aka: ["curl poulie"]),
        x("concentration-curl", tr("Curl concentration"), [.biceps], [], [.dumbbells, .bench], .strength, .beginner, .curl,
          aka: ["curl concentre"], cues: [tr("Assis, coude appuyé contre l'intérieur de la cuisse.")]),
        x("band-curl", tr("Curl élastique"), [.biceps], [.forearms], [.band], .strength, .beginner, .curl, aka: ["curl elastique"]),
        x("pushdown", tr("Extension triceps à la poulie"), [.triceps], [], [.cable], .strength, .beginner, .tricepsExtension,
          aka: ["pushdown", "triceps poulie", "extension poulie haute"]),
        x("rope-pushdown", tr("Extension triceps à la corde"), [.triceps], [], [.cable], .strength, .beginner, .tricepsExtension,
          aka: ["corde triceps"], cues: [tr("Écarte les bouts de la corde en bas du mouvement.")]),
        x("overhead-extension", tr("Extension triceps au-dessus de la tête"), [.triceps], [], [.dumbbells], .strength, .beginner, .overheadExtension,
          aka: ["extension nuque", "french press"]),
        x("skull-crusher", tr("Barre au front"), [.triceps], [], [.barbell, .bench], .strength, .intermediate, .lyingExtension,
          aka: ["skull crusher", "barre front", "extension couche"]),
        x("triceps-dips", tr("Dips (triceps)"), [.triceps], [.chest, .shoulders], [.bodyweight], .strength, .intermediate, .dip,
          aka: ["dips triceps"], cues: [tr("Buste droit, coudes serrés vers l'arrière.")]),
        x("bench-dips", tr("Dips sur banc"), [.triceps], [.shoulders], [.bodyweight, .bench], .strength, .beginner, .dip,
          aka: ["dips banc"], cues: [tr("Mains sur le banc derrière toi, fesses près du banc.")]),
        x("kickback", tr("Kickback triceps"), [.triceps], [], [.dumbbells], .strength, .beginner, .tricepsExtension,
          aka: ["kick back"], cues: [tr("Buste penché, bras collé au corps, tends l'avant-bras vers l'arrière.")]),
        x("wrist-curl", tr("Flexion des poignets"), [.forearms], [], [.barbell, .dumbbells, .bench], .strength, .beginner, .curl,
          aka: ["poignets", "wrist curl"], cues: [tr("Avant-bras posés sur les cuisses, seuls les poignets bougent.")]),
        x("reverse-curl", tr("Curl inversé (pronation)"), [.forearms], [.biceps], [.barbell], .strength, .beginner, .curl, aka: ["curl pronation", "reverse curl"]),
        x("dead-hang", tr("Suspension à la barre"), [.forearms], [.back], [.pullUpBar], .strength, .beginner, .verticalPull,
          aka: ["suspension", "dead hang"], cues: [tr("Reste suspendu bras tendus, épaules légèrement engagées.")]),
        x("farmer-walk", tr("Marche du fermier"), [.forearms, .traps], [.fullBody], [.dumbbells, .kettlebell], .strength, .beginner, .carry,
          aka: ["farmer walk", "farmer carry"]),
    ]

    private static let legs: [ExerciseInfo] = [
        x("back-squat", tr("Squat (barre)"), [.quads], [.glutes, .hamstrings, .lowerBack], [.barbell], .strength, .intermediate, .squat,
          aka: ["squat", "back squat", "flexion"], cues: [tr("Barre sur le haut des trapèzes, mains serrées sur la barre.")]),
        x("front-squat", tr("Squat avant"), [.quads], [.glutes, .abs], [.barbell], .strength, .advanced, .squat,
          aka: ["front squat"], cues: [tr("Barre sur l'avant des épaules, coudes hauts, buste droit.")]),
        x("goblet-squat", tr("Squat gobelet"), [.quads], [.glutes], [.kettlebell, .dumbbells], .strength, .beginner, .squat,
          aka: ["goblet squat"], cues: [tr("Charge tenue contre la poitrine, coudes entre les genoux en bas.")]),
        x("air-squat", tr("Squat au poids du corps"), [.quads], [.glutes], [.bodyweight], .strength, .beginner, .squat, aka: ["squat", "air squat"]),
        x("hack-squat", tr("Hack squat"), [.quads], [.glutes], [.machine], .strength, .intermediate, .squat, aka: ["hack"]),
        x("wall-sit", tr("Chaise contre le mur"), [.quads], [.glutes], [.bodyweight], .strength, .beginner, .squat,
          aka: ["chaise", "wall sit"], cues: [tr("Dos au mur, cuisses parallèles au sol ; tiens la position.")]),
        x("leg-press", tr("Presse à cuisses"), [.quads], [.glutes], [.machine], .strength, .beginner, .legPress, aka: ["presse", "leg press"]),
        x("leg-extension", tr("Leg extension"), [.quads], [], [.machine], .strength, .beginner, .legExtension, aka: ["extension jambes", "leg extension"]),
        x("bulgarian-split", tr("Squat bulgare"), [.quads], [.glutes], [.dumbbells, .bench], .strength, .intermediate, .lunge,
          aka: ["bulgarian split squat", "fente bulgare"], cues: [tr("Pied arrière posé sur le banc, l'essentiel du poids sur la jambe avant.")]),
        x("lunge", tr("Fentes avant"), [.quads], [.glutes, .hamstrings], [.bodyweight, .dumbbells], .strength, .beginner, .lunge, aka: ["fente", "lunge"]),
        x("reverse-lunge", tr("Fentes arrière"), [.quads], [.glutes], [.bodyweight, .dumbbells], .strength, .beginner, .lunge, aka: ["fente arriere"]),
        x("walking-lunge", tr("Fentes marchées"), [.quads], [.glutes, .hamstrings], [.bodyweight, .dumbbells], .strength, .intermediate, .lunge, aka: ["fente marchee"]),
        x("step-up", tr("Montées sur banc"), [.quads], [.glutes], [.bench, .dumbbells], .strength, .beginner, .lunge,
          aka: ["step up"], cues: [tr("Pose tout le pied sur le banc et monte en poussant sur cette jambe.")]),
        x("deadlift", tr("Soulevé de terre"), [.lowerBack, .hamstrings, .glutes], [.quads, .traps, .forearms], [.barbell], .strength, .intermediate, .hinge,
          aka: ["souleve de terre", "deadlift", "sdt"], cues: [tr("Barre au-dessus du milieu du pied, tibias près de la barre au départ.")]),
        x("sumo-deadlift", tr("Soulevé de terre sumo"), [.glutes, .quads], [.hamstrings, .lowerBack], [.barbell], .strength, .intermediate, .hinge,
          aka: ["sumo"], cues: [tr("Pieds très écartés, mains entre les jambes.")]),
        x("rdl", tr("Soulevé de terre roumain"), [.hamstrings], [.glutes, .lowerBack], [.barbell], .strength, .intermediate, .hinge,
          aka: ["romanian deadlift", "rdl", "souleve de terre jambes tendues"]),
        x("db-rdl", tr("Soulevé de terre roumain haltères"), [.hamstrings], [.glutes, .lowerBack], [.dumbbells], .strength, .beginner, .hinge, aka: ["rdl haltere"]),
        x("single-leg-rdl", tr("Soulevé de terre sur une jambe"), [.hamstrings], [.glutes], [.dumbbells, .kettlebell], .strength, .intermediate, .hinge,
          aka: ["rdl une jambe"], cues: [tr("La jambe libre part vers l'arrière, bassin face au sol.")]),
        x("good-morning", tr("Good morning"), [.hamstrings], [.lowerBack, .glutes], [.barbell], .strength, .intermediate, .hinge, aka: ["good morning"]),
        x("lying-leg-curl", tr("Leg curl allongé"), [.hamstrings], [.calves], [.machine], .strength, .beginner, .legCurl, aka: ["leg curl", "ischio machine"]),
        x("seated-leg-curl", tr("Leg curl assis"), [.hamstrings], [], [.machine], .strength, .beginner, .legCurl, aka: ["leg curl assis"]),
        x("nordic-curl", tr("Nordic curl"), [.hamstrings], [], [.bodyweight], .strength, .advanced, .legCurl,
          aka: ["nordic"], cues: [tr("Chevilles bloquées, descends le buste vers l'avant le plus lentement possible.")]),
        x("kb-swing", tr("Kettlebell swing"), [.glutes, .hamstrings], [.lowerBack, .shoulders], [.kettlebell], .strength, .intermediate, .hinge,
          aka: ["swing"], cues: [tr("La force vient des hanches : les bras ne font que tenir la kettlebell.")]),
        x("hip-thrust", tr("Hip thrust (barre)"), [.glutes], [.hamstrings], [.barbell, .bench], .strength, .intermediate, .bridge,
          aka: ["hip thrust", "releve de bassin"], cues: [tr("Haut du dos sur le banc, barre sur les hanches avec une protection.")]),
        x("glute-bridge", tr("Pont fessier"), [.glutes], [.hamstrings], [.bodyweight], .strength, .beginner, .bridge, aka: ["pont", "glute bridge"]),
        x("single-leg-bridge", tr("Pont fessier sur une jambe"), [.glutes], [.hamstrings], [.bodyweight], .strength, .intermediate, .bridge, aka: ["pont une jambe"]),
        x("cable-kickback", tr("Kickback fessier à la poulie"), [.glutes], [.hamstrings], [.cable], .strength, .beginner, .legKickback, aka: ["kickback fessier"]),
        x("donkey-kick", tr("Donkey kick"), [.glutes], [.hamstrings], [.bodyweight], .strength, .beginner, .legKickback, aka: ["donkey kick", "ruade"]),
        x("hip-abduction", tr("Abduction à la machine"), [.glutes], [], [.machine], .strength, .beginner, .generic,
          aka: ["abducteurs", "abduction"], cues: [tr("Assis, écarte les jambes contre la résistance, reviens lentement.")]),
        x("hip-adduction", tr("Adduction à la machine"), [.quads], [], [.machine], .strength, .beginner, .generic,
          aka: ["adducteurs", "adduction"], cues: [tr("Assis, resserre les jambes contre la résistance, reviens lentement.")]),
        x("fire-hydrant", tr("Fire hydrant"), [.glutes], [], [.bodyweight], .strength, .beginner, .generic,
          aka: ["fire hydrant"], cues: [tr("À quatre pattes, lève le genou plié sur le côté, sans tourner le bassin.")]),
        x("cable-pull-through", tr("Pull-through à la poulie"), [.glutes], [.hamstrings], [.cable], .strength, .beginner, .hinge, aka: ["pull through"]),
        x("standing-calf", tr("Mollets debout"), [.calves], [], [.machine, .bodyweight], .strength, .beginner, .calfRaise, aka: ["mollets", "calf raise"]),
        x("seated-calf", tr("Mollets assis"), [.calves], [], [.machine], .strength, .beginner, .calfRaise, aka: ["mollets assis"]),
        x("single-calf", tr("Mollets sur une jambe"), [.calves], [], [.dumbbells, .bodyweight], .strength, .beginner, .calfRaise, aka: ["mollet une jambe"]),
    ]

    private static let core: [ExerciseInfo] = [
        x("crunch", tr("Crunch"), [.abs], [], [.bodyweight], .strength, .beginner, .crunch, aka: ["abdos", "crunch"]),
        x("sit-up", tr("Redressements assis"), [.abs], [], [.bodyweight], .strength, .beginner, .crunch, aka: ["sit up", "redressement"]),
        x("bicycle-crunch", tr("Crunch vélo"), [.obliques], [.abs], [.bodyweight], .strength, .beginner, .crunch,
          aka: ["bicycle"], cues: [tr("Coude vers le genou opposé, en alternant.")]),
        x("cable-crunch", tr("Crunch à la poulie"), [.abs], [], [.cable], .strength, .intermediate, .crunch,
          aka: ["crunch poulie"], cues: [tr("À genoux, enroule le buste vers le sol, hanches fixes.")]),
        x("plank", tr("Planche (gainage)"), [.abs], [.lowerBack, .shoulders], [.bodyweight], .strength, .beginner, .plank, aka: ["gainage", "plank", "planche"]),
        x("side-plank", tr("Planche latérale"), [.obliques], [.abs, .shoulders], [.bodyweight], .strength, .beginner, .plank,
          aka: ["gainage lateral", "side plank"], cues: [tr("Sur un avant-bras, corps de profil et aligné, hanches hautes.")]),
        x("leg-raise", tr("Relevés de jambes"), [.abs], [], [.bodyweight], .strength, .beginner, .legRaise, aka: ["releve de jambes", "leg raise"]),
        x("hanging-leg-raise", tr("Relevés de jambes suspendu"), [.abs], [.forearms], [.pullUpBar], .strength, .advanced, .legRaise,
          aka: ["releve suspendu", "hanging leg raise"]),
        x("dead-bug", tr("Dead bug"), [.abs], [], [.bodyweight], .strength, .beginner, .legRaise,
          aka: ["dead bug"], cues: [tr("Dos plaqué, tends un bras et la jambe opposée en alternant.")]),
        x("hollow-hold", tr("Hollow hold"), [.abs], [], [.bodyweight], .strength, .intermediate, .legRaise,
          aka: ["hollow"], cues: [tr("Bras et jambes tendus au-dessus du sol, bas du dos plaqué ; tiens.")]),
        x("russian-twist", tr("Russian twist"), [.obliques], [.abs], [.bodyweight, .other], .strength, .beginner, .rotation, aka: ["twist", "russian twist"]),
        x("woodchop", tr("Bûcheron à la poulie"), [.obliques], [.abs, .shoulders], [.cable], .strength, .intermediate, .rotation, aka: ["woodchop", "bucheron"]),
        x("pallof-press", tr("Pallof press"), [.obliques], [.abs], [.cable, .band], .strength, .beginner, .frontRaise,
          aka: ["pallof"], cues: [tr("De profil à la poulie, pousse les mains devant toi sans laisser le buste tourner.")]),
        x("mountain-climber", tr("Mountain climbers"), [.abs], [.shoulders, .heart], [.bodyweight], .cardio, .beginner, .mountainClimber, aka: ["mountain climber", "grimpeur"]),
        x("ab-wheel", tr("Roulette abdominale"), [.abs], [.lowerBack, .shoulders], [.other], .strength, .advanced, .plank,
          aka: ["ab wheel", "roue abdominale"], cues: [tr("Roule vers l'avant sans creuser le dos, reviens en contractant les abdos.")]),
        x("back-extension", tr("Extensions lombaires"), [.lowerBack], [.glutes, .hamstrings], [.bench, .machine], .strength, .beginner, .hinge,
          aka: ["hyperextension", "lombaires"], cues: [tr("Banc à 45°, descends le buste puis remonte jusqu'à l'alignement, sans cambrer.")]),
        x("superman", tr("Superman"), [.lowerBack], [.glutes], [.bodyweight], .strength, .beginner, .superman, aka: ["superman"]),
        x("bird-dog", tr("Bird dog"), [.lowerBack], [.abs, .glutes], [.bodyweight], .strength, .beginner, .legKickback,
          aka: ["bird dog"], cues: [tr("À quatre pattes, tends un bras et la jambe opposée, dos plat.")]),
    ]

    private static let fullBody: [ExerciseInfo] = [
        x("burpee", tr("Burpees"), [.fullBody], [.heart], [.bodyweight], .cardio, .intermediate, .jump, aka: ["burpee"]),
        x("thruster", tr("Thruster"), [.fullBody], [.quads, .shoulders], [.barbell, .dumbbells], .strength, .intermediate, .squat,
          aka: ["thruster"], cues: [tr("Enchaîne un squat avant et un développé au-dessus de la tête en un mouvement.")]),
        x("power-clean", tr("Épaulé (power clean)"), [.fullBody], [.traps, .hamstrings], [.barbell], .strength, .advanced, .hinge,
          aka: ["clean", "epaule"], cues: [tr("Explosion des hanches, la barre monte près du corps jusqu'aux épaules. Apprends-le avec un coach.")]),
        x("kb-clean", tr("Épaulé kettlebell"), [.fullBody], [.shoulders], [.kettlebell], .strength, .intermediate, .hinge, aka: ["clean kettlebell"]),
        x("turkish-get-up", tr("Turkish get-up"), [.fullBody], [.shoulders, .abs], [.kettlebell], .strength, .advanced, .generic,
          aka: ["get up"], cues: [tr("Du sol à debout, bras tendu vers le plafond avec la charge, étape par étape.")]),
        x("wall-ball", tr("Wall ball"), [.fullBody], [.quads, .shoulders], [.other], .strength, .intermediate, .squat,
          aka: ["wall ball"], cues: [tr("Squat avec un médecine-ball, puis lance-le contre le mur en te relevant.")]),
        x("battle-ropes", tr("Cordes ondulatoires"), [.fullBody], [.shoulders, .heart], [.other], .cardio, .intermediate, .generic,
          aka: ["battle rope", "cordes"], cues: [tr("Genoux fléchis, fais onduler les cordes en alternant les bras.")]),
        x("sled-push", tr("Poussée de traîneau"), [.fullBody], [.quads, .heart], [.other], .cardio, .intermediate, .run, aka: ["traineau", "sled"]),
        x("bear-crawl", tr("Marche de l'ours"), [.fullBody], [.shoulders, .abs], [.bodyweight], .strength, .beginner, .mountainClimber,
          aka: ["bear crawl"], cues: [tr("À quatre pattes, genoux juste au-dessus du sol, avance main et pied opposés.")]),
    ]

    private static let cardio: [ExerciseInfo] = [
        x("running", tr("Course à pied"), [.heart], [.quads, .calves], [.bodyweight], .cardio, .beginner, .run, aka: ["course", "running", "jogging", "footing"]),
        x("treadmill", tr("Tapis de course"), [.heart], [.quads, .calves], [.machine], .cardio, .beginner, .run, aka: ["tapis", "treadmill"]),
        x("walking", tr("Marche rapide"), [.heart], [.calves], [.bodyweight], .cardio, .beginner, .run, aka: ["marche", "walking"]),
        x("incline-walk", tr("Marche inclinée sur tapis"), [.heart], [.glutes, .calves], [.machine], .cardio, .beginner, .run, aka: ["marche inclinee"]),
        x("high-knees", tr("Montées de genoux"), [.heart], [.quads], [.bodyweight], .cardio, .beginner, .run, aka: ["high knees", "genoux hauts"]),
        x("cycling", tr("Vélo"), [.heart], [.quads], [.machine, .other], .cardio, .beginner, .cycle, aka: ["velo", "bike", "cyclisme"]),
        x("spinning", tr("Vélo d'intérieur (spinning)"), [.heart], [.quads], [.machine], .cardio, .intermediate, .cycle, aka: ["spinning", "velo interieur"]),
        x("rowing-machine", tr("Rameur"), [.heart], [.back, .quads], [.machine], .cardio, .beginner, .rowing, aka: ["rameur", "rowing machine", "ergometre"]),
        x("elliptical", tr("Vélo elliptique"), [.heart], [.quads, .glutes], [.machine], .cardio, .beginner, .run, aka: ["elliptique"]),
        x("stair-climber", tr("Escaliers (stepper)"), [.heart], [.glutes, .quads], [.machine], .cardio, .intermediate, .lunge, aka: ["stepper", "escalier"]),
        x("jump-rope", tr("Corde à sauter"), [.heart], [.calves], [.other], .cardio, .beginner, .jump, aka: ["corde", "jump rope"]),
        x("jumping-jacks", tr("Jumping jacks"), [.heart], [.calves, .shoulders], [.bodyweight], .cardio, .beginner, .jump, aka: ["jumping jack"]),
        x("jump-squat", tr("Squat sauté"), [.quads], [.glutes, .calves, .heart], [.bodyweight], .cardio, .intermediate, .jump, aka: ["jump squat"]),
        x("box-jump", tr("Box jump"), [.quads], [.glutes, .calves], [.other], .cardio, .intermediate, .jump,
          aka: ["saut sur boite"], cues: [tr("Saute sur la boîte à deux pieds, descends en marchant.")]),
        x("hiit", tr("Circuit HIIT"), [.fullBody], [.heart], [.bodyweight], .cardio, .intermediate, .jump, aka: ["hiit", "fractionne", "circuit"]),
        x("swimming", tr("Natation"), [.fullBody], [.heart], [.other], .cardio, .intermediate, .generic, aka: ["nage", "piscine"]),
        x("boxing", tr("Boxe (sac de frappe)"), [.fullBody], [.shoulders, .heart], [.other], .cardio, .intermediate, .generic, aka: ["boxe", "sac"]),
    ]

    private static let mobility: [ExerciseInfo] = [
        x("arm-circles", tr("Cercles de bras"), [.shoulders], [], [.bodyweight], .mobility, .beginner, .armCircles, aka: ["moulinets", "cercles"]),
        x("shoulder-dislocates", tr("Passages d'épaules au bâton"), [.shoulders], [.chest], [.band, .other], .mobility, .beginner, .armCircles,
          aka: ["passage epaules", "dislocates"], cues: [tr("Prise large, passe le bâton de l'avant vers l'arrière bras tendus.")]),
        x("hip-circles", tr("Cercles de hanches"), [.glutes], [.lowerBack], [.bodyweight], .mobility, .beginner, .generic, aka: ["hanches"]),
        x("cat-cow", tr("Chat-vache"), [.lowerBack], [.back], [.bodyweight], .mobility, .beginner, .generic,
          aka: ["chat vache", "cat cow"], cues: [tr("À quatre pattes, arrondis puis creuse doucement le dos au rythme de la respiration.")]),
        x("worlds-greatest", tr("Fente avec rotation"), [.fullBody], [.hamstrings, .back], [.bodyweight], .mobility, .beginner, .lunge,
          aka: ["world greatest stretch"], cues: [tr("En fente, main au sol, ouvre l'autre bras vers le plafond.")]),
        x("ankle-mobility", tr("Mobilité des chevilles"), [.calves], [], [.bodyweight], .mobility, .beginner, .lunge,
          aka: ["cheville", "genou au mur"], cues: [tr("Face au mur, avance le genou vers le mur sans décoller le talon.")]),
        x("thoracic-rotation", tr("Rotations thoraciques"), [.back], [.obliques], [.bodyweight], .mobility, .beginner, .rotation, aka: ["rotation thoracique"]),
        x("deep-squat-hold", tr("Squat profond tenu"), [.quads], [.glutes], [.bodyweight], .mobility, .beginner, .squat,
          aka: ["squat profond"], cues: [tr("Descends le plus bas confortable, talons au sol ; respire et tiens.")]),
    ]

    private static let stretching: [ExerciseInfo] = [
        x("hamstring-stretch", tr("Étirement des ischio-jambiers"), [.hamstrings], [.lowerBack], [.bodyweight], .stretching, .beginner, .stretchFold, aka: ["etirement ischio"]),
        x("quad-stretch", tr("Étirement des quadriceps"), [.quads], [], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement quadriceps"], cues: [tr("Debout, attrape la cheville derrière toi, genoux côte à côte.")]),
        x("hip-flexor-stretch", tr("Étirement des fléchisseurs de hanche"), [.quads], [.glutes], [.bodyweight], .stretching, .beginner, .lunge,
          aka: ["psoas", "flechisseurs"], cues: [tr("En fente, genou arrière au sol, avance doucement le bassin.")]),
        x("calf-stretch", tr("Étirement des mollets"), [.calves], [], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement mollets"], cues: [tr("Mains au mur, jambe arrière tendue, talon au sol.")]),
        x("chest-stretch", tr("Étirement des pectoraux"), [.chest], [.shoulders], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement pectoraux"], cues: [tr("Avant-bras contre un encadrement de porte, avance doucement le buste.")]),
        x("triceps-stretch", tr("Étirement des triceps"), [.triceps], [.shoulders], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement triceps"], cues: [tr("Main derrière la tête, pousse doucement le coude avec l'autre main.")]),
        x("shoulder-stretch", tr("Étirement des épaules (bras croisé)"), [.shoulders], [], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement epaules"], cues: [tr("Ramène le bras tendu contre la poitrine avec l'autre bras.")]),
        x("childs-pose", tr("Posture de l'enfant"), [.lowerBack], [.back], [.bodyweight], .stretching, .beginner, .stretchFold,
          aka: ["enfant", "child pose"], cues: [tr("À genoux, fesses vers les talons, bras allongés devant.")]),
        x("pigeon", tr("Posture du pigeon"), [.glutes], [.lowerBack], [.bodyweight], .stretching, .intermediate, .stretchFold,
          aka: ["pigeon"], cues: [tr("Jambe avant pliée devant toi, jambe arrière allongée, buste qui descend doucement.")]),
        x("cobra", tr("Posture du cobra"), [.abs], [.lowerBack], [.bodyweight], .stretching, .beginner, .superman,
          aka: ["cobra"], cues: [tr("Allongé sur le ventre, pousse doucement sur les mains, hanches au sol.")]),
    ]

    // MARK: Lookup

    private static let byID: [String: ExerciseInfo] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    static func info(_ id: String) -> ExerciseInfo? { byID[id] }

    static func normalized(_ text: String) -> String {
        FoodDatabase.normalized(text)
    }

    /// "Développé couché (barre)" → "developpe couche"
    private static func base(_ name: String) -> String {
        let withoutDetail = name.split(separator: "(").first.map(String.init) ?? name
        return normalized(withoutDetail)
    }

    /// The exercise a name written by the person (in a routine, in a set) refers to, if any.
    static func match(name: String) -> ExerciseInfo? {
        let key = normalized(name)
        guard !key.isEmpty else { return nil }
        return all.first { normalized($0.name) == key }
            ?? all.first { base($0.name) == key }
            ?? all.first { $0.aliases.contains { normalized($0) == key } }
    }

    struct Filters: Hashable {
        var group: MuscleGroup?
        var equipment: Equipment?
        var type: ExerciseType?
        var difficulty: Difficulty?

        var isEmpty: Bool { group == nil && equipment == nil && type == nil && difficulty == nil }

        func allows(_ exercise: ExerciseInfo) -> Bool {
            if let group, !group.muscles.contains(where: { exercise.primary.contains($0) }) { return false }
            if let equipment, !exercise.equipment.contains(equipment) { return false }
            if let type, exercise.type != type { return false }
            if let difficulty, exercise.difficulty != difficulty { return false }
            return true
        }
    }

    /// Typing « développé » offers every développé; a muscle, a tool or a type found in the words works
    /// too. Names starting with the text come first, then words starting with it, then other names.
    static func search(_ query: String, filters: Filters = Filters()) -> [ExerciseInfo] {
        let candidates = all.filter { filters.allows($0) }
        let q = normalized(query)
        guard !q.isEmpty else { return candidates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        let tokens = q.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "'" }).map(String.init)
        func words(_ text: String) -> [String] {
            normalized(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        }
        var ranked: [(Int, Int, ExerciseInfo)] = []
        for (index, exercise) in candidates.enumerated() {
            let name = normalized(exercise.name)
            let nameWords = words(exercise.name)
            let extra = (exercise.aliases + exercise.primary.map(\.title) + exercise.equipment.map(\.title) + [exercise.type.title]).flatMap(words)
            let inName = tokens.allSatisfy { token in nameWords.contains { $0.hasPrefix(token) } }
            let inAll = tokens.allSatisfy { token in (nameWords + extra).contains { $0.hasPrefix(token) } }
            let rank: Int
            if name.hasPrefix(q) { rank = 0 }
            else if inName { rank = 1 }
            else if name.contains(q) { rank = 2 }
            else if inAll { rank = 3 }
            else { continue }
            ranked.append((rank, index, exercise))
        }
        // Same rank: the library's own order, the most common exercise of a family first.
        return ranked.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
    }

    /// Same main muscle and type, other exercises: the variants first (same movement), then the rest.
    static func alternatives(to exercise: ExerciseInfo, limit: Int = 5) -> [ExerciseInfo] {
        let others = all.filter { $0.id != exercise.id && $0.type == exercise.type && !Set($0.primary).isDisjoint(with: exercise.primary) }
        let variants = others.filter { $0.pattern == exercise.pattern }
        let rest = others.filter { $0.pattern != exercise.pattern }
        return Array((variants + rest).prefix(limit))
    }
}
