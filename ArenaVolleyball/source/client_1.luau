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

local aimMarker = worldPart({
	Name = "AimMarker",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(0.03, 1.6, 1.6),
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

---------------------------------------------------------------- your player's ring (follows you on the floor)

local ringModel = Instance.new("Model")
ringModel.Name = "PlayerRing"
ringModel.Parent = world
local RING_RADIUS, RING_SEGMENTS = 2.1, 28
local ringParts = {}
for i = 1, RING_SEGMENTS do
	local a = (i / RING_SEGMENTS) * math.pi * 2
	local seg = worldPart({
		Name = "Segment",
		Size = Vector3.new(0.18, 0.04, 2 * math.pi * RING_RADIUS / RING_SEGMENTS + 0.06),
		CFrame = CFrame.new(math.cos(a) * RING_RADIUS, 0, math.sin(a) * RING_RADIUS) * CFrame.Angles(0, -a, 0),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	seg.Parent = ringModel
	table.insert(ringParts, seg)
end
-- arrow at the front of the ring: which way you're facing
for _, sx in { -1, 1 } do
	local wing = worldPart({
		Name = "Arrow",
		Size = Vector3.new(0.2, 0.04, 0.9),
		CFrame = CFrame.new(sx * 0.3, 0, -RING_RADIUS - 0.55) * CFrame.Angles(0, sx * math.rad(40), 0),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	})
	wing.Parent = ringModel
	table.insert(ringParts, wing)
end
ringModel.WorldPivot = CFrame.new()

local function setRingColor(color)
	for _, seg in ringParts do
		seg.Color = color
	end
end

---------------------------------------------------------------- HUD (styled after football game broadcasts)

local PANEL = Color3.fromRGB(12, 14, 20)
local PANEL_2 = Color3.fromRGB(28, 32, 42)
local TEXT = Color3.fromRGB(244, 246, 250)
local DIM = Color3.fromRGB(150, 156, 170)
local INK = Color3.fromRGB(16, 18, 24)
local GOLD = Color3.fromRGB(255, 212, 80)
local DISPLAY = Enum.Font.Oswald -- tall condensed numbers, broadcast style
local BOLD = Enum.Font.GothamBold
local MEDIUM = Enum.Font.GothamMedium

local inMenu = true
local openMenu, closeMenu -- defined with the menu at the end

local gui = Instance.new("ScreenGui")
gui.Name = "VolleyballHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
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

local function label(props, parent)
	local l = ui("TextLabel", { BackgroundTransparency = 1, TextColor3 = TEXT, Font = MEDIUM, TextSize = 13, Text = "" }, parent)
	for key, value in props do
		l[key] = value
	end
	return l
end

local function box(props, parent)
	local b = ui("Frame", { BorderSizePixel = 0, BackgroundColor3 = PANEL }, parent)
	for key, value in props do
		b[key] = value
	end
	return b
end

local function short(name)
	return string.upper(string.sub(name, 1, 3))
end

-- scorebug, top left:  | HOM | 12 - 9 | AWY |  SET 1
local bug = box({ Position = UDim2.fromOffset(28, 26), Size = UDim2.fromOffset(300, 34), BackgroundTransparency = 1 }, gui)
box({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(5, 34), BackgroundColor3 = COLORS[1] }, bug)
local homeBox = box({ Position = UDim2.fromOffset(5, 0), Size = UDim2.fromOffset(64, 34) }, bug)
label({ Size = UDim2.fromScale(1, 1), Text = short(NAMES[1]), Font = DISPLAY, TextSize = 21 }, homeBox)
local homeServe = box({ Position = UDim2.new(1, -9, 0.5, -3), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = GOLD, Visible = false }, homeBox)
corner(homeServe, 3)
local scoreBox = box({ Position = UDim2.fromOffset(69, 0), Size = UDim2.fromOffset(84, 34), BackgroundColor3 = Color3.fromRGB(236, 238, 242) }, bug)
local scorePop = ui("UIScale", { Scale = 1 }, scoreBox)
local scoreLabel = label({ Size = UDim2.fromScale(1, 1), Text = "0 - 0", Font = DISPLAY, TextSize = 24, TextColor3 = INK }, scoreBox)
local awayBox = box({ Position = UDim2.fromOffset(153, 0), Size = UDim2.fromOffset(64, 34) }, bug)
label({ Size = UDim2.fromScale(1, 1), Text = short(NAMES[2]), Font = DISPLAY, TextSize = 21 }, awayBox)
local awayServe = box({ Position = UDim2.new(0, 3, 0.5, -3), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = GOLD, Visible = false }, awayBox)
corner(awayServe, 3)
box({ Position = UDim2.fromOffset(217, 0), Size = UDim2.fromOffset(5, 34), BackgroundColor3 = COLORS[2] }, bug)
local setBox = box({ Position = UDim2.fromOffset(226, 0), Size = UDim2.fromOffset(70, 34), BackgroundColor3 = PANEL_2 }, bug)
local setLabel = label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 2), Text = "SET 1", Font = DISPLAY, TextSize = 17 }, setBox)
local targetLabel = label({ Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 20), Text = "TO 25", Font = BOLD, TextSize = 9, TextColor3 = DIM }, setBox)

-- strip under the scorebug: touches this possession
local strip = box({ Position = UDim2.fromOffset(28, 62), Size = UDim2.fromOffset(222, 18), BackgroundTransparency = 0.15, Visible = false }, gui)
label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(80, 18), Text = "TOUCHES", Font = BOLD, TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, strip)
local dots = {}
for i = 1, 3 do
	dots[i] = box({ Position = UDim2.fromOffset(78 + (i - 1) * 16, 5), Size = UDim2.fromOffset(10, 8), BackgroundColor3 = TEXT, BackgroundTransparency = 0.8 }, strip)
end

-- menu button, top right
local menuButton = ui("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -28, 0, 26),
	Size = UDim2.fromOffset(96, 30),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "MENU  [M]",
	Font = BOLD,
	TextSize = 12,
	TextColor3 = TEXT,
	AutoButtonColor = true,
}, gui)

-- point banner: sweeps in from the left, like a goal replay wipe
local bannerHolder = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.6, 0.74), Size = UDim2.fromOffset(560, 74), BackgroundTransparency = 1 }, gui)
local bannerColor = box({ Size = UDim2.fromOffset(150, 74), BackgroundColor3 = COLORS[1] }, bannerHolder)
local bannerTeam = label({ Size = UDim2.fromScale(1, 1), Font = DISPLAY, TextSize = 34, Text = "HOM" }, bannerColor)
local bannerBody = box({ Position = UDim2.fromOffset(150, 0), Size = UDim2.fromOffset(410, 74), BackgroundTransparency = 0.08 }, bannerHolder)
ui("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 0.6) }) }, bannerBody)
local bannerTitle = label({ Position = UDim2.fromOffset(20, 6), Size = UDim2.new(1, -30, 0, 42), Font = DISPLAY, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Left }, bannerBody)
local bannerSub = label({ Position = UDim2.fromOffset(21, 48), Size = UDim2.new(1, -30, 0, 16), Font = BOLD, TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, bannerBody)

local bannerToken = 0
local function showBanner(title, sub, team)
	bannerToken += 1
	local token = bannerToken
	local big, small = title, sub
	local s, e = string.find(title, " POINT")
	if s and e == #title then
		big, small = sub, title -- e.g. big "KILL", small "HOME POINT"
	end
	bannerTitle.Text = string.upper(big)
	bannerSub.Text = string.upper(small)
	bannerColor.BackgroundColor3 = COLORS[team] or PANEL_2
	bannerTeam.Text = NAMES[team] and short(NAMES[team]) or "AV"
	bannerHolder.Position = UDim2.fromScale(-0.6, 0.74)
	TweenService:Create(bannerHolder, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.74) }):Play()
	task.delay(2.3, function()
		if bannerToken == token then
			TweenService:Create(bannerHolder, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.6, 0.74) }):Play()
		end
	end)
end

-- player card, bottom left: name, position, match stats and a match rating
local card = box({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -28), Size = UDim2.fromOffset(300, 70), BackgroundTransparency = 0.1 }, gui)
local cardStripe = box({ Size = UDim2.fromOffset(5, 70), BackgroundColor3 = COLORS[1] }, card)
label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(200, 24), Font = DISPLAY, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(player.DisplayName) }, card)
local cardPos = label({ Position = UDim2.fromOffset(16, 32), Size = UDim2.fromOffset(200, 14), Font = BOLD, TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, card)
local cardStats = label({ Position = UDim2.fromOffset(16, 48), Size = UDim2.fromOffset(200, 14), Font = BOLD, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, RichText = true }, card)
local ratingBox = box({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(58, 50), BackgroundColor3 = PANEL_2 }, card)
local ratingLabel = label({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 28), Font = DISPLAY, TextSize = 28, Text = "6.0" }, ratingBox)
label({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 12), Font = BOLD, TextSize = 8, TextColor3 = DIM, Text = "RATING" }, ratingBox)

-- button prompts, bottom right: [KEY] action
local promptHolder = ui("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -28), Size = UDim2.fromOffset(260, 150), BackgroundTransparency = 1 }, gui)
ui("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, promptHolder)
local promptRows = {}
for i = 1, 5 do
	local row = ui("Frame", { Size = UDim2.fromOffset(260, 24), BackgroundTransparency = 1, LayoutOrder = i, Visible = false }, promptHolder)
	local action = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(150, 24), Font = BOLD, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.7 }, row)
	local chip = box({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -158, 0, 0), Size = UDim2.fromOffset(40, 24), BackgroundColor3 = TEXT }, row)
	corner(chip, 4)
	local key = label({ Size = UDim2.fromScale(1, 1), Font = BOLD, TextSize = 11, TextColor3 = INK }, chip)
	promptRows[i] = { row = row, action = action, chip = chip, key = key }
end

local function setPrompts(list)
	for i, r in promptRows do
		local item = list[i]
		r.row.Visible = item ~= nil
		if item then
			r.key.Text = item[1]
			r.action.Text = string.upper(item[2])
			r.chip.Size = UDim2.fromOffset(math.max(28, #item[1] * 8 + 14), 24)
		end
	end
end

-- "your ball" cue, centre bottom
local cueBox = box({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(360, 30), BackgroundTransparency = 0.15, Visible = false }, gui)
box({ Size = UDim2.fromOffset(5, 30), BackgroundColor3 = GOLD }, cueBox)
local cue = label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 1, 0), Font = BOLD, TextSize = 14, RichText = true, TextXAlignment = Enum.TextXAlignment.Left }, cueBox)

-- serve power bar, centre bottom
local powerBar = box({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(300, 12), BackgroundTransparency = 0.2, Visible = false }, gui)
box({ Position = UDim2.fromScale(0.65, 0), Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 140), BackgroundTransparency = 0.35 }, powerBar)
local powerFill = box({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = TEXT, BackgroundTransparency = 0.05 }, powerBar)
for i = 1, 9 do
	box({ Position = UDim2.fromScale(i / 10, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2 }, powerBar)
end
label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(300, 14), Text = "SERVE POWER", Font = BOLD, TextSize = 10, TextColor3 = DIM }, powerBar)

-- PERFECT / GOOD / OK / POOR after your touches
local feedback = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromOffset(240, 30),
	Font = DISPLAY,
	TextSize = 26,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
}, gui)

local function flash(text, color)
	feedback.Text = text
	feedback.TextColor3 = color
	feedback.TextTransparency = 0
	feedback.TextStrokeTransparency = 0.6
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

-- name tag over your head
local tag = Instance.new("BillboardGui")
tag.Name = "VolleyballTag"
tag.Size = UDim2.fromOffset(140, 42)
tag.StudsOffset = Vector3.new(0, 3.4, 0)
tag.AlwaysOnTop = true
tag.LightInfluence = 0
tag.Enabled = false
tag.Parent = player:WaitForChild("PlayerGui")
label({ Size = UDim2.new(1, 0, 0, 22), Font = DISPLAY, TextSize = 18, Text = string.upper(player.DisplayName), TextStrokeTransparency = 0.5 }, tag)
local tagArrow = label({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 18), Font = BOLD, TextSize = 16, Text = "▼", TextStrokeTransparency = 0.6 }, tag)

-- touch-screen buttons
local touchMode = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function touchButton(text, pos, size)
	local b = ui("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
		Text = text,
		Font = BOLD,
		TextSize = 13,
		TextColor3 = TEXT,
		AutoButtonColor = false,
		Visible = touchMode,
	}, gui)
	corner(b, size / 2)
	ui("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end
local hitButton = touchButton("HIT", UDim2.new(1, -150, 1, -200), 74)
local setButton = touchButton("SET", UDim2.new(1, -235, 1, -130), 58)
local diveButton = touchButton("DIVE", UDim2.new(1, -75, 1, -275), 58)
if touchMode then
	promptHolder.Visible = false -- the buttons are labelled already
	card.Visible = false -- keeps the thumbstick area clear
end
