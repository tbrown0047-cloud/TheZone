"""
The Zone: modular test weapon (industrial near-future shotgun).

Builds a hard-surface weapon from beveled blocks and cylinders, applies PBR
materials with procedural wear, renders a preview, and exports GLB + FBX + .blend.

Run headless:
    blender --background --python tools/blender/make_weapon.py -- <output_dir>

Or open it in Blender's Scripting tab and press Run Script (output goes to
~/TheZone_blender_out when no directory is given).

Style rules live in docs/design/GEAR_STYLE_GUIDE.md. Original design: do not
add real brand names, logos or copied markings.

Axes: +X is the muzzle direction, +Z is up, Y is the weapon's side.
Units: meters.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

# ----------------------------------------------------------------- settings
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = ARGV[0] if ARGV else os.path.join(os.path.expanduser("~"), "TheZone_blender_out")
NAME = "KZ_Shotgun_Test"
ACCENT = (0.62, 0.45, 0.10, 1.0)     # small faction accent (brass-like)
RENDER_PREVIEW = True
RENDER_SAMPLES = 64
RES = (1600, 900)
BEVEL_WIDTH = 0.0022
BEVEL_SEGMENTS = 3

COLL = None
PARTS = []


# ------------------------------------------------------------------ helpers
def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def set_input(node, names, value):
    """Set the first matching socket name (names differ between versions)."""
    for n in names:
        sock = node.inputs.get(n)
        if sock is not None:
            sock.default_value = value
            return True
    return False


def make_material(name, color, metallic, roughness, wear=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    set_input(bsdf, ["Base Color"], color)
    set_input(bsdf, ["Metallic"], metallic)
    set_input(bsdf, ["Roughness"], roughness)
    if emission:
        set_input(bsdf, ["Emission Color", "Emission"], emission)
        set_input(bsdf, ["Emission Strength"], 4.0)
    if wear > 0:
        coord = nt.nodes.new("ShaderNodeTexCoord")
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 60.0
        noise.inputs["Detail"].default_value = 8.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = (max(roughness - wear, 0.05),) * 3 + (1,)
        ramp.color_ramp.elements[1].position = 0.65
        ramp.color_ramp.elements[1].color = (min(roughness + wear, 1.0),) * 3 + (1,)
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.08
        nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Roughness"])
        nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def new_object(name, mesh, loc, rot, mat, bevel=True):
    obj = bpy.data.objects.new(name, mesh)
    COLL.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = BEVEL_WIDTH
        mod.segments = BEVEL_SEGMENTS
        mod.limit_method = "ANGLE"
    PARTS.append(obj)
    return obj


def box(name, size, loc, mat, rot=(0, 0, 0), bevel=True):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    bm.to_mesh(mesh)
    bm.free()
    return new_object(name, mesh, loc, rot, mat, bevel)


def cyl(name, radius, length, loc, mat, axis="X", segments=48, bevel=True):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments,
                          radius1=radius, radius2=radius, depth=length)
    bm.to_mesh(mesh)
    bm.free()
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    return new_object(name, mesh, loc, rot, mat, bevel)


def bake(obj):
    """Apply all modifiers by replacing the mesh with its evaluated copy."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    new_mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    old = obj.data
    obj.modifiers.clear()
    obj.data = new_mesh
    for m in old.materials:
        new_mesh.materials.append(m)
    bpy.data.meshes.remove(old)


def cut(target, cutter):
    """Boolean-subtract cutter from target, then discard the cutter."""
    cutter.display_type = "WIRE"
    bake(cutter)
    mod = target.modifiers.new("Cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    try:
        mod.solver = "EXACT"
    except Exception:
        pass
    bake(target)
    PARTS.remove(cutter)
    bpy.data.objects.remove(cutter, do_unlink=True)


# ------------------------------------------------------------------- weapon
def build_weapon(m):
    # receiver and top rail
    receiver = box("Receiver", (0.34, 0.07, 0.11), (0.0, 0, 0.0), m["gunmetal"])
    for i, x in enumerate((-0.13, -0.115, -0.10, -0.085)):
        cut(receiver, box(f"Vent{i}", (0.006, 0.09, 0.035), (x, 0, 0.0), None, bevel=False))
    cut(receiver, box("EjectionPort", (0.10, 0.09, 0.03), (0.06, 0, 0.02), None, bevel=False))
    box("TopRail", (0.40, 0.032, 0.014), (0.03, 0, 0.062), m["steel"])
    for i in range(20):
        box(f"RailTooth{i}", (0.008, 0.034, 0.006), (-0.16 + i * 0.019, 0, 0.0715), m["steel"], bevel=False)
    box("RearSight", (0.014, 0.034, 0.022), (-0.10, 0, 0.082), m["steel"])
    box("FrontSight", (0.012, 0.030, 0.022), (0.30, 0, 0.082), m["steel"])

    # barrels and shroud
    for i, z in enumerate((0.019, -0.019)):
        cyl(f"Barrel{i}", 0.0125, 0.52, (0.43, 0, z), m["blued"])
    shroud = box("Shroud", (0.26, 0.062, 0.090), (0.31, 0, 0.0), m["polymer"])
    cut(shroud, box("ShroudWindow", (0.12, 0.09, 0.045), (0.34, 0, 0.0), None, bevel=False))
    for i, z in enumerate((0.019, -0.019)):
        cyl(f"Muzzle{i}", 0.0165, 0.045, (0.69, 0, z), m["gunmetal"])

    # grip, magazine well, trigger guard, trigger
    box("Grip", (0.046, 0.052, 0.130), (-0.045, 0, -0.112), m["polymer"], rot=(0, math.radians(-14), 0))
    box("GripBase", (0.050, 0.056, 0.020), (-0.012, 0, -0.178), m["rubber"], rot=(0, math.radians(-14), 0))
    guard = box("TriggerGuard", (0.10, 0.04, 0.05), (0.04, 0, -0.082), m["polymer"])
    cut(guard, box("GuardCut", (0.066, 0.06, 0.032), (0.045, 0, -0.088), None, bevel=False))
    box("Trigger", (0.008, 0.012, 0.030), (0.035, 0, -0.080), m["accent"], rot=(0, math.radians(12), 0))

    # stock: slab body with a frame cutout, accent strip, rubber pad
    stock = box("Stock", (0.30, 0.050, 0.120), (-0.330, 0, -0.012), m["polymer"], rot=(0, math.radians(-4), 0))
    cut(stock, box("StockCut", (0.16, 0.07, 0.050), (-0.320, 0, -0.045), None, bevel=False))
    box("StockAccent", (0.30, 0.052, 0.014), (-0.330, 0, -0.075), m["accent"], rot=(0, math.radians(-4), 0))
    box("ButtPad", (0.022, 0.056, 0.128), (-0.488, 0, -0.016), m["rubber"], rot=(0, math.radians(-4), 0))

    # side module with a tiny status LED, bolt handle, cheek riser
    box("SideModule", (0.09, 0.026, 0.046), (0.20, -0.048, -0.022), m["polymer"])
    box("StatusLED", (0.006, 0.004, 0.006), (0.235, -0.063, -0.010), m["led"], bevel=False)
    cyl("BoltKnob", 0.0075, 0.030, (0.055, 0.050, 0.012), m["accent"], axis="Y", segments=24)
    box("CheekRiser", (0.12, 0.040, 0.020), (-0.20, 0, 0.068), m["polymer"])

    # fasteners
    for i, (x, z) in enumerate(((-0.14, 0.04), (0.10, 0.04), (0.14, -0.04), (-0.10, -0.04))):
        cyl(f"Screw{i}", 0.0042, 0.004, (x, 0.0355, z), m["steel"], axis="Y", segments=16, bevel=False)

    for obj in list(PARTS):
        if obj.modifiers:
            bake(obj)


def finish_shading():
    for obj in PARTS:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
        except Exception:
            for poly in obj.data.polygons:
                poly.use_smooth = True


# -------------------------------------------------------------- scene setup
def setup_scene():
    scene = bpy.context.scene
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.02, 0.02, 0.024, 1)
        bg.inputs["Strength"].default_value = 0.6

    def area(name, loc, energy, size):
        light = bpy.data.lights.new(name, "AREA")
        light.energy = energy
        light.size = size
        obj = bpy.data.objects.new(name, light)
        COLL.objects.link(obj)
        obj.location = loc
        con = obj.constraints.new("TRACK_TO")
        con.target = target
        con.track_axis = "TRACK_NEGATIVE_Z"
        con.up_axis = "UP_Y"

    target = bpy.data.objects.new("Target", None)
    COLL.objects.link(target)
    target.location = (0.10, 0, -0.02)

    area("Key", (0.6, -1.2, 0.9), 220, 1.2)
    area("Rim", (-0.9, 0.9, 0.5), 160, 1.0)
    area("Fill", (1.0, -0.6, -0.2), 60, 1.5)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("Cam", cam_data)
    COLL.objects.link(cam)
    cam.location = (0.55, -1.55, 0.38)
    con = cam.constraints.new("TRACK_TO")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    scene.camera = cam

    scene.render.engine = "CYCLES"
    scene.cycles.samples = RENDER_SAMPLES
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.image_settings.file_format = "PNG"


def export_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PARTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    results = {}
    for label, fn in (
        ("glb", lambda p: bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", use_selection=True)),
        ("fbx", lambda p: bpy.ops.export_scene.fbx(filepath=p, use_selection=True)),
    ):
        path = os.path.join(OUT_DIR, f"{NAME}.{label}")
        try:
            fn(path)
            results[label] = path
        except Exception as exc:
            results[label] = f"FAILED: {exc}"
    blend = os.path.join(OUT_DIR, f"{NAME}.blend")
    try:
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        results["blend"] = blend
    except Exception as exc:
        results["blend"] = f"FAILED: {exc}"
    return results


def main():
    global COLL
    clear_scene()
    COLL = bpy.context.scene.collection

    mats = {
        "polymer": make_material("KZ_Polymer", (0.025, 0.025, 0.028, 1), 0.0, 0.55, wear=0.18),
        "gunmetal": make_material("KZ_Gunmetal", (0.13, 0.13, 0.14, 1), 1.0, 0.38, wear=0.15),
        "steel": make_material("KZ_BrushedSteel", (0.56, 0.56, 0.58, 1), 1.0, 0.30, wear=0.12),
        "blued": make_material("KZ_BluedSteel", (0.04, 0.045, 0.055, 1), 1.0, 0.28, wear=0.10),
        "rubber": make_material("KZ_Rubber", (0.012, 0.012, 0.012, 1), 0.0, 0.92),
        "accent": make_material("KZ_Accent", ACCENT, 1.0, 0.36, wear=0.12),
        "led": make_material("KZ_LED", (0.1, 0.8, 0.9, 1), 0.0, 0.4, emission=(0.1, 0.8, 0.9, 1)),
    }
    build_weapon(mats)
    finish_shading()
    setup_scene()

    results = export_all()
    if RENDER_PREVIEW:
        bpy.context.scene.render.filepath = os.path.join(OUT_DIR, f"{NAME}_preview.png")
        bpy.ops.render.render(write_still=True)
        results["preview"] = bpy.context.scene.render.filepath
    print("=== The Zone weapon build finished ===")
    for k, v in results.items():
        print(f"{k}: {v}")


main()
