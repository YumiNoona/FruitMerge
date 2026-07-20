# Fruit Merge architecture and feature guide

## Scene-authoritative fruit setup

Every file under `Scenes/Fruits/Variants` owns its sprite scale, collision shape,
collision offset, and any fruit-specific visual alignment. `FruitData` owns the
chain metadata (tier, score, next tier, mass, preview fallbacks, and the UI-only
`guide_color` accent). Do not
replace a variant collision shape from code.

The live chain has 13 contiguous tiers: Cherry, Berries, Strawberry, Grape,
Kiwi, Lemon, Orange, Apple, Peach, Coconut, Pineapple, Dragonfruit, and
Watermelon. Mango was removed; Peach now merges directly into Coconut. The
gameplay HUD intentionally has no fruit-progression dock.

When adding a fruit:

1. Add its enum tier in `Scripts/Data/enums.gd`.
2. Create its `FruitData` resource under `Data/Fruits`.
3. Create its scene-owned variant under `Scenes/Fruits/Variants`.
4. Register both paths in `Autoloads/FruitDatabase.gd`.
5. Set an opaque, non-white `guide_color` matching the fruit artwork.
6. Run `Tests/run_all.gd`; the validator checks chain continuity, guide colors,
   and required nodes.

## Runtime responsibilities

- `GameManager`: run state, modes, combo scoring, discoveries, and statistics.
- `SaveManager`: versioned profile migration, transactional save, and backup restore.
- `EconomyManager`: validated currencies, ownership, equipment, and consumables.
- `SceneRouter`: the only normal scene navigation entry point.
- `HapticManager`: mobile feedback categories and accessibility strength.
- `DailyMissionManager`: daily progress and automatic rewards.
- `AchievementManager`: permanent achievement progress and automatic rewards.
- `FruitDatabase`: scene-authoritative fruit scene and preview cache.
- `GameplayJuice`: merge particles, bursts, shake, haptics, and tier rewards.
- `PowerupController`: input targeting and the six gameplay power-up behaviors.
- `PetAbilityController`: run-local companion charge, activation, balancing, and
  effects; it keeps gameplay rules out of the visual `Pet` script.
- `PowerLoadoutManager`: validates the saved three-type selection, exposes the
  active HUD slots, and routes consumption through tutorial or saved inventory.
- `MissionManager`: loads the seven mission resources, owns campaign progress,
  deterministic spawn sequences, tutorial charges, objectives, and unlocks.
- `FruitFactory`: creates fruit under the dedicated gameplay `FruitContainer`.

## Companion pet abilities

Pets are gameplay companions rather than stacked account bonuses. Buying a pet
unlocks it permanently, but only the pet equipped in the `pet` equipment slot is
spawned and active during a run. Owned pets never stack. Mission Levels 1-7 keep
pet abilities disabled so their authored spawn sequences and power-up lessons
remain deterministic; the equipped pet may still appear and react cosmetically.

`PetAbilityData` is separate from the generic shop item and power-up juice data.
The nine resources under `Data/PetAbilities/` define the pet ID, activation type,
effect, merge charge, run-use cap, interval, duration, strength, shop summary,
and accent color. `PetAbilityCatalog` maps stable shop IDs to those resources.
`PetAbilityController` reads the equipped ID once when Main starts, listens to
EventBus, and delegates presentation to the existing `Pet` scene.

| Pet | Ability | Runtime behavior |
| --- | --- | --- |
| Strawberry Cat | Match Pounce | Six merges charge a tap that nudges the next drop toward an existing match; two uses. |
| Watermelon Pup | Safety Bark | The first danger warning automatically clears dwell and grants 2.5 seconds of grace. |
| Peach Bunny | Gentle Landing | Every fifth direct drop temporarily reduces gravity, spin, and landing motion. |
| Pineapple Meow | High Perch | Up to three danger warnings reveal the least crowded drop lane for four seconds. |
| Melon Bear | Cozy Hug | Seven merges charge a tap that damps and settles the pile; two uses. |
| Banana Fox | Future Sight | The Next panel reveals a second queued fruit. |
| Berry Hamster | Coin Cache | The first three combo chains reaching x3 grant one bonus coin each. |
| Cherry Bird | Encore | Adds 0.22 seconds to the combo grace window without a direct score multiplier. |
| Lemon Frog | Lucky Hop | Six merges charge a next-fruit reroll; two uses. |

Charged abilities use the pet itself as a mobile touch target rather than adding
a seventh HUD power. The Pet scene has a 128 px world-space touch diameter, a
colored charge ring, READY/callout text, reduced-motion-aware jump/squash motion,
a procedural chirp, particles, and power haptic. Passive/automatic pets briefly
call out their effect when it triggers. Shop cards continue hiding the old flavor
description and instead show the concise ability name/effect from PetAbilityData.

Spawner maintains one reserve tier for Future Sight and emits
`next_fruit_changed`; without Banana Fox the reserve remains hidden. Lucky Hop
rerolls only the immediate next tier and is disabled in Missions. Box owns danger
grace, Fruit owns temporary gentle/calm physics restoration, and Spawner owns the
temporary safe-lane arrows, keeping each effect with its authoritative system.

## Game modes and run setup

`Enums.GameMode` intentionally exposes exactly three entries:

- Classic: standard danger-line endless play with its own best score.
- Missions: a seven-level guided campaign with authored objectives and setups.
- Time Attack: a resource-configured two-minute scoring run with a separate best.

Home's Play/Choose Mode button and the Store's Missions utility icon open the same
`RunSetupPanel`. A new profile is routed
to Mission 1 instead of free play. Completing Mission 1 unlocks Classic;
completing Mission 7 unlocks Time Attack. Existing version-7 profiles migrate as
fully onboarded so an update never re-locks modes for current players.

Classic and Time Attack advance from mode selection to a six-card power picker.
Exactly three distinct types are required. The selection is saved as
`settings.power_loadout`, but quantities remain in `EconomyManager`. Retry keeps
the active selection; every fresh Play flow asks for a loadout again.
Pause/Game Over retry keeps a normal run's selected types. Mission retry is routed
through `MissionManager`, restoring the authored scenario and free tutorial charge.

Time Attack reads `duration_seconds` from `Data/Modes/time_attack.tres`. At zero,
new drops and power input lock immediately, existing merges get a 0.35-second
resolution window, then the mode-specific result screen saves its separate best.
The HUD pulses the final ten seconds and adds stronger haptics at 10, 5, 3, 2,
and 1 seconds. The removed standalone `ModeLabel` is not required: Time Attack
uses the existing score caption for its countdown, while other modes show SCORE.

## Seven-level mission campaign

Mission definitions live in `Data/Missions/mission_01.tres` through
`mission_07.tres`, backed by `MissionDefinition`. Each resource owns its title,
target fruit/count, deterministic spawn sequence, starting fruit/positions,
instruction copy, required power, free charge, and coin/ticket reward.

Level 1 teaches matching and merging. Levels 2-7 introduce Level Up, Shake Box,
Remove Smallest, Grab 'Em, Hammer, and Juice Bomb once each. The required power
is the only visible mission slot and receives one temporary charge. Temporary
charges are consumed before permanent inventory, emit the same gameplay events,
and are recreated on retry; they are never written into `powerup_counts`.

`fruit_merged` retains source-tier semantics for juice. `fruit_created` carries
the new tier for mission progress, including Level Up results. Tutorial cards
react to drops, created fruit, and power usage, while scenario target fruit receive
a short visual pulse unless reduced motion is enabled.

## Fruit-colored landing guide

The spawner's moving dashed landing guide uses the current fruit tier's
`FruitData.guide_color`. A dark outer stroke, translucent colored glow, and light
colored core keep red, blue, purple, yellow, and green guides readable over both
the container art and the fruit pile. The color refreshes with the preview after
every drop; it does not tint or otherwise modify the fruit sprite.

All landing-guide presentation values are exported in the Spawner's `Drop guide`
Inspector category: fruit-color toggle, fallback/override color, dash and gap
lengths, scroll speed, three stroke widths, three opacities, darkening, and
lightening. The scene defaults use a thin 1.5 px core with 3 px glow and 4.5 px
shadow. Disable `guide_use_fruit_color` to use `guide_override_color` globally.

## Persistent shuffled music

`AudioManager` owns the complete four-track playlist for the lifetime of the app.
Bootstrap starts it once after restoring the saved volume. Scene and tab scripts
must not select or restart music, so navigation between Home, Shop, Achievements,
Daily Reward, and gameplay leaves the current track and playback position intact.
Headless validation skips audio playback while still loading and checking the
four-track registration, avoiding audio-server resources during forced test exit.

## Daily reward card containment

`Scenes/UI/DailyReward/daily_reward.tscn` owns the reward grid and day-seven slot,
while `Scripts/UI/DailyReward/daily_reward.gd` generates their cards after the
first layout pass. Each rounded card is inset inside a generated
`MarginContainer`; this reserves space for the anti-aliased corners and small
shadow while the outer grid continues clipping content to the reward panel.
Adjust `_card_style()` for radius, border, and shadow appearance, and adjust the
four `CARD_INSET_*` constants when changing the amount of edge-safe space.
Completed cards retain their reward icon/amount and use the subdued surface as
their status; checkmark and `COLLECTED` labels are intentionally omitted.

Daily claims pass a short-lived currency/amount payload through the
`RewardPresentationManager` autoload before changing to Home. `EconomyManager`
still grants the balance immediately and remains authoritative. Home consumes the
payload once, displays the old count during a center hold, flies the matching icon
into the scene-authored coin/ticket target, then reveals the saved total with a
panel bounce and reward haptic. Only the currency texture travels—there is no
duplicate amount label—and the wallet number changes on impact. The target is
measured after safe-area placement.

Wallet balances in Home, gameplay HUD, Shop, and the reusable CurrencyPill use
the shared `CurrencyFormatter`. Values with four or more digits are compact:
`1000` becomes `1K`, `1250` becomes `1.2K`, and million-scale values use `M`.
The compact text is presentation only; EconomyManager and save data retain the
exact integer, and each wallet label exposes that exact value in its tooltip.
Reward amounts and shop prices remain unshortened so costs stay unambiguous.

Debug startup reapplies an exact test wallet of 10,000 coins and 100 tickets after
the profile is loaded, alongside one of each power-up. These are debug conveniences
owned by Bootstrap/EconomyManager and must remain guarded by `OS.is_debug_build()`.

Imported WAV loop flags are disabled on private runtime copies. The manager plays
every track once in a shuffled four-track cycle, reshuffles after the cycle, and
prevents the last track of one cycle from immediately repeating as the first track
of the next. Two persistent players overlap for a sine-eased crossfade near each
track's end. `music_fade_in_duration`, `music_crossfade_duration`, and
`music_silent_db` are exported on the AudioManager autoload for tuning.

## Danger line and overflow

`Scenes/Core/main.tscn` exposes a `WorldOrigin` at `(360, 1440)`. It translates the
Camera2D and authored gameplay world together so the camera's 720×1600 rectangle
overlaps the fixed-screen HUD in the 2D editor without changing runtime composition.
Inside it, a scene-authored `ContainerRig` contains both `ContainerArt` and the
physical `BoxContainer/Box` instance. Moving that one rig keeps the artwork, walls,
floor, and danger line aligned; its shipped local Y offset is 90 pixels. The
`ContainerRig` script exposes safe width and height multipliers. Width ships at
`1.12` and height at `1.00`, giving mobile play more horizontal room without
pushing the preview into the header. They update the art, wall/floor dimensions,
danger depth, spawner height/drop width, and pet edge placement together. Resize
through those properties only—leave the rig's Node2D scale at `(1, 1)` and do not
resize individual collision children. The standalone HUD scene intentionally contains
no world visuals or physics. World-space clamps must use the Box's global center
and must not assume that gameplay is centered around global X zero.

The central peach Play button on Home uses
`Scripts/UI/Components/floating_button_animator.gd`. It runs a subtle looping
rise/dip/settle sine tween with small scale and rotation accents, starts after
safe-area placement, and stays static when reduced motion is requested. The Store
uses a bottom-anchored category row for Pets, Power-Ups, Skins, and Themes. Its
top-right `CloseButton` is the single return-to-Home action.

Home's scene-authored `RewardsButton` opens Daily Reward through
`SceneRouter.go_daily_reward()`. `MissionButton` opens Run Setup and
`ThemesButton` enters the Store with the Themes category already selected. Keep
those exact node names because `home.gd` and the project validator treat them as
UI contracts; Daily remains available after today's reward is claimed so the
player can review the seven-day sequence.

Gameplay drops are received by `Spawner._unhandled_input()`. Both the full-screen
HUD root and its full-screen `TopRow` layout wrapper therefore use
`MOUSE_FILTER_IGNORE`; only their actual button children consume pointer events.
The wrapper is visually concentrated at the top but its layout rectangle covers
the entire viewport, so leaving its default `STOP` filter would disable mouse and
touch drops in Classic, Missions, and Time Attack. Runtime validation now routes a
real press/release through the viewport and requires it to create a fruit.

The dashed line measures a sustained pile overflow, not a fruit passing through it.
`Box` records that each fruit has entered the container, reads the top and bottom
extents from that fruit's scene-owned collision shape, and starts its danger dwell
only while the fruit remains above the line and is sleeping or moving below the
configured settled-speed threshold. Frozen/grabbed, merging, fast-falling, and
outside-container fruit are ignored.

All three modes show the warning tint after `danger_warning_delay` (0.5 seconds in
the box scene) and ends the run only at `danger_settle_time` (2.4 seconds). Brief
bounces recover faster than danger accumulates, preventing warning flashes during
normal drops while still keeping pressure on a genuinely full container.

## Dynamic final-pile snapshot

Game Over owns its reveal instead of being made visible immediately by `main.gd`.
When `EventBus.game_over` fires, the overlay remains hidden through one
`RenderingServer.frame_post_draw`, then reads the viewport once and crops around
the center-lower playfield. This guarantees the card shows the real losing pile
from that run without photographing the Game Over overlay itself. The captured
image is downscaled to at most 720 pixels wide before becoming an `ImageTexture`,
keeping the one-time mobile memory cost modest.

`snapshot_width_fraction`, `snapshot_vertical_focus`, and `snapshot_max_width`
are exported on `game_over.gd` for future framing/performance tuning. The authored
`SnapshotFrame` clips the image while a short scale/fade and warm flash reveal it;
the image then settles with a subtle one-time zoom. Headless validation skips the
GPU readback and retains the `FINAL PILE` fallback instead of waiting on a render
signal that does not exist.

## Responsive merge timing

`MergeService` keeps its post-await validity checks but uses a 0.075-second
convergence instead of a long anticipation pause. Source fruit shrink/fade over
0.10 seconds, and fruit created by `FruitFactory` use a 0.035-second chain-merge
lock. Normal dropped fruit retain a 0.10-second contact lock. This makes direct
merges and cascades feel immediate without allowing a fruit to merge twice during
the same physics contact.

## Lively fruit impact motion

Non-matching fruit collisions use a layered response instead of relying on rigid
body separation alone. `fruit_physics.tres` uses `0.19` bounce and `0.34` friction,
which gives a soft rebound and lets round fruit roll out of rigid vertical stacks
without turning the box into a trampoline. `Fruit._apply_data()` also applies the
shared lively damping defaults (`0.18` linear and `0.32` angular) after loading the
scene-authoritative mass.

`Fruit._handle_fruit_impact()` compares the previous and post-contact relative
velocities. Contacts below `impact_min_speed` are ignored so a resting pile does
not jitter. Stronger contacts smoothly scale from zero to one and produce:

- directional squash, rebound stretch, and a five-degree sprite tilt;
- a small mass-aware sideways/lift impulse on the receiving fruit;
- a small angular wake response so stacked fruit rock and settle naturally;
- a quiet tier-grouped procedural plop through the spatial SFX pool;
- a light mobile drop haptic only for strong impacts.

Matching tiers skip this path because MergeService already owns their movement,
sound, VFX, and haptics. Each receiver has a 0.12-second impact cooldown, while
AudioManager globally limits plops to one every 45 ms to prevent Shake Box or a
cascade from becoming noisy. Reduced Motion disables sprite deformation but keeps
the restrained physical response. All thresholds, impulse velocities, damping,
visual strength, and timing are exported under the Fruit scene's `Impact feel`
Inspector category; change these shared script defaults before adding per-tier
overrides.

## Portrait Store hub and containment

The rebuilt Store uses `Assets/UI/StoreFrame.png` over the garden background, with
the COZY STORE title, compact coin/ticket wallets, No Ads, and Close in the header.
Four illustrated buttons in the bottom-anchored `HBoxContainer` switch Pets,
Power-Ups, Skins, and Themes. Close is the only navigation action; the deleted
Store icon, Home/Daily/Missions/Settings utility buttons, `UtilityRow`, and
`CatalogPanel` are no longer runtime contracts. `CatalogMargin` directly owns the
hidden-scrollbar `ShopScroll` and clips cards inside the authored frame.

The two-column shop grid uses 220 x 330 minimum cards with a card-local price
panel style. Card contents now fit their declared minimum height, titles have a
dedicated row, and the optional stacked power-up count sits over the icon. The
owned badge was removed; owned cosmetics reuse the action label for `SELECT` and
`ACTIVE`. Pet flavor descriptions stay hidden; their former text row now contains
a concise two-line companion ability summary. Pet, skin, and power-up summaries
use 16 px NERILLKID text, a warm two-pixel outline,
and a dedicated two-line row. Both cards and the catalog panel clip their children.
The catalog scrollbar is visually hidden while touch drag and wheel scrolling remain
available. The grid and Shop card roots use `MOUSE_FILTER_PASS`, while decorative
card controls use `MOUSE_FILTER_IGNORE`, so buttons still receive taps without
swallowing vertical drag events before they reach the ScrollContainer. An explicit
8 px touch deadzone separates a purchase tap from a scroll gesture. Category repopulation frees
old cards immediately, preventing one-frame overlap. Header ad copy is ASCII-only
and sized for the 720-wide portrait canvas.

Store validation follows this rebuilt structure and launches the scene in the
runtime flow test. The test requires `_ready()` to populate all nine Pets and the
Power-Up tab to repopulate all six powers, catching stale node paths that a simple
scene-instantiation check would miss.

The default Cherry and Lemon skin resources are stored as `skin_cherry.tres` and
`skin_lemon.tres` while retaining the stable save IDs `skin_default` and
`skin_pastel`. `ShopCatalog.tres` references those current filenames and no longer
references the retired generic `pet_cat.tres` entry.

Shop presentation combines the illustrated category/utility assets with
`cozy_theme.tres`: cards and buttons use shallow 2–4 px low-opacity shadows,
the active illustrated tab grows and brightens while inactive tabs recede, and
item action panels use green/coral/gold/teal ready/locked/select/active states.
TooltipPanel and TooltipLabel provide a cream, coral-bordered tooltip instead
of the engine default. All UI scenes and the shared theme use only
`Assets/Fonts/NERILLKID Trial.ttf`; validation rejects the retired UI font paths.

## Power-ups

The HUD and shop support Level Up, Shake Box, Remove Smallest, Grab 'Em, Hammer,
and Juice Bomb. Tunable feedback values live in each `ShopItemData` resource.
The Level Up icon path is case-exact as `Assets/PowerUps/LevelUp.png`, which keeps
Android and other case-sensitive exports consistent with Windows development.
New power-ups need a shop resource, catalog entry, HUD entry, and controller
implementation. The debug validator ensures every required power-up is catalogued.
Shake Box uses one synchronized directional tween for its physical walls and
container art, plus an upward fruit impulse, delayed lateral kick, spin, camera
feedback, and two-stage haptics. Its strength and timing values remain data-driven.

The scene still contains six reusable HUD slots under `PowerupColumn`, but
`hud.gd` hides every slot not
present in `PowerLoadoutManager.active_loadout`; normal runs therefore display
exactly three and tutorial missions display zero or one. `PowerupController`
validates and consumes through the loadout manager, preventing hidden/unselected
types from being activated by an event or stale UI reference. The retired
`PowerupTray` panel and `ModeLabel` must not be referenced by either the scene or
script; mobile safe-area placement and visibility are applied directly to
`PowerupColumn`.

An empty selected slot stays tappable and replaces `x0` with a `+`. Tapping it
opens the modular `PowerupRefillPanel`, pauses physics and the Time Attack clock,
and offers either one verified rewarded-ad power or a direct ticket refill. Each
`ShopItemData` has an independent `refill_ticket_cost`, so Store coin prices do
not leak into the in-run ticket economy. A successful refill saves immediately,
resumes the prior run, refreshes the count, and pops the restored HUD icon. The
panel never opens automatically after consumption, avoiding an unwanted modal in
the middle of a power animation.

## Cosmetics

Pets use their existing texture map and combine cosmetic mood reactions with the
companion abilities documented above. Skin equipment changes the in-game fruit
and container palette. The Sunny Garden background enables the supplied background
art. Equipment is stored as profile settings and applies on the next gameplay scene.

## Mobile UX

Interactive top and bottom controls account for `DisplayServer.get_display_safe_area()`.
Safe-area offsets are applied only on Android and iOS. Desktop safe-area values
describe the monitor/work area rather than a notch inside the game window, so using
them on Windows can push portrait controls outside the embedded debug viewport.
Haptics are grouped by tap, drop, merge, big merge, power-up, danger, game over,
and reward. Settings expose continuous 0–100% Music and Sound Effects sliders plus
a vibration toggle. Their taller rows and 12 px gaps provide mobile touch and reading
space. The unused Theme, Game Feel, and Language selectors were removed; the settings
scene has no placeholder controls that claim to apply an unavailable option.

Save version 9 builds on the version-7 cleanup of retired `theme`,
`feedback_level`, and audio-restore keys.
It restores standard haptic/shake/motion values so a previously saved Minimal/Off
preset cannot remain active without a corresponding control. Version 8 adds
the Time Attack best, three-power loadout, campaign progress, and a dedicated
`daily_mission_data` dictionary. During migration, the old `mission_data` daily
payload moves to `daily_mission_data`; existing users receive completed onboarding,
while a new profile starts at Mission 1. Music/SFX volumes, the internal locale
value, and the independent vibration toggle are preserved. Version 9 removes the
old Mango tier from saved discoveries: old Mango maps back to Peach, and old
Coconut-through-Watermelon values shift down once so existing progress remains
attached to the same fruit.

Hindi and Spanish `.po` resources translate the core interface. Newly added copy
should use stable English source strings so Godot's automatic translation lookup
can find it.

## Desktop debugging

The PC debug window is resizable even though the production target is portrait
mobile. Its default 432×960 override represents a modern 9:20 phone and has the same
aspect ratio as the authored 720×1600 canvas, so the editor composition and default
runtime preview match. `expand` still reveals additional canvas space on devices
whose portrait ratio is taller or wider. Home's dock and the Store's category row
are bottom-anchored, central mascot art is vertically centered, the Store catalog
grows with the available height, and the loading footer observes the mobile bottom
safe area.

In debug builds, focus the running game and press `F11` to toggle between windowed
and fullscreen modes. When using Godot's embedded game view, black space around
the 9:20 preview is editor workspace rather than missing game content; use the
game-view menu to run it in a floating window when testing fullscreen behavior.

After changing window, stretch, or safe-area settings, stop and restart the running
project so Godot recreates the debug window with the updated configuration.

## Android build profile

`export_presets.cfg` contains the scene-independent `Android Debug` APK preset used
for phone testing. It exports only ARM64, uses package id `com.yuna.fruitmerge`,
requests vibration but not Internet access, and writes ignored artifacts under
`Builds/Android/`. Android export requires the ETC2/ASTC import flag in
`project.godot`; removing it makes Godot reject the preset before packaging.
The project and Android launcher use the existing smiling peach asset instead of
the engine's default icon. Both the project boot image and Android's Godot boot
splash are disabled; Android may still show its mandatory system launch screen,
but it uses the game icon rather than Godot branding.

`application/config/version` is the single project-facing version source. The
settings footer and About dialog read it dynamically, while the Android preset
keeps the corresponding Play version name and monotonically increasing integer
version code. Keep those values synchronized for every release.

The complete workstation setup, export commands, validated artifact details, and
release/AAB boundary are documented in `Docs/ANDROID_BUILD.md`.

## Validation

Run from a terminal with Godot 4.7:

```powershell
godot --headless --rendering-method gl_compatibility --path . --script res://Tests/run_all.gd
```

The content validator also runs automatically in debug builds. It checks the fruit
chain, scene-owned fruit nodes, shop IDs and definitions, the exact three-mode
catalog, all seven sequential mission definitions, one-time coverage of all six
tutorial powers, required power-ups, core scene paths, settings-slider contract,
removed settings options, shop-card containment, full-screen HUD pointer filters,
and an end-to-end empty-space click-to-drop path.

GDScript warnings are treated as validation defects. Avoid local names that shadow
base `Node2D`/`CanvasItem` properties, cast enum-to-integer calculations explicitly,
and make intentional division types explicit so the editor Debugger remains clean.

## External mobile integrations

`AdManager` is a safe game-side bridge, but release ads and no-ads purchases still
require a platform node named `/root/MobileMonetization` supplied by Google Mobile
Ads and Google Play Billing plugins. It must implement the methods documented in
`Autoloads/AdManager.gd` and call completion methods only after verified SDK callbacks.
For a direct power reward, the bridge receives the selected power ID as the reward
key and must call `complete_rewarded_powerup(id, amount)` only from the SDK's
reward-earned callback; close, skip, and failure callbacks use `cancel_rewarded_ad`.

The removed Privacy Policy button must only be restored after the final public
policy URL is available for store release.

## Documentation rule

Every behavior, architecture, setup, content, platform, or validation change must
update this guide (and the README when it affects first-time setup or common usage)
in the same change set. A feature is not considered complete until its documentation
matches the implementation.
