import Foundation

// MARK: - Vocabulary

enum Muscle: String, Codable, CaseIterable, Identifiable {
    case chest, back, traps, lowerBack, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves, abs, obliques, fullBody, heart
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Pectoraux"
        case .back: "Dos"
        case .traps: "Trapèzes"
        case .lowerBack: "Lombaires"
        case .shoulders: "Épaules"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Avant-bras"
        case .quads: "Quadriceps"
        case .hamstrings: "Ischio-jambiers"
        case .glutes: "Fessiers"
        case .calves: "Mollets"
        case .abs: "Abdominaux"
        case .obliques: "Obliques"
        case .fullBody: "Corps entier"
        case .heart: "Cardio"
        }
    }
}

/// The groups offered as filters: close muscles together, as people search them.
enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, quads, hamstrings, glutes, calves, abs, lowerBack, fullBody
    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Pectoraux"
        case .back: "Dos"
        case .shoulders: "Épaules"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Avant-bras"
        case .quads: "Quadriceps"
        case .hamstrings: "Ischio-jambiers"
        case .glutes: "Fessiers"
        case .calves: "Mollets"
        case .abs: "Abdominaux"
        case .lowerBack: "Lombaires"
        case .fullBody: "Full body"
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
        case .bodyweight: "Poids du corps"
        case .dumbbells: "Haltères"
        case .barbell: "Barre"
        case .machine: "Machine"
        case .cable: "Poulie"
        case .kettlebell: "Kettlebell"
        case .band: "Élastique"
        case .bench: "Banc"
        case .pullUpBar: "Barre de traction"
        case .other: "Autre"
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
        case .strength: "Musculation"
        case .cardio: "Cardio"
        case .mobility: "Mobilité"
        case .stretching: "Étirement"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "Débutant"
        case .intermediate: "Intermédiaire"
        case .advanced: "Avancé"
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

    var technique: ExerciseTechnique { ExerciseTechnique.technique(for: pattern) }

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
                start: "Allongé sur le banc, yeux sous la charge, pieds à plat au sol, omoplates serrées et abaissées.",
                steps: ["Saisis la charge un peu plus large que les épaules.", "Descends lentement vers le bas de la poitrine, coudes à environ 45° du corps.", "Pousse jusqu'aux bras tendus, sans verrouiller brutalement les coudes."],
                range: "Descends jusqu'à effleurer la poitrine, sans rebond.",
                breathing: "Inspire en descendant, expire en poussant.",
                tips: ["Garde les fesses sur le banc et les pieds ancrés.", "Poignets droits, au-dessus des coudes."],
                mistakes: ["Coudes écartés à 90°, qui chargent les épaules.", "Rebondir sur la poitrine.", "Décoller les fesses du banc.", "Charger lourd sans pareur ni sécurités."]
            )
        case .pushUp:
            ExerciseTechnique(
                start: "Mains au sol un peu plus larges que les épaules, corps gainé en ligne droite des talons à la tête.",
                steps: ["Descends la poitrine vers le sol, coudes à environ 45° du corps.", "Pousse le sol pour remonter jusqu'aux bras tendus."],
                range: "La poitrine arrive à quelques centimètres du sol.",
                breathing: "Inspire en descendant, expire en remontant.",
                tips: ["Serre les fessiers et le ventre tout le long.", "Regarde le sol un peu devant tes mains."],
                mistakes: ["Hanches qui s'affaissent ou montent trop.", "Tête qui avance avant le buste.", "Amplitude trop courte."]
            )
        case .dip:
            ExerciseTechnique(
                start: "En appui sur les barres (ou les mains sur un banc derrière toi), bras tendus, épaules basses.",
                steps: ["Plie les coudes pour descendre le corps.", "Remonte en poussant jusqu'aux bras tendus."],
                range: "Descends jusqu'aux coudes à environ 90°, sans douleur aux épaules.",
                breathing: "Inspire en descendant, expire en remontant.",
                tips: ["Buste droit pour les triceps, légèrement penché pour les pectoraux.", "Garde les épaules loin des oreilles."],
                mistakes: ["Descendre trop bas au détriment des épaules.", "Épaules qui montent.", "Balancer les jambes."]
            )
        case .verticalPush:
            ExerciseTechnique(
                start: "Debout (ou assis), charge à hauteur des épaules, ventre et fessiers gainés.",
                steps: ["Pousse la charge au-dessus de la tête jusqu'aux bras tendus.", "La tête passe légèrement vers l'avant une fois la charge au-dessus.", "Redescends sous contrôle jusqu'aux épaules."],
                range: "Des épaules jusqu'aux bras tendus, charge au-dessus du milieu du pied.",
                breathing: "Inspire en bas, expire en poussant.",
                tips: ["Coudes légèrement devant la charge au départ.", "Garde les côtes basses."],
                mistakes: ["Cambrer fortement le bas du dos.", "Pousser la charge vers l'avant.", "Plier les genoux pour tricher."]
            )
        case .horizontalPull:
            ExerciseTechnique(
                start: "Buste penché à environ 45°, dos droit, genoux légèrement fléchis, bras tendus sous les épaules.",
                steps: ["Tire la charge vers le bas du ventre en serrant les omoplates.", "Marque une courte pause.", "Redescends lentement jusqu'aux bras tendus."],
                range: "Des bras tendus jusqu'à la charge contre le ventre.",
                breathing: "Expire en tirant, inspire en redescendant.",
                tips: ["Pense à tirer avec les coudes, pas avec les mains.", "Garde la nuque dans l'alignement du dos."],
                mistakes: ["Dos rond.", "Redresser le buste pour donner de l'élan.", "Hausser les épaules."]
            )
        case .verticalPull:
            ExerciseTechnique(
                start: "Suspendu à la barre (ou assis à la poulie), mains un peu plus larges que les épaules, bras tendus.",
                steps: ["Abaisse d'abord les épaules, puis tire les coudes vers le bas et l'arrière.", "Monte jusqu'au menton au-dessus de la barre (ou la barre au haut de la poitrine).", "Redescends lentement jusqu'aux bras tendus."],
                range: "Bras tendus en bas, menton au-dessus de la barre en haut.",
                breathing: "Expire en tirant, inspire en redescendant.",
                tips: ["Poitrine vers la barre.", "Jambes calmes, sans balancer."],
                mistakes: ["Élan des jambes.", "Amplitude partielle.", "Épaules qui montent vers les oreilles."]
            )
        case .seatedRow:
            ExerciseTechnique(
                start: "Assis, pieds calés, dos droit, bras tendus vers la poignée.",
                steps: ["Tire la poignée vers le ventre en serrant les omoplates.", "Reviens bras tendus en laissant les omoplates s'écarter, sans arrondir le dos."],
                range: "Des bras tendus jusqu'à la poignée contre le ventre.",
                breathing: "Expire en tirant, inspire en revenant.",
                tips: ["Garde le buste presque immobile.", "Coudes près du corps pour le milieu du dos."],
                mistakes: ["Basculer le buste d'avant en arrière.", "Hausser les épaules.", "Arrondir le dos au retour."]
            )
        case .pullover:
            ExerciseTechnique(
                start: "Bras presque tendus au-dessus de la tête (debout face à la poulie, ou allongé en travers d'un banc).",
                steps: ["Abaisse les bras en arc de cercle jusqu'aux hanches (ou au-dessus de la poitrine).", "Reviens lentement en gardant les coudes fixes."],
                range: "Tant que les épaules restent confortables.",
                breathing: "Expire en abaissant, inspire en revenant.",
                tips: ["Coudes légèrement fléchis et immobiles.", "Gaine le ventre pour ne pas cambrer."],
                mistakes: ["Plier les coudes (ça devient un triceps).", "Cambrer le dos.", "Aller trop loin derrière la tête."]
            )
        case .squat:
            ExerciseTechnique(
                start: "Debout, pieds largeur d'épaules, pointes légèrement ouvertes, charge stable.",
                steps: ["Inspire et gaine le ventre.", "Pousse les hanches vers l'arrière et plie les genoux dans l'axe des pieds.", "Remonte en poussant dans tout le pied."],
                range: "Au moins jusqu'aux cuisses parallèles au sol si ta mobilité le permet, dos neutre.",
                breathing: "Inspire avant de descendre, expire en remontant.",
                tips: ["Genoux dans la direction des orteils.", "Poids réparti sur tout le pied."],
                mistakes: ["Genoux qui rentrent vers l'intérieur.", "Talons qui décollent.", "Dos qui s'arrondit en bas."]
            )
        case .hinge:
            ExerciseTechnique(
                start: "Debout, pieds largeur de hanches, charge près des jambes, dos neutre.",
                steps: ["Pousse les hanches vers l'arrière en gardant la charge collée aux jambes.", "Descends jusqu'à l'étirement des ischio-jambiers (ou la charge au sol).", "Remonte en poussant les hanches vers l'avant."],
                range: "Tant que le dos reste droit : c'est la hanche qui bouge, pas le dos.",
                breathing: "Inspire et gaine en haut, expire en remontant.",
                tips: ["Genoux légèrement fléchis.", "Serre les fessiers en haut, sans te pencher en arrière."],
                mistakes: ["Dos rond.", "Charge qui s'éloigne des jambes.", "Cambrer en fin de mouvement."]
            )
        case .lunge:
            ExerciseTechnique(
                start: "Debout, pieds largeur de hanches, buste droit.",
                steps: ["Fais un grand pas (en avant, en arrière ou sur le banc).", "Descends jusqu'aux deux genoux pliés à environ 90°.", "Pousse sur le pied avant pour revenir."],
                range: "Le genou arrière approche le sol sans le toucher.",
                breathing: "Inspire en descendant, expire en remontant.",
                tips: ["Genou avant dans l'axe du pied.", "Buste droit, regard devant."],
                mistakes: ["Genou avant qui rentre.", "Pas trop court.", "Buste qui plonge vers l'avant."]
            )
        case .legPress:
            ExerciseTechnique(
                start: "Assis dans la machine, dos plaqué au dossier, pieds largeur de hanches sur la plateforme.",
                steps: ["Déverrouille la plateforme.", "Plie les genoux vers la poitrine.", "Pousse jusqu'aux jambes presque tendues."],
                range: "Tant que le bas du dos reste collé au dossier.",
                breathing: "Inspire en descendant, expire en poussant.",
                tips: ["Pousse dans les talons et le milieu du pied."],
                mistakes: ["Verrouiller les genoux en haut.", "Bassin qui décolle en bas.", "Genoux qui rentrent."]
            )
        case .legExtension:
            ExerciseTechnique(
                start: "Assis, dos contre le dossier, rouleau sur le bas des tibias.",
                steps: ["Tends les jambes.", "Marque une seconde en haut.", "Redescends lentement."],
                range: "Jusqu'aux jambes tendues.",
                breathing: "Expire en tendant, inspire en redescendant.",
                tips: ["Tiens les poignées pour rester assis."],
                mistakes: ["Donner de l'élan.", "Décoller les fesses du siège."]
            )
        case .legCurl:
            ExerciseTechnique(
                start: "Allongé ou assis dans la machine, rouleau au-dessus des talons.",
                steps: ["Plie les genoux au maximum.", "Redescends lentement."],
                range: "Des jambes tendues jusqu'à la flexion complète.",
                breathing: "Expire en pliant, inspire en revenant.",
                tips: ["Garde les hanches collées au banc."],
                mistakes: ["Hanches qui décollent.", "Élan.", "Descente trop rapide."]
            )
        case .bridge:
            ExerciseTechnique(
                start: "Dos au sol (ou le haut du dos sur un banc), genoux pliés, pieds à plat largeur de hanches.",
                steps: ["Pousse dans les talons pour monter les hanches.", "Serre les fessiers en haut, épaules-hanches-genoux alignés.", "Redescends sous contrôle."],
                range: "Jusqu'à l'alignement du buste et des cuisses, pas au-delà.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Menton rentré, regard devant toi en haut."],
                mistakes: ["Cambrer le bas du dos en haut.", "Pousser sur la pointe des pieds."]
            )
        case .legKickback:
            ExerciseTechnique(
                start: "À quatre pattes (ou debout face à la poulie), dos plat, ventre gainé.",
                steps: ["Pousse une jambe vers l'arrière en contractant le fessier.", "Reviens lentement sans poser le genou."],
                range: "Jusqu'à la cuisse dans l'alignement du dos.",
                breathing: "Expire en poussant, inspire en revenant.",
                tips: ["Le bassin reste face au sol."],
                mistakes: ["Cambrer le dos pour monter plus haut.", "Tourner le bassin."]
            )
        case .calfRaise:
            ExerciseTechnique(
                start: "Debout, l'avant du pied sur une marche ou au sol, jambes tendues.",
                steps: ["Monte sur la pointe des pieds le plus haut possible.", "Tiens une seconde.", "Redescends lentement, sous l'horizontale si tu es sur une marche."],
                range: "Du talon bas jusqu'à la pointe haute.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Garde les genoux droits sans les verrouiller."],
                mistakes: ["Rebondir.", "Amplitude trop courte."]
            )
        case .curl:
            ExerciseTechnique(
                start: "Debout, bras tendus, coudes près du buste.",
                steps: ["Plie les coudes pour monter la charge vers les épaules.", "Serre en haut.", "Redescends lentement jusqu'aux bras tendus."],
                range: "Des bras tendus jusqu'à la flexion complète.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Seuls les avant-bras bougent."],
                mistakes: ["Balancer le buste.", "Coudes qui avancent.", "Descente trop rapide."]
            )
        case .tricepsExtension:
            ExerciseTechnique(
                start: "Coudes fixes près du corps, avant-bras pliés, charge en main.",
                steps: ["Tends complètement les bras vers le bas (ou l'arrière).", "Reviens lentement jusqu'aux avant-bras à l'horizontale."],
                range: "Du coude plié à 90° jusqu'au bras tendu.",
                breathing: "Expire en tendant, inspire en revenant.",
                tips: ["Coudes collés au corps, épaules basses."],
                mistakes: ["Coudes qui s'écartent ou avancent.", "Pencher le buste pour pousser."]
            )
        case .overheadExtension:
            ExerciseTechnique(
                start: "Debout ou assis, charge tenue au-dessus de la tête, bras tendus.",
                steps: ["Plie les coudes pour descendre la charge derrière la tête.", "Tends de nouveau les bras."],
                range: "Tant que les épaules restent confortables.",
                breathing: "Inspire en descendant, expire en tendant.",
                tips: ["Coudes vers le haut, proches de la tête.", "Gaine le ventre pour ne pas cambrer."],
                mistakes: ["Coudes qui s'écartent.", "Cambrer le dos."]
            )
        case .lyingExtension:
            ExerciseTechnique(
                start: "Allongé sur un banc, bras tendus au-dessus de la poitrine.",
                steps: ["Plie les coudes pour descendre la charge vers le front.", "Tends les bras pour revenir."],
                range: "Jusqu'à la charge près du front, sans toucher.",
                breathing: "Inspire en descendant, expire en tendant.",
                tips: ["Les bras restent légèrement inclinés vers la tête."],
                mistakes: ["Coudes qui s'ouvrent.", "Descendre trop vite près du visage."]
            )
        case .lateralRaise:
            ExerciseTechnique(
                start: "Debout, charges le long du corps, coudes légèrement fléchis.",
                steps: ["Lève les bras sur les côtés jusqu'à hauteur des épaules.", "Redescends lentement."],
                range: "Jusqu'aux bras à l'horizontale.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Mène avec les coudes.", "Léger buste vers l'avant."],
                mistakes: ["Hausser les épaules.", "Donner de l'élan.", "Charge trop lourde."]
            )
        case .frontRaise:
            ExerciseTechnique(
                start: "Debout, charge devant les cuisses, bras presque tendus.",
                steps: ["Lève les bras devant toi jusqu'à hauteur des épaules.", "Redescends lentement."],
                range: "Jusqu'aux bras à l'horizontale.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Buste immobile."],
                mistakes: ["Balancer le buste.", "Monter au-dessus des épaules."]
            )
        case .fly:
            ExerciseTechnique(
                start: "Bras presque tendus devant la poitrine, coudes légèrement fléchis (allongé, assis ou à la poulie).",
                steps: ["Ouvre les bras en arc de cercle jusqu'à l'étirement des pectoraux (ou de l'arrière des épaules pour l'oiseau).", "Referme en gardant l'angle des coudes."],
                range: "Tant que les épaules restent confortables.",
                breathing: "Inspire en ouvrant, expire en refermant.",
                tips: ["Imagine serrer un gros tronc d'arbre."],
                mistakes: ["Plier et tendre les coudes pendant le mouvement.", "Descendre trop bas."]
            )
        case .uprightRow:
            ExerciseTechnique(
                start: "Debout, charge devant les cuisses, mains largeur d'épaules.",
                steps: ["Monte la charge le long du corps jusqu'au bas de la poitrine, coudes vers l'extérieur.", "Redescends lentement."],
                range: "Jusqu'aux coudes à hauteur des épaules, pas plus haut.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Une prise plus large ménage les épaules."],
                mistakes: ["Monter les coudes au-dessus des épaules.", "Prise trop serrée."]
            )
        case .shrug:
            ExerciseTechnique(
                start: "Debout, charge en main, bras tendus.",
                steps: ["Hausse les épaules vers les oreilles.", "Tiens une seconde.", "Redescends lentement."],
                range: "Le plus haut possible, sans plier les bras.",
                breathing: "Expire en montant.",
                tips: ["Mouvement vertical, sans rouler les épaules."],
                mistakes: ["Rouler les épaules.", "Plier les bras."]
            )
        case .crunch:
            ExerciseTechnique(
                start: "Allongé sur le dos, genoux pliés, pieds au sol, mains aux tempes ou croisées sur la poitrine.",
                steps: ["Enroule le haut du dos pour décoller les omoplates.", "Redescends lentement."],
                range: "Les omoplates décollent, le bas du dos reste au sol.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Regarde vers le haut, pas vers les genoux."],
                mistakes: ["Tirer sur la nuque.", "Donner de l'élan."]
            )
        case .plank:
            ExerciseTechnique(
                start: "En appui sur les avant-bras et la pointe des pieds, coudes sous les épaules.",
                steps: ["Gaine le ventre et serre les fessiers.", "Garde le corps aligné de la tête aux talons.", "Tiens la position le temps voulu."],
                range: "Position fixe.",
                breathing: "Respire calmement, sans bloquer.",
                tips: ["Pousse le sol avec les avant-bras."],
                mistakes: ["Hanches trop hautes ou affaissées.", "Retenir sa respiration."]
            )
        case .legRaise:
            ExerciseTechnique(
                start: "Allongé sur le dos (ou suspendu à une barre), jambes tendues.",
                steps: ["Lève les jambes en gardant le bas du dos plaqué (ou jusqu'aux hanches à 90° suspendu).", "Redescends lentement sans toucher le sol."],
                range: "Jusqu'aux jambes verticales allongé.",
                breathing: "Expire en montant, inspire en redescendant.",
                tips: ["Mains sous les fesses si le dos se cambre."],
                mistakes: ["Creuser le bas du dos.", "Balancer les jambes."]
            )
        case .rotation:
            ExerciseTechnique(
                start: "Assis, genoux pliés, buste incliné en arrière (ou debout face à la poulie).",
                steps: ["Tourne le buste d'un côté.", "Reviens au centre puis tourne de l'autre côté."],
                range: "Rotation contrôlée, sans forcer.",
                breathing: "Expire à chaque rotation.",
                tips: ["C'est le buste qui tourne, pas seulement les bras."],
                mistakes: ["Arrondir le dos.", "Aller trop vite."]
            )
        case .superman:
            ExerciseTechnique(
                start: "Allongé sur le ventre, bras tendus devant.",
                steps: ["Décolle doucement les bras, la poitrine et les jambes.", "Tiens deux secondes.", "Redescends lentement."],
                range: "Quelques centimètres suffisent.",
                breathing: "Expire en montant.",
                tips: ["Regard vers le sol, nuque longue."],
                mistakes: ["Lever la tête vers l'avant.", "Monter trop haut en forçant."]
            )
        case .mountainClimber:
            ExerciseTechnique(
                start: "En position de pompe, bras tendus, corps gainé.",
                steps: ["Ramène un genou vers la poitrine.", "Change de jambe rapidement, comme si tu courais."],
                range: "Le genou vient sous la poitrine.",
                breathing: "Respire en rythme.",
                tips: ["Épaules au-dessus des mains."],
                mistakes: ["Hanches qui montent.", "Rebondir sur les pieds."]
            )
        case .carry:
            ExerciseTechnique(
                start: "Debout, une charge lourde dans chaque main.",
                steps: ["Marche à petits pas contrôlés.", "Garde le buste droit et les épaules basses."],
                range: "Sur la distance ou le temps choisi.",
                breathing: "Respire régulièrement, sans bloquer.",
                tips: ["Serre fort les poignées."],
                mistakes: ["Se pencher d'un côté.", "Hausser les épaules."]
            )
        case .run:
            ExerciseTechnique(
                start: "Debout, buste droit, regard devant.",
                steps: ["Commence à allure facile quelques minutes.", "Garde une foulée souple et régulière.", "Accélère progressivement si tu veux."],
                range: "Sur la durée ou la distance prévue.",
                breathing: "Respire régulièrement ; en endurance, tu dois pouvoir parler.",
                tips: ["Bras détendus, coudes à 90°."],
                mistakes: ["Partir trop vite.", "Talonner lourdement."]
            )
        case .cycle:
            ExerciseTechnique(
                start: "Assis sur le vélo, selle réglée pour une jambe presque tendue en bas.",
                steps: ["Pédale à cadence régulière.", "Ajuste la résistance selon ta séance."],
                range: "Sur la durée prévue.",
                breathing: "Respire régulièrement.",
                tips: ["Haut du corps détendu."],
                mistakes: ["Selle trop basse.", "Résistance trop forte qui te fait balancer."]
            )
        case .rowing:
            ExerciseTechnique(
                start: "Assis, pieds sanglés, bras tendus, tibias verticaux.",
                steps: ["Pousse d'abord avec les jambes.", "Bascule légèrement le buste en arrière puis tire la poignée sous les côtes.", "Reviens dans l'ordre inverse : bras, buste, jambes."],
                range: "Du tassé en avant jusqu'aux jambes tendues.",
                breathing: "Expire en tirant, inspire en revenant.",
                tips: ["Les jambes font l'essentiel du travail."],
                mistakes: ["Tirer avec les bras en premier.", "Dos rond."]
            )
        case .jump:
            ExerciseTechnique(
                start: "Debout, pieds largeur de hanches, genoux souples.",
                steps: ["Saute en poussant dans le sol.", "Reçois-toi sur l'avant du pied, genoux fléchis.", "Enchaîne à ton rythme."],
                range: "Hauteur confortable.",
                breathing: "Respire en rythme.",
                tips: ["Atterrissage silencieux."],
                mistakes: ["Genoux qui rentrent à la réception.", "Atterrir jambes tendues."]
            )
        case .armCircles:
            ExerciseTechnique(
                start: "Debout, stable, bras le long du corps.",
                steps: ["Fais de grands cercles lents avec les bras.", "Change de sens après 8 à 12 tours."],
                range: "Toute l'amplitude confortable.",
                breathing: "Respire calmement.",
                tips: ["Mouvements lents et contrôlés."],
                mistakes: ["Aller trop vite.", "Forcer dans la douleur."]
            )
        case .stretchFold:
            ExerciseTechnique(
                start: "Assis ou debout, jambes tendues sans verrouiller les genoux.",
                steps: ["Penche-toi vers l'avant depuis les hanches.", "Tiens 20 à 40 secondes en respirant lentement.", "Remonte doucement."],
                range: "Jusqu'à une tension agréable, jamais une douleur.",
                breathing: "Respire lentement ; relâche un peu plus à chaque expiration.",
                tips: ["Dos le plus long possible."],
                mistakes: ["Forcer jusqu'à la douleur.", "Faire des rebonds."]
            )
        case .stretchStand:
            ExerciseTechnique(
                start: "Debout, en appui stable (un mur peut aider).",
                steps: ["Mets-toi en position d'étirement.", "Tiens 20 à 40 secondes.", "Relâche doucement et change de côté."],
                range: "Jusqu'à une tension agréable, jamais une douleur.",
                breathing: "Respire lentement.",
                tips: ["Épaules détendues."],
                mistakes: ["Forcer jusqu'à la douleur.", "Faire des rebonds."]
            )
        case .generic:
            ExerciseTechnique(
                start: "Installe-toi dans une position stable et confortable.",
                steps: ["Fais le mouvement lentement et sous contrôle.", "Reviens à la position de départ."],
                range: "Toute l'amplitude confortable.",
                breathing: "Expire pendant l'effort, inspire en revenant.",
                tips: ["La qualité avant la charge."],
                mistakes: ["Donner de l'élan.", "Forcer dans la douleur."]
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
        x("bench-press", "Développé couché (barre)", [.chest], [.triceps, .shoulders], [.barbell, .bench], .strength, .intermediate, .benchPress,
          aka: ["developpe couche", "bench press", "bench"], cues: ["Barre au-dessus des épaules en haut, au bas des pectoraux en bas."]),
        x("db-bench", "Développé couché haltères", [.chest], [.triceps, .shoulders], [.dumbbells, .bench], .strength, .beginner, .benchPress,
          aka: ["developpe couche", "dumbbell bench"], cues: ["Les haltères descendent sur les côtés de la poitrine."]),
        x("incline-bench", "Développé incliné (barre)", [.chest], [.shoulders, .triceps], [.barbell, .bench], .strength, .intermediate, .benchPress,
          aka: ["developpe incline", "incline bench"], cues: ["Banc incliné à 30-45° : la barre descend vers le haut de la poitrine."]),
        x("incline-db", "Développé incliné haltères", [.chest], [.shoulders, .triceps], [.dumbbells, .bench], .strength, .beginner, .benchPress,
          aka: ["developpe incline"], cues: ["Banc à 30-45°, haltères au niveau du haut de la poitrine."]),
        x("decline-bench", "Développé décliné", [.chest], [.triceps], [.barbell, .bench], .strength, .intermediate, .benchPress, aka: ["developpe decline"]),
        x("machine-chest-press", "Développé à la machine (chest press)", [.chest], [.triceps, .shoulders], [.machine], .strength, .beginner, .benchPress,
          aka: ["chest press", "presse pectoraux"], cues: ["Règle le siège pour que les poignées arrivent au milieu de la poitrine."]),
        x("close-grip-bench", "Développé couché prise serrée", [.triceps], [.chest, .shoulders], [.barbell, .bench], .strength, .intermediate, .benchPress,
          aka: ["developpe serre", "close grip"], cues: ["Mains largeur d'épaules, coudes près du corps."]),
        x("push-up", "Pompes", [.chest], [.triceps, .shoulders, .abs], [.bodyweight], .strength, .beginner, .pushUp, aka: ["pompe", "push up", "push-up"]),
        x("knee-push-up", "Pompes sur les genoux", [.chest], [.triceps, .shoulders], [.bodyweight], .strength, .beginner, .pushUp,
          aka: ["pompe genoux"], cues: ["Genoux au sol, corps aligné des genoux à la tête."]),
        x("incline-push-up", "Pompes inclinées (mains surélevées)", [.chest], [.triceps, .shoulders], [.bodyweight, .bench], .strength, .beginner, .pushUp,
          aka: ["pompe inclinee"], cues: ["Plus les mains sont hautes, plus c'est facile."]),
        x("decline-push-up", "Pompes déclinées (pieds surélevés)", [.chest], [.shoulders, .triceps], [.bodyweight, .bench], .strength, .intermediate, .pushUp,
          aka: ["pompe declinee"]),
        x("diamond-push-up", "Pompes diamant", [.triceps], [.chest], [.bodyweight], .strength, .intermediate, .pushUp,
          aka: ["pompe diamant", "pompes serrees"], cues: ["Pouces et index se touchent sous la poitrine."]),
        x("db-fly", "Écarté couché haltères", [.chest], [.shoulders], [.dumbbells, .bench], .strength, .intermediate, .fly, aka: ["ecarte", "fly", "ecartes"]),
        x("cable-fly", "Écarté à la poulie (vis-à-vis)", [.chest], [.shoulders], [.cable], .strength, .intermediate, .fly,
          aka: ["ecarte poulie", "cable crossover", "vis a vis"], cues: ["Un pied en avant pour la stabilité ; les mains se rejoignent devant la poitrine."]),
        x("pec-deck", "Pec deck (butterfly)", [.chest], [.shoulders], [.machine], .strength, .beginner, .fly, aka: ["butterfly", "pec deck", "ecarte machine"]),
        x("chest-dips", "Dips (pectoraux)", [.chest], [.triceps, .shoulders], [.bodyweight], .strength, .intermediate, .dip,
          aka: ["dips"], cues: ["Buste légèrement penché vers l'avant, coudes un peu écartés."]),
    ]

    private static let back: [ExerciseInfo] = [
        x("pull-up", "Tractions (pronation)", [.back], [.biceps, .forearms], [.pullUpBar], .strength, .intermediate, .verticalPull,
          aka: ["traction", "pull up", "pull-up"]),
        x("chin-up", "Tractions supination (chin-up)", [.back], [.biceps], [.pullUpBar], .strength, .intermediate, .verticalPull,
          aka: ["traction supination", "chin up"], cues: ["Paumes vers toi, mains largeur d'épaules."]),
        x("assisted-pull-up", "Tractions assistées", [.back], [.biceps], [.band, .machine], .strength, .beginner, .verticalPull,
          aka: ["traction assistee"], cues: ["L'élastique ou la machine allège une partie du poids du corps."]),
        x("lat-pulldown", "Tirage vertical (poulie haute)", [.back], [.biceps], [.cable], .strength, .beginner, .verticalPull,
          aka: ["tirage poitrine", "lat pulldown", "tirage vertical"], cues: ["Tire la barre vers le haut de la poitrine, pas derrière la nuque."]),
        x("close-pulldown", "Tirage vertical prise serrée", [.back], [.biceps], [.cable], .strength, .beginner, .verticalPull, aka: ["tirage serre"]),
        x("barbell-row", "Rowing barre", [.back], [.biceps, .lowerBack], [.barbell], .strength, .intermediate, .horizontalPull,
          aka: ["rowing", "bent over row", "rowing buste penche"]),
        x("db-row", "Rowing haltère (un bras)", [.back], [.biceps], [.dumbbells, .bench], .strength, .beginner, .horizontalPull,
          aka: ["rowing haltere", "one arm row"], cues: ["Genou et main en appui sur le banc, dos plat."]),
        x("t-bar-row", "Rowing T-bar", [.back], [.biceps, .lowerBack], [.barbell], .strength, .intermediate, .horizontalPull, aka: ["t bar"]),
        x("inverted-row", "Rowing inversé", [.back], [.biceps], [.bodyweight], .strength, .beginner, .horizontalPull,
          aka: ["australian pull up", "traction horizontale"], cues: ["Sous une barre basse, corps gainé, tire la poitrine vers la barre."]),
        x("seated-cable-row", "Tirage horizontal à la poulie", [.back], [.biceps], [.cable], .strength, .beginner, .seatedRow,
          aka: ["tirage horizontal", "seated row", "rowing poulie"]),
        x("machine-row", "Rowing à la machine", [.back], [.biceps], [.machine], .strength, .beginner, .seatedRow, aka: ["rowing machine assis"]),
        x("straight-arm-pulldown", "Pull-over à la poulie bras tendus", [.back], [.triceps], [.cable], .strength, .intermediate, .pullover,
          aka: ["pullover poulie", "straight arm pulldown"]),
        x("db-pullover", "Pull-over haltère", [.back, .chest], [.triceps], [.dumbbells, .bench], .strength, .intermediate, .pullover, aka: ["pullover"]),
        x("face-pull", "Face pull", [.shoulders], [.back, .traps], [.cable], .strength, .beginner, .seatedRow,
          aka: ["face pull", "tirage visage"], cues: ["Corde à hauteur des yeux, tire vers le visage en ouvrant les coudes."]),
        x("band-pull-apart", "Élastique écarté (pull-apart)", [.shoulders], [.back], [.band], .strength, .beginner, .lateralRaise,
          aka: ["pull apart", "elastique"], cues: ["Bras tendus devant toi, écarte l'élastique jusqu'à la poitrine."]),
        x("bb-shrug", "Haussements d'épaules (barre)", [.traps], [.forearms], [.barbell], .strength, .beginner, .shrug, aka: ["shrug", "haussement"]),
        x("db-shrug", "Haussements d'épaules haltères", [.traps], [.forearms], [.dumbbells], .strength, .beginner, .shrug, aka: ["shrug"]),
    ]

    private static let shoulders: [ExerciseInfo] = [
        x("ohp", "Développé militaire (barre)", [.shoulders], [.triceps, .traps], [.barbell], .strength, .intermediate, .verticalPush,
          aka: ["developpe militaire", "overhead press", "military press", "ohp"]),
        x("db-shoulder-press", "Développé épaules haltères", [.shoulders], [.triceps], [.dumbbells, .bench], .strength, .beginner, .verticalPush,
          aka: ["developpe epaules", "shoulder press"], cues: ["Assis, dos contre le dossier, haltères à hauteur des oreilles au départ."]),
        x("arnold-press", "Développé Arnold", [.shoulders], [.triceps], [.dumbbells], .strength, .intermediate, .verticalPush,
          aka: ["arnold"], cues: ["Paumes vers toi en bas, tourne-les vers l'avant en poussant."]),
        x("machine-shoulder-press", "Développé épaules à la machine", [.shoulders], [.triceps], [.machine], .strength, .beginner, .verticalPush, aka: ["presse epaules"]),
        x("kb-press", "Développé kettlebell", [.shoulders], [.triceps, .abs], [.kettlebell], .strength, .intermediate, .verticalPush, aka: ["press kettlebell"]),
        x("pike-push-up", "Pompes piquées (pike)", [.shoulders], [.triceps], [.bodyweight], .strength, .intermediate, .pushUp,
          aka: ["pike push up"], cues: ["Hanches hautes, tête vers le sol entre les mains."]),
        x("handstand-push-up", "Pompes en équilibre (handstand)", [.shoulders], [.triceps, .traps], [.bodyweight], .strength, .advanced, .verticalPush,
          aka: ["hspu", "handstand"], cues: ["Contre un mur, descends la tête vers le sol sous contrôle."]),
        x("lateral-raise", "Élévations latérales", [.shoulders], [.traps], [.dumbbells], .strength, .beginner, .lateralRaise,
          aka: ["elevation laterale", "lateral raise"]),
        x("cable-lateral", "Élévations latérales à la poulie", [.shoulders], [.traps], [.cable], .strength, .intermediate, .lateralRaise, aka: ["elevation laterale poulie"]),
        x("front-raise", "Élévations frontales", [.shoulders], [.chest], [.dumbbells], .strength, .beginner, .frontRaise, aka: ["elevation frontale", "front raise"]),
        x("rear-delt-fly", "Oiseau (buste penché)", [.shoulders], [.back, .traps], [.dumbbells], .strength, .beginner, .horizontalPull,
          aka: ["oiseau", "rear delt", "elevation buste penche"], cues: ["Buste penché, ouvre les bras sur les côtés : c'est l'arrière de l'épaule qui travaille."]),
        x("reverse-pec-deck", "Oiseau à la machine", [.shoulders], [.back], [.machine], .strength, .beginner, .seatedRow, aka: ["reverse pec deck", "oiseau machine"]),
        x("upright-row", "Rowing menton", [.shoulders], [.traps], [.barbell], .strength, .intermediate, .uprightRow, aka: ["upright row", "tirage menton"]),
    ]

    private static let arms: [ExerciseInfo] = [
        x("bb-curl", "Curl barre", [.biceps], [.forearms], [.barbell], .strength, .beginner, .curl, aka: ["curl", "biceps curl"]),
        x("ez-curl", "Curl barre EZ", [.biceps], [.forearms], [.barbell], .strength, .beginner, .curl, aka: ["curl ez"]),
        x("db-curl", "Curl haltères", [.biceps], [.forearms], [.dumbbells], .strength, .beginner, .curl,
          aka: ["curl", "curl alterne"], cues: ["En alterné ou les deux bras ensemble, paumes vers le haut."]),
        x("hammer-curl", "Curl marteau", [.biceps], [.forearms], [.dumbbells], .strength, .beginner, .curl,
          aka: ["hammer", "curl prise neutre"], cues: ["Paumes face à face tout le long du mouvement."]),
        x("incline-curl", "Curl incliné", [.biceps], [], [.dumbbells, .bench], .strength, .intermediate, .curl, aka: ["curl incline"]),
        x("preacher-curl", "Curl au pupitre", [.biceps], [.forearms], [.barbell, .machine], .strength, .intermediate, .curl,
          aka: ["larry scott", "preacher"], cues: ["Bras bien posés sur le pupitre ; ne tends pas brutalement en bas."]),
        x("cable-curl", "Curl à la poulie", [.biceps], [.forearms], [.cable], .strength, .beginner, .curl, aka: ["curl poulie"]),
        x("concentration-curl", "Curl concentration", [.biceps], [], [.dumbbells, .bench], .strength, .beginner, .curl,
          aka: ["curl concentre"], cues: ["Assis, coude appuyé contre l'intérieur de la cuisse."]),
        x("band-curl", "Curl élastique", [.biceps], [.forearms], [.band], .strength, .beginner, .curl, aka: ["curl elastique"]),
        x("pushdown", "Extension triceps à la poulie", [.triceps], [], [.cable], .strength, .beginner, .tricepsExtension,
          aka: ["pushdown", "triceps poulie", "extension poulie haute"]),
        x("rope-pushdown", "Extension triceps à la corde", [.triceps], [], [.cable], .strength, .beginner, .tricepsExtension,
          aka: ["corde triceps"], cues: ["Écarte les bouts de la corde en bas du mouvement."]),
        x("overhead-extension", "Extension triceps au-dessus de la tête", [.triceps], [], [.dumbbells], .strength, .beginner, .overheadExtension,
          aka: ["extension nuque", "french press"]),
        x("skull-crusher", "Barre au front", [.triceps], [], [.barbell, .bench], .strength, .intermediate, .lyingExtension,
          aka: ["skull crusher", "barre front", "extension couche"]),
        x("triceps-dips", "Dips (triceps)", [.triceps], [.chest, .shoulders], [.bodyweight], .strength, .intermediate, .dip,
          aka: ["dips triceps"], cues: ["Buste droit, coudes serrés vers l'arrière."]),
        x("bench-dips", "Dips sur banc", [.triceps], [.shoulders], [.bodyweight, .bench], .strength, .beginner, .dip,
          aka: ["dips banc"], cues: ["Mains sur le banc derrière toi, fesses près du banc."]),
        x("kickback", "Kickback triceps", [.triceps], [], [.dumbbells], .strength, .beginner, .tricepsExtension,
          aka: ["kick back"], cues: ["Buste penché, bras collé au corps, tends l'avant-bras vers l'arrière."]),
        x("wrist-curl", "Flexion des poignets", [.forearms], [], [.dumbbells, .barbell], .strength, .beginner, .curl,
          aka: ["poignets", "wrist curl"], cues: ["Avant-bras posés sur les cuisses, seuls les poignets bougent."]),
        x("reverse-curl", "Curl inversé (pronation)", [.forearms], [.biceps], [.barbell], .strength, .beginner, .curl, aka: ["curl pronation", "reverse curl"]),
        x("dead-hang", "Suspension à la barre", [.forearms], [.back], [.pullUpBar], .strength, .beginner, .verticalPull,
          aka: ["suspension", "dead hang"], cues: ["Reste suspendu bras tendus, épaules légèrement engagées."]),
        x("farmer-walk", "Marche du fermier", [.forearms, .traps], [.fullBody], [.dumbbells, .kettlebell], .strength, .beginner, .carry,
          aka: ["farmer walk", "farmer carry"]),
    ]

    private static let legs: [ExerciseInfo] = [
        x("back-squat", "Squat (barre)", [.quads], [.glutes, .hamstrings, .lowerBack], [.barbell], .strength, .intermediate, .squat,
          aka: ["squat", "back squat", "flexion"], cues: ["Barre sur le haut des trapèzes, mains serrées sur la barre."]),
        x("front-squat", "Squat avant", [.quads], [.glutes, .abs], [.barbell], .strength, .advanced, .squat,
          aka: ["front squat"], cues: ["Barre sur l'avant des épaules, coudes hauts, buste droit."]),
        x("goblet-squat", "Squat gobelet", [.quads], [.glutes], [.kettlebell, .dumbbells], .strength, .beginner, .squat,
          aka: ["goblet squat"], cues: ["Charge tenue contre la poitrine, coudes entre les genoux en bas."]),
        x("air-squat", "Squat au poids du corps", [.quads], [.glutes], [.bodyweight], .strength, .beginner, .squat, aka: ["squat", "air squat"]),
        x("hack-squat", "Hack squat", [.quads], [.glutes], [.machine], .strength, .intermediate, .squat, aka: ["hack"]),
        x("wall-sit", "Chaise contre le mur", [.quads], [.glutes], [.bodyweight], .strength, .beginner, .squat,
          aka: ["chaise", "wall sit"], cues: ["Dos au mur, cuisses parallèles au sol ; tiens la position."]),
        x("leg-press", "Presse à cuisses", [.quads], [.glutes], [.machine], .strength, .beginner, .legPress, aka: ["presse", "leg press"]),
        x("leg-extension", "Leg extension", [.quads], [], [.machine], .strength, .beginner, .legExtension, aka: ["extension jambes", "leg extension"]),
        x("bulgarian-split", "Squat bulgare", [.quads], [.glutes], [.dumbbells, .bench], .strength, .intermediate, .lunge,
          aka: ["bulgarian split squat", "fente bulgare"], cues: ["Pied arrière posé sur le banc, l'essentiel du poids sur la jambe avant."]),
        x("lunge", "Fentes avant", [.quads], [.glutes, .hamstrings], [.bodyweight, .dumbbells], .strength, .beginner, .lunge, aka: ["fente", "lunge"]),
        x("reverse-lunge", "Fentes arrière", [.quads], [.glutes], [.bodyweight, .dumbbells], .strength, .beginner, .lunge, aka: ["fente arriere"]),
        x("walking-lunge", "Fentes marchées", [.quads], [.glutes, .hamstrings], [.bodyweight, .dumbbells], .strength, .intermediate, .lunge, aka: ["fente marchee"]),
        x("step-up", "Montées sur banc", [.quads], [.glutes], [.bench, .dumbbells], .strength, .beginner, .lunge,
          aka: ["step up"], cues: ["Pose tout le pied sur le banc et monte en poussant sur cette jambe."]),
        x("deadlift", "Soulevé de terre", [.lowerBack, .hamstrings, .glutes], [.quads, .traps, .forearms], [.barbell], .strength, .intermediate, .hinge,
          aka: ["souleve de terre", "deadlift", "sdt"], cues: ["Barre au-dessus du milieu du pied, tibias près de la barre au départ."]),
        x("sumo-deadlift", "Soulevé de terre sumo", [.glutes, .quads], [.hamstrings, .lowerBack], [.barbell], .strength, .intermediate, .hinge,
          aka: ["sumo"], cues: ["Pieds très écartés, mains entre les jambes."]),
        x("rdl", "Soulevé de terre roumain", [.hamstrings], [.glutes, .lowerBack], [.barbell], .strength, .intermediate, .hinge,
          aka: ["romanian deadlift", "rdl", "souleve de terre jambes tendues"]),
        x("db-rdl", "Soulevé de terre roumain haltères", [.hamstrings], [.glutes, .lowerBack], [.dumbbells], .strength, .beginner, .hinge, aka: ["rdl haltere"]),
        x("single-leg-rdl", "Soulevé de terre sur une jambe", [.hamstrings], [.glutes], [.dumbbells, .kettlebell], .strength, .intermediate, .hinge,
          aka: ["rdl une jambe"], cues: ["La jambe libre part vers l'arrière, bassin face au sol."]),
        x("good-morning", "Good morning", [.hamstrings], [.lowerBack, .glutes], [.barbell], .strength, .intermediate, .hinge, aka: ["good morning"]),
        x("lying-leg-curl", "Leg curl allongé", [.hamstrings], [.calves], [.machine], .strength, .beginner, .legCurl, aka: ["leg curl", "ischio machine"]),
        x("seated-leg-curl", "Leg curl assis", [.hamstrings], [], [.machine], .strength, .beginner, .legCurl, aka: ["leg curl assis"]),
        x("nordic-curl", "Nordic curl", [.hamstrings], [], [.bodyweight], .strength, .advanced, .legCurl,
          aka: ["nordic"], cues: ["Chevilles bloquées, descends le buste vers l'avant le plus lentement possible."]),
        x("kb-swing", "Kettlebell swing", [.glutes, .hamstrings], [.lowerBack, .shoulders], [.kettlebell], .strength, .intermediate, .hinge,
          aka: ["swing"], cues: ["La force vient des hanches : les bras ne font que tenir la kettlebell."]),
        x("hip-thrust", "Hip thrust (barre)", [.glutes], [.hamstrings], [.barbell, .bench], .strength, .intermediate, .bridge,
          aka: ["hip thrust", "releve de bassin"], cues: ["Haut du dos sur le banc, barre sur les hanches avec une protection."]),
        x("glute-bridge", "Pont fessier", [.glutes], [.hamstrings], [.bodyweight], .strength, .beginner, .bridge, aka: ["pont", "glute bridge"]),
        x("single-leg-bridge", "Pont fessier sur une jambe", [.glutes], [.hamstrings], [.bodyweight], .strength, .intermediate, .bridge, aka: ["pont une jambe"]),
        x("cable-kickback", "Kickback fessier à la poulie", [.glutes], [.hamstrings], [.cable], .strength, .beginner, .legKickback, aka: ["kickback fessier"]),
        x("donkey-kick", "Donkey kick", [.glutes], [.hamstrings], [.bodyweight], .strength, .beginner, .legKickback, aka: ["donkey kick", "ruade"]),
        x("hip-abduction", "Abduction à la machine", [.glutes], [], [.machine], .strength, .beginner, .generic,
          aka: ["abducteurs", "abduction"], cues: ["Assis, écarte les jambes contre la résistance, reviens lentement."]),
        x("hip-adduction", "Adduction à la machine", [.quads], [], [.machine], .strength, .beginner, .generic,
          aka: ["adducteurs", "adduction"], cues: ["Assis, resserre les jambes contre la résistance, reviens lentement."]),
        x("fire-hydrant", "Fire hydrant", [.glutes], [], [.bodyweight], .strength, .beginner, .generic,
          aka: ["fire hydrant"], cues: ["À quatre pattes, lève le genou plié sur le côté, sans tourner le bassin."]),
        x("cable-pull-through", "Pull-through à la poulie", [.glutes], [.hamstrings], [.cable], .strength, .beginner, .hinge, aka: ["pull through"]),
        x("standing-calf", "Mollets debout", [.calves], [], [.machine, .bodyweight], .strength, .beginner, .calfRaise, aka: ["mollets", "calf raise"]),
        x("seated-calf", "Mollets assis", [.calves], [], [.machine], .strength, .beginner, .calfRaise, aka: ["mollets assis"]),
        x("single-calf", "Mollets sur une jambe", [.calves], [], [.dumbbells, .bodyweight], .strength, .beginner, .calfRaise, aka: ["mollet une jambe"]),
    ]

    private static let core: [ExerciseInfo] = [
        x("crunch", "Crunch", [.abs], [], [.bodyweight], .strength, .beginner, .crunch, aka: ["abdos", "crunch"]),
        x("sit-up", "Redressements assis", [.abs], [], [.bodyweight], .strength, .beginner, .crunch, aka: ["sit up", "redressement"]),
        x("bicycle-crunch", "Crunch vélo", [.obliques], [.abs], [.bodyweight], .strength, .beginner, .crunch,
          aka: ["bicycle"], cues: ["Coude vers le genou opposé, en alternant."]),
        x("cable-crunch", "Crunch à la poulie", [.abs], [], [.cable], .strength, .intermediate, .crunch,
          aka: ["crunch poulie"], cues: ["À genoux, enroule le buste vers le sol, hanches fixes."]),
        x("plank", "Planche (gainage)", [.abs], [.lowerBack, .shoulders], [.bodyweight], .strength, .beginner, .plank, aka: ["gainage", "plank", "planche"]),
        x("side-plank", "Planche latérale", [.obliques], [.abs, .shoulders], [.bodyweight], .strength, .beginner, .plank,
          aka: ["gainage lateral", "side plank"], cues: ["Sur un avant-bras, corps de profil et aligné, hanches hautes."]),
        x("leg-raise", "Relevés de jambes", [.abs], [], [.bodyweight], .strength, .beginner, .legRaise, aka: ["releve de jambes", "leg raise"]),
        x("hanging-leg-raise", "Relevés de jambes suspendu", [.abs], [.forearms], [.pullUpBar], .strength, .advanced, .legRaise,
          aka: ["releve suspendu", "hanging leg raise"]),
        x("dead-bug", "Dead bug", [.abs], [], [.bodyweight], .strength, .beginner, .legRaise,
          aka: ["dead bug"], cues: ["Dos plaqué, tends un bras et la jambe opposée en alternant."]),
        x("hollow-hold", "Hollow hold", [.abs], [], [.bodyweight], .strength, .intermediate, .legRaise,
          aka: ["hollow"], cues: ["Bras et jambes tendus au-dessus du sol, bas du dos plaqué ; tiens."]),
        x("russian-twist", "Russian twist", [.obliques], [.abs], [.bodyweight, .other], .strength, .beginner, .rotation, aka: ["twist", "russian twist"]),
        x("woodchop", "Bûcheron à la poulie", [.obliques], [.abs, .shoulders], [.cable], .strength, .intermediate, .rotation, aka: ["woodchop", "bucheron"]),
        x("pallof-press", "Pallof press", [.obliques], [.abs], [.cable, .band], .strength, .beginner, .frontRaise,
          aka: ["pallof"], cues: ["De profil à la poulie, pousse les mains devant toi sans laisser le buste tourner."]),
        x("mountain-climber", "Mountain climbers", [.abs], [.shoulders, .heart], [.bodyweight], .cardio, .beginner, .mountainClimber, aka: ["mountain climber", "grimpeur"]),
        x("ab-wheel", "Roulette abdominale", [.abs], [.lowerBack, .shoulders], [.other], .strength, .advanced, .plank,
          aka: ["ab wheel", "roue abdominale"], cues: ["Roule vers l'avant sans creuser le dos, reviens en contractant les abdos."]),
        x("back-extension", "Extensions lombaires", [.lowerBack], [.glutes, .hamstrings], [.bench, .machine], .strength, .beginner, .hinge,
          aka: ["hyperextension", "lombaires"], cues: ["Banc à 45°, descends le buste puis remonte jusqu'à l'alignement, sans cambrer."]),
        x("superman", "Superman", [.lowerBack], [.glutes], [.bodyweight], .strength, .beginner, .superman, aka: ["superman"]),
        x("bird-dog", "Bird dog", [.lowerBack], [.abs, .glutes], [.bodyweight], .strength, .beginner, .legKickback,
          aka: ["bird dog"], cues: ["À quatre pattes, tends un bras et la jambe opposée, dos plat."]),
    ]

    private static let fullBody: [ExerciseInfo] = [
        x("burpee", "Burpees", [.fullBody], [.heart], [.bodyweight], .cardio, .intermediate, .jump, aka: ["burpee"]),
        x("thruster", "Thruster", [.fullBody], [.quads, .shoulders], [.barbell, .dumbbells], .strength, .intermediate, .squat,
          aka: ["thruster"], cues: ["Enchaîne un squat avant et un développé au-dessus de la tête en un mouvement."]),
        x("power-clean", "Épaulé (power clean)", [.fullBody], [.traps, .hamstrings], [.barbell], .strength, .advanced, .hinge,
          aka: ["clean", "epaule"], cues: ["Explosion des hanches, la barre monte près du corps jusqu'aux épaules. Apprends-le avec un coach."]),
        x("kb-clean", "Épaulé kettlebell", [.fullBody], [.shoulders], [.kettlebell], .strength, .intermediate, .hinge, aka: ["clean kettlebell"]),
        x("turkish-get-up", "Turkish get-up", [.fullBody], [.shoulders, .abs], [.kettlebell], .strength, .advanced, .generic,
          aka: ["get up"], cues: ["Du sol à debout, bras tendu vers le plafond avec la charge, étape par étape."]),
        x("wall-ball", "Wall ball", [.fullBody], [.quads, .shoulders], [.other], .strength, .intermediate, .squat,
          aka: ["wall ball"], cues: ["Squat avec un médecine-ball, puis lance-le contre le mur en te relevant."]),
        x("battle-ropes", "Cordes ondulatoires", [.fullBody], [.shoulders, .heart], [.other], .cardio, .intermediate, .generic,
          aka: ["battle rope", "cordes"], cues: ["Genoux fléchis, fais onduler les cordes en alternant les bras."]),
        x("sled-push", "Poussée de traîneau", [.fullBody], [.quads, .heart], [.other], .cardio, .intermediate, .run, aka: ["traineau", "sled"]),
        x("bear-crawl", "Marche de l'ours", [.fullBody], [.shoulders, .abs], [.bodyweight], .strength, .beginner, .mountainClimber,
          aka: ["bear crawl"], cues: ["À quatre pattes, genoux juste au-dessus du sol, avance main et pied opposés."]),
    ]

    private static let cardio: [ExerciseInfo] = [
        x("running", "Course à pied", [.heart], [.quads, .calves], [.bodyweight], .cardio, .beginner, .run, aka: ["course", "running", "jogging", "footing"]),
        x("treadmill", "Tapis de course", [.heart], [.quads, .calves], [.machine], .cardio, .beginner, .run, aka: ["tapis", "treadmill"]),
        x("walking", "Marche rapide", [.heart], [.calves], [.bodyweight], .cardio, .beginner, .run, aka: ["marche", "walking"]),
        x("incline-walk", "Marche inclinée sur tapis", [.heart], [.glutes, .calves], [.machine], .cardio, .beginner, .run, aka: ["marche inclinee"]),
        x("high-knees", "Montées de genoux", [.heart], [.quads], [.bodyweight], .cardio, .beginner, .run, aka: ["high knees", "genoux hauts"]),
        x("cycling", "Vélo", [.heart], [.quads], [.machine, .other], .cardio, .beginner, .cycle, aka: ["velo", "bike", "cyclisme"]),
        x("spinning", "Vélo d'intérieur (spinning)", [.heart], [.quads], [.machine], .cardio, .intermediate, .cycle, aka: ["spinning", "velo interieur"]),
        x("rowing-machine", "Rameur", [.heart], [.back, .quads], [.machine], .cardio, .beginner, .rowing, aka: ["rameur", "rowing machine", "ergometre"]),
        x("elliptical", "Vélo elliptique", [.heart], [.quads, .glutes], [.machine], .cardio, .beginner, .run, aka: ["elliptique"]),
        x("stair-climber", "Escaliers (stepper)", [.heart], [.glutes, .quads], [.machine], .cardio, .intermediate, .lunge, aka: ["stepper", "escalier"]),
        x("jump-rope", "Corde à sauter", [.heart], [.calves], [.other], .cardio, .beginner, .jump, aka: ["corde", "jump rope"]),
        x("jumping-jacks", "Jumping jacks", [.heart], [.calves, .shoulders], [.bodyweight], .cardio, .beginner, .jump, aka: ["jumping jack"]),
        x("jump-squat", "Squat sauté", [.quads], [.glutes, .calves, .heart], [.bodyweight], .cardio, .intermediate, .jump, aka: ["jump squat"]),
        x("box-jump", "Box jump", [.quads], [.glutes, .calves], [.other], .cardio, .intermediate, .jump,
          aka: ["saut sur boite"], cues: ["Saute sur la boîte à deux pieds, descends en marchant."]),
        x("hiit", "Circuit HIIT", [.fullBody], [.heart], [.bodyweight], .cardio, .intermediate, .jump, aka: ["hiit", "fractionne", "circuit"]),
        x("swimming", "Natation", [.fullBody], [.heart], [.other], .cardio, .intermediate, .generic, aka: ["nage", "piscine"]),
        x("boxing", "Boxe (sac de frappe)", [.fullBody], [.shoulders, .heart], [.other], .cardio, .intermediate, .generic, aka: ["boxe", "sac"]),
    ]

    private static let mobility: [ExerciseInfo] = [
        x("arm-circles", "Cercles de bras", [.shoulders], [], [.bodyweight], .mobility, .beginner, .armCircles, aka: ["moulinets", "cercles"]),
        x("shoulder-dislocates", "Passages d'épaules au bâton", [.shoulders], [.chest], [.band, .other], .mobility, .beginner, .armCircles,
          aka: ["passage epaules", "dislocates"], cues: ["Prise large, passe le bâton de l'avant vers l'arrière bras tendus."]),
        x("hip-circles", "Cercles de hanches", [.glutes], [.lowerBack], [.bodyweight], .mobility, .beginner, .generic, aka: ["hanches"]),
        x("cat-cow", "Chat-vache", [.lowerBack], [.back], [.bodyweight], .mobility, .beginner, .generic,
          aka: ["chat vache", "cat cow"], cues: ["À quatre pattes, arrondis puis creuse doucement le dos au rythme de la respiration."]),
        x("worlds-greatest", "Fente avec rotation", [.fullBody], [.hamstrings, .back], [.bodyweight], .mobility, .beginner, .lunge,
          aka: ["world greatest stretch"], cues: ["En fente, main au sol, ouvre l'autre bras vers le plafond."]),
        x("ankle-mobility", "Mobilité des chevilles", [.calves], [], [.bodyweight], .mobility, .beginner, .lunge,
          aka: ["cheville", "genou au mur"], cues: ["Face au mur, avance le genou vers le mur sans décoller le talon."]),
        x("thoracic-rotation", "Rotations thoraciques", [.back], [.obliques], [.bodyweight], .mobility, .beginner, .rotation, aka: ["rotation thoracique"]),
        x("deep-squat-hold", "Squat profond tenu", [.quads], [.glutes], [.bodyweight], .mobility, .beginner, .squat,
          aka: ["squat profond"], cues: ["Descends le plus bas confortable, talons au sol ; respire et tiens."]),
    ]

    private static let stretching: [ExerciseInfo] = [
        x("hamstring-stretch", "Étirement des ischio-jambiers", [.hamstrings], [.lowerBack], [.bodyweight], .stretching, .beginner, .stretchFold, aka: ["etirement ischio"]),
        x("quad-stretch", "Étirement des quadriceps", [.quads], [], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement quadriceps"], cues: ["Debout, attrape la cheville derrière toi, genoux côte à côte."]),
        x("hip-flexor-stretch", "Étirement des fléchisseurs de hanche", [.quads], [.glutes], [.bodyweight], .stretching, .beginner, .lunge,
          aka: ["psoas", "flechisseurs"], cues: ["En fente, genou arrière au sol, avance doucement le bassin."]),
        x("calf-stretch", "Étirement des mollets", [.calves], [], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement mollets"], cues: ["Mains au mur, jambe arrière tendue, talon au sol."]),
        x("chest-stretch", "Étirement des pectoraux", [.chest], [.shoulders], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement pectoraux"], cues: ["Avant-bras contre un encadrement de porte, avance doucement le buste."]),
        x("triceps-stretch", "Étirement des triceps", [.triceps], [.shoulders], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement triceps"], cues: ["Main derrière la tête, pousse doucement le coude avec l'autre main."]),
        x("shoulder-stretch", "Étirement des épaules (bras croisé)", [.shoulders], [], [.bodyweight], .stretching, .beginner, .stretchStand,
          aka: ["etirement epaules"], cues: ["Ramène le bras tendu contre la poitrine avec l'autre bras."]),
        x("childs-pose", "Posture de l'enfant", [.lowerBack], [.back], [.bodyweight], .stretching, .beginner, .stretchFold,
          aka: ["enfant", "child pose"], cues: ["À genoux, fesses vers les talons, bras allongés devant."]),
        x("pigeon", "Posture du pigeon", [.glutes], [.lowerBack], [.bodyweight], .stretching, .intermediate, .stretchFold,
          aka: ["pigeon"], cues: ["Jambe avant pliée devant toi, jambe arrière allongée, buste qui descend doucement."]),
        x("cobra", "Posture du cobra", [.abs], [.lowerBack], [.bodyweight], .stretching, .beginner, .superman,
          aka: ["cobra"], cues: ["Allongé sur le ventre, pousse doucement sur les mains, hanches au sol."]),
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
