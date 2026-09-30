-- Asset contract hooks (GDD 13.3): weapon models validate against the contract and bind to the character as
-- presentation only; missing/invalid content is reported once and never affects gameplay. Uses synthetic
-- test models (plain parts) created and removed by this spec.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local S = t.services
	local H = require(S.Dev.MatchHarness)
	local WeaponModels = require(S.Dev.Parent.Presentation.WeaponModels)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local function handle(parent: Instance, name: string, attachments: { string }): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(0.6, 0.6, 2.4)
		p.CanCollide = true -- the binder must override this
		p.Parent = parent
		for k, a in attachments do
			local att = Instance.new("Attachment")
			att.Name = a
			att.Position = Vector3.new(0, 0, -1 + (k - 1) * 0.8)
			att.Parent = p
		end
		return p
	end
	local function model(name: string, key: string?): Model
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("AssetKey", key or name)
		m:SetAttribute("ContractVersion", 1)
		return m
	end

	describe("Weapon model contract", function()
		local assets
		it("validates good and broken models precisely", function()
			assets = Instance.new("Folder")
			assets.Name = "ColorClashAssets"
			local weapons = Instance.new("Folder")
			weapons.Name = "Weapons"
			weapons.Parent = assets
			local spray = model("sprayline")
			handle(spray, "Handle", { "Grip", "Muzzle" })
			spray.PrimaryPart = spray.Handle
			spray.Parent = weapons
			local roller = model("lane_roller")
			handle(roller, "Handle", { "Grip", "EffectOrigin" })
			roller.Parent = weapons
			local twin = model("twin_jets")
			for side, muzzle in { Left = "MuzzleL", Right = "MuzzleR" } do
				local half = Instance.new("Model")
				half.Name = side
				handle(half, "Handle", { "Grip", muzzle })
				half.Parent = twin
			end
			twin.Parent = weapons
			local broken = model("popshot", "pop")
			handle(broken, "Handle", { "Grip" })
			broken.Parent = weapons
			assets.Parent = ReplicatedStorage
			expect(#WeaponModels.validate(spray, "sprayline")):toBe(0)
			expect(#WeaponModels.validate(roller, "lane_roller")):toBe(0)
			expect(#WeaponModels.validate(twin, "twin_jets")):toBe(0)
			local errs = table.concat(WeaponModels.validate(broken, "popshot"), "; ")
			expect(string.find(errs, "AssetKey must be popshot", 1, true) ~= nil):toBe(true)
			expect(string.find(errs, "missing Attachment Muzzle", 1, true) ~= nil):toBe(true)
			local half = twin.Left:Clone()
			half.Parent = nil
			twin.Left:Destroy()
			expect(string.find(table.concat(WeaponModels.validate(twin, "twin_jets"), "; "), "missing child Model Left", 1, true) ~= nil):toBe(true)
			half.Parent = twin
		end)

		it("binds the equipped model as presentation only; missing/invalid reported once", function()
			local p = H.startSolo(S)
			WeaponModels.resetReports()
			S.LoadoutService.devSetKit(p, "sprayline")
			task.wait(0.3)
			local character = p.Character
			expect(character:GetAttribute("CCWeaponModel")):toBe("sprayline")
			local m = character:FindFirstChild("CCWeaponModel")
			expect(m ~= nil):toBe(true)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					expect(d.CanCollide or d.CanQuery or d.CanTouch or not d.Massless or d.Anchored):toBe(false)
				end
			end
			task.wait(0.3)
			local grip = m.Handle.Grip
			local hand = character.RightHand.RightGripAttachment
			expect((grip.WorldPosition - hand.WorldPosition).Magnitude < 0.3):toBe(true)
			S.LoadoutService.devSetKit(p, "twin_jets")
			task.wait(0.3)
			expect(character:GetAttribute("CCWeaponModel")):toBe("twin_jets")
			local miss0 = S.DiagnosticsService.getCount("event.WeaponModelMissing")
			S.LoadoutService.devSetKit(p, "linecaster")
			task.wait(0.2)
			S.LoadoutService.devSetKit(p, "splash_pot")
			task.wait(0.2)
			S.LoadoutService.devSetKit(p, "linecaster")
			task.wait(0.2)
			expect(character:GetAttribute("CCWeaponModel")):toBe("missing")
			expect(character:FindFirstChild("CCWeaponModel")):toBe(nil)
			expect(S.DiagnosticsService.getCount("event.WeaponModelMissing")):toBe(miss0 + 2) -- once per kit
			local inv0 = S.DiagnosticsService.getCount("event.WeaponModelInvalid")
			S.LoadoutService.devSetKit(p, "popshot")
			task.wait(0.2)
			expect(character:GetAttribute("CCWeaponModel")):toBe("invalid")
			expect(S.DiagnosticsService.getCount("event.WeaponModelInvalid")):toBe(inv0 + 1)
			-- gameplay is unaffected by a missing model: the kit still fires
			S.LoadoutService.devSetKit(p, "linecaster")
			assets:Destroy()
			S.LoadoutService.devSetKit(p, "sprayline")
			task.wait(0.2)
			expect(character:GetAttribute("CCWeaponModel")):toBe("missing")
			H.stop(S)
		end)
	end)
end
