-- ARENA VOLLEYBALL teams: the twelve clubs of the Arena League and their squads.
-- Squads are generated from fixed seeds, so the server and every player see the
-- same names, numbers and ratings.
local Teams = {}

Teams.LEAGUE = "ARENA LEAGUE"
Teams.STARTERS = 6
Teams.SQUAD_SIZE = 12 -- six starters, the libero and five on the bench

Teams.ROLES = {
	S = "SETTER",
	OH = "OUTSIDE HITTER",
	MB = "MIDDLE BLOCKER",
	OPP = "OPPOSITE",
	L = "LIBERO",
}
Teams.ATTRS = { "SRV", "ATK", "BLK", "REC", "SET", "PHY" }
Teams.ATTR_NAMES = { SRV = "Serve", ATK = "Attack", BLK = "Block", REC = "Reception", SET = "Setting", PHY = "Athleticism" }

Teams.list = {
	{ name = "ARENA CITY", short = "ACV", primary = Color3.fromRGB(60, 130, 255), secondary = Color3.fromRGB(16, 26, 64), rating = 86 },
	{ name = "NORTHPORT TITANS", short = "NPT", primary = Color3.fromRGB(220, 50, 60), secondary = Color3.fromRGB(245, 245, 245), rating = 84 },
	{ name = "LAKESIDE RAVENS", short = "LKR", primary = Color3.fromRGB(125, 75, 205), secondary = Color3.fromRGB(22, 20, 32), rating = 82 },
	{ name = "REDHILL ROCKETS", short = "RHR", primary = Color3.fromRGB(255, 120, 30), secondary = Color3.fromRGB(28, 28, 32), rating = 80 },
	{ name = "COASTAL WAVES", short = "CWV", primary = Color3.fromRGB(20, 180, 170), secondary = Color3.fromRGB(240, 250, 250), rating = 78 },
	{ name = "IRON VALLEY", short = "IRV", primary = Color3.fromRGB(112, 118, 128), secondary = Color3.fromRGB(250, 205, 40), rating = 76 },
	{ name = "SUMMIT HAWKS", short = "SMH", primary = Color3.fromRGB(40, 160, 80), secondary = Color3.fromRGB(240, 240, 240), rating = 74 },
	{ name = "HARBOR KINGS", short = "HBK", primary = Color3.fromRGB(230, 180, 40), secondary = Color3.fromRGB(20, 30, 70), rating = 72 },
	{ name = "METRO STRIKERS", short = "MTS", primary = Color3.fromRGB(215, 40, 150), secondary = Color3.fromRGB(22, 22, 26), rating = 70 },
	{ name = "SUNSET SPIKERS", short = "SSP", primary = Color3.fromRGB(255, 100, 90), secondary = Color3.fromRGB(70, 30, 110), rating = 68 },
	{ name = "GLACIER BEARS", short = "GLB", primary = Color3.fromRGB(150, 210, 255), secondary = Color3.fromRGB(250, 250, 255), rating = 66 },
	{ name = "VOLT UNITED", short = "VLT", primary = Color3.fromRGB(250, 225, 30), secondary = Color3.fromRGB(22, 22, 22), rating = 64 },
}

local FIRST = {
	"Lucas", "Mateo", "Kai", "Leon", "Noah", "Hugo", "Ivan", "Marco", "Tomas", "Luca",
	"Elias", "Yuki", "Rafael", "Jonas", "Omar", "Diego", "Felix", "Theo", "Nikola", "Arturo",
	"Sami", "Bruno", "Ezra", "Mikael", "Andre", "Dario", "Kenji", "Viktor", "Pablo", "Emil",
	"Jules", "Tariq", "Aaron", "Milan", "Oscar", "Ruben", "Stefan", "Kofi", "Lars", "Enzo",
}
local LAST = {
	"Silva", "Kato", "Novak", "Reyes", "Okafor", "Lindqvist", "Moreau", "Park", "Rossi", "Haddad",
	"Ivanov", "Costa", "Bauer", "Kowalski", "Tanaka", "Fischer", "Duarte", "Petrov", "Laurent", "Nakamura",
	"Jensen", "Moretti", "Ferreira", "Sato", "Horvat", "Andersen", "Rivera", "Dubois", "Kaya", "Santos",
	"Wagner", "Popescu", "Mendes", "Yilmaz", "Bianchi", "Larsen", "Ortiz", "Mazur", "Hoffmann", "Vargas",
	"Ricci", "Nowak", "Takahashi", "Leclerc", "Sorensen", "Marin", "Kruger", "Abe", "Castillo", "Volkov",
}

-- The starting six in rotation order (position 1 first: a 5-1 system), the libero, then the bench
local SQUAD_ROLES = { "S", "OH", "MB", "OPP", "OH", "MB", "L", "S", "OH", "MB", "OPP", "L" }

-- How each role differs from the club's rating
local TEMPLATE = {
	S = { SRV = -2, ATK = -10, BLK = -6, REC = -2, SET = 10, PHY = 0 },
	OH = { SRV = 2, ATK = 6, BLK = -2, REC = 4, SET = -12, PHY = 2 },
	MB = { SRV = -4, ATK = 3, BLK = 9, REC = -14, SET = -16, PHY = 4 },
	OPP = { SRV = 5, ATK = 9, BLK = 2, REC = -10, SET = -14, PHY = 3 },
	L = { SRV = -18, ATK = -25, BLK = -25, REC = 12, SET = 0, PHY = 2 },
}
-- What counts towards a player's overall, by role
local WEIGHTS = {
	S = { SRV = 1, ATK = 0.5, BLK = 1, REC = 1, SET = 4, PHY = 1 },
	OH = { SRV = 1, ATK = 3, BLK = 1, REC = 2.5, SET = 0.3, PHY = 1.2 },
	MB = { SRV = 0.8, ATK = 2, BLK = 3.5, REC = 0.3, SET = 0.2, PHY = 1.2 },
	OPP = { SRV = 1.5, ATK = 3.5, BLK = 1.5, REC = 0.5, SET = 0.2, PHY = 1.2 },
	L = { SRV = 0.2, ATK = 0, BLK = 0, REC = 4, SET = 1.5, PHY = 1 },
}

Teams.TEMPLATE = TEMPLATE
Teams.ROLE_ORDER = { "S", "OH", "MB", "OPP", "L" }

-- Small exact random generator (same results everywhere)
local function roller(seed)
	local state = seed % 2147483646 + 1
	return function(lo, hi)
		state = (state * 16807) % 2147483647
		return lo + state % (hi - lo + 1)
	end
end

function Teams.overall(role, attrs)
	local total, weight = 0, 0
	for attr, w in WEIGHTS[role] do
		total += attrs[attr] * w
		weight += w
	end
	return math.floor(total / weight + 0.5)
end

local cache = {}
-- Twelve players: { first, last, number, role, attrs, ovr, hand }
function Teams.squad(id)
	if cache[id] then
		return cache[id]
	end
	local team = Teams.list[id]
	local roll = roller(id * 7919 + 13)
	local squad, usedLast, usedNumber = {}, {}, {}
	for i, role in SQUAD_ROLES do
		local last
		repeat
			last = LAST[roll(1, #LAST)]
		until not usedLast[last]
		usedLast[last] = true
		local number
		repeat
			number = roll(1, 20)
		until not usedNumber[number]
		usedNumber[number] = true
		-- role strengths lift a player's overall about 5 above his base
		local base = team.rating + (i <= 6 and -4 or -9)
		local attrs = {}
		for _, attr in Teams.ATTRS do
			attrs[attr] = math.clamp(base + TEMPLATE[role][attr] + roll(-5, 5), 35, 99)
		end
		squad[i] = {
			first = FIRST[roll(1, #FIRST)],
			last = string.upper(last),
			number = number,
			role = role,
			attrs = attrs,
			ovr = Teams.overall(role, attrs),
			hand = roll(1, 100) <= 85 and "Right" or "Left",
		}
	end
	cache[id] = squad
	return squad
end

function Teams.defaultLineup()
	return { 1, 2, 3, 4, 5, 6 }
end

-- Six different squad places from 1 to SQUAD_SIZE?
function Teams.validLineup(lineup)
	if type(lineup) ~= "table" or #lineup ~= 6 then
		return false
	end
	local seen = {}
	for i = 1, 6 do
		local v = lineup[i]
		if type(v) ~= "number" or v ~= math.floor(v) or v < 1 or v > Teams.SQUAD_SIZE or seen[v] then
			return false
		end
		seen[v] = true
	end
	return true
end

-- Average ratings of a lineup: { OVR, SRV, ATK, BLK, REC, SET, PHY }
function Teams.ratings(id, lineup)
	local squad = Teams.squad(id)
	lineup = lineup or Teams.defaultLineup()
	local sums, count, ovr = {}, 0, 0
	for _, attr in Teams.ATTRS do
		sums[attr] = 0
	end
	for _, index in lineup do
		local p = squad[index]
		if p then
			count += 1
			ovr += p.ovr
			for _, attr in Teams.ATTRS do
				sums[attr] += p.attrs[attr]
			end
		end
	end
	count = math.max(count, 1)
	local out = { OVR = math.floor(ovr / count + 0.5) }
	for _, attr in Teams.ATTRS do
		out[attr] = math.floor(sums[attr] / count + 0.5)
	end
	return out
end

-- Stars in halves from an overall: 84+ is five stars, every 3 points less is half a star
function Teams.stars(ovr)
	return math.clamp(math.floor((ovr - 66) / 3) * 0.5 + 2, 1, 5)
end

-- How good a team's AI is, 0 (weakest) to 1 (best), from its overall
function Teams.skill(ovr)
	return math.clamp((ovr - 58) / 30, 0, 1)
end

---------------------------------------------------------------- game plans: tactics and roles

-- Team tactics: the AI (and your AI teammates) play to these
Teams.TACTICS = {
	{ key = "tempo", name = "ATTACK TEMPO", options = { "HIGH", "BALANCED", "FAST" },
		info = { HIGH = "High, safe sets. Accurate, but blockers have time to get there.", BALANCED = "A mix of high and quick sets.", FAST = "Quick, flat sets that beat the block. Harder to set well." } },
	{ key = "focus", name = "SET DISTRIBUTION", options = { "OUTSIDE", "BALANCED", "MIDDLE", "OPPOSITE" },
		info = { OUTSIDE = "Most sets go to the outside hitters.", BALANCED = "The setter spreads the ball around.", MIDDLE = "Lots of quick balls to the middle blockers.", OPPOSITE = "Feed the opposite on the right side." } },
	{ key = "serve", name = "SERVE STRATEGY", options = { "SAFE", "BALANCED", "AGGRESSIVE" },
		info = { SAFE = "Get it in. Few aces, very few errors.", BALANCED = "Steady serves with some risk.", AGGRESSIVE = "Jump serves at the lines. More aces, more errors." } },
	{ key = "block", name = "BLOCKING", options = { "READ", "BALANCED", "COMMIT" },
		info = { READ = "Jump less often, but block better when they do.", BALANCED = "Block most attacks.", COMMIT = "Block everything. Strong hitters can tool the block." } },
	{ key = "defense", name = "DEFENSIVE LINE", options = { "DEEP", "BALANCED", "UP" },
		info = { DEEP = "Back row stays deep for hard spikes. Tips can drop.", BALANCED = "Standard positions.", UP = "Back row plays close to cover tips. Hard spikes get past." } },
}

-- Team roles, like captain and set pieces in football games
Teams.ROLE_SLOTS = {
	{ key = "captain", name = "CAPTAIN", info = "Lifts the whole team a little." },
	{ key = "libero", name = "LIBERO", info = "Comes on for the middle blocker in the back row." },
	{ key = "goto", name = "GO-TO HITTER", info = "Gets the most sets, and even more late in the set." },
	{ key = "quick", name = "QUICK ATTACKER", info = "The middle blocker the setter goes to for quick balls." },
}

-- Every club has its own style, so opponents play differently
function Teams.defaultTactics(id)
	local roll = roller(id * 104729 + 7)
	local out = {}
	for _, t in Teams.TACTICS do
		-- mostly balanced, with a club flavour or two
		out[t.key] = roll(1, 100) <= 55 and "BALANCED" or t.options[roll(1, #t.options)]
	end
	return out
end

local function hasRole(squad, index, roles)
	local p = squad[index]
	return p ~= nil and table.find(roles, p.role) ~= nil
end

-- Which squad players can take a team role
function Teams.eligible(id, plan, key)
	local squad = Teams.squad(id)
	local out = {}
	if key == "libero" then
		for i, p in squad do
			if p.role == "L" and not table.find(plan.lineup, i) then
				table.insert(out, i)
			end
		end
	elseif key == "captain" then
		for _, i in plan.lineup do
			table.insert(out, i)
		end
	elseif key == "goto" then
		for _, i in plan.lineup do
			if hasRole(squad, i, { "OH", "OPP", "MB" }) then
				table.insert(out, i)
			end
		end
	elseif key == "quick" then
		for _, i in plan.lineup do
			if hasRole(squad, i, { "MB" }) then
				table.insert(out, i)
			end
		end
		if #out == 0 then
			for _, i in plan.lineup do
				if hasRole(squad, i, { "OH", "OPP" }) then
					table.insert(out, i)
				end
			end
		end
	end
	return out
end

-- A full, valid game plan from whatever was sent (missing or bad parts get sensible defaults)
function Teams.cleanPlan(id, plan)
	plan = type(plan) == "table" and plan or {}
	local out = { lineup = Teams.validLineup(plan.lineup) and table.clone(plan.lineup) or Teams.defaultLineup(), tactics = {} }
	local default = Teams.defaultTactics(id)
	local tactics = type(plan.tactics) == "table" and plan.tactics or {}
	for _, t in Teams.TACTICS do
		out.tactics[t.key] = table.find(t.options, tactics[t.key]) and tactics[t.key] or default[t.key]
	end
	for _, r in Teams.ROLE_SLOTS do
		local options = Teams.eligible(id, out, r.key)
		local want = plan[r.key]
		if table.find(options, want) then
			out[r.key] = want
		else
			-- defaults: the setter captains, the best hitter is the go-to, the first middle the quick
			local best, bestOvr = options[1], -1
			for _, i in options do
				local p = Teams.squad(id)[i]
				local score = p.ovr + ((r.key == "captain" and p.role == "S") and 20 or 0)
				if score > bestOvr then
					best, bestOvr = i, score
				end
			end
			out[r.key] = best
		end
	end
	return out
end

---------------------------------------------------------------- kits, courts and perks

-- Three kits per club: home, away (colours swapped) and a darker third kit
function Teams.kits(id)
	local d = Teams.list[id]
	local p = d.primary
	return {
		{ name = "HOME", shirt = d.primary, shorts = d.secondary },
		{ name = "AWAY", shirt = d.secondary, shorts = d.primary },
		{ name = "THIRD", shirt = Color3.new(p.R * 0.35, p.G * 0.35, p.B * 0.35), shorts = Color3.new(math.min(p.R * 1.2, 1), math.min(p.G * 1.2, 1), math.min(p.B * 1.2, 1)) },
	}
end

-- how alike two colours are (0 = the same)
function Teams.colorGap(a, b)
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

-- The away side's kit: the one picked, unless it clashes with the home shirt
function Teams.awayKit(homeId, homeKit, awayId, want)
	local homeShirt = Teams.kits(homeId)[homeKit or 1].shirt
	local kits = Teams.kits(awayId)
	local order = { want or 1, 1, 2, 3 }
	for _, k in order do
		if kits[k] and Teams.colorGap(kits[k].shirt, homeShirt) > 0.45 then
			return k
		end
	end
	return 3
end

-- Court looks: free zone, court, lines and floor material
Teams.COURTS = {
	{ name = "CLASSIC", free = Color3.fromRGB(34, 74, 128), court = Color3.fromRGB(214, 128, 62), lines = Color3.fromRGB(245, 245, 245), material = "SmoothPlastic" },
	{ name = "PRO BLUE", free = Color3.fromRGB(22, 40, 92), court = Color3.fromRGB(52, 110, 200), lines = Color3.fromRGB(250, 250, 250), material = "SmoothPlastic" },
	{ name = "HARDWOOD", free = Color3.fromRGB(150, 98, 58), court = Color3.fromRGB(214, 170, 112), lines = Color3.fromRGB(255, 255, 255), material = "WoodPlanks" },
	{ name = "EMERALD", free = Color3.fromRGB(30, 70, 50), court = Color3.fromRGB(64, 150, 96), lines = Color3.fromRGB(240, 250, 240), material = "SmoothPlastic" },
	{ name = "NIGHT", free = Color3.fromRGB(14, 12, 30), court = Color3.fromRGB(40, 30, 90), lines = Color3.fromRGB(94, 242, 224), material = "Glass" },
}

-- Career perks: unlocked when an attribute reaches 80
Teams.PERKS = {
	{ attr = "SRV", name = "CANNON", info = "Your serves travel faster" },
	{ attr = "ATK", name = "HAMMER", info = "Your spikes are harder" },
	{ attr = "BLK", name = "WALL", info = "Your block covers more of the net" },
	{ attr = "REC", name = "MAGNET", info = "Cleaner passes from hard hits" },
	{ attr = "SET", name = "MAESTRO", info = "More accurate sets" },
	{ attr = "PHY", name = "SKY HIGH", info = "More reach for every touch" },
}
Teams.PERK_LEVEL = 80

function Teams.perksFor(attrs)
	local out = {}
	for _, perk in Teams.PERKS do
		if (attrs[perk.attr] or 0) >= Teams.PERK_LEVEL then
			out[perk.name] = true
		end
	end
	return out
end

-- League position by rating (1 = best)
local ranks
function Teams.rank(id)
	if not ranks then
		local order = {}
		for i = 1, #Teams.list do
			order[i] = i
		end
		table.sort(order, function(a, b)
			return Teams.ratings(a).OVR > Teams.ratings(b).OVR
		end)
		ranks = {}
		for position, teamId in order do
			ranks[teamId] = position
		end
	end
	return ranks[id] or #Teams.list
end

return Teams
