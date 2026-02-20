# 🏃 Ultra Runner – iOS Game

## Quick Start

1. Open **Xcode 15+**
2. Create a new **iOS > Game** project  
   - Product Name: `UltraRunner`  
   - Interface: `UIKit`  
   - Life Cycle: `UIKit App Delegate`  
   - Game Technology: `SpriteKit`  
   - Language: `Swift`
3. Delete the default `GameScene.swift`, `GameScene.sks`, `Actions.sks`, and `GameViewController.swift`
4. Drag **all** `.swift` files from this folder into your Xcode project  
5. Replace `Info.plist` content with the one provided  
6. Replace `Assets.xcassets/Contents.json` with the one provided  
7. Build & Run on an iPad or iPhone (landscape mode)

---

## 🎮 Controls

| Action | Input |
|--------|-------|
| **Jump** over obstacle | Tap screen |
| **Sprint** | Hold screen > 0.25 sec |
| **Collect items** | Run into them |
| **Bathroom** 🚻 | Run into it (lose time, gain energy) |
| **Trash can** 🗑 | Run into it (lose time, gain energy) |

---

## 🌍 Levels (8 Total)

| # | Level | Terrain | Distance |
|---|-------|---------|----------|
| 1 | Mountain Ultra | Colorado Rockies | 160 km |
| 2 | Desert Dash | Badwater 135 | 217 km |
| 3 | City Streets | Urban Marathon | 80 km |
| 4 | Mars Mission | Red Planet | 42 km |
| 5 | Jungle Run | Amazon | 50 km |
| 6 | Swamp Stomp | Everglades | 100 km |
| 7 | Redwood Trail | California Redwoods | 80 km |
| 8 | Canyon Lands | Grand Canyon | 40 km |

---

## ⚡ Energy System

- **Running** → energy drains slowly  
- **Sprinting** → energy drains fast  
- **Walking** → energy restores  
- **Aid Station** → full restore  
- **Collectibles** → partial restore  

---

## 🏕 Aid Station Items

| Item | Energy | Points |
|------|--------|--------|
| 💧 Water | +20 | +50 |
| ⚡ Gel | +30 | +75 |
| 🧂 Salt | +15 | +50 |
| 🐻 Gummy Bears | +12 | +50 |
| 🍌 Banana | +18 | +50 |
| 🥤 Cola | +25 | +80 |
| 🥨 Pretzel | +10 | +50 |
| 🩺 Medkit | +40 | +100 |
| 🚻 Bathroom | +35 | -200 pts |
| 🗑 Trash Can | +28 | -150 pts |

---

## 📱 Requirements

- iOS 15.0+  
- Xcode 15+  
- Landscape orientation  

---

*Built with SpriteKit. No third-party dependencies.*
