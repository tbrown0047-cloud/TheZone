"""Pack Arena Volleyball into ArenaVolleyball.rbxm (binary) and ArenaVolleyball.rbxmx (XML).

    python3 build.py

If the Luau command-line tools are on PATH (or in $LUAU_BIN), every script is
syntax-checked and the headless tests run first: ball and rule checks, then a
20-minute AI vs AI match.
"""
import os, pathlib, shutil, struct, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).parent
SRC, TESTS = HERE / "source", HERE / "tests"


def read(name):
    return (SRC / name).read_text(encoding="utf-8")


server = "".join(read(f"server_{i}.luau") for i in range(1, 5))
client = read("client_1.luau") + read("client_2.luau")
config = read("Config.luau")


def luau_tool(name):
    folder = os.environ.get("LUAU_BIN")
    path = pathlib.Path(folder) / name if folder else shutil.which(name)
    return str(path) if path and pathlib.Path(path).exists() else None


def run_checks():
    compiler, runner = luau_tool("luau-compile"), luau_tool("luau")
    if not compiler or not runner:
        print("Luau tools not found: skipping syntax checks and tests")
        return
    tmp = pathlib.Path(tempfile.mkdtemp())
    for name, src in {"Server": server, "Client": client, "Config": config}.items():
        (tmp / f"{name}.luau").write_text(src, encoding="utf-8")
        r = subprocess.run([compiler, "--null", str(tmp / f"{name}.luau")], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"{name}: syntax error\n{r.stdout}{r.stderr}")
        print(f"{name}: ok ({len(src.splitlines())} lines)")
    test = lambda n: (TESTS / n).read_text(encoding="utf-8")
    ai_part = read("server_4.luau").split("-" * 64 + " input from players")[0]
    suites = {
        "ball and rules": test("test_prelude.luau") + read("server_3.luau") + test("test_body.luau"),
        "AI vs AI match": test("test_prelude.luau") + test("sim_extra.luau") + read("server_2.luau")
        + read("server_3.luau") + ai_part + test("sim_body.luau"),
    }
    for title, code in suites.items():
        path = tmp / "suite.luau"
        path.write_text(code, encoding="utf-8")
        r = subprocess.run([runner, str(path)], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"{title}: failed\n{r.stdout}{r.stderr}")
        print(f"--- {title}\n{r.stdout.rstrip()}")


run_checks()

# instance tree: (class, name, source, parent index)
INSTANCES = [
    ("Folder", "ArenaVolleyball", None, -1),
    ("Script", "Server", server, 0),
    ("ModuleScript", "Config", config, 0),
    ("LocalScript", "Client", client, 0),
]


def zigzag(v):
    return ((v << 1) ^ (v >> 31)) & 0xFFFFFFFF


def interleave(values):
    raw = [zigzag(v).to_bytes(4, "big") for v in values]
    return bytes(raw[i][j] for j in range(4) for i in range(len(raw)))


def refs(values):
    deltas, prev = [], 0
    for v in values:
        deltas.append(v - prev)
        prev = v
    return interleave(deltas)


def bstr(s):
    b = s.encode("utf-8")
    return struct.pack("<I", len(b)) + b


def chunk(name, payload, compress=True):
    try:
        import lz4.block
    except ImportError:
        compress = False  # uncompressed chunks are valid too
    if compress:
        comp = lz4.block.compress(payload, store_size=False)
        return name + struct.pack("<III", len(comp), len(payload), 0) + comp
    return name + struct.pack("<III", 0, len(payload), 0) + payload


classes = []
for cls, *_ in INSTANCES:
    if cls not in classes:
        classes.append(cls)

out = bytearray(b"<roblox!\x89\xff\r\n\x1a\n")
out += struct.pack("<HII", 0, len(classes), len(INSTANCES)) + b"\0" * 8
for cid, cls in enumerate(classes):
    members = [i for i, inst in enumerate(INSTANCES) if inst[0] == cls]
    out += chunk(b"INST", struct.pack("<I", cid) + bstr(cls) + b"\0" + struct.pack("<I", len(members)) + refs(members))
for cid, cls in enumerate(classes):
    members = [i for i, inst in enumerate(INSTANCES) if inst[0] == cls]
    out += chunk(b"PROP", struct.pack("<I", cid) + bstr("Name") + b"\x01" + b"".join(bstr(INSTANCES[i][1]) for i in members))
    if INSTANCES[members[0]][2] is not None:
        out += chunk(b"PROP", struct.pack("<I", cid) + bstr("Source") + b"\x01" + b"".join(bstr(INSTANCES[i][2]) for i in members))
children = list(range(len(INSTANCES)))
parents = [inst[3] for inst in INSTANCES]
out += chunk(b"PRNT", b"\0" + struct.pack("<I", len(children)) + refs(children) + refs(parents))
out += chunk(b"END\0", b"</roblox>", compress=False)
(HERE / "ArenaVolleyball.rbxm").write_bytes(bytes(out))


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(i, depth):
    cls, name, src, _ = INSTANCES[i]
    pad = "\t" * depth
    props = f'{pad}\t<Properties>\n{pad}\t\t<string name="Name">{name}</string>\n'
    if src is not None:
        props += f'{pad}\t\t<ProtectedString name="Source">{cdata(src)}</ProtectedString>\n'
    props += f"{pad}\t</Properties>\n"
    kids = "".join(item(k, depth + 1) for k, inst in enumerate(INSTANCES) if inst[3] == i)
    return f'{pad}<Item class="{cls}" referent="RBX{i}">\n{props}{kids}{pad}</Item>\n'


(HERE / "ArenaVolleyball.rbxmx").write_text('<roblox version="4">\n' + item(0, 1) + "</roblox>\n", encoding="utf-8")
print(f"wrote ArenaVolleyball.rbxm ({len(out)} bytes) and ArenaVolleyball.rbxmx")
