--!strict
-- UI binding contract (GDD 12.3, docs/UI_CONTRACT.md). Production root: a ScreenGui named "ColorClashUI" with
-- attribute ContractVersion = 1. Controls are found by their unique UIKey attribute, never by hierarchy paths.
-- Codex's production UI and Claude's development wireframe must both satisfy this list.
--
-- Kinds: "button" = GuiButton, "text" = TextLabel/TextButton/TextBox, "frame" = GuiObject, "image" = ImageLabel/
-- ImageButton, "scroll" = ScrollingFrame, "template" = GuiObject used as a cloned row template (hidden).

local UIContract = {}

UIContract.RootName = "ColorClashUI"
UIContract.ContractVersion = 1

-- Mandatory keys from GDD 12.3.
UIContract.Mandatory = {
	["Loading.Root"] = "frame",
	["Loading.Stage"] = "text",
	["Loading.Retry"] = "button",
	["Staging.Root"] = "frame",
	["Staging.Ready"] = "button",
	["Staging.Unready"] = "button",
	["Staging.Status"] = "text",
	["Armory.Root"] = "frame",
	["Armory.KitList"] = "scroll",
	["Armory.Equip"] = "button",
	["Armory.Close"] = "button",
	["Controls.Root"] = "frame",
	["Controls.Close"] = "button",
	["HUD.Root"] = "frame",
	["HUD.Timer"] = "text",
	["HUD.CoverageA"] = "frame",
	["HUD.CoverageB"] = "frame",
	["HUD.Neutral"] = "frame",
	["HUD.Paint"] = "frame",
	["HUD.Health"] = "frame",
	["HUD.Reticle"] = "frame",
	["HUD.Gadget"] = "frame",
	["HUD.Ultimate"] = "frame",
	["Touch.Primary"] = "button",
	["Touch.Secondary"] = "button",
	["Touch.Glide"] = "button",
	["Touch.Jump"] = "button",
	["Touch.Gadget"] = "button",
	["Touch.Ultimate"] = "button",
	["Touch.Map"] = "button",
	["Map.Root"] = "frame",
	["Map.Image"] = "frame",
	["Map.TargetList"] = "scroll",
	["Map.ConfirmLaunch"] = "button",
	["Map.Close"] = "button",
	["Scoreboard.Root"] = "frame",
	["Scoreboard.TeamA"] = "scroll",
	["Scoreboard.TeamB"] = "scroll",
	["Elimination.Root"] = "frame",
	["Elimination.Countdown"] = "text",
	["Results.Root"] = "frame",
	["Results.Outcome"] = "text",
	["Results.Coverage"] = "frame",
	["Results.Stats"] = "scroll",
	["Settings.Root"] = "frame",
	["Settings.Close"] = "button",
	["Notices.Root"] = "frame",
}

-- Supporting keys the adapter binds when present (the wireframe provides all of them; production UI should too).
UIContract.Optional = {
	["Settings.Status"] = "text",
	["Touch.Root"] = "frame",
	["Results.CoverageFillA"] = "frame",
	["Results.CoverageFillB"] = "frame",
	["Scoreboard.Header"] = "text",
	["Staging.Play"] = "button",
	["Staging.OpenArmory"] = "button",
	["Staging.OpenControls"] = "button",
	["Staging.OpenSettings"] = "button",
	["Staging.Kit"] = "text",
	["Staging.Onboarding"] = "frame",
	["Staging.OnboardingDismiss"] = "button",
	["Loading.Back"] = "button",
	["Loading.Detail"] = "text",
	["Armory.KitTemplate"] = "template",
	["Armory.Detail"] = "text",
	["Armory.Status"] = "text",
	["Controls.Text"] = "text",
	["HUD.CoverageText"] = "text",
	["HUD.PaintFill"] = "frame",
	["HUD.PaintText"] = "text",
	["HUD.HealthFill"] = "frame",
	["HUD.HealthText"] = "text",
	["HUD.Kit"] = "text",
	["HUD.GadgetText"] = "text",
	["HUD.UltimateFill"] = "frame",
	["HUD.UltimateText"] = "text",
	["HUD.ReticleState"] = "text",
	["HUD.Callout"] = "text",
	["HUD.Shield"] = "text",
	["Map.TargetTemplate"] = "template",
	["Map.Status"] = "text",
	["Scoreboard.RowTemplate"] = "template",
	["Elimination.Attacker"] = "text",
	["Results.CoverageText"] = "text",
	["Results.StatRowTemplate"] = "template",
	["Settings.List"] = "scroll",
	["Settings.RowTemplate"] = "template",
	["Notices.Template"] = "template",
	["Intro.Root"] = "frame",
	["Intro.Title"] = "text",
	["Intro.Count"] = "text",
}

local function classOk(inst: Instance, kind: string): boolean
	if kind == "button" then
		return inst:IsA("GuiButton")
	elseif kind == "text" then
		return inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
	elseif kind == "frame" or kind == "template" then
		return inst:IsA("GuiObject")
	elseif kind == "image" then
		return inst:IsA("ImageLabel") or inst:IsA("ImageButton")
	elseif kind == "scroll" then
		return inst:IsA("ScrollingFrame")
	end
	return false
end

-- Validates a UI root. Returns (keyToInstance, errors). Duplicate actionable keys, missing mandatory keys and wrong
-- classes are errors (GDD 12.3). Instances under a template are row content and are not bound globally.
function UIContract.validate(root: Instance): ({ [string]: Instance }, { string })
	local errors = {}
	if root:GetAttribute("ContractVersion") ~= UIContract.ContractVersion then
		table.insert(errors, "root ContractVersion must be " .. UIContract.ContractVersion)
	end
	local found: { [string]: Instance } = {}
	local templates: { Instance } = {}
	for _, d in root:GetDescendants() do
		local key = d:GetAttribute("UIKey")
		if type(key) == "string" then
			local insideTemplate = false
			for _, tpl in templates do
				if d:IsDescendantOf(tpl) then
					insideTemplate = true
					break
				end
			end
			if not insideTemplate then
				if found[key] then
					table.insert(errors, "duplicate UIKey " .. key)
				else
					found[key] = d
				end
				local kind = UIContract.Mandatory[key] or UIContract.Optional[key]
				if kind == "template" then
					table.insert(templates, d)
				end
			end
		end
	end
	for key, kind in UIContract.Mandatory do
		local inst = found[key]
		if not inst then
			table.insert(errors, "missing mandatory UIKey " .. key)
		elseif not classOk(inst, kind) then
			table.insert(errors, string.format("UIKey %s is a %s, expected %s", key, inst.ClassName, kind))
		end
	end
	for key, kind in UIContract.Optional do
		local inst = found[key]
		if inst and not classOk(inst, kind) then
			table.insert(errors, string.format("UIKey %s is a %s, expected %s", key, inst.ClassName, kind))
		end
	end
	table.sort(errors)
	return found, errors
end

return UIContract
