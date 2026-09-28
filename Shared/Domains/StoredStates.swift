import Foundation

// Where each mini-app keeps its data in the shared container.

extension NutritionState: StoredState { static var file: StoreFile { .nutrition } }
extension FitnessState: StoredState { static var file: StoreFile { .fitness } }
extension BudgetState: StoredState { static var file: StoreFile { .budget } }
extension BusinessState: StoredState { static var file: StoreFile { .business } }
extension PortfolioState: StoredState { static var file: StoreFile { .portfolio } }
extension MarketsState: StoredState { static var file: StoreFile { .following } }
extension StudentState: StoredState { static var file: StoreFile { .student } }
extension TravelState: StoredState { static var file: StoreFile { .travel } }
extension CarState: StoredState { static var file: StoreFile { .car } }
extension ProductivityState: StoredState { static var file: StoreFile { .productivity } }
extension LifeState: StoredState { static var file: StoreFile { .life } }
