--!strict
-- Planar paint patch geometry (GDD 10.2). Pure: uses the Luau `vector` library only, so it runs in Roblox and Lune.
--
-- A patch is a rectangle of one-stud cells with an immutable orthonormal basis:
--   Origin : world position of the cell (0,0) corner
--   U, V   : unit in-plane axes (cells advance along +U and +V)
--   Normal : unit outward normal (the paintable side)
-- Cell (i, j) (0-based) covers Origin + U*[i, i+1] + V*[j, j+1]; its centre is Origin + U*(i+0.5) + V*(j+0.5).

local Surface = {}

export type SurfaceKind = "Floor" | "Ramp" | "Wall" | "Base"

export type SurfaceDef = {
	SurfaceId: string,
	Origin: vector,
	U: vector,
	V: vector,
	Normal: vector,
	SizeU: number,
	SizeV: number,
	Scoreable: boolean,
	Climbable: boolean,
	Kind: SurfaceKind,
	InitialOwner: number?,
	-- Optional legal-cell mask: buffer of SizeU*SizeV bytes, 1 = legal, 0 = not paintable. nil = all legal.
	Mask: buffer?,
}

local EPS = 1e-3

function Surface.validate(def: SurfaceDef): (boolean, string?)
	if type(def.SurfaceId) ~= "string" or #def.SurfaceId == 0 then
		return false, "missing SurfaceId"
	end
	local function isInt(n: any)
		return type(n) == "number" and n == n and n >= 1 and n <= 4096 and math.floor(n) == n
	end
	if not isInt(def.SizeU) or not isInt(def.SizeV) then
		return false, def.SurfaceId .. ": SizeU/SizeV must be positive integers"
	end
	for _, axis in { "U", "V", "Normal" } do
		local a = (def :: any)[axis]
		if typeof(a) ~= "vector" and typeof(a) ~= "Vector3" then
			return false, def.SurfaceId .. ": " .. axis .. " is not a vector"
		end
		if math.abs(vector.magnitude(a) - 1) > EPS then
			return false, def.SurfaceId .. ": " .. axis .. " is not unit length"
		end
	end
	if math.abs(vector.dot(def.U, def.V)) > EPS then
		return false, def.SurfaceId .. ": U and V are not orthogonal"
	end
	local n = vector.cross(def.U, def.V)
	if math.abs(math.abs(vector.dot(n, def.Normal)) - 1) > EPS then
		return false, def.SurfaceId .. ": Normal is not perpendicular to U and V"
	end
	if def.Mask ~= nil and buffer.len(def.Mask) ~= def.SizeU * def.SizeV then
		return false, def.SurfaceId .. ": Mask length does not match SizeU*SizeV"
	end
	local kinds = { Floor = true, Ramp = true, Wall = true, Base = true }
	if not kinds[def.Kind] then
		return false, def.SurfaceId .. ": unknown Kind " .. tostring(def.Kind)
	end
	if def.Kind == "Wall" and def.Scoreable then
		return false, def.SurfaceId .. ": walls cannot be scoreable (GDD 03.3)"
	end
	if def.Kind == "Base" and def.Scoreable then
		return false, def.SurfaceId .. ": protected base surfaces cannot be scoreable (GDD 03.3)"
	end
	if def.Scoreable and def.Normal.Y < 0.5 then
		return false, def.SurfaceId .. ": scoreable surfaces must face upward (no ceilings/undersides)"
	end
	return true, nil
end

-- Local coordinates of a world point: (u, v) in studs along the axes, d = signed distance along Normal.
function Surface.toLocal(def: SurfaceDef, p: vector): (number, number, number)
	local rel = p - def.Origin
	return vector.dot(rel, def.U), vector.dot(rel, def.V), vector.dot(rel, def.Normal)
end

function Surface.cellCenter(def: SurfaceDef, i: number, j: number): vector
	return def.Origin + def.U * (i + 0.5) + def.V * (j + 0.5)
end

function Surface.cellIndex(def: SurfaceDef, i: number, j: number): number
	return j * def.SizeU + i
end

function Surface.cellCoords(def: SurfaceDef, index: number): (number, number)
	return index % def.SizeU, index // def.SizeU
end

function Surface.isLegal(def: SurfaceDef, index: number): boolean
	local mask = def.Mask
	if mask == nil then
		return true
	end
	return buffer.readu8(mask, index) ~= 0
end

function Surface.legalCount(def: SurfaceDef): number
	local mask = def.Mask
	if mask == nil then
		return def.SizeU * def.SizeV
	end
	local n = 0
	for k = 0, def.SizeU * def.SizeV - 1 do
		if buffer.readu8(mask, k) ~= 0 then
			n += 1
		end
	end
	return n
end

-- World-space axis-aligned bounds of the patch (min, max), padded by `pad` studs.
function Surface.bounds(def: SurfaceDef, pad: number): (vector, vector)
	local o = def.Origin
	local a = o + def.U * def.SizeU
	local b = o + def.V * def.SizeV
	local c = a + def.V * def.SizeV
	local minv = vector.min(vector.min(o, a), vector.min(b, c))
	local maxv = vector.max(vector.max(o, a), vector.max(b, c))
	local p = vector.create(pad, pad, pad)
	return minv - p, maxv + p
end

-- Cell containing a world point that lies on the patch plane (within `tolerance`), or nil.
function Surface.locate(def: SurfaceDef, p: vector, tolerance: number): (number?, number?)
	local u, v, d = Surface.toLocal(def, p)
	if math.abs(d) > tolerance then
		return nil, nil
	end
	local i, j = math.floor(u), math.floor(v)
	if i < 0 or j < 0 or i >= def.SizeU or j >= def.SizeV then
		return nil, nil
	end
	return i, j
end

-- Builds a patch definition from a Roblox-style part description: centre, size and the part's right/up/look
-- vectors, choosing which face is paintable. Pure so validators and fixtures can share it.
-- face: "Top" | "Front" | "Back" | "Left" | "Right"
function Surface.fromBox(
	surfaceId: string,
	center: vector,
	size: vector,
	right: vector,
	up: vector,
	look: vector,
	face: string,
	props: { Scoreable: boolean, Climbable: boolean, Kind: SurfaceKind, InitialOwner: number? }
): SurfaceDef
	local back = -look -- Roblox LookVector is -Z; +Z face normal is -look
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local origin, u, v, n, su, sv
	if face == "Top" then
		n = up
		u, v = right, back
		su, sv = size.X, size.Z
		origin = center + up * hy - right * hx - back * hz
	elseif face == "Front" then -- faces LookVector (-Z)
		n = look
		u, v = -right, up
		su, sv = size.X, size.Y
		origin = center + look * hz + right * hx - up * hy
	elseif face == "Back" then -- faces +Z
		n = back
		u, v = right, up
		su, sv = size.X, size.Y
		origin = center + back * hz - right * hx - up * hy
	elseif face == "Right" then
		n = right
		u, v = back, up
		su, sv = size.Z, size.Y
		origin = center + right * hx - back * hz - up * hy
	elseif face == "Left" then
		n = -right
		u, v = -back, up
		su, sv = size.Z, size.Y
		origin = center - right * hx + back * hz - up * hy
	else
		error("unsupported face " .. tostring(face))
	end
	-- Right-handedness: make Normal = U x V by flipping V if needed.
	if vector.dot(vector.cross(u, v), n) < 0 then
		v = -v
		origin = origin - v * sv
	end
	return {
		SurfaceId = surfaceId,
		Origin = origin,
		U = u,
		V = v,
		Normal = n,
		SizeU = math.floor(su + 0.5),
		SizeV = math.floor(sv + 0.5),
		Scoreable = props.Scoreable,
		Climbable = props.Climbable,
		Kind = props.Kind,
		InitialOwner = props.InitialOwner,
	}
end

return Surface
