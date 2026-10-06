from pathlib import Path
import zipfile
import re

root = Path(__file__).resolve().parents[1]
plugin = root / "readingroom.koplugin"
dist = root / "dist"
dist.mkdir(exist_ok=True)
version = re.search(r'version = "([^"]+)"', (plugin / "_meta.lua").read_text()).group(1)
with zipfile.ZipFile(dist / f"readingroom-{version}.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(plugin.glob("*.lua")):
        archive.write(file, "readingroom.koplugin/" + file.name)
    for name in ("README.md", "LICENSE"):
        archive.write(root / name, "readingroom.koplugin/" + name)
with zipfile.ZipFile(dist / f"readingroom-source-{version}.zip", "w", zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(root.rglob("*")):
        if file.is_file() and not any(part in ("dist", "__pycache__", ".git") for part in file.relative_to(root).parts):
            archive.write(file, "reading-room/" + str(file.relative_to(root)))
print("Packaged install and source ZIPs in", dist)
