--!strict
-- Pure team formation, backfill and scoring helpers (GDD 03.2, 03.3, 03.5).

local Teams = {}

-- Deterministic 32-bit PRNG (xorshift32) so a seed reproduces the same shuffle in Roblox and Lune.
local function prng(seed: number)
	local state = bit32.bor(seed % 4294967296, 1)
	return function(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state
	end
end
Teams.prng = prng

-- Splits ready players into sides A (1) and B (2). Sizes differ by at most one; no side exceeds `cap`.
-- Players beyond 2*cap are left out (returned in `overflow`). `seed` makes the shuffle reproducible; the side that
-- receives the extra player of an odd split alternates with the seed so no one is pinned to one side.
function Teams.form(playerIds: { number }, seed: number, cap: number): ({ [number]: number }, { number })
	local ids = table.clone(playerIds)
	table.sort(ids)
	local rand = prng(seed)
	for i = #ids, 2, -1 do
		local j = (rand() % i) + 1
		ids[i], ids[j] = ids[j], ids[i]
	end
	local assignment: { [number]: number } = {}
	local overflow: { number } = {}
	local first = if seed % 2 == 0 then 1 else 2
	local second = 3 - first
	local counts = { [1] = 0, [2] = 0 }
	for index, id in ids do
		local side = if index % 2 == 1 then first else second
		if counts[side] >= cap then
			side = 3 - side
		end
		if counts[side] >= cap then
			table.insert(overflow, id)
		else
			assignment[id] = side
			counts[side] += 1
		end
	end
	return assignment, overflow
end

-- Side for a backfilling player: the smaller team; on a tie, `tieSide` (caller alternates it). nil when full.
function Teams.backfillSide(countA: number, countB: number, cap: number, tieSide: number): number?
	if countA >= cap and countB >= cap then
		return nil
	end
	if countA < countB then
		return 1
	elseif countB < countA then
		return 2
	end
	return tieSide
end

export type Score = {
	a: number,
	b: number,
	neutral: number,
	total: number,
	aPercent: number,
	bPercent: number,
	neutralPercent: number,
	winner: number?, -- 1, 2, or nil for a draw
	outcome: string, -- "A" | "B" | "Draw"
}

-- Percentages from raw integer area; the winner is decided by raw counts, never by rounded display values.
function Teams.score(a: number, b: number, total: number): Score
	assert(total > 0, "scoring denominator must be positive")
	local neutral = total - a - b
	assert(neutral >= 0, "ownership exceeds scoring area")
	local winner: number? = nil
	local outcome = "Draw"
	if a > b then
		winner, outcome = 1, "A"
	elseif b > a then
		winner, outcome = 2, "B"
	end
	local aP = 100 * a / total
	local bP = 100 * b / total
	return {
		a = a,
		b = b,
		neutral = neutral,
		total = total,
		aPercent = aP,
		bPercent = bP,
		neutralPercent = 100 - aP - bP,
		winner = winner,
		outcome = outcome,
	}
end

-- Display string with one decimal, or two when one decimal would hide a raw-count difference (GDD 03.3).
function Teams.formatPercents(score: Score): (string, string, string)
	local decimals = 1
	if score.a ~= score.b and string.format("%.1f", score.aPercent) == string.format("%.1f", score.bPercent) then
		decimals = 2
	end
	local fmt = "%." .. decimals .. "f%%"
	return string.format(fmt, score.aPercent), string.format(fmt, score.bPercent), string.format(fmt, score.neutralPercent)
end

return Teams
