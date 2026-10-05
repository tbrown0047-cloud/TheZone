-- ARENA VOLLEYBALL (server)
-- Builds the court, runs the rules, the ball and the AI players.
-- Settings are in the Config module next to this script.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local pack = script.Parent
local Config = require(pack:WaitForChild("Config"))
local clientTemplate = pack:WaitForChild("Client")

if ReplicatedStorage:FindFirstChild("ArenaVolleyball") then
	warn("[Arena Volleyball] Another copy is already running. Delete the extra ArenaVolleyball.")
	return
end

local TEAM_SIZE = math.clamp(math.floor(Config.TEAM_SIZE or 6), 1, 6)
local HALF_L = Config.COURT_LENGTH / 2
local HALF_W = Config.COURT_WIDTH / 2
local NET_H = Config.NET_HEIGHT
local G = Config.GRAVITY
local R = Config.BALL_RADIUS
local REACH = Config.REACH
local ATTACK_H = NET_H + 2 -- height a spike is hit at
local LEVEL = math.clamp(math.floor(Config.AI_LEVEL or 2), 1, 3)

-- How each AI level plays
local AI = ({
	{ speed = 14, react = 0.38, quality = 0.55, spike = 54, blockTry = 0.3, blockWin = 0.4, letGo = 0.4, serveLo = 0.35, serveHi = 0.7, margin = 4.5, fault = 0.07, attackErr = 0.16, shank = 0.1, jumpServe = 0.1 },
	{ speed = 17, react = 0.24, quality = 0.72, spike = 66, blockTry = 0.55, blockWin = 0.55, letGo = 0.75, serveLo = 0.45, serveHi = 0.82, margin = 3, fault = 0.04, attackErr = 0.09, shank = 0.05, jumpServe = 0.3 },
	{ speed = 20, react = 0.14, quality = 0.88, spike = 78, blockTry = 0.8, blockWin = 0.65, letGo = 0.92, serveLo = 0.55, serveHi = 0.9, margin = 1.8, fault = 0.025, attackErr = 0.05, shank = 0.02, jumpServe = 0.5 },
})[LEVEL]

local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

-- Team 1 plays on the +Z half, team 2 on the -Z half
local function side(team)
	return team == 1 and 1 or -1
end

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Match state shared by every part of this script
local phase = "waiting" -- waiting, serve, rally, point, setover, matchover
local servingTeam = 1
local serveAt, serveDeadline, phaseUntil = 0, 0, 0
local sendState, sendBall, currentServer, setupServe -- defined further down

---------------------------------------------------------------- court

local function findGround(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	local hit = workspace:Raycast(pos + Vector3.new(0, 150, 0), Vector3.new(0, -300, 0), params)
	return hit and hit.Position.Y or pos.Y
end

local courtFolder = Instance.new("Folder")
courtFolder.Name = "VolleyballCourt"

local base = Config.COURT_CENTER
local groundY = findGround(base)
local GY = groundY + 0.44 -- top of the playing surface
local C = Vector3.new(base.X, GY, base.Z) -- centre of the court, on the floor

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.CanCollide ~= nil then
		p.CanCollide = props.CanCollide -- before CanQuery, which needs it off
	end
	for key, value in props do
		p[key] = value
	end
	p.Parent = courtFolder
	return p
end

-- floor: blue free zone around an orange court
part({
	Name = "FreeZone",
	Size = Vector3.new(Config.COURT_WIDTH + 36, 0.4, Config.COURT_LENGTH + 46), -- 5 m at the sides, 6.5 m at the ends
	CFrame = CFrame.new(C.X, groundY + 0.2, C.Z),
	Color = Color3.fromRGB(34, 74, 128),
})
part({
	Name = "Court",
	Size = Vector3.new(Config.COURT_WIDTH, 0.44, Config.COURT_LENGTH),
	CFrame = CFrame.new(C.X, groundY + 0.22, C.Z),
	Color = Color3.fromRGB(214, 128, 62),
})

local LINE = Color3.fromRGB(245, 245, 245)
local function line(name, size, offset, transparency)
	part({
		Name = name,
		Size = size,
		CFrame = CFrame.new(C + offset),
		Color = LINE,
		Transparency = transparency or 0,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
end
line("SideLine", Vector3.new(0.35, 0.06, Config.COURT_LENGTH + 0.35), Vector3.new(-HALF_W, 0, 0))
line("SideLine", Vector3.new(0.35, 0.06, Config.COURT_LENGTH + 0.35), Vector3.new(HALF_W, 0, 0))
line("EndLine", Vector3.new(Config.COURT_WIDTH + 0.35, 0.06, 0.35), Vector3.new(0, 0, -HALF_L))
line("EndLine", Vector3.new(Config.COURT_WIDTH + 0.35, 0.06, 0.35), Vector3.new(0, 0, HALF_L))
line("CentreLine", Vector3.new(Config.COURT_WIDTH, 0.06, 0.3), Vector3.zero)
local attack = Config.COURT_LENGTH / 6
line("AttackLine", Vector3.new(Config.COURT_WIDTH, 0.06, 0.3), Vector3.new(0, 0, attack), 0.35)
line("AttackLine", Vector3.new(Config.COURT_WIDTH, 0.06, 0.3), Vector3.new(0, 0, -attack), 0.35)

-- net, posts and antennas
for _, sx in { -1, 1 } do
	part({
		Name = "Post",
		Size = Vector3.new(0.6, NET_H + 1.5, 0.6),
		CFrame = CFrame.new(C.X + sx * (HALF_W + 3.6), GY + (NET_H + 1.5) / 2, C.Z),
		Color = Color3.fromRGB(60, 64, 72),
		Material = Enum.Material.Metal,
	})
	part({
		Name = "Antenna",
		Size = Vector3.new(0.18, 6.5, 0.18), -- 1.8 m, 0.8 m above the tape
		CFrame = CFrame.new(C.X + sx * HALF_W, GY + NET_H - 0.35, C.Z),
		Color = Color3.fromRGB(230, 60, 60),
		CanCollide = false,
		CastShadow = false,
	})
end
part({
	Name = "Net",
	Size = Vector3.new(Config.COURT_WIDTH + 6.5, 3.6, 0.12), -- 1 m tall mesh
	CFrame = CFrame.new(C.X, GY + NET_H - 2, C.Z),
	Color = Color3.fromRGB(235, 235, 235),
	Material = Enum.Material.Fabric,
	Transparency = 0.55,
	CastShadow = false,
})
part({
	Name = "NetBand",
	Size = Vector3.new(Config.COURT_WIDTH + 6.5, 0.4, 0.18),
	CFrame = CFrame.new(C.X, GY + NET_H - 0.2, C.Z),
	Color = Color3.fromRGB(250, 250, 250),
	CastShadow = false,
})
-- invisible wall so nobody walks or jumps onto the other side
part({
	Name = "Divider",
	Size = Vector3.new(Config.COURT_WIDTH + 60, 40, 0.6),
	CFrame = CFrame.new(C.X, GY + 20, C.Z),
	Transparency = 1,
	CastShadow = false,
})

---------------------------------------------------------------- shared objects for the client

local shared = Instance.new("Folder")
shared.Name = "ArenaVolleyball"
shared:SetAttribute("Center", C)
local remote = Instance.new("RemoteEvent")
remote.Name = "Remote"
remote.Parent = shared
local configCopy = pack.Config:Clone()
configCopy.Parent = shared
shared.Parent = ReplicatedStorage
courtFolder.Parent = workspace
