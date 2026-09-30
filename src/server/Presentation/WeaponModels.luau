--!strict
-- Weapon model binding (GDD 13.3, docs/ASSET_CONTRACT.md). Codex models live in
-- ReplicatedStorage.ColorClashAssets.Weapons.<kitId>. The server attaches the equipped kit's model to each spawned
-- character so every client sees it. Models are presentation only: every part is massless, non-colliding and not
-- queryable (never a hitbox, never a physics change). A missing or invalid model is reported once and the character
-- simply has no weapon model; gameplay never depends on it.
--
-- Contract (ContractVersion 1):
--   single-handed kits: Model { AssetKey = kitId, ContractVersion = 1 } containing Attachment "Grip" (in the handle
--     part) and, for ranged kits, Attachment "Muzzle"; melee kits (roller, brush) carry "EffectOrigin" instead.
--   twin_jets: Model with child Models "Left" and "Right", each with "Grip"; muzzles "MuzzleL" (Left) / "MuzzleR"
--     (Right).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage:WaitForChild("Shared").Config.Weapons)

local WeaponModels = {}

local reported: { [string]: boolean } = {}

local MELEE = { roller = true, brush = true }

local function findAttachment(root: Instance, name: string): Attachment?
	for _, d in root:GetDescendants() do
		if d:IsA("Attachment") and d.Name == name then
			return d
		end
	end
	return nil
end

function WeaponModels.folder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("ColorClashAssets")
	return assets and assets:FindFirstChild("Weapons")
end

-- Returns a list of contract errors for a candidate model (empty = valid).
function WeaponModels.validate(model: Instance, kitId: string): { string }
	local errors = {}
	local def = Weapons.Defs[kitId]
	if not def then
		table.insert(errors, "unknown kit " .. kitId)
		return errors
	end
	if not model:IsA("Model") then
		table.insert(errors, kitId .. ": not a Model")
		return errors
	end
	if model:GetAttribute("AssetKey") ~= kitId then
		table.insert(errors, kitId .. ": AssetKey must be " .. kitId)
	end
	if model:GetAttribute("ContractVersion") ~= 1 then
		table.insert(errors, kitId .. ": ContractVersion must be 1")
	end
	local function need(root: Instance, name: string, label: string)
		if not findAttachment(root, name) then
			table.insert(errors, string.format("%s: missing Attachment %s%s", kitId, name, label))
		end
	end
	if kitId == "twin_jets" then
		for side, muzzle in { Left = "MuzzleL", Right = "MuzzleR" } do
			local half = model:FindFirstChild(side)
			if not half or not half:IsA("Model") then
				table.insert(errors, "twin_jets: missing child Model " .. side)
			else
				need(half, "Grip", " in " .. side)
				need(half, muzzle, " in " .. side)
			end
		end
	else
		need(model, "Grip", "")
		if MELEE[def.Family] then
			need(model, "EffectOrigin", "")
		else
			need(model, "Muzzle", "")
		end
	end
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	if parts == 0 then
		table.insert(errors, kitId .. ": no parts")
	end
	return errors
end

local function presentationOnly(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
end

local function mount(piece: Instance, character: Model, handName: string, gripName: string): boolean
	local grip = findAttachment(piece, "Grip")
	local hand = character:FindFirstChild(handName)
	local handAttachment = hand and hand:FindFirstChild(gripName)
	if not grip or not handAttachment or not handAttachment:IsA("Attachment") then
		return false
	end
	local c = Instance.new("RigidConstraint")
	c.Name = "CCWeaponGrip"
	c.Attachment0 = handAttachment
	c.Attachment1 = grip
	c.Parent = grip.Parent
	-- start aligned so the constraint does not yank the character
	local gripPart = grip.Parent :: BasePart
	local target = handAttachment.WorldCFrame * grip.CFrame:Inverse()
	if piece:IsA("Model") then
		piece:PivotTo(target * gripPart.CFrame:Inverse() * piece:GetPivot())
	end
	return true
end

-- Attaches the kit's model to `character`. Returns "attached", "missing" or "invalid".
function WeaponModels.attach(character: Model, kitId: string, report: ((string, { [string]: any }) -> ())?): string
	local old = character:FindFirstChild("CCWeaponModel")
	if old then
		old:Destroy()
	end
	local folder = WeaponModels.folder()
	local template = folder and folder:FindFirstChild(kitId)
	if not template then
		character:SetAttribute("CCWeaponModel", "missing")
		if report and not reported["missing:" .. kitId] then
			reported["missing:" .. kitId] = true
			report("WeaponModelMissing", { kit = kitId })
		end
		return "missing"
	end
	local errors = WeaponModels.validate(template, kitId)
	if #errors > 0 then
		character:SetAttribute("CCWeaponModel", "invalid")
		if report and not reported["invalid:" .. kitId] then
			reported["invalid:" .. kitId] = true
			report("WeaponModelInvalid", { kit = kitId, first = errors[1], count = #errors })
		end
		return "invalid"
	end
	local model = template:Clone()
	model.Name = "CCWeaponModel"
	presentationOnly(model)
	local ok
	if kitId == "twin_jets" then
		ok = mount(model:FindFirstChild("Left") :: Instance, character, "LeftHand", "LeftGripAttachment")
			and mount(model:FindFirstChild("Right") :: Instance, character, "RightHand", "RightGripAttachment")
	else
		ok = mount(model, character, "RightHand", "RightGripAttachment")
	end
	model.Parent = character
	character:SetAttribute("CCWeaponModel", if ok then kitId else "unmounted")
	return if ok then "attached" else "invalid"
end

-- Tests: forget one-time reports.
function WeaponModels.resetReports()
	table.clear(reported)
end

return WeaponModels
