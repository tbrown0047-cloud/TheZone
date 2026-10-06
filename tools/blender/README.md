# Blender tools

Scripts that build game assets with Blender's Python API. Tested target: Blender 5.2.

## Run a script
Headless (no interface), writes files and a preview render:

    blender --background --python tools/blender/make_weapon.py -- ./out

In the interface: open the **Scripting** workspace, **Open** the `.py` file, press **Run Script**.
Without an output folder argument, files go to `~/TheZone_blender_out`.

## Scripts
- `make_weapon.py`: modular industrial test shotgun (see `docs/design/GEAR_STYLE_GUIDE.md`). Outputs GLB, FBX, .blend and a preview PNG.

## If a script errors
Copy the full error text from Blender's console (Window > Toggle System Console on Windows) and share it. API names change between Blender versions.
