# Editing fruit collision circles

Each fruit in this folder is a complete, independent Godot scene. Its sprite and `CollisionShape2D` are visible in the editor and are no longer replaced at runtime.

To tune one fruit:

1. Open its `.tscn` scene directly.
2. Select `CollisionShape2D` in the Scene tree.
3. Drag the orange circle handle to resize the radius, or enter an exact `Radius` in the Inspector.
4. Move the collision node slightly if the fruit body is not centered under leaves or a crown.
5. Save that scene and test it in the game.

Keep `Use Scene Visuals` and `Use Scene Collision` enabled on the fruit root. The scene's circle controls physics contact and safe horizontal drop spacing. `FruitData.radius` still controls the displayed preview size.
