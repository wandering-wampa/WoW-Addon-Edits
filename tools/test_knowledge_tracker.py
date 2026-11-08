"""Check the packaged Knowledge Point Tracker with Lua 5.1 and mocked UI APIs."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON_NAME = "MyusKnowledgePointsTracker_Edit"
ADDON = ROOT / "addons" / ADDON_NAME
lua = LuaRuntime(unpack_returned_tuples=True)
files = list(ADDON.rglob("*.lua"))
for path in files:
    lua.execute("assert(loadstring(...))", path.read_text(encoding="utf-8-sig"))
print(f"PASS: Lua 5.1 syntax ({len(files)} files)")

# Resolve case-insensitively as on the supported Windows Retail installation.
relative_files = {path.relative_to(ADDON).as_posix().lower() for path in ADDON.rglob("*") if path.is_file()}
toc = (ADDON / f"{ADDON_NAME}.toc").read_text(encoding="utf-8-sig")
for line in toc.splitlines():
    line = line.strip()
    if line and not line.startswith("#"):
        assert line.replace("\\", "/").lower() in relative_files, f"Missing TOC file: {line}"
assert "## SavedVariables: MKPT_Config" in toc
icon = next(line.split(":", 1)[1].strip() for line in toc.splitlines() if line.startswith("## IconTexture:"))
prefix = f"Interface/AddOns/{ADDON_NAME}/"
assert icon.replace("\\", "/").startswith(prefix), "Icon must resolve inside the edited addon"
icon_file = icon.replace("\\", "/")[len(prefix):].lower() + ".tga"
assert icon_file in relative_files, "Missing addon icon"
assert not (ADDON / "MyusKnowledgePointsTracker.toc").exists(), "Unexpected original TOC"
print("PASS: edited folder/TOC layout, icon path and SavedVariables declaration")

lua.globals().ADDON_DIR = ADDON.as_posix()
lua.globals().ADDON_NAME = ADDON_NAME
lua.execute((ROOT / "tools" / "knowledge_tracker_ui_behavior.lua").read_text(encoding="utf-8"))
