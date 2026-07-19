# Fruit Merge — Project Recreation Guide

> **Purpose:** This is the long-form technical and design record for the current Godot project. It is written so that a future developer can rebuild the game from an empty Godot project without needing to reverse-engineer the existing scenes first.
>
> **Reading length:** roughly 20–30 printed pages, depending on page size, font, and code-block spacing.
>
> **Current engine:** Godot 4.7.1. The project is portrait-first and uses a 720 × 1280 logical viewport.

---

## Table of contents

1. [What this game is](#1-what-this-game-is)
2. [Player experience and core loop](#2-player-experience-and-core-loop)
3. [Technical baseline](#3-technical-baseline)
4. [Repository map](#4-repository-map)
5. [Godot project settings](#5-godot-project-settings)
6. [Startup and scene navigation](#6-startup-and-scene-navigation)
7. [Global services and responsibilities](#7-global-services-and-responsibilities)
8. [Game states and pause behavior](#8-game-states-and-pause-behavior)
9. [Events: the project’s communication layer](#9-events-the-projects-communication-layer)
10. [Fruit data and the merge order](#10-fruit-data-and-the-merge-order)
11. [Per-fruit scenes, art, and collision](#11-per-fruit-scenes-art-and-collision)
12. [Box, danger line, and game over](#12-box-danger-line-and-game-over)
13. [Spawner, aiming, preview, and animated guide](#13-spawner-aiming-preview-and-animated-guide)
14. [Merge service, scoring, combos, and rewards](#14-merge-service-scoring-combos-and-rewards)
15. [World layout, camera, and input coordinates](#15-world-layout-camera-and-input-coordinates)
16. [HUD and safe UI layout](#16-hud-and-safe-ui-layout)
17. [Home, loading, daily reward, and shop](#17-home-loading-daily-reward-and-shop)
18. [Pause, settings, game over, and no-ads UI](#18-pause-settings-game-over-and-no-ads-ui)
19. [Economy and item purchasing](#19-economy-and-item-purchasing)
20. [Power-up system and juice tuning](#20-power-up-system-and-juice-tuning)
21. [Audio, effects, and motion language](#21-audio-effects-and-motion-language)
22. [Save data and daily-reward rules](#22-save-data-and-daily-reward-rules)
23. [Ads and Google Play billing integration](#23-ads-and-google-play-billing-integration)
24. [Asset pipeline and visual design system](#24-asset-pipeline-and-visual-design-system)
25. [Rebuilding from scratch: exact order](#25-rebuilding-from-scratch-exact-order)
26. [Testing, debugging, and common failures](#26-testing-debugging-and-common-failures)
27. [Safe extension patterns](#27-safe-extension-patterns)
28. [Final recreation checklist](#28-final-recreation-checklist)

---

## 1. What this game is

**Fruit Merge** is a portrait mobile merge game inspired by the “drop two matching objects into a container to make the next object” format. The player moves a small fruit preview across the top of a transparent box, drops it, and lets 2D physics settle the pile. Two matching fruits merge into the next fruit in a fixed chain. The objective is to build the biggest fruit possible without allowing a settled fruit to remain over the danger line.

The game’s identity is deliberately cozy rather than frantic:

- warm kitchen/garden background;
- soft cream, peach, green, and brown UI palette;
- friendly fruit art with faces;
- elastic, short feedback rather than harsh effects;
- collectible pets, skins, tickets, daily rewards, and shop power-ups;
- a compact mobile HUD that leaves the drop zone usable.

The implementation separates **gameplay world nodes** from **screen-space UI**. Physics and fruit positions live in a `Node2D` world with a `Camera2D`. HUD, menus, and overlays live in a `CanvasLayer`, so they remain fixed to the phone screen.

---

## 2. Player experience and core loop

The intended player loop is:

1. Launch the app.
2. See a short loading screen with a random humorous tip.
3. If today’s daily reward is not claimed, see the daily-reward panel. Otherwise go straight to Home.
4. From Home, start a run or open the Shop, Settings, Achievements info, or No Ads panel.
5. In a run, aim the preview fruit by moving/touching across the container and release to drop it.
6. Match two equal fruits. The pair shrinks, a new fruit appears, score is awarded, particles and a merge burst play, and the combo system may increase the multiplier.
7. Use tickets to purchase power-ups. Use powers during a run to level a fruit, shake the pile, remove one smallest fruit, or reposition one fruit.
8. Create Pineapple, Dragonfruit, or Watermelon to earn 1, 2, or 3 tickets respectively.
9. If fruit lingers at the dashed danger line long enough, the run ends. Coins are awarded from the run score and the result card appears.
10. Restart or return Home. The high score, coins, tickets, purchases, and settings persist.

The key rule is simple: **matching fruits grow into the next fruit, but gravity and space management create the challenge.** Do not add direct “tap to merge” gameplay; the physical pile is central to the experience.

---

## 3. Technical baseline

| Area | Current decision | Why it matters |
| --- | --- | --- |
| Engine | Godot 4.7.1 | All scene/script syntax is Godot 4.x GDScript. |
| Game mode | 2D physics | Fruits are `RigidBody2D`; the container is a `StaticBody2D`. |
| Logical viewport | 720 × 1280 | All UI offsets are authored against this portrait canvas. |
| Desktop preview | 432 × 960 override | Emulates a modern 9:20 phone and exposes tall-screen anchor mistakes. |
| Stretch mode | `canvas_items`, aspect `expand` | Preserves the authored UI coordinate system. |
| Physics | 2D default gravity = 820 | Drives the fall weight and pile behavior. |
| Audio | Music and SFX buses | Music/sound settings alter buses rather than individual players. |
| Persistence | JSON at `user://savegame.json` | Easy to inspect/reset during development. |
| Architecture | Autoload services + event bus | Keeps scene scripts decoupled. |

The project intentionally avoids a third-party dependency for its core loop. Ads and Google Play billing are **not** fully integrated; they use an internal bridge interface described later.

---

## 4. Repository map

The canonical project layout is:

```text
Merge/
├─ Assets/
│  ├─ Fonts/                  # NERILLKID Trial.ttf is the active UI font
│  ├─ Fruits/                 # Fruit PNGs, one file per tier
│  ├─ Mascots/                # Optional mascot art
│  ├─ Menu/                   # Home dock, icons, buttons, currency art
│  ├─ Pets/                   # Shop/equipped pet art
│  ├─ PowerUps/               # LevelUP, ShakeIT, SuckUP, GrabEM, etc.
│  ├─ Shop/                   # Shop decoration/header art
│  └─ UI/                     # Background, container, panels, dock, ticket
├─ Audio/
│  └─ Music/                  # Gameplay, Menu, Shop, Achievements WAVs
├─ Autoloads/                 # Global runtime services
├─ Data/
│  ├─ Fruits/                 # FruitData `.tres` resources
│  ├─ Resources/              # Physics materials
│  ├─ ShopItems/              # ShopItemData `.tres` resources
│  └─ Themes/                 # Cozy Godot theme and design notes
├─ Docs/                      # This guide and future project documentation
├─ Scenes/
│  ├─ Core/                   # Main gameplay composition
│  ├─ Entities/               # Box, Spawner, Pet
│  ├─ Fruits/                 # Generic fruit + per-tier variants
│  ├─ UI/                     # Every player-facing screen/popup
│  └─ VFX/                    # Merge burst and drop-line helpers
├─ Scripts/
│  ├─ Core/                   # Main gameplay coordinator
│  ├─ Data/                   # Resource classes and enums
│  ├─ Entities/               # Scripts for world objects
│  ├─ States/                 # State placeholders/support classes
│  ├─ UI/                     # Scripts grouped by UI screen
│  └─ VFX/                    # VFX scripts and particle helpers
├─ MusicBus.tres              # Audio bus layout
└─ project.godot              # Main engine configuration
```

### Folder ownership rule

- **Assets** contains source art/audio files that Godot imports. Do not put logic there.
- **Data** contains editable balance/configuration resources. A designer should be able to tune fruit values, item prices, and power-up juice without changing logic.
- **Scenes** contains saved node graphs and layout.
- **Scripts** contains behavior only.
- **Autoloads** contains project-wide runtime state/services only.

Keep resource paths case-consistent: use `res://Assets/...`, `res://Data/...`, `res://Scenes/...`, and `res://Scripts/...`. Windows can hide case problems; Android/Linux builds will not.

### Scene and script catalog

This is the complete high-level map of the current authored scenes. Per-fruit variant files are grouped because they share one required structure.

| Scene path | Script path | Role |
| --- | --- | --- |
| `Scenes/Core/main.tscn` | `Scripts/Core/main.gd` | Live gameplay composition, power-up execution, camera/world feedback. |
| `Scenes/Entities/Box/box.tscn` | `Scripts/Entities/Box/box.gd` | Physical walls/floor and danger line. |
| `Scenes/Entities/Spawner/spawner.tscn` | `Scripts/Entities/Spawner/spawner.gd` | Preview, aim input, animated guide, and fruit spawning. |
| `Scenes/Entities/Pet/pet.tscn` | `Scripts/Entities/Pet/pet.gd` | Optional equipped companion in the gameplay world. |
| `Scenes/Fruits/fruit.tscn` | `Scripts/Entities/Fruit/fruit.gd` | Generic/reference fruit composition. |
| `Scenes/Fruits/Variants/*.tscn` | `Scripts/Entities/Fruit/fruit.gd` | The fourteen playable tier-specific fruit scenes and manual collision shapes. |
| `Scenes/UI/MainMenu/main_menu.tscn` | `Scripts/UI/MainMenu/main_menu.gd` | Loading screen, random tips, daily/home routing. |
| `Scenes/UI/Home/home.tscn` | `Scripts/UI/Home/home.gd` | Main home screen, mascot, dock, currencies, navigation. |
| `Scenes/UI/HUD/hud.tscn` | `Scripts/UI/HUD/hud.gd` | In-game score/powers/next fruit/danger/combo/pause UI. |
| `Scenes/UI/DailyReward/daily_reward.tscn` | `Scripts/UI/DailyReward/daily_reward.gd` | Seven-day reward screen and claim state. |
| `Scenes/UI/Shop/shop.tscn` | `Scripts/UI/Shop/shop.gd` | Shop catalog, tabs, currencies, ad reward entry point. |
| `Scenes/UI/Pause/pause_menu.tscn` | `Scripts/UI/Pause/pause_menu.gd` | Pause overlay and nested settings opener. |
| `Scenes/UI/Settings/settings_menu.tscn` | `Scripts/UI/Settings/settings_menu.gd` | Persistent audio, preference, and about controls. |
| `Scenes/UI/GameOver/game_over.tscn` | `Scripts/UI/GameOver/game_over.gd` | End-of-run results and navigation. |
| `Scenes/UI/NoAds/no_ads_purchase.tscn` | `Scripts/UI/NoAds/no_ads_purchase.gd` | No-ads purchase presentation. |
| `Scenes/UI/Components/currency_pill.tscn` | `Scripts/UI/Components/currency_pill.gd` | Reusable currency display component. |
| `Scenes/UI/Components/score_pop.tscn` | `Scripts/UI/Components/score_pop.gd` | Reusable floating score text. |
| `Scenes/UI/Components/shop_item_button.tscn` | `Scripts/UI/Components/shop_item_button.gd` | Reusable pet/skin/power-up shop card. |
| `Scenes/VFX/merge_burst.tscn` | `Scripts/VFX/merge_burst.gd` | Merge ring/spark visual. |
| `Scenes/VFX/drop_line.tscn` | `Scripts/VFX/drop_line.gd` | Simple fading vertical guide helper. |

The files under `Scripts/States/` (`base_state`, `state_menu`, `state_playing`, `state_paused`, and `state_game_over`) are lightweight state-pattern scaffolding. The active game currently uses `GameManager`’s enum state machine instead; do not assume those state classes are wired into the runtime unless you intentionally migrate to that pattern.

---

## 5. Godot project settings

The important settings in `project.godot` are:

```ini
[application]
run/main_scene="res://Scenes/UI/MainMenu/main_menu.tscn"
boot_splash/show_image=false

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/size/window_width_override=432
window/size/window_height_override=960
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[physics]
2d/default_gravity=820.0
```

The 432 × 960 value changes only the desktop debug window. With `expand`, that
9:20 window exposes a 720 × 1600 logical canvas, matching how the 720-wide game
expands on a tall phone. Top HUD controls stay top-anchored, dock controls stay
bottom-anchored, central art uses vertical-center anchors, and scrollable panels
stretch between their top and bottom margins. Do not replace the 720 × 1280
authored viewport with a device's physical pixel resolution.

The autoload order is also important. Register these in **Project → Project Settings → Autoload**:

1. `EventBus`
2. `SaveManager`
3. `EconomyManager`
4. `GameManager`
5. `AudioManager`
6. `FruitDatabase`
7. `Bootstrap`
8. `AdManager`

All are enabled as global nodes. `Bootstrap` restores saved state at launch. `FruitDatabase` loads fruit resources/scenes. UI and gameplay scripts assume these names exist globally.

### Input

No custom input map is required for dropping. The Spawner reads mouse and touch events directly. The default `ui_cancel` action is used to close pause/settings/daily reward panels. On mobile, that maps to Android Back when exported appropriately.

---

## 6. Startup and scene navigation

### Startup route

`Scenes/UI/MainMenu/main_menu.tscn` is the real loading screen, even though its script class is a general menu loader. Its script:

1. picks one entry from `LOADING_TIPS`;
2. starts a threaded load of Home;
3. displays the loading bar for at least 1.35 seconds;
4. fades itself out;
5. checks `SaveManager.daily_reward_last_claim` against today’s system date;
6. opens Daily Reward if today is unclaimed, otherwise opens Home.

This prevents the daily reward from appearing repeatedly after it has been claimed. If the player closes Daily Reward without claiming, no date is saved, so it returns the next time the app starts.

### Navigation table

| From | Action | To | Owner |
| --- | --- | --- | --- |
| Loading | Finish | Daily Reward or Home | `main_menu.gd` |
| Daily Reward | Claim/continue/close | Home | `daily_reward.gd` |
| Home | Play | Main gameplay | `GameManager.start_new_run()` |
| Home | Shop | Shop | `home.gd` |
| Shop | Play | Main gameplay | `shop.gd` |
| Shop | Back/Home | Home | `shop.gd` |
| Gameplay | Pause → Home | Home | `pause_menu.gd` |
| Gameplay | Game over → Menu | Home | `game_over.gd` |
| Gameplay | Restart | fresh Main gameplay | `GameManager.start_new_run()` |

Always use `get_tree().change_scene_to_file("res://...")` for whole-screen transitions. Replacing a scene manually while leaving prior scene nodes alive is a common source of duplicate event connections and stale physics objects.

---

## 7. Global services and responsibilities

### `EventBus.gd`

The event bus contains signals only. It does not store game state. Use it to communicate from a world object to UI without making either side know the other’s node path.

Examples:

- Fruit emits a physical contact → `MergeService` merges → `EventBus.fruit_merged`.
- `GameManager.add_score()` updates the score → `EventBus.score_changed`.
- HUD presses a power button → `EventBus.powerup_requested`.
- Box settled-overflow detector changes state → `EventBus.danger_line_entered/exited`.

### `GameManager.gd`

Stores **run state**:

- current game state;
- current score and high score;
- highest fruit tier reached during the run;
- next spawn tier;
- combo count/timer;
- whether a target-based power is currently capturing input.
- separate Classic and Time Attack high scores;
- run-end reason and the short Time Attack input-lock/merge-resolution phase.

It owns `start_new_run()`, `change_state()`, and score calculation. It must not own scene UI details or direct fruit node paths.

### `FruitDatabase.gd`

Loads the ordered fruit resource chain and per-tier scene chain. It caches:

- `FruitData` by tier;
- packed scenes;
- collision half-width/bottom extent from each scene;
- visual texture and visual scale from each scene.

This cache lets the Spawner preview the correct art and clamp drops to the manual collision shape without instantiating fruit repeatedly during play.

### `EconomyManager.gd`

Owns coins, tickets, item ownership/equipping, and consumable power-up counts. Purchasing always goes through it. It emits events after balances/counts change.

### `PowerLoadoutManager.gd`

Owns the six supported power IDs, the saved three-type selection, and the active
run selection. Normal runs require exactly three distinct IDs. Mission runs replace
that selection with only the pinned lesson power and consume a temporary Mission
charge before asking EconomyManager for permanent inventory.

### `MissionManager.gd`

Loads seven `MissionDefinition` resources, tracks completion/unlocks, provides
deterministic spawn tiers, seeds authored starting fruit, updates objective and
tutorial events, grants mission rewards, and unlocks Classic after Level 1 and
Time Attack after Level 7.

### `RewardPresentationManager.gd`

Keeps short-lived coin/ticket presentation payloads alive across a scene change. It never grants or saves currency; `EconomyManager` remains authoritative. Daily Reward queues the earned currency here, then Home consumes the queue exactly once and animates the matching icon into its real wallet panel.

### `SaveManager.gd`

Writes one JSON save file. It serializes non-JSON Godot values such as `owned_items` using `var_to_str`, then restores them with `str_to_var`.

### `AudioManager.gd`

Owns two persistent music players for shuffled crossfades and a pool of eight SFX players. Bootstrap starts the four-track playlist once; scene/tab navigation never selects or restarts music. It creates a short procedural merge pop if a fruit has no authored merge sound.

### `Bootstrap.gd`

Restores saved data and settings at startup. In debug builds it calls `EconomyManager.set_debug_powerups(1)`, so every implemented power begins at ×1 for testing. This overwrites any previous debug-session inventory on each launch; remove or gate the grant before release.

### `AdManager.gd`

Contains a safe ads/billing façade, not a completed SDK integration. Its interface and release limitations are documented in [section 23](#23-ads-and-google-play-billing-integration).

---

## 8. Game states and pause behavior

`Enums.GameState` has five states:

```gdscript
MENU, PLAYING, PAUSED, GAME_OVER, SHOP
```

`GameManager.change_state()` is the single state transition function. It sets `SceneTree.paused` as follows:

| State | Tree paused? | Important side effect |
| --- | ---: | --- |
| MENU | No | Home/menu behavior is active. |
| PLAYING | No | Spawner and physics may run. |
| PAUSED | Yes | Freeze world; pause UI is process-always. |
| GAME_OVER | No | Save result, emit game-over event, show result. |
| SHOP | No | Shop scene is active. |

UI that must work while paused—Pause Menu, Settings Menu, No Ads Purchase—uses `PROCESS_MODE_ALWAYS`. The HUD itself lives in a CanvasLayer but does not automatically bypass pause; the child pause scene handles that explicitly.

When adding a new feature, decide whether it should run during pause. If yes, set its process mode deliberately. Do not accidentally keep gameplay timers running while the game is paused.

---

## 9. Events: the project’s communication layer

These are the important `EventBus` signals and normal producers/consumers:

| Signal | Produced by | Typical consumers |
| --- | --- | --- |
| `fruit_merged(tier, world_pos, score)` | MergeService | Main VFX, HUD combo text, Pet |
| `fruit_dropped(tier)` | Spawner | HUD next-fruit preview |
| `score_changed(score)` | GameManager | HUD |
| `high_score_changed(high_score)` | GameManager | HUD/Home |
| `coins_changed(coins)` | EconomyManager | HUD/Home/Shop |
| `tickets_changed(tickets)` | EconomyManager | HUD/Home/Shop |
| `game_over(score)` | GameManager | Main/GameOver/Pet |
| `danger_line_entered/exited` | Box | HUD/Pet |
| `shop_item_purchased(id)` | EconomyManager | Shop refresh |
| `item_equipped(id)` | EconomyManager | Shop/Pet on next run |
| `powerup_count_changed(id,count)` | EconomyManager | HUD/Shop |
| `powerup_requested(id)` | HUD | Main gameplay coordinator |
| `powerup_targeting_changed(active,message)` | Main | HUD hint/highlight |
| `state_changed(state)` | GameManager | Spawner/Box/Pet/etc. |

Rule of thumb: emit data, not nodes where possible. `fruit_merged` emits world position and tier rather than exposing a mutable fruit node to UI. This reduces use-after-free errors.

---

## 10. Fruit data and the merge order

The merge order is defined twice in the same order:

1. `Autoloads/FruitDatabase.gd` `FRUIT_PATHS` and `FRUIT_SCENE_PATHS`;
2. `Scripts/Data/enums.gd` `FruitTier` enum.

They must remain identical. The current order is:

| Tier | Enum | Fruit | Next |
| ---: | --- | --- | --- |
| 0 | `CHERRY` | Cherry | Berries |
| 1 | `BERRIES` | Berries | Strawberry |
| 2 | `STRAWBERRY` | Strawberry | Grape |
| 3 | `GRAPE` | Grape | Kiwi |
| 4 | `KIWI` | Kiwi | Lemon |
| 5 | `LEMON` | Lemon | Orange |
| 6 | `ORANGE` | Orange | Apple |
| 7 | `APPLE` | Apple | Peach |
| 8 | `PEACH` | Peach | Mango |
| 9 | `MANGO` | Mango | Coconut |
| 10 | `COCONUT` | Coconut | Pineapple |
| 11 | `PINEAPPLE` | Pineapple | Dragonfruit |
| 12 | `DRAGONFRUIT` | Dragonfruit | Watermelon |
| 13 | `WATERMELON` | Watermelon | none; final tier |

Each `Data/Fruits/*.tres` is a `FruitData` resource. Its relevant fields are:

- `tier`: integer/enum identity;
- `display_name`: UI/debug name;
- `sprite`: fallback art and UI icon source;
- `sprite_visual_width`: only used by the generic runtime-scaling fallback;
- `radius`: fallback collision/drop-spacing value;
- `score_value`: score awarded when two fruits of this tier merge;
- `next_tier`: target tier or `-1` for final fruit;
- `merge_sfx`: optional authored sound; empty uses procedural audio;
- `mass`: physical mass;
- `color`: final visual modulation.

When inserting a fruit into the middle, update **all** of the following in the same change:

1. `FruitTier` enum values;
2. each affected `next_tier` in `.tres` files;
3. `FRUIT_PATHS`;
4. `FRUIT_SCENE_PATHS`;
5. ticket reward tier constants if the final three shift;
6. FruitsDock art if it visibly depicts the order;
7. any user-facing text/achievement count.

---

## 11. Per-fruit scenes, art, and collision

Each live fruit uses an independent scene in:

```text
Scenes/Fruits/Variants/<fruit>.tscn
```

Every variant follows this structural contract:

```text
RigidBody2D (root, group: fruits, script: fruit.gd)
├─ Sprite2D              # must keep this exact name
├─ AnimatedSprite2D Face # must keep this exact name
├─ CollisionShape2D      # must keep this exact name
├─ WakeTimer             # must keep this exact name
└─ IdleTimer             # must keep this exact name
```

The root has `use_scene_visuals = true` and `use_scene_collision = true`. This is crucial: art scale and collision now come from each scene, not a runtime-generated circle. The player/developer can open a fruit scene and manually adjust its collision shape to match its silhouette.

### Collision tuning procedure

1. Open the variant scene, for example `Scenes/Fruits/Variants/mango.tscn`.
2. Select `CollisionShape2D`.
3. Use Circle, Capsule, or Rectangle based on the silhouette.
4. Move the shape if stems/leaves make the visual centre different from the physical centre.
5. Keep the shape inside the fruit’s main body; do not include transparent padding.
6. Save, then test in a crowded pile.

`FruitDatabase` instantiates each variant briefly at startup to read the collision width/bottom extent. Those values drive Spawner clamping and preview guide placement. This is why manually tuned scenes automatically improve both collision and safe drop spacing.

### `fruit.gd` behavior

The fruit script handles:

- collision contact tracking;
- merge checks after a brief spawn grace period;
- wake/sleep behavior;
- landing squash;
- procedural emotions if enabled;
- merge exit animation and safe collision disable;
- idle/sleepy face behavior.

`is_merging` is a lock. Never remove it: it prevents a fruit from participating in a second merge after the first merge started.

---

## 12. Box, danger line, and game over

`Scenes/Entities/Box/box.tscn` is a `StaticBody2D` with three physical shapes:

- left wall;
- right wall;
- floor.

The box script draws its dashed limit at `danger_line_y` and polls active fruit during physics updates. It uses the scene-owned collision top and bottom extents cached by `FruitDatabase`, so offset capsule, circle, and rectangle shapes are measured correctly without a separate generic trigger shape.

### Danger sequence

1. A fruit is marked as having entered only after its collision bottom passes the danger line inside the container width.
2. Crossing fruit, grabbed/frozen fruit, merging fruit, and fast-moving fruit do not accumulate danger.
3. Once an entered fruit's collision top remains above the line while sleeping or moving slowly, its per-fruit dwell starts accumulating.
4. At `danger_warning_delay` (0.5 seconds in the box scene), Box sets the highest fruit's emotion to worried and emits `danger_line_entered`; the HUD/Pet then show the warning state.
5. At `danger_settle_time` (2.4 seconds), Box requests `GameManager.GAME_OVER`.
6. If the pile drops, the dwell recovers faster than it accumulates. Once below the warning threshold, `danger_line_exited` restores normal HUD/Pet state.

This stateful check is important: a newly dropped fruit normally crosses the dashed line on its way to the bottom, but that transit must never flash the warning tint. Classic, Missions, and Time Attack all retain this overflow rule.

### Important layout relationship

The visual `ContainerArt` and physical `BoxContainer/Box` are authored together under `Main/WorldOrigin/ContainerRig`. Open `Scenes/Core/main.tscn` and move `ContainerRig.position` to reposition the complete container without desynchronizing its artwork, floor, walls, or danger line. The shipped rig has a local `y = 50` downward offset. Do not try to position the gameplay container from `hud.tscn`: HUD is a CanvasLayer-only reusable UI scene and intentionally has no world physics.

The Box scene is an authored child instance, so it appears in Main's scene tree. Expand `WorldOrigin/ContainerRig/BoxContainer/Box` to locate it; open `box.tscn` to edit the three collision shapes, or enable editable children on the instance when inspecting them in Main.

`WorldOrigin` exists only to make the Main editor composition intuitive. A fixed-screen CanvasLayer HUD uses screen coordinates from `(0, 0)` to `(720, 1280)`, while the original gameplay camera viewed world coordinates from `(-360, -1280)` to `(360, 0)`. That made the correctly positioned container look one screen above the HUD in the 2D editor. `WorldOrigin.position = Vector2(360, 1280)` translates the camera and authored world together so its purple viewport rectangle overlaps the HUD in the editor. Because camera and world receive the same translation, the running game looks and behaves exactly the same.

---

## 13. Spawner, aiming, preview, and animated guide

`Spawner` has four responsibilities:

1. Choose the current and next fruit tiers.
2. Show a preview at the pointer X position.
3. Draw an animated dashed vertical landing guide using the current fruit's UI accent color.
4. Spawn a frozen fruit on release, then unfreeze it on the next physics frame.

Each `FruitData` resource supplies an opaque `guide_color` chosen to match its artwork. The guide draws a dark outline, translucent colored glow, and lighter core from that accent. Keep this separate from `FruitData.color`: `color` modulates the actual sprite, while `guide_color` changes only the aiming UI.

Spawner exposes the complete guide style under the `Drop guide` Inspector category: `guide_use_fruit_color`, `guide_override_color`, dash length, gap length, scroll speed, shadow/glow/core widths and opacities, plus shadow darkening and core lightening. The shipped thin preset is 4.5 px shadow, 3 px glow, and 1.5 px core. Adjust the scene values instead of editing `_draw()` when tuning presentation.

Only the first four tiers can spawn directly:

```gdscript
CHERRY, BERRIES, STRAWBERRY, GRAPE
```

This prevents the player from receiving large fruits for free. Larger fruit must come from merges or powers.

### Drop logic

- Mouse/touch press starts aiming.
- Movement shifts the preview along X only.
- Release drops if the movement distance is under the game’s intended click threshold.
- X is clamped with the current fruit’s cached collision radius, keeping it inside the physical walls.
- The fruit is frozen when created, positioned, then released after `physics_frame` so it never spawns partially through a wall.
- A cooldown hides the preview briefly to stop accidental rapid drops.

### Animated dashed guide

The line is not a texture. `Spawner._draw_animated_guide()` draws line segments using a phase that advances every frame. It raycasts downward from below the preview to the first physics hit, so it points to the real floor or pile rather than a guessed Y coordinate.

Hide the preview and guide whenever `GameManager.is_powerup_targeting` is true. This avoids targeting powers and drops fighting for input.

---

## 14. Merge service, scoring, combos, and rewards

`Autoloads/merge_service.gd` is the authoritative merge gate. It validates before doing anything:

- both references are still valid;
- both fruits are still in the scene tree;
- game state is Playing;
- neither fruit is already merging;
- both have data;
- tiers match;
- the source fruit has a next tier.

After a brief 0.075-second convergence, it performs all validity checks again. This second check is intentional. It fixes the class of error where a coroutine tries to access a fruit that was freed between frames while keeping the merge response immediate.

### Successful merge flow

1. Mark both fruits `is_merging = true`.
2. Set their emotion to excited.
3. Pull both fruit to the midpoint over 0.075 seconds.
4. Calculate the midpoint and inherited upward velocity.
5. Ask `GameManager.add_score()` for the combo-adjusted score.
6. Emit `fruit_merged(source_tier, midpoint, score_gained)`.
7. Play merge audio.
8. Start exit animations on source fruits.
9. Spawn one instance of the next fruit at the midpoint.

Source fruit complete their shrink/fade in 0.10 seconds. `FruitFactory` gives the
replacement fruit only a 0.035-second contact lock so chain reactions can continue
quickly; normally dropped fruit use a 0.10-second lock to avoid spawn-frame double
contacts. Keep the merge lock and second validity check even when tuning timings.

### Score formula

The base points are the `score_value` of the **source** FruitData. `GameManager` uses a 0.85-second combo window and a 1.5 multiplier growth factor:

```text
first merge:  base × 1.0
second merge: base × 1.5
third merge:  base × 2.25
fourth merge: base × 3.375
```

The HUD calls out `JUICY COMBO!`, `SWEET STREAK!`, `FRUIT FRENZY!`, or `MEGA MERGE!` based on combo level.

### High-tier ticket rewards

Creating these result tiers awards tickets once per merge:

| Created fruit | Ticket reward |
| --- | ---: |
| Pineapple | 1 |
| Dragonfruit | 2 |
| Watermelon | 3 |

The `fruit_merged` event reports the old tier, so Main checks `tier + 1` when determining the created fruit. Update this if changing the merge chain.

---

## 15. World layout, camera, and input coordinates

`Scenes/Core/main.tscn` composes the active run:

```text
Main (Node2D, main.gd)
├─ WorldOrigin (Node2D at 360,1280; aligns world and HUD in the editor)
│  ├─ Background (Sprite2D; currently hidden)
│  ├─ ContainerRig (Node2D; move this to reposition the whole container)
│  │  ├─ ContainerArt (Sprite2D)
│  │  └─ BoxContainer (Node2D)
│  │     └─ Box (authored scene instance with walls, floor, and danger line)
│  ├─ Camera2D
│  ├─ SpawnerContainer (Node2D → Spawner instance)
│  └─ PetContainer (Node2D → optional Pet instance)
├─ FruitContainer
└─ Interface (CanvasLayer)
   ├─ HUD
   └─ GameOverPanel
```

The camera keeps a local position of `(0, -640)` inside `WorldOrigin`. Its global editor position is therefore `(360, 640)`, aligning the 720×1280 Camera2D rectangle with the HUD canvas. This makes the world’s physical floor land low in the phone viewport while keeping room for the top HUD and bottom FruitDock. UI should not be placed in world coordinates unless it deliberately belongs to a fruit/physics effect.

### Coordinate conversion

Target powers must convert screen-space touch/mouse coordinates into world space:

```gdscript
world_position = get_viewport().get_canvas_transform().affine_inverse() * screen_position
```

Do not use raw screen coordinates for `intersect_point()`. Doing so produces a visible offset whenever the camera moves or has a non-zero position.

### Mouse-filter rule

HUD overlays that are visual only must use `MOUSE_FILTER_IGNORE`. Interactive buttons consume clicks normally. A decorative panel with `STOP`/`PASS` can silently block the Spawner, making the player unable to drop fruit under it.

---

## 16. HUD and safe UI layout

`Scenes/UI/HUD/hud.tscn` is a full-rect `Control` inside Main’s `CanvasLayer`. It contains:

- compact top score bar;
- pause button;
- coin and ticket pills;
- up to three loadout-filtered power buttons below the header;
- next fruit panel on the opposite side;
- danger overlay/warning;
- combo banner and score pop container;
- FruitDock art at the bottom;
- ticket reward banner;
- Pause Menu instance.

### Layout intent

| Screen zone | Intended content | Must not cover |
| --- | --- | --- |
| Top 8–106 px | pause, score, currencies | none; dedicated HUD strip |
| 112–206 px | powers left, next fruit right | top edge of box / drop preview |
| ~215–1050 px | actual container and fruit playfield | all interactive gameplay |
| bottom ~117 px | FruitDock art | physical floor / pile |

The FruitDock image already includes the merge-order fruit artwork. HUD must **not** dynamically add another row of fruit icons over it. The old `FruitGuide` runtime system was removed specifically to avoid duplicated art and null-node errors.

`hud.gd` listens to EventBus rather than polling gameplay objects. It updates score/currencies/next fruit, launches combo animation, shows power counts, opens Pause, and displays high-tier ticket reward text.

Mission runs add two runtime panels: a compact objective/progress card and a
larger dismissible instruction card with the relevant fruit icon. Level 1 hides
the power tray; later lessons show only their pinned power. Classic and Time
Attack show exactly the three types selected in Run Setup.

---

## 17. Home, loading, daily reward, and shop

### Loading screen

Files:

- Scene: `Scenes/UI/MainMenu/main_menu.tscn`
- Script: `Scripts/UI/MainMenu/main_menu.gd`

It is intentionally a loading scene, not the player’s Home screen. The logo art should be part of the scene art; do not restore an old text-only brand label.

### Home

Files:

- Scene: `Scenes/UI/Home/home.tscn`
- Script: `Scripts/UI/Home/home.gd`

Home shows the mascot, best score, currencies, Play, Shop, Achievements, Settings, No Ads, and the scene-authored `RewardsButton`. Pressing `RewardsButton` uses `SceneRouter.go_daily_reward()` so the seven-day panel can be reviewed even after the automatic startup gate has been completed. The bottom dock uses MenuDock art and is the only primary navigation system. Avoid duplicate floating Play/Settings controls elsewhere on the screen.

Play on Home or Shop opens `Scenes/UI/RunSetup/run_setup.tscn`. New profiles see Mission 1 first.
Returning players see three mode cards; locked cards explain progression. Missions
open the seven-level map and lesson briefing. Classic/Time Attack open a two-column,
touch-scrollable six-power picker and enable Play only at exactly three selections.
Normal retry preserves the active three types; mission retry rebuilds the scenario
and its temporary charge through `MissionManager`.

The dock's central peach `PlayButton` uses the reusable `floating_button_animator.gd` on both Home and Shop. Its looping sine tween rises 8 pixels with a slight counter-clockwise tilt and scale-up, dips softly with the opposite tilt, then restores the exact authored position, rotation, and scale before repeating. Start it only after mobile safe-area offsets are applied. The animator accepts height and duration parameters and remains still when reduced motion is active.

Achievements is currently an informative overlay, not a full achievement-tracking system.

### Daily reward

Files:

- Scene: `Scenes/UI/DailyReward/daily_reward.tscn`
- Script: `Scripts/UI/DailyReward/daily_reward.gd`

The seven-day sequence is presently:

| Day | Reward |
| ---: | --- |
| 1 | 25 coins |
| 2 | 35 coins |
| 3 | 1 ticket |
| 4 | 60 coins |
| 5 | 2 tickets |
| 6 | 100 coins |
| 7 | 3 tickets |

The cards are generated dynamically **after one process frame** because the GridContainer needs its final size before calculations. The grid is clipped and the day-seven slot is explicitly full-rect to prevent reward cards leaking outside the panel. Each generated card is wrapped in a small `MarginContainer` safe area before its rounded panel is added. That inset keeps the anti-aliased lower corners and soft shadow inside the clipped grid instead of cutting them into bright wedges at the panel edge.

Claimed days keep displaying their original currency icon and amount. Their subdued card surface is the claimed-state indicator; do not add checkmark or `COLLECTED` labels, which make the compact cards visually noisy.

To tune this presentation later, edit `_card_style()` and the four `CARD_INSET_*` constants in `Scripts/UI/DailyReward/daily_reward.gd`. The shared style currently uses a 2 px, 12%-opacity shadow with a 1 px downward offset. Edit the authored `RewardsGrid` and `DaySevenSlot` bounds in `Scenes/UI/DailyReward/daily_reward.tscn` for layout changes; do not place a full-size shadowed card directly against either clipped boundary.

Claiming queues the earned icon with `RewardPresentationManager`, grants and saves the real balance, then automatically returns Home after the claim-button pop. Home initially displays the pre-claim number, holds only the reward texture at screen center, flies it into the authored coin or ticket icon, updates the wallet number on impact, bounces the destination panel, and triggers reward haptics. No duplicate `+amount` label travels with the artwork. Reduced-motion mode skips the travel while still updating the correct destination. Never hard-code wallet coordinates; Home reads the current global rectangle of its scene-authored target icon after safe-area layout.

### Shop

Files:

- Scene: `Scenes/UI/Shop/shop.tscn`
- Script: `Scripts/UI/Shop/shop.gd`
- Item card: `Scenes/UI/Components/shop_item_button.tscn`

Shop loads the `ShopCatalog` resource, filters entries into skins/pets/power-ups, and creates one reusable card per item. To add a shop item, create its `.tres`, register it in the catalog, and ensure the icon/resource path is valid.

The Shop dock keeps the authored scene names `HomeButton`, `AchievementsButton`, `PlayButton`, `ShopButton`, and `SettingsButton`; `shop.gd` and the project validator use those exact contracts. Do not introduce alternate `*NavButton` names in only the script. The peach `PlayButton` uses the same shared float animator as Home.

The portrait catalog is a clipped three-column grid. Each card has a 210 x 320 minimum with a
compact local price style; do not reuse the normal `GreenPanel` padding inside the
card because its large content margins make rows overlap. The name row is reserved
above the icon, the optional stacked power-up count stays over the icon, and both
the card root and catalog panel clip children. The old owned badge and its status
label were removed; an owned cosmetic uses the existing action label to show
`SELECT` or `ACTIVE` instead. Pet descriptions are hidden and their icons expand
into the reclaimed space; descriptions remain available on skins and power-ups.
Those descriptions reserve a two-line 50 px row and use 16 px NERILLKID text with
a light warm outline, while non-pet artwork uses a 150 px row. The catalog remains
wheel-, drag-, and touch-scrollable, but `ShopScroll.vertical_scroll_mode` is
`SCROLL_MODE_SHOW_NEVER` so no scrollbar covers the card edge.
`ShopScroll.scroll_deadzone` is 8 px. The grid and each card keep
`MOUSE_FILTER_PASS`, while decorative card labels and textures use
`MOUSE_FILTER_IGNORE`; this preserves card taps but lets a mobile drag continue up
to the parent ScrollContainer.
The action panel uses four explicit states: leaf green for a purchasable item,
coral when currency is insufficient, gold for an owned selectable cosmetic, and
teal for the active cosmetic. Free filtered cards immediately before repopulating so old/new categories
cannot share a layout frame.

Shop card and button shadows are intentionally shallow: 2–4 px with low opacity,
not the old 7–9 px floating blocks. Tabs use `ShopTabButton`: warm peach is idle,
sunny orange is hover/focus, and vibrant leaf green is selected. Tooltips use the
theme's cream `TooltipPanel` with coral border and dark-brown `TooltipLabel`; do
not rely on Godot's unstyled default tooltip. Card tooltip copy is action-oriented
(`Unlock`, `Need`, `Tap to select`, or `active`) and never restores pet descriptions.

---

## 18. Pause, settings, game over, and no-ads UI

### Pause Menu

`pause_menu.tscn` appears inside HUD. It can continue, restart, return Home, or open nested settings. `open()` changes the state to Paused. `close()` returns to Playing. It must stay process-always.

### Settings

`settings_menu.tscn` persists:

- continuous music volume from 0–100%;
- continuous sound-effects volume from 0–100%;
- vibration preference.

Both sliders apply immediately through `AudioManager` and save `music_volume` or
`sfx_volume`; a value of zero is mute. The three audio/haptic rows are 62 px tall
with 12 px container separation so labels and sliders do not crowd each other.
Theme, Game Feel, and the Language selector were removed from this panel. Do not
re-add placeholder options without implementing and validating the complete
feature first. Existing locale data remains an internal translation default and
is not exposed by Settings.

Save migration version 7 erases the retired theme/feedback/audio-restore keys and
normalizes haptic strength, screen shake, and reduced motion to the standard
baseline. This prevents an old Minimal/Off preset from remaining invisible and
unrecoverable after its selector is removed. It does not change saved volume,
locale, or the independent vibration-enabled value.

Save migration version 8 separates the old daily goal payload from the new guided
campaign. Legacy `mission_data` becomes `daily_mission_data`; campaign
`mission_data` receives all seven completed for existing profiles. It also adds
`time_attack_high_score` and a valid default `settings.power_loadout`. New saves
remain un-onboarded at Level 1.

### Game Over

Game Over is instantiated in Main’s CanvasLayer. `GameManager` emits `game_over`; the panel displays the score, high score, and the coin amount calculated as `int(score * 0.1)`. The actual award happens once in `SaveManager.save_run_result()` when GameManager enters GAME_OVER.

### No Ads Purchase

`no_ads_purchase.tscn` provides the user experience for a permanent ad-free unlock. Its button calls `AdManager.request_no_ads_purchase()`. It does not itself process payments; that must happen in the platform bridge.

---

## 19. Economy and item purchasing

There are two currencies:

| Currency | Icon | Main use | Sources |
| --- | --- | --- | --- |
| Coins | `Assets/Menu/Coin.png` | pets/skins/general shop items | game-over score reward, daily reward |
| Tickets | `Assets/UI/Ticket.png` | power-ups | daily reward, high-tier merges, debug/rewarded ads |

`ShopItemData` is the generic data resource used by pets, skins, and powers. Core fields are:

```gdscript
id, display_name, icon, cost, currency, category, description
```

### Ownership rules

- **Pets/skins:** bought once, added to `owned_items`, then equipped by category.
- **Power-ups:** consumable; each purchase increments `powerup_counts[id]`. The shop hides the redundant inventory badge for counts of zero or one and only shows `xN` when the player has two or more.
- **Equipped item:** saved in a setting such as `equipped_pet`.

`shop_item_button.gd` does presentation and button handling. The dependency-free `shop_item_display_rules.gd` owns small display policies such as hiding a redundant `x1` consumable badge; keeping those rules separate also lets tests load them without compiling the scene-bound button and its autoload dependencies. `EconomyManager` is the authority for affordability, spending, ownership, and save calls. Do not let a UI card edit money dictionaries directly.

### Pets

The currently equipped pet is spawned only when a run begins. `pet.gd` maps item IDs to textures and responds to merges/danger/game over with small mood animations. Equipping a pet during a run does not replace the existing pet until the next run unless that behavior is deliberately added.

---

## 20. Power-up system and juice tuning

### Implemented powers

| ID | HUD art | Behavior |
| --- | --- | --- |
| `powerup_level_up` | LevelUP | Select one fruit and replace it with its next tier. |
| `powerup_shake_box` | ShakeIT | Mixes the pile with impulses, full-direction box movement, and a smaller camera shake. |
| `powerup_remove_smallest` | SuckUP | Marks all lowest-tier fruits with crosshairs, locks one, then removes it. |
| `powerup_grab_em` | GrabEM | Pick up one fruit, drag it inside the box, and release it onto the pile/matching fruit. |
| `powerup_hammer` | Hammer | Select and destroy one troublesome fruit. |
| `powerup_bomb` | Bomb | Select a cluster center and clear nearby eligible fruit. |

All six powers are functional, purchasable, selectable, and taught exactly once
across Mission Levels 2-7.

### Request flow

```text
visible, selected HUD button
  → EventBus.powerup_requested(id)
  → PowerupController validates run input and effective count
  → immediate action or target mode
  → PowerLoadoutManager consumes a temporary tutorial charge first,
	otherwise EconomyManager.consume_powerup(id)
  → EventBus.powerup_used(id)
  → EventBus.powerup_count_changed
  → HUD and Shop refresh counts
```

`PowerupController` owns targeting because it can convert input to world coordinates
and perform physics point queries. HUD only requests and displays powers present in
the active run loadout.

### Power-up data resources

Every active power uses a resource in `Data/ShopItems/`. `ShopItemData` now has a **Power-up Juice** section visible in the Godot Inspector:

| Inspector property | Used by | Meaning |
| --- | --- | --- |
| `effect_duration` | Remove/Grab | crosshair and grab pulse timing |
| `camera_shake_strength` | Level/Shake/Remove | amount of camera movement |
| `camera_shake_duration` | Level/Shake/Remove | camera tween time multiplier |
| `container_motion_strength` | Shake | box/container travel distance |
| `container_motion_duration` | Shake | entire box movement duration |
| `fruit_impulse_strength` | Shake | launch/mix force |
| `fruit_spin_strength` | Shake | angular velocity variation |
| `fruit_followup_impulse_ratio` | Shake | fraction of the main force used by the delayed sideways follow-up kick |
| `target_marker_scale` | Remove | crosshair size relative to fruit collision |
| `target_marker_hold_time` | Remove | time all smallest fruits remain marked |
| `target_lock_time` | Remove | final selected-target pause |
| `grab_held_scale` | Grab | visual enlarge factor while held |
| `grab_release_speed` | Grab | maximum throw velocity on release |
| `grab_ring_speed` | Grab | orbiting grab-ring animation speed |

### Shake It sequence

Shake It uses an explicit movement sequence rather than random left/right jitter:

```text
left → right → up → down → upper-left → lower-right
	 → upper-right → lower-left → left → right → up → down → settle
```

Both the visual container art and physical BoxContainer use one shared smooth sine tween, so every directional offset is identical and the walls cannot drift away from the art. The path uses a strong opening movement followed by a gradual falloff and exact restoration to the authored positions. Fruit receive an upward launch followed shortly by a smaller sideways kick and a second mobile haptic pulse, making the pile tumble instead of only hopping once. Container travel, duration, both impulse stages, spin, and camera feedback remain tunable in `powerup_shake_box.tres`. Camera movement is restored to the exact original position if interrupted by another shake.

### Remove Smallest sequence

1. Find every fruit tied for the lowest active tier.
2. Consume one power.
3. Add `Crosshair.png` as a temporary child marker to every candidate.
4. Hold the markers for the data-driven time.
5. Choose one candidate randomly, enlarge/tint its crosshair, then remove it.
6. Spawn particles, play pop audio, and apply a small camera shake.

Attaching each crosshair to its fruit makes it follow even if physics shifts the fruit during the short sequence.

### Grab ’Em sequence

1. Activate targeting mode.
2. Point-query a fruit.
3. Consume the power only after a valid fruit is selected.
4. Freeze the fruit, disable its collision layer/mask, raise its Z index, and add animated rings.
5. Clamp it inside the physical box while dragging.
6. Restore collision, velocity, and Z index on release.
7. If it lands on a matching target, request a normal MergeService merge.

Never bypass `MergeService` for the final merge. That would skip score, sound, VFX, tickets, and validity safeguards.

---

## 21. Audio, effects, and motion language

### Music

Music files are in `Audio/Music/`:

- `Main Menu.wav`
- `Gameplay.wav`
- `Shop.wav`
- `Achievements.wav`

`Bootstrap` calls `AudioManager.start_music_playlist()` once after loading saved volume. The manager duplicates the four imported WAV resources, disables their per-file loop flags on those private copies, and plays a shuffled bag containing every track. At the end of a four-track cycle it reshuffles while preventing an immediate repeat across the cycle boundary.

Two persistent `AudioStreamPlayer` nodes provide sine-eased overlap: the outgoing track fades down while the incoming track fades up. The initial track also fades in. Configure `music_fade_in_duration`, `music_crossfade_duration`, and `music_silent_db` on the AudioManager autoload script. Do not add music-selection calls to scene or tab scripts; doing so would break uninterrupted navigation playback.

### SFX

`AudioManager` creates eight SFX players for overlapping UI/gameplay effects. It uses temporary `AudioStreamPlayer2D` nodes for positional merge sounds.

If `FruitData.merge_sfx` is empty, a procedural 16-bit WAV pop is generated and cached per tier. Higher tiers receive a slightly longer and higher-pitched pop.

### Visual effects

- `merge_burst.tscn`: expanding ring/spark effect, hue derived from tier.
- pooled `GPUParticles2D` in Main: short yellow/orange particle burst.
- `score_pop.tscn`: floating `+score` UI label at the world-to-screen conversion of a merge.
- combo banner: back-eased scale/rotation, then rising fade.
- high-tier ticket banner: bounce/fade notification over the FruitDock area.
- Grab ring: drawn by Main in `_draw()` around the held fruit.
- remove crosshair: temporary Sprite2D marker attached to candidates.

### Motion rules

Use `Tween.TRANS_BACK` for a friendly pop/bounce, `Tween.TRANS_SINE` for physical sway/shake, and short durations during active play. Avoid long blocking tween sequences that prevent the player from dropping again.

### Fruit-on-fruit impact response

Normal rigid-body contact was visually too stiff, so non-matching fruit now use a
small layered spring response. The shared fruit physics material is deliberately
soft rather than rubbery: friction `0.34`, bounce `0.19`. Fruit applies linear
damping `0.18` and angular damping `0.32` from its exported impact settings after
the tier mass is loaded.

On contact, only the lower instance ID evaluates the pair. It compares previous
and current relative velocity, ignores contacts at or below 85 px/s, and uses a
smooth 85-430 px/s strength curve. The faster source visually compresses; the
receiver compresses, stretches past neutral, and settles with a tiny five-degree
tilt. A mass-ratio-clamped impulse adds at most 17 px/s sideways, 9 px/s upward,
and 0.75 rad/s spin. This is enough to wake the touched fruit without destabilizing
large late-game tiers.

Matching tiers bypass this behavior and go straight to MergeService. Receiver
cooldown is 0.12 seconds, procedural plops are limited globally to one per 45 ms,
and strong impacts share the existing Drop haptic category. The plop is generated
as a short mono AudioStreamWAV, cached by impact strength and tier group, and played
through the positional SFX pool. Reduced Motion keeps physics but skips squash and
tilt. Tune `Impact feel` exports on `fruit.gd`; do not enlarge collision shapes to
fake softness because collision remains scene-authoritative.

---

## 22. Save data and daily-reward rules

`SaveManager` writes this conceptual JSON structure:

```json
{
  "version": 8,
  "coins": 0,
  "tickets": 0,
  "owned_items": "[...]",
  "powerup_counts": {},
  "high_score": 0,
  "time_attack_high_score": 0,
  "mission_data": {},
  "daily_mission_data": {},
  "settings": {}
}
```

Important setting keys currently include:

- `daily_reward_day_index`
- `daily_reward_last_claim`
- `music_volume`
- `sfx_volume`
- `vibration_enabled`
- `locale`
- `equipped_pet`
- `no_ads_purchased`
- `power_loadout` (exactly three distinct power-up IDs)

### Daily reward rule, exactly

```text
show Daily Reward if last_claim != today
hide Daily Reward if last_claim == today
```

The day advances by one when the player next opens an unclaimed new day after a previous claim. It wraps with `posmod` after day seven. It is a simple daily loop, not a strict streak/calendar-recovery system. Missing several days currently advances only one reward when returning. If a true streak system is desired, redesign this explicitly rather than assuming the existing logic does it.

### Resetting saves during development

Delete `user://savegame.json` through Godot’s user-data location or provide a debug reset button. Do not hard-code a filesystem path in release code. Remember that debug power-up injection is memory-only at startup but consumed counts may still be saved during that play session.

---

## 23. Ads and Google Play billing integration

The current `AdManager` is intentionally safe: it **does not grant rewards in release builds without a real platform callback.**

### Current behavior

- Debug build: “watch ad” simulates a short delay then grants one ticket.
- Release without bridge: advertises that ads/billing are unavailable and grants nothing.
- Release with bridge: calls methods on `/root/MobileMonetization` if available.

### Required bridge methods

Your Android plugin/bridge should expose:

```text
show_rewarded_ad(currency: StringName, amount: int)
purchase_no_ads(product_id: String)
restore_no_ads_purchase(product_id: String)
```

The plugin must call these only from verified platform results:

```gdscript
AdManager.complete_rewarded_ticket(amount)  # reward-earned callback only
AdManager.cancel_rewarded_ad(message)       # skipped/failed/cancelled
AdManager.complete_no_ads_purchase()        # verified + acknowledged billing purchase
```

The configured no-ads product ID is `fruit_merge_no_ads`. Create the matching managed product in Google Play Console, connect a supported Godot Android billing plugin, then test with licensed test accounts. Do not treat “ad closed” as “reward earned.”

---

## 24. Asset pipeline and visual design system

### Required art conventions

- Keep transparent PNG backgrounds truly transparent.
- Use consistent naming: `Watermelon.png`, not misspelled alternatives such as `Watermellon.png`.
- Do not rename a file in Explorer without updating every `res://` reference.
- Keep UI assets inside `Assets/UI`, power icons in `Assets/PowerUps`, pets in `Assets/Pets`, and fruit art in `Assets/Fruits`.
- Let Godot regenerate `.import` metadata; do not hand-edit it.

### Design system

See `Data/Themes/DESIGN_SYSTEM.md` for the base palette and component values. The visual language is:

- cream canvas/panels;
- peach/coral secondary action;
- leaf green primary action;
- dark brown type and outlines;
- thick pale borders;
- soft, low warm shadows;
- rounded/bubbly typography.

Use `Data/Themes/cozy_theme.tres` for normal Control styling. Use the imported art panels—PausePanel, SettingPanel, Daily Reward, ShopButton, etc.—where the supplied illustration is richer than a flat StyleBox.

### Typography

- `Assets/Fonts/NERILLKID Trial.ttf` is the single UI typeface for the shared
  theme and every scene under `Scenes/UI/`.
- Do not add scene overrides for Cloudy, Atop, Spenbeb, or system-font fallbacks;
  the project validator treats them as retired UI fonts.

Large values should use an outline and subtle shadow for readability over art. Body text stays around 16–20 px, touch labels around 21–27 px, and score/title moments can reach 36–76 px.

---

## 25. Rebuilding from scratch: exact order

Use this order to avoid building UI before the game has a stable world:

### Phase A — foundation

1. Create a Godot 4.x project.
2. Set 720 × 1280 logical viewport, portrait orientation, `canvas_items` stretch mode, default 2D gravity 820.
3. Create `Assets`, `Audio`, `Autoloads`, `Data`, `Scenes`, `Scripts`, and `Docs` directories.
4. Add the music bus layout with Music/SFX buses.
5. Add Enums, EventBus, SaveManager, GameManager, EconomyManager, AudioManager, FruitDatabase, Bootstrap, and AdManager autoloads.

### Phase B — data and fruit foundation

6. Create `FruitData` resource class and one `.tres` for every tier.
7. Define the FruitTier enum and matching ordered paths in FruitDatabase.
8. Create one generic `Fruit` RigidBody script.
9. Create one independent variant scene per fruit with its own sprite and CollisionShape2D.
10. Tune collision shapes in the editor and confirm FruitDatabase reads their real dimensions.

### Phase C — playable world

11. Create Box with left/right/floor shapes and danger line area.
12. Create Spawner with preview, cooldown timer, pointer input, horizontal clamp, raycast guide, and delayed physical release.
13. Create `MergeService` with strict validity checks before and after its anticipation delay.
14. Create Main composition with ContainerArt, Camera, Box, Spawner, and CanvasLayer.
15. Verify a complete Cherry → Watermelon chain before adding UI polish.

### Phase D — score and effects

16. Add GameManager scoring/combo state.
17. Emit events for drop, merge, score, danger, and game over.
18. Add HUD score/next fruit/danger overlay.
19. Add merge burst, score pop, particles, procedural pop SFX, and screen shake.
20. Add Game Over and save score/coins once.

### Phase E — UX and meta game

21. Add Loading, Home, bottom dock, Shop, Pause, Settings, Daily Reward, and No Ads scenes.
22. Add ShopItemData, purchases, ownership/equipping, pets, coins, and tickets.
23. Add power-up inventory, HUD counts, and gameplay-side power execution.
24. Move all power feel values into the resources’ Power-up Juice section.
25. Add daily reward gating and persistence.
26. Add the three mode resources, Run Setup, the three-power loadout manager, and
	separate Classic/Time Attack records.
27. Add seven MissionDefinition resources and MissionManager progression before
	polishing tutorial overlays and scenario setup.

### Phase F — mobile release work

28. Test touch input, safe areas, and different aspect ratios.
29. Integrate real rewarded ads and billing bridge.
30. Add analytics, privacy policy, store assets, test purchases, and export signing.

At the end of every phase, make a playable build and resolve warnings before adding the next system.

---

## 26. Testing, debugging, and common failures

### Useful validation command

From the project folder, validate the Godot project without opening the graphical editor:

```powershell
& "<path-to-godot.exe>" --headless --path "D:\Godot\Merge" --editor --quit
```

Also run `git diff --check` if using Git to catch whitespace errors.

### Common failures and fixes

| Symptom | Likely cause | Correct fix |
| --- | --- | --- |
| HUD says `FruitGuide` node not found | Script still references a deleted dynamic dock node | Keep only FruitDock art and remove dynamic guide code. |
| Watermelon resource not found | Filename spelling/case mismatch or scene missing | Use `Watermelon.png`, fix `.tres` and GameOver references, retain `watermelon.tscn`. |
| Fruit leaks through a wall | collision shape/wall mismatch or fast body | inspect variant collision, wall collision, continuous collision detection. |
| Fruits land on tips / feel stiff | shape does not match silhouette, mass/damping/material needs tuning | adjust the per-fruit collision scene first; then material values. |
| Cannot drop fruit | HUD/overlay intercepts pointer | set decorative `Control.mouse_filter = IGNORE`; reserve capture for real buttons. |
| Bottom UI cut off | authored outside 720×1280 or CanvasLayer missing | use anchors/offsets inside logical viewport and test real run. |
| Daily panel appears every launch after claim | claim date was not saved or clock differs | inspect `daily_reward_last_claim`; claim via button, not close. |
| Claim UI leaks outside panel | generated cards before layout or no clipping | wait one frame, calculate from Grid size, set `clip_contents`. |
| Invalid access on freed fruit | coroutine continued after exit/merge | validate instance and tree membership after every await. |
| Release receives ad reward without viewing ad | grant on close callback | grant only from verified reward-earned callback. |

### Debug tools worth adding later

- reset save button;
- fruit-tier spawn selector;
- visual collision overlay toggle;
- force daily-reward date button;
- ticket/coin grant buttons;
- physics material live-tuning panel;
- an event log for merges and power consumption.

The current debug build grants each implemented power ×1 at launch and overwrites any previous debug-session count. Remove this behavior before a production release.

---

## 27. Safe extension patterns

### Add a new fruit

1. Import art.
2. Create FruitData `.tres`.
3. Create its independent variant scene.
4. Tune collision manually.
5. Update enum/database paths/previous next tier.
6. Update FruitsDock art and ticket thresholds if necessary.
7. Validate all paths in a headless editor pass.

### Add a new power

1. Create `Assets/PowerUps/<Name>.png`.
2. Create `Data/ShopItems/powerup_<id>.tres` with price, ticket currency, description, and juice values.
3. Add it to Shop `ITEM_PATHS`.
4. Add it to HUD scene and `hud.gd` count/update/request logic.
5. Add a constant and data path in `main.gd`.
6. Implement behavior in Main or a dedicated gameplay service.
7. Consume only after validating a valid target/action.
8. Emit appropriate events, add VFX/SFX, and test cancellation/pause/game-over edge cases.
9. Add it to debug inventory if it is implemented.

### Add a new UI screen

1. Create a scene under `Scenes/UI/<Feature>/`.
2. Put its script under `Scripts/UI/<Feature>/`.
3. Make root a full-rect `Control` using the Cozy Theme.
4. Use `CanvasLayer` or scene replacement depending on whether it is an overlay or a full screen.
5. Mark noninteractive decoration as mouse-ignore.
6. Set process-always if it must work while Pause is active.
7. Add back/close behavior and test Android back (`ui_cancel`).

### Add real audio

Assign a stream to `FruitData.merge_sfx` for tier-specific merge sounds. For UI clicks, add a small `AudioManager.play_sfx()` call at the interaction owner; do not make every button spawn its own persistent audio player.

---

## 28. Final recreation checklist

### Gameplay

- [ ] All 14 fruit tiers load in the exact correct order.
- [ ] Every fruit scene has `Sprite2D`, `Face`, `CollisionShape2D`, `WakeTimer`, and `IdleTimer`.
- [ ] Fruit collision shapes are tuned manually and match art.
- [ ] Preview clamps inside the container and guide animates to the real landing point.
- [ ] Matching fruits merge once only; no use-after-free error occurs.
- [ ] Danger line ends the run after a sustained violation.
- [ ] Score, combos, high score, coins, tickets, and game-over rewards work.
- [ ] Mission Levels 1-7 load sequentially, teach all six powers, grant temporary
	  charges without changing inventory, and unlock Classic/Time Attack correctly.
- [ ] Time Attack locks new input at zero, resolves pending merges, and saves a
	  best score independently from Classic.

### UI

- [ ] Loading → conditional daily reward → Home flow works.
- [ ] Daily reward only returns while today’s reward is unclaimed.
- [ ] HUD does not block pointer input over the container.
- [ ] FruitDock is art-only; no duplicate dynamic fruit row exists.
- [ ] Pause, Settings, Shop, Game Over, and No Ads screens close/navigate correctly.
- [ ] All canvas-screen layouts fit the logical 720 × 1280 viewport.
- [ ] Run Setup requires exactly three distinct powers for Classic/Time Attack;
	  gameplay displays only those three slots.

### Meta game

- [ ] Coins/tickets update in Home, HUD, Shop, and save file.
- [ ] Pets/skins buy and equip correctly.
- [ ] Power counts buy, display, consume, and save correctly.
- [ ] Debug power grant is disabled or release-gated before launch.
- [ ] Ad/billing bridge is real and verified before release.

### Quality

- [ ] No missing `res://` resources.
- [ ] No filename case mismatches.
- [ ] Godot headless editor validation passes.
- [ ] Run the game on at least one real Android device before release.
- [ ] Every change to fruit order updates data, scene, dock art, and rewards together.

---

## Appendix: files to read first

If a future developer has only 30 minutes, read these files in this order:

1. `project.godot`
2. `Autoloads/GameManager.gd`
3. `Autoloads/FruitDatabase.gd`
4. `Autoloads/merge_service.gd`
5. `Scripts/Entities/Fruit/fruit.gd`
6. `Scripts/Entities/Spawner/spawner.gd`
7. `Scripts/Entities/Box/box.gd`
8. `Scripts/Core/main.gd`
9. `Scripts/UI/HUD/hud.gd`
10. `Scripts/Data/shop_item_data.gd`
11. `Autoloads/EconomyManager.gd`
12. `Autoloads/SaveManager.gd`

That reading order explains the game’s state, data chain, physics, spawning, merge safety, UI coordination, monetization, and persistence without requiring a tour of every scene first.
