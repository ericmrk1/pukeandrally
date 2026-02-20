import SpriteKit
import UIKit

// MARK: - Level Definitions
struct LevelConfig {
    let name: String
    let subtitle: String
    let skyTop: UIColor
    let skyBottom: UIColor
    let groundColor: UIColor
    let accentColor: UIColor
    let obstacleTypes: [ObstacleType]
    let particleColor: UIColor
    let aidStations: Int
    let distanceKm: Int
    let bgElements: [BgElementType]
    let ambientDesc: String
}

enum ObstacleType: String, CaseIterable {
    case rock, log, mudPuddle, cactus, boulder, crater, tree,
         vine, waterCross, fog, sandDune, building, barrel
}

enum BgElementType {
    case mountain, tree, cactus, building, redwood, canyon, swamp, crater, sand
}

enum CollectibleType: String {
    case water = "💧"
    case gel = "⚡"
    case salt = "🧂"
    case gummyBear = "🐻"
    case banana = "🍌"
    case cola = "🥤"
    case pretzel = "🥨"
    case medkit = "🩺"
}

enum PickupType {
    case water, gel, salt, gummyBear, banana, cola, pretzel, medkit
    case bathroom, trashCan
}

let ALL_LEVELS: [LevelConfig] = [
    LevelConfig(
        name: "MOUNTAIN ULTRA", subtitle: "Colorado Rockies 100M",
        skyTop: UIColor(red:0.1,green:0.2,blue:0.5,alpha:1),
        skyBottom: UIColor(red:0.5,green:0.7,blue:0.9,alpha:1),
        groundColor: UIColor(red:0.45,green:0.35,blue:0.25,alpha:1),
        accentColor: UIColor(red:0.7,green:0.8,blue:0.6,alpha:1),
        obstacleTypes: [.rock,.boulder,.log,.mudPuddle],
        particleColor: UIColor.white,
        aidStations: 5, distanceKm: 160,
        bgElements: [.mountain,.tree],
        ambientDesc: "🏔 Thin air, rocky trails, alpine meadows"
    ),
    LevelConfig(
        name: "DESERT DASH", subtitle: "Badwater 135",
        skyTop: UIColor(red:0.9,green:0.5,blue:0.1,alpha:1),
        skyBottom: UIColor(red:1.0,green:0.85,blue:0.5,alpha:1),
        groundColor: UIColor(red:0.85,green:0.72,blue:0.45,alpha:1),
        accentColor: UIColor(red:0.95,green:0.65,blue:0.2,alpha:1),
        obstacleTypes: [.cactus,.sandDune,.rock,.boulder],
        particleColor: UIColor(red:1,green:0.9,blue:0.6,alpha:0.5),
        aidStations: 5, distanceKm: 217,
        bgElements: [.cactus,.sand],
        ambientDesc: "🌵 Scorching heat, sand dunes, mirages"
    ),
    LevelConfig(
        name: "CITY STREETS", subtitle: "Urban Ultra Marathon",
        skyTop: UIColor(red:0.4,green:0.4,blue:0.5,alpha:1),
        skyBottom: UIColor(red:0.6,green:0.65,blue:0.7,alpha:1),
        groundColor: UIColor(red:0.4,green:0.4,blue:0.45,alpha:1),
        accentColor: UIColor(red:0.9,green:0.9,blue:0.2,alpha:1),
        obstacleTypes: [.building,.barrel,.mudPuddle],
        particleColor: UIColor.yellow,
        aidStations: 4, distanceKm: 80,
        bgElements: [.building],
        ambientDesc: "🏙 Concrete jungle, traffic, city noise"
    ),
    LevelConfig(
        name: "MARS MISSION", subtitle: "Red Planet 42K",
        skyTop: UIColor(red:0.6,green:0.2,blue:0.1,alpha:1),
        skyBottom: UIColor(red:0.8,green:0.4,blue:0.2,alpha:1),
        groundColor: UIColor(red:0.7,green:0.3,blue:0.15,alpha:1),
        accentColor: UIColor(red:1.0,green:0.5,blue:0.3,alpha:1),
        obstacleTypes: [.crater,.boulder,.rock],
        particleColor: UIColor(red:1,green:0.5,blue:0.3,alpha:0.6),
        aidStations: 4, distanceKm: 42,
        bgElements: [.crater],
        ambientDesc: "🔴 Low gravity, craters, alien terrain"
    ),
    LevelConfig(
        name: "JUNGLE RUN", subtitle: "Amazon 50K",
        skyTop: UIColor(red:0.05,green:0.3,blue:0.05,alpha:1),
        skyBottom: UIColor(red:0.2,green:0.6,blue:0.2,alpha:1),
        groundColor: UIColor(red:0.2,green:0.45,blue:0.1,alpha:1),
        accentColor: UIColor(red:0.3,green:0.9,blue:0.3,alpha:1),
        obstacleTypes: [.vine,.tree,.mudPuddle,.waterCross],
        particleColor: UIColor(red:0.3,green:1,blue:0.3,alpha:0.4),
        aidStations: 4, distanceKm: 50,
        bgElements: [.tree,.swamp],
        ambientDesc: "🌿 Dense canopy, humidity, exotic wildlife"
    ),
    LevelConfig(
        name: "SWAMP STOMP", subtitle: "Everglades 100K",
        skyTop: UIColor(red:0.2,green:0.3,blue:0.15,alpha:1),
        skyBottom: UIColor(red:0.4,green:0.5,blue:0.3,alpha:1),
        groundColor: UIColor(red:0.25,green:0.35,blue:0.15,alpha:1),
        accentColor: UIColor(red:0.5,green:0.8,blue:0.3,alpha:1),
        obstacleTypes: [.mudPuddle,.log,.waterCross,.vine],
        particleColor: UIColor(red:0.5,green:0.8,blue:0.2,alpha:0.5),
        aidStations: 4, distanceKm: 100,
        bgElements: [.swamp,.tree],
        ambientDesc: "🐊 Murky waters, Spanish moss, alligators"
    ),
    LevelConfig(
        name: "REDWOOD TRAIL", subtitle: "California Redwoods 50M",
        skyTop: UIColor(red:0.2,green:0.15,blue:0.1,alpha:1),
        skyBottom: UIColor(red:0.5,green:0.65,blue:0.4,alpha:1),
        groundColor: UIColor(red:0.35,green:0.25,blue:0.15,alpha:1),
        accentColor: UIColor(red:0.6,green:0.85,blue:0.5,alpha:1),
        obstacleTypes: [.log,.root,.rock,.mudPuddle],
        particleColor: UIColor(red:0.7,green:0.5,blue:0.3,alpha:0.4),
        aidStations: 5, distanceKm: 80,
        bgElements: [.redwood,.tree],
        ambientDesc: "🌲 Ancient giants, fern carpet, filtered light"
    ),
    LevelConfig(
        name: "CANYON LANDS", subtitle: "Grand Canyon Rim-to-Rim",
        skyTop: UIColor(red:0.1,green:0.3,blue:0.7,alpha:1),
        skyBottom: UIColor(red:0.6,green:0.4,blue:0.2,alpha:1),
        groundColor: UIColor(red:0.65,green:0.35,blue:0.15,alpha:1),
        accentColor: UIColor(red:0.9,green:0.5,blue:0.2,alpha:1),
        obstacleTypes: [.rock,.boulder,.sandDune],
        particleColor: UIColor(red:0.9,green:0.6,blue:0.3,alpha:0.5),
        aidStations: 5, distanceKm: 40,
        bgElements: [.canyon],
        ambientDesc: "🏜 Dramatic drops, switchbacks, ancient rock"
    ),
]

// Physics categories
struct PhysicsCategory {
    static let none:    UInt32 = 0
    static let player:  UInt32 = 0b0001
    static let ground:  UInt32 = 0b0010
    static let obstacle:UInt32 = 0b0100
    static let pickup:  UInt32 = 0b1000
}

struct GameConstants {
    static let playerRunSpeed: CGFloat = 280
    static let playerSprintSpeed: CGFloat = 460
    static let playerWalkSpeed: CGFloat = 110
    static let jumpImpulse: CGFloat = 520
    static let energyMax: CGFloat = 100
    static let energyDrainRun: CGFloat = 3.5      // per second
    static let energyDrainSprint: CGFloat = 9.0
    static let energyRestoreWalk: CGFloat = 4.0
    static let energyFromWater: CGFloat = 20
    static let energyFromGel: CGFloat = 30
    static let energyFromSalt: CGFloat = 15
    static let energyFromGummy: CGFloat = 12
    static let energyFromBanana: CGFloat = 18
    static let energyFromCola: CGFloat = 25
    static let energyFromPretzel: CGFloat = 10
    static let energyFromMedkit: CGFloat = 40
    static let energyFromBathroom: CGFloat = 35
    static let energyFromTrash: CGFloat = 28
    static let bathroomTimePenalty: Double = 8.0
    static let trashTimePenalty: Double = 5.0
    static let pointsPerAidStation: Int = 500
    static let pointsPerCollectible: Int = 50
    static let pointsPerSecond: Double = 0.5       // bonus for speed
    static let groundHeight: CGFloat = 120
    static let playerSize = CGSize(width: 40, height: 60)
}
