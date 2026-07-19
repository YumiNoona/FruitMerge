# Editing fruit collision circles

Each fruit in this folder is a complete, independent Godot scene. Its sprite and `CollisionShape2D` are visible in the editor and are no longer replaced at runtime.

The current merge chain contains 13 fruits. Mango is retired, so Peach merges
directly into Coconut; Coconut and every later fruit use the contiguous shifted
tier values documented in `Docs/PROJECT_RECREATION_GUIDE.md`.

To tune one fruit:

1. Open its `.tscn` scene directly.
2. Select `CollisionShape2D` in the Scene tree.
3. Drag the orange circle handle to resize the radius, or enter an exact `Radius` in the Inspector.
4. Move the collision node slightly if the fruit body is not centered under leaves or a crown.
5. Save that scene and test it in the game.

Keep `Use Scene Visuals` and `Use Scene Collision` enabled on the fruit root. The scene's circle controls physics contact and safe horizontal drop spacing. `FruitData.radius` still controls the displayed preview size.

To resize the gameplay container, open `Scenes/Core/main.tscn`, select
`WorldOrigin/ContainerRig`, and change the Width or Height Multiplier in its
Container Sizing group. Those values keep the artwork, walls, floor, danger line,
drop limits, and spawner aligned. Never resize individual collision nodes or apply
Node2D scale to the rig.

## Architecture and features

See `Docs/ARCHITECTURE_AND_FEATURES.md` for the save/profile design, game modes,
power-up flow, nine equipped-pet companion abilities, mobile haptics and safe-area behavior, cosmetics, localization,
and the headless validation command.

Play now opens a mobile-first run setup flow. New profiles begin with the first
of seven guided Missions; completing Level 1 unlocks Classic, and completing
Level 7 unlocks Time Attack. Classic and Time Attack require a three-type power
loadout before each new run. Mission tutorial charges are temporary and never
consume the player's saved shop inventory.

Purchased pets are functional companions: only the equipped pet contributes one
passive, automatic, or merge-charged ability. The pet itself is the mobile touch
target, so the gameplay HUD still shows only the selected three power-up types.

## Android debug build

The project includes an ARM64 `Android Debug` export preset. See
`Docs/ANDROID_BUILD.md` for the installed toolchain, build command, package and
version policy, artifact validation, device-install command, and Play-release
requirements. The Android preset uses the peach launcher icon and suppresses the
default Godot boot splash. Generated files under `Builds/` are local artifacts and
are not committed.

For PC debugging, the window is resizable and `F11` toggles fullscreen in debug
builds. The default 432×960 debug window previews a modern 9:20 phone while the
authored UI remains 720×1280. Mobile safe-area offsets intentionally do not run on
desktop platforms.
