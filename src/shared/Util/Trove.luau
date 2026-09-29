--!strict
-- Lifecycle ownership (GDD 11.5): everything a system creates is registered here and disposed exactly once.
-- Supports RBXScriptConnections, Instances, threads (cancelled only if still suspended), cleanup functions and
-- nested troves.

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable({} :: { items: { any }, destroyed: boolean }, Trove))

function Trove.new(): Trove
	return setmetatable({ items = {}, destroyed = false }, Trove)
end

function Trove.add<T>(self: Trove, item: T): T
	if self.destroyed then
		Trove.cleanItem(item)
		return item
	end
	table.insert(self.items, item)
	return item
end

function Trove.connect(self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	return self:add(signal:Connect(fn))
end

function Trove.extend(self: Trove): Trove
	local child = Trove.new()
	self:add(child)
	return child
end

function Trove.cleanItem(item: any)
	local t = typeof(item)
	if t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		item:Destroy()
	elseif t == "function" then
		item()
	elseif t == "thread" then
		if coroutine.status(item) == "suspended" then
			pcall(task.cancel, item)
		end
	elseif t == "table" then
		if getmetatable(item) == Trove then
			item:destroy()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.destroy) == "function" then
			item:destroy()
		end
	end
end

function Trove.clean(self: Trove)
	local items = self.items
	self.items = {}
	for i = #items, 1, -1 do
		Trove.cleanItem(items[i])
	end
end

function Trove.destroy(self: Trove)
	self:clean()
	self.destroyed = true
end

return Trove
