-- Deterministic native asset export. No gameplay code is generated or modified.
local fs=require("@lune/fs")
local R=require("@lune/roblox")
for _,dir in {"assets/maps","assets/presentation","assets/ui","assets/staging","assets/animation_sources"} do fs.writeDir(dir) end
local maps,staging=require("./content/maps")()
local counts=if fs.isFile("assets/map_counts.json") then require("@lune/serde").decode("json",fs.readFile("assets/map_counts.json")) else {}
for _,m in maps:GetChildren() do
    for key,value in counts[m:GetAttribute("MapId")] or {} do m:SetAttribute(key,value) end
end
fs.writeFile("assets/maps/ColorClashMaps.rbxmx",R.serializeModel({maps},true))
fs.writeFile("assets/staging/ColorClashStaging.rbxmx",R.serializeModel({staging},true))
print("Exported original arenas and staging")
local presentation=require("./content/presentation")()
local animations=require("./content/animations")()
fs.writeFile("assets/animation_sources/AnimationSources.rbxmx",R.serializeModel({animations},true))
-- KeyframeSequences are publishing sources only; never replicate authoring poses to players.
fs.writeFile("assets/presentation/ColorClashAssets.rbxmx",R.serializeModel({presentation},true))
print("Exported seven weapons, athlete appearance and presentation effects")
local gui=require("./content/ui_finish")(require("./content/ui").build())
local style=R.Instance.new("LocalScript") style.Name="Presentation" style.Source=fs.readFile("tools/content/Presentation.client.luau") style.Parent=gui
local _,errors=require("../src/shared/UI/UIContract").validate(gui)
assert(#errors==0,table.concat(errors,"; "))
fs.writeFile("assets/ui/ColorClashUI.rbxmx",R.serializeModel({gui},true))
print("Exported native UI; contract validation passed")
