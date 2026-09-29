-- Development/test gate (GDD 11.5, SEC-01). Dev behaviour exists only when BOTH are true:
--   * running in Roblox Studio, and
--   * the Dev folder is present (it is excluded from production.project.json builds).
-- No remote ever exposes dev controls to clients; overrides are applied server-side by test harness code only.

local RunService = game:GetService("RunService")

local DevGate = {}

local overrides: { [string]: any } = {}

function DevGate.enabled(): boolean
	return RunService:IsStudio() and script.Parent:FindFirstChild("Dev") ~= nil
end

-- Returns a dev override value, or `default` when dev mode is off or no override is set.
function DevGate.get(key: string, default: any): any
	if not DevGate.enabled() then
		return default
	end
	local v = overrides[key]
	if v == nil then
		return default
	end
	return v
end

-- Sets an override. Refuses (returns false) outside dev mode, so production code paths can never be altered.
function DevGate.set(key: string, value: any): boolean
	if not DevGate.enabled() then
		return false
	end
	overrides[key] = value
	return true
end

function DevGate.clear()
	table.clear(overrides)
end

function DevGate.devFolder(): Instance?
	if not DevGate.enabled() then
		return nil
	end
	return script.Parent:FindFirstChild("Dev")
end

return DevGate
