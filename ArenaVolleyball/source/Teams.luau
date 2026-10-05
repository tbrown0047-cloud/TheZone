-- ARENA VOLLEYBALL teams: the twelve clubs of the Arena League and their squads.
-- Squads are generated from fixed seeds, so the server and every player see the
-- same names, numbers and ratings.
local Teams = {}

Teams.LEAGUE = "ARENA LEAGUE"
Teams.STARTERS = 6
Teams.SQUAD_SIZE = 8 -- six starters and two on the bench

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

-- The starting six in rotation order (position 1 first: a 5-1 system), then the bench
local SQUAD_ROLES = { "S", "OH", "MB", "OPP", "OH", "MB", "OH", "L" }

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
-- Eight players: { first, last, number, role, attrs, ovr, hand }
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
