-- Validate the actual serialized exports, not just the authoring functions.
local fs=require("@lune/fs")
local R=require("@lune/roblox")
local serde=require("@lune/serde")
local UI=require("../src/shared/UI/UIContract")
local Weapons=require("../src/shared/Config/Weapons")
local function read(path) return R.deserializeModel(fs.readFile(path))[1] end
local assets=read("assets/presentation/ColorClashAssets.rbxmx")
local maps=read("assets/maps/ColorClashMaps.rbxmx")
local gui=read("assets/ui/ColorClashUI.rbxmx")
local report={contractVersion=1,contentVersion=2,maps={},weapons={},animations={},effects={},externalAssetIds={},blockers={"Owner deferred animation publishing and live permission verification","Owner deferred audio publishing and live permission verification","Physical-device and 8-client checks not run"}}
local _,errors=UI.validate(gui)
assert(#errors==0,table.concat(errors,"; "))
assert(gui:GetAttribute("IsWireframe")==false)
report.ui={contractErrors=#errors,isWireframe=false,nativeInstances=#gui:GetDescendants()}
for _,m in maps:GetChildren() do
    local a=m:GetAttributes()
    assert(a.ExpectedScoringCells<=50000 and a.ExpectedWallCells<=16000 and a.ExpectedPatches<=96)
    assert(#m.Spawns:GetChildren()==8)
    local ids={}
    for _,p in m.PaintSurfaces:GetChildren() do
        assert(not ids[p:GetAttribute("SurfaceId")]) ids[p:GetAttribute("SurfaceId")]=true
        assert(p.Anchored and p.CanCollide)
    end
    local count=0
    local banks={}
    for _,p in m.Geometry:GetChildren() do
        if p.Name:match("^UtilityBank") then assert(not banks[p.Name],"duplicate utility bank") banks[p.Name]=true end
    end
    for _,p in m:GetDescendants() do
        assert(not p:IsA("LuaSourceContainer"),"map includes executable code")
        if p:IsA("BasePart") then count+=1 end
    end
    report.maps[a.MapId]={mapVersion=a.MapVersion,scoringCells=a.ExpectedScoringCells,wallCells=a.ExpectedWallCells,patches=a.ExpectedPatches,nativeParts=count}
end
for _,m in assets.Weapons:GetChildren() do
    local count=0
    assert(m:GetAttribute("AssetKey")==m.Name and m:GetAttribute("ContractVersion")==1)
    for _,p in m:GetDescendants() do if p:IsA("BasePart") then
        assert(p.Massless and not p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch)
        assert(p:FindFirstChild("Grip") or p:FindFirstChildOfClass("WeldConstraint"))
        count+=1
    end end
    -- Conservative primitive budgeting bound; actual renderer tessellation is device dependent.
    assert(count*256<=8000)
    report.weapons[m.Name]={parts=count,conservativeTriangleBound=count*256}
end
assert(not assets:FindFirstChild("AnimationSources"),"authoring sources shipped in runtime assets")
for _,d in assets:GetDescendants() do assert(not d:IsA("KeyframeSequence") and not d:IsA("Pose"),"authoring pose shipped to clients") end
local animationSources=read("assets/animation_sources/AnimationSources.rbxmx")
assert(#animationSources:GetChildren()==26,"publishing sources must be preserved")
for _,seq in animationSources:GetChildren() do
    assert(seq:IsA("KeyframeSequence"))
    local duration=seq:GetAttribute("Duration")
    local last=0 local fire={}
    for _,k in seq:GetChildren() do if k:IsA("Keyframe") then
        assert(k.Time>=0 and k.Time<=duration+0.0001)
        last=math.max(last,k.Time)
        for _,p in k:GetDescendants() do
            if p:IsA("Pose") and p.Name=="HumanoidRootPart" then assert(p.CFrame.Position.Magnitude==0) end
            if p:IsA("KeyframeMarker") and p.Name=="Fire" then table.insert(fire,k.Time) end
        end
    end end
    assert(math.abs(last-duration)<0.0001)
    if string.sub(seq.Name,1,7)=="Attack_" then
        local def=assert(Weapons.Defs[string.sub(seq.Name,8)])
        assert(#fire==1 and math.abs(fire[1]-(def.Windup or 0))<0.0001,"attack marker differs from configured windup: "..seq.Name)
        assert(math.abs(duration-def.Cadence)<0.0001,"attack duration differs from configured cadence: "..seq.Name)
    end
    report.animations[seq.Name]={duration=duration,looped=seq.Loop,fireMarkers=fire,status="UNPUBLISHED",assetId=serde.null}
end
for _,fx in assets.Effects:GetChildren() do
    local n=0
    for _,p in fx:GetDescendants() do if p:IsA("BasePart") then
        assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch) n+=1
    end end
    assert(fx:GetAttribute("Lifetime")<=10)
    report.effects[fx.Name]={parts=n,lifetime=fx:GetAttribute("Lifetime")}
end
fs.writeDir("docs/qa/phase-09")
fs.writeFile("docs/qa/phase-09/export-audit.json",serde.encode("json",report,true))
print("Export audit passed: native UI, maps, weapon construction, effect safety, animation source timing. Publishing gates remain open.")
