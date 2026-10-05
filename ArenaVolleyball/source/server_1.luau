-- ARENA VOLLEYBALL (server)
-- Builds the court, runs the rules, the ball and the AI players.
-- Settings are in the Config module next to this script.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local pack = script.Parent
local Config = require(pack:WaitForChild("Config"))
local Teams = require(pack:WaitForChild("Teams"))
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
-- How the AI plays at the bottom, middle and top of the skill range. A team's skill
-- (from its overall rating, see Teams.skill) blends between these.
local BASE_LEVELS = {
	{ speed = 14, react = 0.38, quality = 0.55, spike = 54, blockTry = 0.3, blockWin = 0.4, letGo = 0.4, serveLo = 0.35, serveHi = 0.7, margin = 4.5, fault = 0.07, attackErr = 0.16, shank = 0.1, jumpServe = 0.1 },
	{ speed = 17, react = 0.24, quality = 0.72, spike = 66, blockTry = 0.55, blockWin = 0.55, letGo = 0.75, serveLo = 0.45, serveHi = 0.82, margin = 3, fault = 0.04, attackErr = 0.09, shank = 0.05, jumpServe = 0.3 },
	{ speed = 20, react = 0.14, quality = 0.88, spike = 78, blockTry = 0.8, blockWin = 0.65, letGo = 0.92, serveLo = 0.55, serveHi = 0.9, margin = 1.8, fault = 0.025, attackErr = 0.05, shank = 0.02, jumpServe = 0.5 },
}
local function aiForSkill(skill)
	local a, b, t = BASE_LEVELS[1], BASE_LEVELS[2], skill * 2
	if skill > 0.5 then
		a, b, t = BASE_LEVELS[2], BASE_LEVELS[3], (skill - 0.5) * 2
	end
	local out = {}
	for key, value in a do
		out[key] = value + (b[key] - value) * t
	end
	return out
end
-- the menu sets these when someone starts a match
local pointsToWin = Config.POINTS_TO_WIN
local setsToWin = Config.SETS_TO_WIN

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
local phase = "idle" -- idle, setup, serve, rally, point, setover, matchover
local matchActive = false -- no match runs until someone starts one from the menu
local servingTeam = 1
local serveAt, serveDeadline, phaseUntil = 0, 0, 0
local paused, pausedAt = false, 0 -- the pause menu really stops the match
local sendState, sendBall, currentServer, setupServe, stopMatch -- defined further down
local onMatchFinished -- career and online results, defined further down
local cleanCustom -- Edit Player choices, defined further down
local serveFault -- a serve that breaks the rules, defined further down
local practice = nil -- practice arena: { drill, attempts, made } while a practice session runs

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

-- floor: blue free zone around an orange court (the look changes with Teams.COURTS)
local courtLook = { lines = {} }
courtLook.free = part({
	Name = "FreeZone",
	Size = Vector3.new(Config.COURT_WIDTH + 36, 0.4, Config.COURT_LENGTH + 46), -- 5 m at the sides, 6.5 m at the ends
	CFrame = CFrame.new(C.X, groundY + 0.2, C.Z),
	Color = Color3.fromRGB(34, 74, 128),
})
courtLook.court = part({
	Name = "Court",
	Size = Vector3.new(Config.COURT_WIDTH, 0.44, Config.COURT_LENGTH),
	CFrame = CFrame.new(C.X, groundY + 0.22, C.Z),
	Color = Color3.fromRGB(214, 128, 62),
})

local LINE = Color3.fromRGB(245, 245, 245)
local function line(name, size, offset, transparency)
	courtLook.lines[#courtLook.lines + 1] = part({
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

-- the arena: stands on all four sides full of fans, scoreboards, LED boards, the referee,
-- line judges, benches and floodlights
local stadium = { fans = {}, bench = { {}, {} }, screens = {} }
do
	local folder = Instance.new("Folder")
	folder.Name = "Stadium"
	folder.Parent = courtFolder
	local crowd = Instance.new("Folder")
	crowd.Name = "Crowd"
	crowd.Parent = folder
	local crowdRng = Random.new(7)
	local SKIN = { Color3.fromRGB(255, 220, 177), Color3.fromRGB(234, 192, 134), Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 58, 26) }
	local function piece(props, parent)
		local p = part(props)
		p.CanCollide = props.CanCollide == true
		p.CastShadow = false
		p.Parent = parent or folder
		return p
	end
	-- a simple person: body with a head on top (the head is a child so they move together)
	local function figure(pos, look, shirtColor, parent, name)
		local body = piece({ Name = name or "Figure", Size = Vector3.new(1.3, 2.1, 0.9), CFrame = CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)), Color = shirtColor, CanCollide = false, CanQuery = false, CanTouch = false }, parent)
		local head = piece({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = body.CFrame * CFrame.new(0, 1.55, 0), Color = SKIN[crowdRng:NextInteger(1, #SKIN)], CanCollide = false, CanQuery = false, CanTouch = false }, body)
		return body, head
	end
	-- a tier of stand with fans along it
	local function tier(center, size, facing, fanLine)
		piece({ Name = "Stand", Size = size, CFrame = CFrame.new(center), Color = Color3.fromRGB(46, 50, 66), Material = Enum.Material.Concrete, CanCollide = true })
		local seatTop = center.Y + size.Y / 2
		local step = 2.1
		local count = math.floor(fanLine.length / step)
		for k = 0, count - 1 do
			if crowdRng:NextNumber() < 0.82 then
				local along = -fanLine.length / 2 + (k + 0.5) * step + crowdRng:NextNumber(-0.3, 0.3)
				local pos = center + fanLine.dir * along
				pos = Vector3.new(pos.X, seatTop + 1.05, pos.Z)
				local body = figure(pos, pos + facing, Color3.fromRGB(200, 200, 210), crowd, "Fan")
				body:SetAttribute("BaseY", pos.Y)
				table.insert(stadium.fans, body)
			end
		end
	end
	-- sideline stands (6 tiers) and end stands (4 tiers)
	local sideLength = Config.COURT_LENGTH + 40
	for _, sx in { -1, 1 } do
		for t = 0, 5 do
			local height = 1.5 + t * 1.7
			local x = C.X + sx * (HALF_W + 21 + t * 3)
			tier(Vector3.new(x, groundY + height / 2, C.Z), Vector3.new(3, height, sideLength), Vector3.new(-sx, 0, 0), { length = sideLength - 2, dir = Vector3.new(0, 0, 1) })
		end
	end
	local endWidth = Config.COURT_WIDTH + 40
	for _, sz in { -1, 1 } do
		for t = 0, 4 do
			local height = 1.5 + t * 1.7
			local z = C.Z + sz * (HALF_L + 26 + t * 3)
			tier(Vector3.new(C.X, groundY + height / 2, z), Vector3.new(endWidth, height, 3), Vector3.new(0, 0, -sz), { length = endWidth - 2, dir = Vector3.new(1, 0, 0) })
		end
	end
	-- dark walls closing in the arena
	for _, sx in { -1, 1 } do
		piece({ Name = "Wall", Size = Vector3.new(2, 34, sideLength + 40), CFrame = CFrame.new(C.X + sx * (HALF_W + 41), groundY + 17, C.Z), Color = Color3.fromRGB(22, 20, 40), Material = Enum.Material.Concrete, CanCollide = true })
	end
	for _, sz in { -1, 1 } do
		piece({ Name = "Wall", Size = Vector3.new(endWidth + 50, 34, 2), CFrame = CFrame.new(C.X, groundY + 17, C.Z + sz * (HALF_L + 43)), Color = Color3.fromRGB(22, 20, 40), Material = Enum.Material.Concrete, CanCollide = true })
	end
	-- LED boards round the free zone
	local ADS = { "ARENA VOLLEYBALL", "ARENA LEAGUE", "SEASON 1", "PLAY FAIR", "ARENA LIVE" }
	local adColors = { Color3.fromRGB(94, 242, 224), Color3.fromRGB(255, 84, 204), Color3.fromRGB(255, 212, 80), Color3.fromRGB(150, 98, 255) }
	local n = 0
	local function board(cf, length)
		n += 1
		local p = piece({ Name = "LEDBoard", Size = Vector3.new(length, 2, 0.4), CFrame = cf, Color = Color3.fromRGB(12, 10, 30), CanCollide = true })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(length * 25, 50)
		gui.LightInfluence = 0
		gui.Brightness = 1.5
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(12, 10, 30)
		label.TextColor3 = adColors[n % #adColors + 1]
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = ADS[n % #ADS + 1]
		label.Parent = gui
		gui.Parent = p
	end
	for _, sx in { -1, 1 } do
		for k = -3, 3 do
			local pos = Vector3.new(C.X + sx * (HALF_W + 17.5), groundY + 1, C.Z + k * 14)
			board(CFrame.lookAt(pos, Vector3.new(C.X, pos.Y, pos.Z)), 13.6)
		end
	end
	for _, sz in { -1, 1 } do
		for k = -2, 2 do
			local pos = Vector3.new(C.X + k * 13, groundY + 1, C.Z + sz * (HALF_L + 22.5))
			board(CFrame.lookAt(pos, Vector3.new(pos.X, pos.Y, C.Z)), 12.6)
		end
	end
	-- scoreboards above both ends
	for _, sz in { -1, 1 } do
		local pos = Vector3.new(C.X, GY + 26, C.Z + sz * (HALF_L + 40))
		local screen = piece({ Name = "Scoreboard", Size = Vector3.new(30, 13, 1), CFrame = CFrame.lookAt(pos, Vector3.new(C.X, pos.Y, C.Z)), Color = Color3.fromRGB(10, 10, 20) })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(600, 260)
		gui.LightInfluence = 0
		gui.Brightness = 2
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(26, 22, 90)
		back.Parent = gui
		local top = Instance.new("TextLabel")
		top.Name = "Top"
		top.Size = UDim2.new(1, 0, 0.25, 0)
		top.BackgroundTransparency = 1
		top.TextColor3 = Color3.fromRGB(94, 242, 224)
		top.Font = Enum.Font.GothamBlack
		top.TextScaled = true
		top.Text = "ARENA VOLLEYBALL"
		top.Parent = back
		local score = Instance.new("TextLabel")
		score.Name = "Score"
		score.Position = UDim2.fromScale(0, 0.25)
		score.Size = UDim2.new(1, 0, 0.5, 0)
		score.BackgroundTransparency = 1
		score.TextColor3 = Color3.new(1, 1, 1)
		score.Font = Enum.Font.GothamBlack
		score.TextScaled = true
		score.Text = "WELCOME"
		score.Parent = back
		local bottom = Instance.new("TextLabel")
		bottom.Name = "Bottom"
		bottom.Position = UDim2.fromScale(0, 0.75)
		bottom.Size = UDim2.new(1, 0, 0.25, 0)
		bottom.BackgroundTransparency = 1
		bottom.TextColor3 = Color3.fromRGB(255, 212, 80)
		bottom.Font = Enum.Font.GothamBold
		bottom.TextScaled = true
		bottom.Text = "ARENA LEAGUE"
		bottom.Parent = back
		gui.Parent = screen
		table.insert(stadium.screens, { top = top, score = score, bottom = bottom })
	end
	-- the first referee on his stand at the net, and four line judges with flags
	local refX = C.X - (HALF_W + 5.5)
	piece({ Name = "RefereeStand", Size = Vector3.new(2.4, 5, 2.4), CFrame = CFrame.new(refX, groundY + 2.5, C.Z), Color = Color3.fromRGB(70, 74, 84), Material = Enum.Material.Metal, CanCollide = true })
	figure(Vector3.new(refX, groundY + 6.1, C.Z), Vector3.new(C.X, 0, C.Z), Color3.fromRGB(20, 20, 24), folder, "Referee")
	for _, corner in { { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } } do
		local pos = Vector3.new(C.X + corner[1] * (HALF_W + 2.5), groundY + 1.45, C.Z + corner[2] * (HALF_L + 2.5))
		local judge = figure(pos, Vector3.new(C.X, 0, C.Z), Color3.fromRGB(20, 20, 24), folder, "LineJudge")
		piece({ Name = "Flag", Size = Vector3.new(0.1, 1.2, 0.8), CFrame = judge.CFrame * CFrame.new(0.9, 0.6, 0), Color = Color3.fromRGB(240, 60, 60) }, judge)
	end
	-- both teams' benches, with the substitutes sitting on them
	for team = 1, 2 do
		local sz = team == 1 and 1 or -1
		local x = C.X + HALF_W + 9
		piece({ Name = "Bench", Size = Vector3.new(1.6, 1.2, 14), CFrame = CFrame.new(x + 0.6, groundY + 0.6, C.Z + sz * 12), Color = Color3.fromRGB(40, 44, 60), CanCollide = true })
		for k = 0, 4 do
			local pos = Vector3.new(x + 0.6, groundY + 2.15, C.Z + sz * (6.5 + k * 2.6))
			local body = figure(pos, Vector3.new(C.X, 0, pos.Z), Color3.fromRGB(120, 120, 130), folder, "Substitute")
			table.insert(stadium.bench[team], body)
		end
	end
	-- floodlights
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local lamp = part({
			Name = "Floodlight",
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.lookAt(Vector3.new(C.X + corner[1] * (HALF_W + 10), GY + 42, C.Z + corner[2] * (HALF_L - 6)), C) * CFrame.Angles(-math.pi / 2, 0, 0),
			Color = Color3.fromRGB(250, 248, 230),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Top
		light.Angle = 70
		light.Range = 60
		light.Brightness = 2
		light.Parent = lamp
	end
end

-- crowd and benches in the two clubs' colours for a match
local function dressStadium(home, away)
	local generic = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 50), Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 230), Color3.fromRGB(240, 200, 60) }
	local fanRng = Random.new(11)
	for _, fan in stadium.fans do
		local roll = fanRng:NextNumber()
		fan.Color = roll < 0.45 and home.shirt or roll < 0.7 and away.shirt or generic[fanRng:NextInteger(1, #generic)]
	end
	for team, kit in { home, away } do
		for _, body in stadium.bench[team] do
			body.Color = kit.shirt
		end
	end
end

-- the big screens show the score
local function updateScoreboards(topText, scoreText, bottomText)
	for _, screen in stadium.screens do
		screen.top.Text = topText
		screen.score.Text = scoreText
		screen.bottom.Text = bottomText
	end
end

-- the court style picked by whoever starts the match
local function applyCourtStyle(index)
	local style = Teams.COURTS[index] or Teams.COURTS[1]
	courtLook.free.Color = style.free
	courtLook.court.Color = style.court
	pcall(function()
		courtLook.court.Material = Enum.Material[style.material]
	end)
	for _, l in courtLook.lines do
		l.Color = style.lines
	end
end

-- teammates walk through each other (each team has its own collision group)
local PhysicsService = game:GetService("PhysicsService")
local TEAM_GROUPS = { "ArenaVolleyballHome", "ArenaVolleyballAway" }
pcall(function()
	for _, g in TEAM_GROUPS do
		if not PhysicsService:IsCollisionGroupRegistered(g) then
			PhysicsService:RegisterCollisionGroup(g)
		end
		PhysicsService:CollisionGroupSetCollidable(g, g, false)
	end
end)

---------------------------------------------------------------- shared objects for the client

local shared = Instance.new("Folder")
shared.Name = "ArenaVolleyball"
shared:SetAttribute("Center", C)
local remote = Instance.new("RemoteEvent")
remote.Name = "Remote"
remote.Parent = shared
local configCopy = pack.Config:Clone()
configCopy.Parent = shared
local teamsCopy = pack.Teams:Clone()
teamsCopy.Parent = shared
shared.Parent = ReplicatedStorage
courtFolder.Parent = workspace
