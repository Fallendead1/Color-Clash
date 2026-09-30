-- Presentation hooks (client): cues resolve Codex assets by key, optional assets are skipped and counted, transient
-- objects are bounded and cleaned up. Uses temporary client-local test assets (plain Sound/Part), removed at the end.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local C = t.services
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	describe("Presentation hooks", function()
		it("plays present assets, skips missing ones and stays bounded", function()
			local P = C.PresentationController
			local existing = ReplicatedStorage:FindFirstChild("ColorClashAssets")
			-- Isolate synthetic missing-asset cases from the real production library, then restore it even on failure.
			if existing then
				existing.Parent = nil
			end
			local assets = Instance.new("Folder")
			assets.Name = "ColorClashAssets"
			assets:SetAttribute("CCTestAssets", true)
			local sounds = Instance.new("Folder")
			sounds.Name = "Sounds"
			sounds.Parent = assets
			local shot = Instance.new("Sound")
			shot.Name = "Shot_sprayline"
			shot:SetAttribute("Lifetime", 0.3)
			shot.Parent = sounds
			local effects = Instance.new("Folder")
			effects.Name = "Effects"
			effects.Parent = assets
			local burst = Instance.new("Part")
			burst.Name = "Burst"
			burst.Size = Vector3.new(1, 1, 1)
			burst:SetAttribute("Lifetime", 0.3)
			burst:SetAttribute("Burst", 5)
			Instance.new("ParticleEmitter").Parent = burst
			burst.Parent = effects
			assets.Parent = ReplicatedStorage

			local ok, failure = pcall(function()
				local st = P.stats()
				local fx0 = st.played["Effect.Burst"] or 0
				local miss0 = st.missing["Sound.Burst"] or 0
				P.onCue({ k = "Burst", o = Vector3.new(0, 105, 0), tm = 1 })
				expect((st.played["Effect.Burst"] or 0) - fx0):toBe(1)
				expect((st.missing["Sound.Burst"] or 0) - miss0):toBe(1)
				local folder = workspace:FindFirstChild("ColorClashPresentation")
				expect(folder ~= nil and #folder:GetChildren() >= 1):toBe(true)
				local snd0 = st.played["Sound.Shot_sprayline"] or 0
				local anim0 = st.missing["Anim.Attack_sprayline"] or 0
				local prevWeapon = game.Players.LocalPlayer:GetAttribute("CCWeapon")
				P.onLocalAction("Fire")
				if prevWeapon == nil or prevWeapon == "sprayline" then
					expect((st.played["Sound.Shot_sprayline"] or 0) - snd0):toBe(1)
					expect((st.missing["Anim.Attack_sprayline"] or 0) - anim0 >= 0):toBe(true)
				end
				-- bounded: a flood of effects never exceeds the transient cap
				local dropped0 = st.dropped
				for _ = 1, 120 do
					P.effect("Burst", Vector3.new(0, 105, 0))
				end
				expect(P.liveCount() <= 64):toBe(true)
				expect(st.dropped > dropped0):toBe(true)
				task.wait(0.8)
				expect(P.liveCount()):toBe(0)
				expect(#folder:GetChildren()):toBe(0)
				-- unknown cue kinds are ignored
				P.onCue({ k = "NotACue" })
			end)
			assets:Destroy()
			if existing then
				existing.Parent = ReplicatedStorage
			end
			if not ok then
				error(failure)
			end
		end)
	end)
end
