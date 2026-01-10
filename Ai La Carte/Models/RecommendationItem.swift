//
//  RecommendationItem.swift
//  AILaCarte
//
//  Created by Claude on 1/2/26.
//

import Foundation
import SwiftData

@Model
final class RecommendationItem {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var title: String
    var itemDescription: String
    var tagsData: Data? // Encoded [FoodTag] or [WineTag] based on type
    var confidence: Double // 0-1
    var sessionId: String

    // Food-specific fields
    var photoUrl: String?
    var price: String?
    var categoryRaw: String?  // Food category

    // Wine-specific fields
    var grapeVarietal: String?
    var region: String?
    var country: String?
    var priceGlass: String?
    var priceBottle: String?

    var session: Session?

    var type: RecommendationType {
        get { RecommendationType(rawValue: typeRaw) ?? .food }
        set { typeRaw = newValue.rawValue }
    }

    var category: FoodCategory? {
        get {
            guard let raw = categoryRaw else { return nil }
            return FoodCategory(rawValue: raw)
        }
        set { categoryRaw = newValue?.rawValue }
    }

    var foodTags: [FoodTag] {
        get {
            guard type == .food, let data = tagsData else { return [] }
            return (try? JSONDecoder().decode([FoodTag].self, from: data)) ?? []
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }

    var wineTags: [WineTag] {
        get {
            guard type == .wine, let data = tagsData else { return [] }
            return (try? JSONDecoder().decode([WineTag].self, from: data)) ?? []
        }
        set {
            tagsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: String = UUID().uuidString,
        type: RecommendationType,
        title: String,
        description: String,
        foodTags: [FoodTag] = [],
        wineTags: [WineTag] = [],
        confidence: Double = 0.0,
        sessionId: String,
        photoUrl: String? = nil,
        price: String? = nil,
        category: FoodCategory? = nil,
        grapeVarietal: String? = nil,
        region: String? = nil,
        country: String? = nil,
        priceGlass: String? = nil,
        priceBottle: String? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.itemDescription = description
        if type == .food {
            self.tagsData = try? JSONEncoder().encode(foodTags)
        } else {
            self.tagsData = try? JSONEncoder().encode(wineTags)
        }
        self.confidence = confidence
        self.sessionId = sessionId
        self.photoUrl = photoUrl
        self.price = price
        self.categoryRaw = category?.rawValue
        self.grapeVarietal = grapeVarietal
        self.region = region
        self.country = country
        self.priceGlass = priceGlass
        self.priceBottle = priceBottle
    }
}

// MARK: - Recommendation Type

enum RecommendationType: String, Codable {
    case food
    case wine
}

// MARK: - Food Category

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case appetizer = "appetizer"
    case soup = "soup"
    case entree = "entree"
    case seafood = "seafood"
    case dessert = "dessert"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appetizer: return "Appetizers"
        case .soup: return "Soups"
        case .entree: return "Entrees"
        case .seafood: return "Seafood"
        case .dessert: return "Desserts"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .appetizer: return "sparkles"
        case .soup: return "cup.and.saucer.fill"
        case .entree: return "flame.fill"
        case .seafood: return "fish.fill"
        case .dessert: return "birthday.cake.fill"
        case .other: return "star.fill"
        }
    }

    /// Sort order for displaying sections
    var sortOrder: Int {
        switch self {
        case .appetizer: return 1
        case .soup: return 2
        case .entree: return 3
        case .seafood: return 4
        case .other: return 6
        case .dessert: return 5
        }
    }
}

// MARK: - Wine Category

enum WineCategory: String, Codable, CaseIterable, Identifiable {
    case sparkling = "sparkling"
    case white = "white"
    case rose = "rose"
    case red = "red"
    case sweetWine = "sweet"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sparkling: return "Sparkling"
        case .white: return "White Wines"
        case .rose: return "Rosé"
        case .red: return "Red Wines"
        case .sweetWine: return "Sweet Wines"
        case .other: return "Other Wines"
        }
    }

    var icon: String {
        switch self {
        case .sparkling: return "bubbles.and.sparkles"
        case .white: return "wineglass"
        case .rose: return "wineglass.fill"
        case .red: return "wineglass.fill"
        case .sweetWine: return "drop.fill"
        case .other: return "wineglass"
        }
    }

    /// Sort order for displaying sections
    var sortOrder: Int {
        switch self {
        case .sparkling: return 0
        case .white: return 1
        case .rose: return 2
        case .red: return 3
        case .sweetWine: return 4
        case .other: return 6
        }
    }
}

// MARK: - Food Tag

struct FoodTag: Codable, Identifiable, Hashable {
    let code: String
    let label: String

    var id: String { code }

    // Food-specific reason codes
    static let communityFavorite = FoodTag(code: "COMMUNITY_FAVORITE", label: "Community Favorite")
    static let chefSignature = FoodTag(code: "CHEF_SIGNATURE", label: "Chef's Signature")
    static let crowdPleaser = FoodTag(code: "CROWD_PLEASER", label: "Crowd Pleaser")
    static let greatValue = FoodTag(code: "GREAT_VALUE", label: "Great Value")
}

// MARK: - Wine Tag

struct WineTag: Codable, Identifiable, Hashable {
    let code: String
    let label: String

    var id: String { code }

    // Wine-specific reason codes
    static let highCpValue = WineTag(code: "HIGH_CP_VALUE", label: "High QPR")
    static let risingStar = WineTag(code: "RISING_STAR", label: "Rising Star")
    static let fineAndRare = WineTag(code: "FINE_AND_RARE", label: "Fine & Rare")
    static let awardWinning = WineTag(code: "AWARD_WINNING", label: "Award Winning")
    static let famous = WineTag(code: "FAMOUS", label: "Famous")
    static let highScore = WineTag(code: "HIGH_SCORE", label: "High Score")
}

// MARK: - Recommendation Response DTOs

struct RecommendationResponse: Codable {
    let food: [FoodItemResponse]
    let wine: [WineItemResponse]
}

// MARK: - Food Item Response

struct FoodItemResponse: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String
    let tags: [FoodTagResponse]
    let photoUrl: String?
    let price: Double?
    let category: String?
    let spice: Int?           // 1-5 scale
    let richness: Int?        // 1-5 scale
    let ingredients: [String]? // Maps to FoodIngredient raw values
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title = "name"     // Server sends "name", we use "title"
        case description
        case tags
        case photoUrl = "photo_url"
        case price
        case category
        case spice
        case richness
        case ingredients
        case createdAt = "created_at"
    }

    // Memberwise initializer for testing/preview
    init(
        id: Int,
        title: String,
        description: String,
        tags: [FoodTagResponse] = [],
        photoUrl: String? = nil,
        price: Double? = nil,
        category: String? = nil,
        spice: Int? = nil,
        richness: Int? = nil,
        ingredients: [String]? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = tags
        self.photoUrl = photoUrl
        self.price = price
        self.category = category
        self.spice = spice
        self.richness = richness
        self.ingredients = ingredients
        self.createdAt = createdAt
    }

    // Custom decoder to handle missing tags
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        tags = (try? container.decode([FoodTagResponse].self, forKey: .tags)) ?? []
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        price = try container.decodeIfPresent(Double.self, forKey: .price)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        spice = try container.decodeIfPresent(Int.self, forKey: .spice)
        richness = try container.decodeIfPresent(Int.self, forKey: .richness)
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var foodTags: [FoodTag] {
        tags.map { FoodTag(code: $0.code, label: $0.label) }
    }

    var foodCategory: FoodCategory {
        guard let category = category else { return .other }
        return FoodCategory(rawValue: category) ?? .other
    }

    var foodIngredients: [FoodIngredient] {
        (ingredients ?? []).compactMap { FoodIngredient(rawValue: $0) }
    }

    // Formatted price string for UI display
    var priceFormatted: String? {
        guard let price = price else { return nil }
        return String(format: "$%.0f", price)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FoodItemResponse, rhs: FoodItemResponse) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Wine Item Response

struct WineItemResponse: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String
    let tags: [WineTagResponse]
    let grapeVarietal: String?
    let region: String?
    let country: String?
    let priceGlass: Double?
    let priceBottle: Double?
    let category: String?
    let flavor: String?        // Maps to WineFlavor raw value
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title = "name"     // Server sends "name", we use "title"
        case description
        case tags
        case grapeVarietal = "grape_varietal"
        case region
        case country
        case priceGlass = "price_glass"
        case priceBottle = "price_bottle"
        case category
        case flavor
        case createdAt = "created_at"
    }

    // Memberwise initializer for testing/preview
    init(
        id: Int,
        title: String,
        description: String,
        tags: [WineTagResponse] = [],
        grapeVarietal: String? = nil,
        region: String? = nil,
        country: String? = nil,
        priceGlass: Double? = nil,
        priceBottle: Double? = nil,
        category: String? = nil,
        flavor: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = tags
        self.grapeVarietal = grapeVarietal
        self.region = region
        self.country = country
        self.priceGlass = priceGlass
        self.priceBottle = priceBottle
        self.category = category
        self.flavor = flavor
        self.createdAt = createdAt
    }

    // Custom decoder to handle missing tags
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        tags = (try? container.decode([WineTagResponse].self, forKey: .tags)) ?? []
        grapeVarietal = try container.decodeIfPresent(String.self, forKey: .grapeVarietal)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        priceGlass = try container.decodeIfPresent(Double.self, forKey: .priceGlass)
        priceBottle = try container.decodeIfPresent(Double.self, forKey: .priceBottle)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        flavor = try container.decodeIfPresent(String.self, forKey: .flavor)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var wineTags: [WineTag] {
        tags.map { WineTag(code: $0.code, label: $0.label) }
    }

    var wineCategory: WineCategory {
        guard let category = category else { return .other }
        return WineCategory(rawValue: category) ?? .other
    }

    var wineFlavor: WineFlavor? {
        guard let flavor = flavor else { return nil }
        return WineFlavor(rawValue: flavor)
    }

    var wineOrigin: String? {
        let parts = [region, country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var hasWinePricing: Bool {
        priceGlass != nil || priceBottle != nil
    }

    // Formatted price strings for UI display
    var priceGlassFormatted: String? {
        guard let price = priceGlass else { return nil }
        return String(format: "$%.0f", price)
    }

    var priceBottleFormatted: String? {
        guard let price = priceBottle else { return nil }
        return String(format: "$%.0f", price)
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WineItemResponse, rhs: WineItemResponse) -> Bool {
        lhs.id == rhs.id
    }
}

struct FoodTagResponse: Codable, Hashable {
    let code: String
    let label: String
}

struct WineTagResponse: Codable, Hashable {
    let code: String
    let label: String
}
