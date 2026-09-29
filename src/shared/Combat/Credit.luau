--!strict
-- Pure elimination credit (GDD 06.3). The damage log holds entries { attacker: any?, amount, t, weapon } where
-- attacker is an opaque key (a Player on the server, any value in tests) and nil means environmental damage.
--   * The final damaging enemy is credited.
--   * Environmental eliminations credit the most recent enemy hit within `envWindow` seconds, else nobody.
--   * An assist needs at least `assistMin` damage from another enemy within `assistWindow` seconds.
-- `isEnemy(attacker)` filters friendly/self keys (no friendly fire exists, but the log is defensive).

local Credit = {}

export type Entry = { attacker: any?, amount: number, t: number, weapon: string? }

function Credit.resolve(
	log: { Entry },
	now: number,
	finalAttacker: any?,
	finalWeapon: string?,
	isEnemy: (any) -> boolean,
	cfg: { AssistMinimumDamage: number, AssistWindowSeconds: number, EnvironmentalCreditWindowSeconds: number }
): (any?, string?, { any })
	local credited = finalAttacker
	local weapon = finalWeapon
	if credited == nil then
		for k = #log, 1, -1 do
			local e = log[k]
			if e.attacker ~= nil and isEnemy(e.attacker) and now - e.t <= cfg.EnvironmentalCreditWindowSeconds then
				credited = e.attacker
				weapon = e.weapon
				break
			end
		end
	elseif not isEnemy(credited) then
		credited = nil
	end
	local totals: { [any]: number } = {}
	local order: { any } = {}
	for _, e in log do
		local a = e.attacker
		if a ~= nil and a ~= credited and isEnemy(a) and now - e.t <= cfg.AssistWindowSeconds then
			if totals[a] == nil then
				totals[a] = 0
				table.insert(order, a)
			end
			totals[a] += e.amount
		end
	end
	local assists = {}
	for _, a in order do
		if totals[a] >= cfg.AssistMinimumDamage then
			table.insert(assists, a)
		end
	end
	return credited, weapon, assists
end

return Credit
