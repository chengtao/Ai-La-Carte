//
//  RecommendationViewModel.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation

@MainActor
@Observable
final class RecommendationViewModel: BaseViewModel {
    let sessionId: String
    let foodMenuId: Int?
    let wineMenuId: Int?

    // Raw items from server (no confidence scores)
    private var rawFoodItems: [FoodItemResponse] = []
    private var rawWineItems: [WineItemResponse] = []

    // Scored items (with locally-calculated confidence)
    var scoredFoodRecommendations: [ScoredFoodItem] = []
    var scoredWineRecommendations: [ScoredWineItem] = []

    var profileSummary: String?
    var expandedItemId: String?
    var selectedTab: RecommendationTab = .food

    // Preference state - triggers re-scoring on change
    var currentPreferences: UserPreferences {
        get { preferenceManager.currentPreferences }
        set {
            if preferenceManager.currentPreferences != newValue {
                preferenceManager.updatePreferences(newValue)
                recalculateScores()
            }
        }
    }

    // Preference sheet state
    var isPreferenceSheetPresented: Bool = false

    // Cart state (using scored items)
    var foodCartItems: [ScoredFoodItem] = []
    var wineCartItems: [ScoredWineItem] = []

    private let menuService: MenuAPIServiceProtocol
    private let recommendationEngine: RecommendationEngineProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let preferenceManager: PreferenceManagerProtocol

    init(
        sessionId: String,
        foodMenuId: Int?,
        wineMenuId: Int?,
        menuService: MenuAPIServiceProtocol,
        recommendationEngine: RecommendationEngineProtocol,
        analyticsService: AnalyticsServiceProtocol,
        preferenceManager: PreferenceManagerProtocol
    ) {
        self.sessionId = sessionId
        self.foodMenuId = foodMenuId
        self.wineMenuId = wineMenuId
        self.menuService = menuService
        self.recommendationEngine = recommendationEngine
        self.analyticsService = analyticsService
        self.preferenceManager = preferenceManager
        super.init()
    }

    // MARK: - Data Loading

    func loadRecommendations() async {
        isLoading = true

        do {
            let response = try await menuService.getMenus(foodMenuId: foodMenuId, wineMenuId: wineMenuId)
            rawFoodItems = response.food
            rawWineItems = response.wine
            profileSummary = "Dish photos are for illustrative purposes only and not from the restaurant."

            // Calculate initial scores with default preferences
            recalculateScores()

            analyticsService.track(event: .recommendationViewed, sessionId: sessionId, meta: [
                "food_count": "\(response.food.count)",
                "wine_count": "\(response.wine.count)"
            ])
        } catch {
            self.error = handleNetworkError(error)
        }

        isLoading = false
    }

    // MARK: - Score Recalculation

    private func recalculateScores() {
        scoredFoodRecommendations = recommendationEngine.scoreFood(
            items: rawFoodItems,
            preferences: currentPreferences.food
        )
        scoredWineRecommendations = recommendationEngine.scoreWine(
            items: rawWineItems,
            preferences: currentPreferences.wine
        )

        // Update cart items with new scores
        updateCartScores()

        analyticsService.track(
            event: .preferenceAdjusted,
            sessionId: sessionId,
            meta: [
                "ingredients": currentPreferences.food.ingredients.map { $0.rawValue }.joined(separator: ","),
                "spice": "\(currentPreferences.food.spicePreference)",
                "richness": "\(currentPreferences.food.richness)"
            ]
        )
    }

    private func updateCartScores() {
        // Re-score cart items to reflect new preferences
        let foodCartIds = Set(foodCartItems.map { $0.id })
        let wineCartIds = Set(wineCartItems.map { $0.id })

        foodCartItems = scoredFoodRecommendations.filter { foodCartIds.contains($0.id) }
        wineCartItems = scoredWineRecommendations.filter { wineCartIds.contains($0.id) }
    }

    // MARK: - Item Interaction

    func toggleExpanded(_ itemId: String) {
        if expandedItemId == itemId {
            expandedItemId = nil
        } else {
            expandedItemId = itemId
            analyticsService.track(event: .itemExpanded, sessionId: sessionId, meta: ["item_id": itemId])
        }
    }

    func trackItemTap(_ itemId: String) {
        analyticsService.track(event: .itemTapped, sessionId: sessionId, meta: ["item_id": itemId])
    }

    // MARK: - Computed Properties

    var hasWineRecommendations: Bool {
        !scoredWineRecommendations.isEmpty
    }

    // MARK: - Grouped Food Recommendations

    /// Food recommendations grouped by category, sorted by category order
    var groupedFoodRecommendations: [(category: FoodCategory, items: [ScoredFoodItem])] {
        let grouped = Dictionary(grouping: scoredFoodRecommendations) { $0.foodCategory }
        return grouped
            .map { (category: $0.key, items: $0.value.sorted { $0.confidence > $1.confidence }) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    /// Categories that have food recommendations
    var availableFoodCategories: [FoodCategory] {
        groupedFoodRecommendations.map { $0.category }
    }

    /// Get food items for a specific category
    func foodItems(for category: FoodCategory) -> [ScoredFoodItem] {
        scoredFoodRecommendations.filter { $0.foodCategory == category }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Grouped Wine Recommendations

    /// Wine recommendations grouped by category, sorted by category order
    var groupedWineRecommendations: [(category: WineCategory, items: [ScoredWineItem])] {
        let grouped = Dictionary(grouping: scoredWineRecommendations) { $0.wineCategory }
        return grouped
            .map { (category: $0.key, items: $0.value.sorted { $0.confidence > $1.confidence }) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    /// Categories that have wine recommendations
    var availableWineCategories: [WineCategory] {
        groupedWineRecommendations.map { $0.category }
    }

    /// Get wine items for a specific category
    func wineItems(for category: WineCategory) -> [ScoredWineItem] {
        scoredWineRecommendations.filter { $0.wineCategory == category }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Cart Management

    var cartItemCount: Int {
        foodCartItems.count + wineCartItems.count
    }

    var totalCartItems: [(id: String, title: String, price: String?, isFood: Bool)] {
        let foodItems = foodCartItems.map { (id: $0.id, title: $0.title, price: $0.price, isFood: true) }
        let wineItems = wineCartItems.map { (id: $0.id, title: $0.title, price: $0.priceGlass ?? $0.priceBottle, isFood: false) }
        return foodItems + wineItems
    }

    func isFoodInCart(_ item: ScoredFoodItem) -> Bool {
        foodCartItems.contains { $0.id == item.id }
    }

    func isWineInCart(_ item: ScoredWineItem) -> Bool {
        wineCartItems.contains { $0.id == item.id }
    }

    func addFoodToCart(_ item: ScoredFoodItem) {
        guard !isFoodInCart(item) else { return }
        foodCartItems.append(item)
        analyticsService.track(event: .itemAddedToCart, sessionId: sessionId, meta: [
            "item_id": item.id,
            "item_type": "food",
            "item_title": item.title
        ])
    }

    func addWineToCart(_ item: ScoredWineItem) {
        guard !isWineInCart(item) else { return }
        wineCartItems.append(item)
        analyticsService.track(event: .itemAddedToCart, sessionId: sessionId, meta: [
            "item_id": item.id,
            "item_type": "wine",
            "item_title": item.title
        ])
    }

    func removeFoodFromCart(_ item: ScoredFoodItem) {
        foodCartItems.removeAll { $0.id == item.id }
        analyticsService.track(event: .itemRemovedFromCart, sessionId: sessionId, meta: [
            "item_id": item.id,
            "item_type": "food"
        ])
    }

    func removeWineFromCart(_ item: ScoredWineItem) {
        wineCartItems.removeAll { $0.id == item.id }
        analyticsService.track(event: .itemRemovedFromCart, sessionId: sessionId, meta: [
            "item_id": item.id,
            "item_type": "wine"
        ])
    }

    func toggleFoodCart(_ item: ScoredFoodItem) {
        if isFoodInCart(item) {
            removeFoodFromCart(item)
        } else {
            addFoodToCart(item)
        }
    }

    func toggleWineCart(_ item: ScoredWineItem) {
        if isWineInCart(item) {
            removeWineFromCart(item)
        } else {
            addWineToCart(item)
        }
    }

    func removeFromCartById(_ id: String) {
        if let index = foodCartItems.firstIndex(where: { $0.id == id }) {
            let item = foodCartItems[index]
            removeFoodFromCart(item)
        } else if let index = wineCartItems.firstIndex(where: { $0.id == id }) {
            let item = wineCartItems[index]
            removeWineFromCart(item)
        }
    }

    func clearCart() {
        foodCartItems.removeAll()
        wineCartItems.removeAll()
    }

    // MARK: - Preferences

    /// Resets user preferences to defaults
    func resetPreferences() {
        preferenceManager.resetPreferences()
        recalculateScores()
    }
}

enum RecommendationTab: String, CaseIterable {
    case food = "Food"
    case wine = "Wine"
    case cart = "Cart"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .wine: return "wineglass"
        case .cart: return "cart"
        }
    }
}
