# Editing fruit collision circles

Each fruit in this folder is a complete, independent Godot scene. Its sprite and `CollisionShape2D` are visible in the editor and are no longer replaced at runtime.

To tune one fruit:

1. Open its `.tscn` scene directly.
2. Select `CollisionShape2D` in the Scene tree.
3. Drag the orange circle handle to resize the radius, or enter an exact `Radius` in the Inspector.
4. Move the collision node slightly if the fruit body is not centered under leaves or a crown.
5. Save that scene and test it in the game.

Keep `Use Scene Visuals` and `Use Scene Collision` enabled on the fruit root. The scene's circle controls physics contact and safe horizontal drop spacing. `FruitData.radius` still controls the displayed preview size.

## Architecture and features

See `Docs/ARCHITECTURE_AND_FEATURES.md` for the save/profile design, game modes,
power-up flow, mobile haptics and safe-area behavior, cosmetics, localization,
and the headless validation command.

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
