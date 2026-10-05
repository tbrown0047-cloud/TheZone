-- ARENA VOLLEYBALL (client): draws the ball, reads your controls, shows the HUD.
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
local COLORS = Config.TEAM_COLORS
local NAMES = Config.TEAM_NAMES

local function serverNow()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- ball, shadow and landing marker (only you see these)

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

local ballPart = worldPart({
	Name = "Ball",
	Shape = Enum.PartType.Ball,
	Size = Vector3.one * (R * 2),
	Color = Color3.fromRGB(255, 214, 64),
	CastShadow = true,
})
-- two blue bands so you can see the ball spin
local stripes = {}
local STRIPE_OFFSET = { CFrame.new(), CFrame.Angles(0, math.pi / 2, 0) }
for i = 1, 2 do
	stripes[i] = worldPart({
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.16, R * 2 + 0.03, R * 2 + 0.03),
		Color = Color3.fromRGB(40, 90, 210),
	})
end
local shadow = worldPart({
	Name = "BallShadow",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.04, 2, 2),
	Color = Color3.new(0, 0, 0),
	Transparency = 0.6,
})
local marker = worldPart({
	Name = "LandingMarker",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.03, 4.4, 4.4),
	Color = Color3.new(1, 1, 1),
	Material = Enum.Material.Neon,
	Transparency = 1,
})

local reachGlow = Instance.new("Highlight")
reachGlow.Adornee = ballPart
reachGlow.FillTransparency = 1
reachGlow.OutlineColor = Color3.new(1, 1, 1)
reachGlow.OutlineTransparency = 0
reachGlow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
reachGlow.Enabled = false
reachGlow.Parent = ballPart

local function burst(pos, color, size)
	local p = worldPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
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
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 7, 7),
		Transparency = 1,
	}):Play()
	task.delay(0.55, function()
		p:Destroy()
	end)
end

---------------------------------------------------------------- HUD

local PANEL = Color3.fromRGB(14, 16, 22)
local TEXT = Color3.fromRGB(240, 242, 246)
local DIM = Color3.fromRGB(150, 156, 168)
local BOLD = Enum.Font.GothamBold
local MEDIUM = Enum.Font.GothamMedium

local gui = Instance.new("ScreenGui")
gui.Name = "VolleyballHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function ui(class, props, parent)
	local o = Instance.new(class)
	for key, value in props do
		o[key] = value
	end
	o.Parent = parent
	return o
end

local function corner(o, radius)
	ui("UICorner", { CornerRadius = UDim.new(0, radius) }, o)
end

local function outline(o)
	ui("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.86, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local function label(props, parent)
	local l = ui("TextLabel", { BackgroundTransparency = 1, TextColor3 = TEXT, Font = MEDIUM, TextSize = 13, Text = "" }, parent)
	for key, value in props do
		l[key] = value
	end
	return l
end

-- scoreboard, top centre
local board = ui("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(320, 40),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, gui)
corner(board, 8)
outline(board)
ui("Frame", { Position = UDim2.new(0, 10, 1, -2), Size = UDim2.new(0.5, -10, 0, 2), BackgroundColor3 = COLORS[1], BorderSizePixel = 0 }, board)
ui("Frame", { Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(0.5, -10, 0, 2), BackgroundColor3 = COLORS[2], BorderSizePixel = 0 }, board)
local homeDot = ui("Frame", { Position = UDim2.new(0, 9, 0.5, -3), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = TEXT, BorderSizePixel = 0, Visible = false }, board)
corner(homeDot, 3)
local awayDot = ui("Frame", { Position = UDim2.new(1, -15, 0.5, -3), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = TEXT, BorderSizePixel = 0, Visible = false }, board)
corner(awayDot, 3)
local homeName = label({ Position = UDim2.fromOffset(20, 0), Size = UDim2.fromOffset(74, 38), Text = NAMES[1], Font = BOLD, TextXAlignment = Enum.TextXAlignment.Left }, board)
local homeScore = label({ Position = UDim2.fromOffset(94, 0), Size = UDim2.fromOffset(42, 38), Text = "0", Font = BOLD, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right }, board)
local midLabel = label({ Position = UDim2.fromOffset(136, 0), Size = UDim2.fromOffset(48, 38), TextSize = 10, TextColor3 = DIM }, board)
local awayScore = label({ Position = UDim2.fromOffset(184, 0), Size = UDim2.fromOffset(42, 38), Text = "0", Font = BOLD, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left }, board)
local awayName = label({ Position = UDim2.fromOffset(226, 0), Size = UDim2.fromOffset(74, 38), Text = NAMES[2], Font = BOLD, TextXAlignment = Enum.TextXAlignment.Right }, board)

-- touches used this possession
local dotsFrame = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(44, 8), BackgroundTransparency = 1, Visible = false }, gui)
local dots = {}
for i = 1, 3 do
	dots[i] = ui("Frame", { Position = UDim2.fromOffset((i - 1) * 18, 0), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = TEXT, BackgroundTransparency = 0.75, BorderSizePixel = 0 }, dotsFrame)
	corner(dots[i], 4)
end

-- point banner
local bannerGroup = ui("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(380, 46),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	GroupTransparency = 1,
}, gui)
corner(bannerGroup, 8)
local bannerAccent = ui("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = TEXT, BorderSizePixel = 0 }, bannerGroup)
local bannerTitle = label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), Font = BOLD, TextSize = 16 }, bannerGroup)
local bannerSub = label({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = DIM }, bannerGroup)

-- control hints, bottom centre
local hint = label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(760, 20),
	RichText = true,
	TextTransparency = 0.15,
	TextStrokeTransparency = 0.75,
}, gui)

-- "your ball" cue when you should play the next touch
local cue = label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -48),
	Size = UDim2.fromOffset(420, 22),
	Font = BOLD,
	TextSize = 16,
	RichText = true,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
}, gui)

-- serve power bar
local powerBar = ui("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -54),
	Size = UDim2.fromOffset(240, 8),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
corner(powerBar, 4)
ui("Frame", { Position = UDim2.fromScale(0.65, 0), Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 140), BackgroundTransparency = 0.45, BorderSizePixel = 0 }, powerBar)
local powerFill = ui("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, powerBar)
corner(powerFill, 4)
label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -3), Size = UDim2.fromOffset(240, 14), Text = "POWER", Font = BOLD, TextSize = 10, TextColor3 = DIM }, powerBar)

-- PERFECT / GOOD / OK / POOR after your touches
local feedback = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromOffset(200, 24),
	Font = BOLD,
	TextSize = 15,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
}, gui)

local function flash(text, color)
	feedback.Text = text
	feedback.TextColor3 = color
	feedback.TextTransparency = 0
	feedback.TextStrokeTransparency = 0.7
	feedback.Position = UDim2.fromScale(0.5, 0.6)
	TweenService:Create(feedback, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.56),
	}):Play()
end

local function showQuality(q)
	if q >= 0.85 then
		flash("PERFECT", Color3.fromRGB(120, 255, 170))
	elseif q >= 0.65 then
		flash("GOOD", TEXT)
	elseif q >= 0.4 then
		flash("OK", DIM)
	else
		flash("POOR", Color3.fromRGB(255, 140, 120))
	end
end

local bannerToken = 0
local function showBanner(title, sub, team)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerSub.Text = sub
	bannerAccent.BackgroundColor3 = COLORS[team] or TEXT
	TweenService:Create(bannerGroup, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	task.delay(2.4, function()
		if bannerToken == token then
			TweenService:Create(bannerGroup, TweenInfo.new(0.4), { GroupTransparency = 1 }):Play()
		end
	end)
end

-- touch-screen buttons
local touchMode = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function touchButton(text, pos, size)
	local b = ui("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.35,
		Text = text,
		Font = BOLD,
		TextSize = 13,
		TextColor3 = TEXT,
		AutoButtonColor = false,
		Visible = touchMode,
	}, gui)
	corner(b, size / 2)
	ui("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.7, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end
local hitButton = touchButton("HIT", UDim2.new(1, -150, 1, -200), 74)
local setButton = touchButton("SET", UDim2.new(1, -235, 1, -130), 58)
local diveButton = touchButton("DIVE", UDim2.new(1, -75, 1, -275), 58)
