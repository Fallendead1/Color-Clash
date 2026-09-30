local R = require("@lune/roblox")
local C = { R = R }
function C.new(class, name, parent, props, attrs)
	local i = R.Instance.new(class)
	i.Name = name
	for k, v in props or {} do
		i[k] = v
	end
	for k, v in attrs or {} do
		i:SetAttribute(k, v)
	end
	i.Parent = parent
	return i
end
function C.part(parent, name, size, pos, color, attrs)
	return C.new("Part", name, parent, {
		Size = R.Vector3.new(table.unpack(size)),
		CFrame = R.CFrame.new(table.unpack(pos)),
		Color = R.Color3.fromRGB(table.unpack(color or { 190, 198, 192 })),
		Anchored = true,
		CanCollide = true,
		CanQuery = true,
		CanTouch = false,
		Material = R.Enum.Material.SmoothPlastic,
		TopSurface = R.Enum.SurfaceType.Smooth,
		BottomSurface = R.Enum.SurfaceType.Smooth,
	}, attrs)
end
function C.cosmetic(parent, name, size, pos, color)
	local p = C.part(parent, name, size, pos, color)
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	return p
end
return C
