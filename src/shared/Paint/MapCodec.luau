--!strict
-- Encodes the server's validated surface definitions for clients so the client mirror grid and renderer use exactly
-- the same patches and masks as the authoritative grid (no client-side re-derivation from geometry).
-- Masks travel as bit-packed buffers.

local MapCodec = {}

local function packMask(mask: buffer?, n: number): buffer?
	if mask == nil then
		return nil
	end
	local out = buffer.create((n + 7) // 8)
	for k = 0, n - 1 do
		if buffer.readu8(mask, k) ~= 0 then
			local byteAt = k // 8
			buffer.writeu8(out, byteAt, bit32.bor(buffer.readu8(out, byteAt), bit32.lshift(1, k % 8)))
		end
	end
	return out
end

local function unpackMask(bits: buffer?, n: number): buffer?
	if bits == nil then
		return nil
	end
	local out = buffer.create(n)
	for k = 0, n - 1 do
		if bit32.band(buffer.readu8(bits, k // 8), bit32.lshift(1, k % 8)) ~= 0 then
			buffer.writeu8(out, k, 1)
		end
	end
	return out
end

local KIND_CODE = { Floor = 1, Ramp = 2, Wall = 3, Base = 4 }
local CODE_KIND = { "Floor", "Ramp", "Wall", "Base" }

function MapCodec.encode(defs: { any }): { any }
	local out = {}
	for i, d in defs do
		out[i] = {
			d.SurfaceId,
			d.Origin,
			d.U,
			d.V,
			d.Normal,
			d.SizeU,
			d.SizeV,
			(if d.Scoreable then 1 else 0) + (if d.Climbable then 2 else 0),
			KIND_CODE[d.Kind],
			d.InitialOwner or 0,
			packMask(d.Mask, d.SizeU * d.SizeV) or false,
		}
	end
	return out
end

-- Decodes and re-validates shape; returns nil + reason on malformed data.
function MapCodec.decode(payload: any): ({ any }?, string?)
	if type(payload) ~= "table" then
		return nil, "payload not a table"
	end
	local defs = {}
	for i, e in payload do
		if type(e) ~= "table" or #e ~= 11 then
			return nil, "entry " .. tostring(i) .. " malformed"
		end
		local sizeU, sizeV = e[6], e[7]
		if type(sizeU) ~= "number" or type(sizeV) ~= "number" then
			return nil, "entry " .. tostring(i) .. " size malformed"
		end
		local flags = e[8]
		local mask = if e[11] then unpackMask(e[11], sizeU * sizeV) else nil
		defs[i] = {
			SurfaceId = e[1],
			Origin = e[2],
			U = e[3],
			V = e[4],
			Normal = e[5],
			SizeU = sizeU,
			SizeV = sizeV,
			Scoreable = bit32.band(flags, 1) ~= 0,
			Climbable = bit32.band(flags, 2) ~= 0,
			Kind = CODE_KIND[e[9]],
			InitialOwner = if e[10] ~= 0 then e[10] else nil,
			Mask = mask,
		}
	end
	return defs, nil
end

MapCodec.packMask = packMask
MapCodec.unpackMask = unpackMask

return MapCodec
