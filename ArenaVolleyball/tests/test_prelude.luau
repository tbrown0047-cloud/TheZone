-- Minimal stand-ins for the Roblox pieces server_3 uses, so its maths can run in plain Luau.
local V = {}
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	return nil
end
V.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
V.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V.__tostring = function(v) return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z) end
Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)

local seed = 7
Random = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				seed = (seed * 1103515245 + 12345) % 2147483648
				local u = seed / 2147483648
				a, b = a or 0, b or 1
				return a + (b - a) * u
			end,
			NextInteger = function(_, a, b)
				seed = (seed * 1103515245 + 12345) % 2147483648
				return a + seed % (b - a + 1)
			end,
		}
	end,
}

Config = { TEAM_NAMES = { "HOME", "AWAY" }, POINTS_TO_WIN = 25, WIN_BY = 2, SETS_TO_WIN = 1 }
TEAM_SIZE, HALF_L, HALF_W, NET_H, G, R, REACH = 6, 32, 16, 8.7, 35, 0.42, 6.5
ATTACK_H = NET_H + 2
AI = { spike = 66, blockWin = 0.55 }
rng = Random.new()
CLOCK = 0
function now() return CLOCK end
function side(team) return team == 1 and 1 or -1 end
function flatDist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
phase, servingTeam, phaseUntil = "rally", 1, 0
GY = 0.44
C = Vector3.new(0, GY, 90)
EVENTS = {}
remote = {
	FireAllClients = function(_, kind, a, b, c)
		table.insert(EVENTS, { kind = kind, a = a, b = b, c = c })
	end,
	FireClient = function() end,
}
function sendState() end
function standHeight() return GY + 3 end
teams = {}
for t = 1, 2 do
	teams[t] = { slots = {}, score = 0, sets = 0, serveIndex = 1 }
	for i = 1, TEAM_SIZE do
		teams[t].slots[i] = { team = t, index = i, isAI = true, ai = {}, root = nil }
	end
end
