-- ARENA VOLLEYBALL (client): menus, HUD, camera, animations and controls.
-- The server copies this script to every player; you don't need to move it.

if _G.ArenaVolleyballClient then
	return
end
_G.ArenaVolleyballClient = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("ArenaVolleyball")
local remote = shared:WaitForChild("Remote")
local Config = require(shared:WaitForChild("Config"))
local Teams = require(shared:WaitForChild("Teams"))

local C = shared:GetAttribute("Center")
while not C do
	task.wait(0.1)
	C = shared:GetAttribute("Center")
end
local GY = C.Y
local G = Config.GRAVITY
local R = Config.BALL_RADIUS
local REACH = Config.REACH
local FLOOR = GY + R
local HALF_L = Config.COURT_LENGTH / 2
local HALF_W = Config.COURT_WIDTH / 2

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- your choices from the settings screen
-- camera: "broadcast" (TV-style) or "player" (Roblox's camera behind you, with shift lock)
-- control: "switch" to control any teammate, "lock" to stay one player all match
local settings = { camera = "broadcast", aimMarker = true, radar = true, hints = true, control = "switch", autoSwitch = true, assist = true }

---------------------------------------------------------------- look: colours and fonts

-- a calm navy base with one bright accent (teal) and coral for the opponent
local COL = {
	bg1 = Color3.fromRGB(16, 24, 46),
	bg2 = Color3.fromRGB(8, 12, 26),
	panel = Color3.fromRGB(21, 31, 58),
	panelHi = Color3.fromRGB(34, 49, 88),
	line = Color3.fromRGB(78, 98, 150),
	teal = Color3.fromRGB(46, 222, 192),
	cyan = Color3.fromRGB(226, 236, 255),
	pink = Color3.fromRGB(255, 84, 140),
	coral = Color3.fromRGB(255, 108, 96),
	violet = Color3.fromRGB(84, 124, 255),
	lime = Color3.fromRGB(176, 232, 104),
	text = Color3.fromRGB(240, 244, 252),
	dim = Color3.fromRGB(146, 160, 196),
	ink = Color3.fromRGB(10, 14, 28),
	win = Color3.fromRGB(64, 204, 120),
	loss = Color3.fromRGB(232, 72, 80),
	gold = Color3.fromRGB(255, 198, 66),
}

local function family(name, weight)
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight)
end
local FONT = {
	title = family("BuilderSans", Enum.FontWeight.Bold),
	head = family("BuilderSans", Enum.FontWeight.Medium),
	body = family("BuilderSans", Enum.FontWeight.Regular),
	num = family("Oswald", Enum.FontWeight.Medium),
}

---------------------------------------------------------------- UI building blocks

local function make(class, props, parent)
	local o = Instance.new(class)
	for key, value in props do
		o[key] = value
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function text(props, parent)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.TextColor3 = COL.text
	l.FontFace = FONT.body
	l.TextSize = 14
	l.Text = ""
	for key, value in props do
		l[key] = value
	end
	l.Parent = parent
	return l
end

local function frame(props, parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = COL.panel
	for key, value in props do
		f[key] = value
	end
	f.Parent = parent
	return f
end

local function button(props, parent)
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	for key, value in props do
		b[key] = value
	end
	b.Parent = parent
	return b
end

local function round(o, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, o)
end

local function outline(o, color, thickness, transparency)
	return make("UIStroke", {
		Color = color or COL.line,
		Thickness = thickness or 1,
		Transparency = transparency or 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function gradient(o, c1, c2, rotation, t1, t2)
	return make("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rotation or 0,
		Transparency = NumberSequence.new(t1 or 0, t2 or 0),
	}, o)
end

-- the main call-to-action button: solid accent, dark label
local function primaryButton(props, parent, label, textSize)
	local b = button(props, parent)
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = COL.teal
	round(b, 8)
	local l = text({ Size = UDim2.fromScale(1, 1), Text = label, FontFace = FONT.title, TextSize = textSize or 20, TextColor3 = COL.ink, ZIndex = b.ZIndex + 1 }, b)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = COL.teal:Lerp(Color3.new(1, 1, 1), 0.25)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = COL.teal
	end)
	return b, l
end

-- a quieter button
local function secondaryButton(props, parent, label, textSize)
	local b = button(props, parent)
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = COL.panelHi
	round(b, 8)
	outline(b, COL.line, 1, 0.5)
	local l = text({ Size = UDim2.fromScale(1, 1), Text = label, FontFace = FONT.title, TextSize = textSize or 18, ZIndex = b.ZIndex + 1 }, b)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = COL.panelHi:Lerp(Color3.new(1, 1, 1), 0.12)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = COL.panelHi
	end)
	return b, l
end

---------------------------------------------------------------- drag and drop (squad screen and substitutions)
-- Drag.source(button, payload, ghost, onClick) makes a button draggable; Drag.target(gui,
-- payload) marks where it can be dropped; Drag.onDrop(from, to) is called when it is.

local Drag = { targets = setmetatable({}, { __mode = "k" }), active = nil }
Drag.gui = make("ScreenGui", { Name = "VolleyballDrag", ResetOnSpawn = false, DisplayOrder = 60, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))

function Drag.target(gui, payload)
	Drag.targets[gui] = payload
end

local function dropTargetAt(pos)
	local ok, list = pcall(function()
		return player.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
	end)
	if not ok then
		return nil
	end
	for _, obj in list do
		local node = obj
		while node and node ~= player.PlayerGui do
			local payload = Drag.targets[node]
			if payload ~= nil and node.Visible then
				return payload
			end
			node = node.Parent
		end
	end
	return nil
end

function Drag.source(gui, payload, makeGhost, onClick, onDrop)
	gui.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		Drag.active = { gui = gui, payload = payload, start = Vector2.new(input.Position.X, input.Position.Y), makeGhost = makeGhost, onClick = onClick, onDrop = onDrop, input = input }
	end)
end

UserInputService.InputChanged:Connect(function(input)
	local d = Drag.active
	if not d or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if not d.ghost and (pos - d.start).Magnitude > 8 then
		d.ghost = d.makeGhost and d.makeGhost() or frame({ Size = UDim2.fromOffset(60, 60), BackgroundColor3 = COL.teal }, nil)
		d.ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		d.ghost.ZIndex = 50
		d.ghost.Parent = Drag.gui
	end
	if d.ghost then
		d.ghost.Position = UDim2.fromOffset(pos.X, pos.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local d = Drag.active
	if not d or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
		return
	end
	Drag.active = nil
	if d.ghost then
		d.ghost:Destroy()
		local target = dropTargetAt(Vector2.new(input.Position.X, input.Position.Y))
		if target ~= nil and d.onDrop then
			d.onDrop(d.payload, target)
		end
	elseif d.onClick then
		d.onClick(d.payload)
	end
end)

-- dark text on light colours, white on dark ones
local function contrast(color)
	return (color.R * 0.3 + color.G * 0.59 + color.B * 0.11) > 0.62 and COL.ink or Color3.new(1, 1, 1)
end

-- a straight line between two pixel points inside a frame
local function lineBetween(parent, a, b, thickness, color, transparency)
	local d = b - a
	return frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.fromOffset(d.Magnitude, thickness),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
	}, parent)
end

-- team crest: a roundel in the club colours with its short name
local function badge(parent, teamId, size, pos, anchor)
	local def = Teams.list[teamId]
	local b = frame({
		Size = UDim2.fromOffset(size, size),
		Position = pos or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = def.primary,
	}, parent)
	round(b, size)
	make("UIStroke", { Color = def.secondary, Thickness = math.max(2, math.floor(size * 0.07)) }, b)
	local ring = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.74, 0.74), BackgroundTransparency = 1 }, b)
	round(ring, size)
	make("UIStroke", { Color = contrast(def.primary), Thickness = 1, Transparency = 0.55 }, ring)
	text({ Size = UDim2.fromScale(1, 1), Text = def.short, FontFace = FONT.title, TextSize = math.max(10, math.floor(size * 0.3)), TextColor3 = contrast(def.primary) }, b)
	return b
end

-- a shirt in a colour with a number on it
local function shirt(parent, color, number, size, pos)
	local holder = frame({ Size = UDim2.fromOffset(size, size), Position = pos, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, parent)
	for _, sx in { -1, 1 } do
		local sleeve = frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5 + sx * 0.33, 0, 0.06, 0),
			Size = UDim2.fromScale(0.28, 0.34),
			Rotation = sx * 30,
			BackgroundColor3 = color,
		}, holder)
		round(sleeve, 3)
	end
	local body = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.56, 0.92), BackgroundColor3 = color }, holder)
	round(body, math.max(2, math.floor(size * 0.08)))
	local collar = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.4, 0.1), BackgroundColor3 = COL.ink, BackgroundTransparency = 0.35 }, body)
	round(collar, 6)
	text({ Position = UDim2.fromScale(0, 0.12), Size = UDim2.fromScale(1, 0.8), Text = tostring(number), FontFace = FONT.num, TextSize = math.max(9, math.floor(size * 0.42)), TextColor3 = contrast(color) }, body)
	return holder
end

-- five stars, filled in halves
local function starRow(parent, stars, size, pos, anchor)
	local holder = frame({ Size = UDim2.fromOffset(size * 5, size), Position = pos, AnchorPoint = anchor or Vector2.zero, BackgroundTransparency = 1 }, parent)
	for i = 1, 5 do
		local cell = frame({ Position = UDim2.fromOffset((i - 1) * size, 0), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, holder)
		text({ Size = UDim2.fromScale(1, 1), Text = "★", TextSize = size, TextColor3 = COL.dim, TextTransparency = 0.6 }, cell)
		local fill = math.clamp(stars - (i - 1), 0, 1)
		if fill > 0 then
			local clip = frame({ Size = UDim2.new(fill, 0, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true }, cell)
			text({ Size = UDim2.fromOffset(size, size), Text = "★", TextSize = size, TextColor3 = COL.gold }, clip)
		end
	end
	return holder
end

-- a bar coloured by how high the value is, like a ratings bar
local function ratingColor(v)
	if v >= 80 then
		return Color3.fromRGB(70, 210, 90)
	elseif v >= 70 then
		return Color3.fromRGB(170, 220, 70)
	elseif v >= 60 then
		return Color3.fromRGB(240, 200, 60)
	elseif v >= 50 then
		return Color3.fromRGB(245, 140, 60)
	end
	return Color3.fromRGB(235, 70, 70)
end

local function ordinal(n)
	local suffix = "TH"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "ST", "ND", "RD" })[n % 10] or "TH"
	end
	return n .. suffix
end

---------------------------------------------------------------- ball, shadow and markers (only you see these)

local world = Instance.new("Folder")
world.Name = "VolleyballLocal"
world.Parent = workspace

local function worldPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		p[key] = value
	end
	p.Parent = world
	return p
end

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder into a disc on the floor

local Ball = {}
Ball.part = worldPart({ Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.one * (R * 2), Color = Color3.fromRGB(255, 214, 64), CastShadow = true })
-- two blue bands so you can see the ball spin
Ball.bands = {}
Ball.BAND_OFFSET = { CFrame.new(), CFrame.Angles(0, math.pi / 2, 0) }
for i = 1, 2 do
	Ball.bands[i] = worldPart({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, R * 2 + 0.03, R * 2 + 0.03), Color = Color3.fromRGB(40, 90, 210) })
end
Ball.shadow = worldPart({ Name = "BallShadow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, 2, 2), Color = Color3.new(0, 0, 0), Transparency = 0.6 })
Ball.marker = worldPart({ Name = "LandingMarker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 3.4, 3.4), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 1 })
Ball.aim = worldPart({ Name = "AimMarker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 1.6, 1.6), Material = Enum.Material.Neon, Transparency = 1 })
-- a streak behind fast balls (gold for power shots)
do
	local top = make("Attachment", { Position = Vector3.new(0, R * 0.8, 0) }, Ball.part)
	local bottom = make("Attachment", { Position = Vector3.new(0, -R * 0.8, 0) }, Ball.part)
	Ball.trail = make("Trail", {
		Attachment0 = top,
		Attachment1 = bottom,
		Lifetime = 0.22,
		LightEmission = 0.6,
		Transparency = NumberSequence.new(0.2, 1),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Enabled = false,
	}, Ball.part)
end
Ball.glow = make("Highlight", {
	Adornee = Ball.part,
	FillTransparency = 1,
	OutlineColor = Color3.new(1, 1, 1),
	OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Enabled = false,
}, Ball.part)

local function burst(pos, color, size)
	local p = worldPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(pos), Color = color, Material = Enum.Material.Neon, Transparency = 0.35 })
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	task.delay(0.35, function()
		p:Destroy()
	end)
end

local function ripple(pos, color)
	local p = worldPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 1, 1),
		CFrame = CFrame.new(pos.X, GY + 0.06, pos.Z) * FLAT,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, 7, 7), Transparency = 1 }):Play()
	task.delay(0.55, function()
		p:Destroy()
	end)
end

---------------------------------------------------------------- what the server tells us

local state = {
	active = false,
	phase = "idle",
	score = { 0, 0 },
	sets = { 0, 0 },
	serving = 1,
	server = 0,
	serverTeam = 0,
	serverIndex = 0,
	touches = 0,
	touchTeam = 0,
	roster = { {}, {} },
	deadline = 0,
	serveIndex = { 1, 0 },
	teamIds = { 1, 2 },
	lineups = { Teams.defaultLineup(), Teams.defaultLineup() },
	points = Config.POINTS_TO_WIN,
	setsToWin = Config.SETS_TO_WIN,
	teamSize = Config.TEAM_SIZE,
}
local ballState = { id = 0, mode = "hidden", p0 = C, v0 = Vector3.zero, t0 = 0, rest = C }
local lastTouch = { team = 0, index = 0 } -- who played the ball last, for the HUD

local inMenu = true
local openMenu, closeMenu -- defined with the menus

local function myEntry()
	for t = 1, 2 do
		for _, e in state.roster[t] or {} do
			if e.id == player.UserId then
				return e, t
			end
		end
	end
	return nil, 0
end

-- your team: from the list of people playing (you always control someone on it)
local function myTeam()
	local ctrl = state.controls and state.controls[tostring(player.UserId)]
	if ctrl then
		return ctrl.team
	end
	local _, t = myEntry()
	return t
end

local function myControl()
	return state.controls and state.controls[tostring(player.UserId)]
end

local function entryAt(team, index)
	for _, e in state.roster[team] or {} do
		if e.index == index then
			return e
		end
	end
	return nil
end

local function teamDef(team)
	return Teams.list[state.teamIds[team] or team] or Teams.list[1]
end

local function myServe()
	return state.phase == "serve" and state.server == player.UserId
end

-- the body you're controlling right now (never your own character during a match)
local function controlledModel()
	local e = myEntry()
	local model = e and e.model
	if model and model.Parent then
		return model
	end
	return nil
end

local function character()
	local model = controlledModel()
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	return hum, hrp
end

local function airborne(hum)
	return hum ~= nil and hum.FloorMaterial == Enum.Material.Air
end

local function ballAt(t)
	if state.paused and state.pausedAt then
		t = math.min(t, state.pausedAt) -- frozen while the match is paused
	end
	if ballState.mode == "fly" then
		local dt = math.max(t - ballState.t0, 0)
		local p = ballState.p0 + ballState.v0 * dt + Vector3.new(0, -0.5 * G * dt * dt, 0)
		if p.Y < FLOOR then
			p = Vector3.new(p.X, FLOOR, p.Z)
		end
		return p
	elseif ballState.mode == "hold" then
		local holder = ballState.holder
		local hrp = holder and holder.Parent and holder:FindFirstChild("HumanoidRootPart")
		if hrp then
			return (hrp.CFrame * CFrame.new(0.5, 0.4, -1.4)).Position
		end
	end
	return ballState.rest
end

local function landingPoint()
	local p0, v0 = ballState.p0, ballState.v0
	local disc = v0.Y * v0.Y + 2 * G * (p0.Y - FLOOR)
	if disc < 0 then
		return nil
	end
	local s = (v0.Y + math.sqrt(disc)) / G
	return p0 + v0 * s + Vector3.new(0, -0.5 * G * s * s, 0)
end

local lastInput = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "touch" or "kbm"
UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if inputType == Enum.UserInputType.Touch then
		lastInput = "touch"
	elseif string.find(inputType.Name, "Gamepad") then
		lastInput = "pad"
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		lastInput = "kbm"
	end
end)
