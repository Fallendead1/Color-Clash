--!strict
-- Ultimate meter gain with abuse limits (GDD 08.2). Pure; the server owns one instance per player life-span in a
-- match (retained across deaths, cleared at reset).
--   gain = eligibleConvertedCells / CellsPerPoint
--   at most MaxGainPerSecond points per second (token bucket)
--   the same cell credits the same player at most once per SameCellCreditCooldown seconds

local UltimateCredit = {}
UltimateCredit.__index = UltimateCredit

export type Credit = typeof(setmetatable(
	{} :: {
		cfg: any,
		meter: number,
		lastCellCredit: { [number]: number },
		budget: number,
		budgetAt: number,
		pruneAt: number,
	},
	UltimateCredit
))

function UltimateCredit.new(cfg: any, now: number): Credit
	return setmetatable({
		cfg = cfg,
		meter = 0,
		lastCellCredit = {},
		budget = cfg.MaxGainPerSecond,
		budgetAt = now,
		pruneAt = now + 10,
	}, UltimateCredit)
end

-- `globalCells` are scoring cells this player's main-weapon/gadget paint converted from neutral/enemy to friendly.
-- Returns the meter gained.
function UltimateCredit.credit(self: Credit, globalCells: { number }, now: number): number
	local cfg = self.cfg
	self.budget = math.min(cfg.MaxGainPerSecond, self.budget + (now - self.budgetAt) * cfg.MaxGainPerSecond)
	self.budgetAt = now
	local eligible = 0
	for _, cell in globalCells do
		local last = self.lastCellCredit[cell]
		if last == nil or now - last >= cfg.SameCellCreditCooldown then
			self.lastCellCredit[cell] = now
			eligible += 1
		end
	end
	local want = eligible / cfg.CellsPerPoint
	local gain = math.min(want, self.budget, cfg.Max - self.meter)
	gain = math.max(0, gain)
	self.budget -= gain
	self.meter += gain
	if now >= self.pruneAt then
		self.pruneAt = now + 10
		for cell, at in self.lastCellCredit do
			if now - at >= cfg.SameCellCreditCooldown then
				self.lastCellCredit[cell] = nil
			end
		end
	end
	return gain
end

function UltimateCredit.isFull(self: Credit): boolean
	return self.meter >= self.cfg.Max - 1e-6
end

-- Spends the full meter atomically. Returns true on success.
function UltimateCredit.spend(self: Credit): boolean
	if not self:isFull() then
		return false
	end
	self.meter = 0
	return true
end

-- Elimination retains a fraction of the unspent meter, rounded down (GDD 06.3).
function UltimateCredit.onEliminated(self: Credit, retain: number)
	self.meter = math.floor(self.meter * retain)
end

function UltimateCredit.reset(self: Credit, now: number)
	self.meter = 0
	self.lastCellCredit = {}
	self.budget = self.cfg.MaxGainPerSecond
	self.budgetAt = now
end

return UltimateCredit
