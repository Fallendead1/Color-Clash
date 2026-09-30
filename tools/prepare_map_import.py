"""Maps-only fallback for a disconnected Rojo plugin. Never replaces scripts, UI or presentation assets.
Reconnection to the existing Rojo server is required afterwards. Does not publish the place.
"""
from pathlib import Path
import json

common = Path("tools/content/common.luau").read_text().replace(
    'local R = require("@lune/roblox")',
    'local R = {Instance=Instance,Vector3=Vector3,Color3=Color3,CFrame=CFrame,Enum=Enum,UDim2=UDim2,UDim=UDim,Vector2=Vector2}',
)
parts = ["local C=(function()\n" + common + "\nend)()"]
for name, filename in [("coverLayouts", "cover_layouts"), ("elevatedCover", "elevated_cover"), ("maps", "maps")]:
    source = Path(f"tools/content/{filename}.luau").read_text()
    for dependency in ['local C = require("./common")', 'local coverLayouts = require("./cover_layouts")', 'local elevatedCover = require("./elevated_cover")']:
        source = source.replace(dependency, "")
    parts.append(f"local {name}=(function()\n{source}\nend)()")
parts.append("local m,staging=maps() staging:Destroy()")
for map_id, attrs in json.loads(Path("assets/map_counts.json").read_text()).items():
    for key, value in attrs.items():
        parts.append(f'for _,map in m:GetChildren() do if map:GetAttribute("MapId")=="{map_id}" then map:SetAttribute("{key}",{value}) end end')
parts.append('local old=game.ServerStorage:FindFirstChild("ColorClashMaps") if old then old:Destroy() end m.Parent=game.ServerStorage return "Maps only imported; reconnect Rojo to localhost:34872"')
Path("build/import_maps.luau").write_text("\n".join(parts))
