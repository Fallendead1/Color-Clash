"""Assemble the SAME native content builders for Studio MCP execution when Rojo is disconnected.
Output is local authoring code, never mapped into the live game. Does not publish the place.
"""
from pathlib import Path
import json

def main():
 common=Path('tools/content/common.luau').read_text().replace('local R = require("@lune/roblox")','local R = {Instance=Instance,Vector3=Vector3,Color3=Color3,CFrame=CFrame,Enum=Enum,UDim2=UDim2,UDim=UDim,Vector2=Vector2}')
 parts=['local C=(function()\n'+common+'\nend)()']
 for var,file in [('maps','maps'),('presentation','presentation'),('animations','animations'),('finishUI','ui_finish')]:
  s=Path('tools/content/'+file+'.luau').read_text().replace('local C = require("./common")','')
  parts.append('local '+var+'=(function()\n'+s+'\nend)()')
 s=Path('tools/content/ui.luau').read_text().replace('local R = require("@lune/roblox")','local R=C.R').replace('require("../../src/shared/UI/UIContract")','require(game.ReplicatedStorage.Shared.UI.UIContract)').replace('require("../../src/shared/UI/Strings")','require(game.ReplicatedStorage.Shared.UI.Strings)')
 parts.append('local ui=(function()\n'+s+'\nend)()')
 parts.append('''local function install(root,parent)
 local old=parent:FindFirstChild(root.Name) if old then old:Destroy() end root.Parent=parent
end
local m,s=maps()
''')
 for mid,attrs in json.loads(Path('assets/map_counts.json').read_text()).items():
  for key,val in attrs.items():parts.append(f'for _,map in m:GetChildren() do if map:GetAttribute("MapId")=="{mid}" then map:SetAttribute("{key}",{val}) end end')
 parts.append('install(m,game.ServerStorage) install(s,workspace)\nlocal a=presentation() animations().Parent=a install(a,game.ReplicatedStorage)\nlocal g=finishUI(ui.build())')
 source=Path('tools/content/Presentation.client.luau').read_text()
 parts.append('local style=Instance.new("LocalScript") style.Name="Presentation" style.Source=[====[\n'+source+'\n]====] style.Parent=g install(g,game.StarterGui)')
 parts.append('return {maps=#m:GetChildren(),ui=g:GetAttribute("IsWireframe"),assets=#a:GetDescendants()}')
 Path('build/import_content.luau').write_text('\n'.join(parts))
if __name__=='__main__':main()
