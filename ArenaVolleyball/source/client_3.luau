
---------------------------------------------------------------- main menu (football-game style tiles)

local Lighting = game:GetService("Lighting")

local blur = Instance.new("BlurEffect")
blur.Name = "VolleyballMenuBlur"
blur.Size = 14
blur.Parent = Lighting

local menuGui = Instance.new("ScreenGui")
menuGui.Name = "VolleyballMenu"
menuGui.ResetOnSpawn = false
menuGui.IgnoreGuiInset = true
menuGui.DisplayOrder = 5
menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuGui.Parent = player:WaitForChild("PlayerGui")

local shade = box({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0 }, menuGui)
ui("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.7) }) }, shade)

-- everything is laid out on a 1180 x 640 board that scales to the screen
local board = ui("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1180, 640), BackgroundTransparency = 1 }, menuGui)
local boardScale = ui("UIScale", { Scale = 1 }, board)
local function fitBoard()
	local vp = workspace.CurrentCamera.ViewportSize
	boardScale.Scale = math.min(vp.X / 1260, vp.Y / 700, 1.25)
end
fitBoard()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitBoard)

-- header
label({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(420, 48), Text = "ARENA VOLLEYBALL", Font = DISPLAY, TextSize = 42, TextXAlignment = Enum.TextXAlignment.Left }, board)
local seasonChip = box({ Position = UDim2.fromOffset(392, 14), Size = UDim2.fromOffset(78, 22), BackgroundColor3 = GOLD }, board)
corner(seasonChip, 3)
label({ Size = UDim2.fromScale(1, 1), Text = "SEASON 1", Font = BOLD, TextSize = 11, TextColor3 = INK }, seasonChip)

local TABS = { "PLAY", "CAREER", "ONLINE", "CLUB" }
for i, name in TABS do
	local x = (i - 1) * 120
	label({ Position = UDim2.fromOffset(x, 58), Size = UDim2.fromOffset(110, 26), Text = name, Font = DISPLAY, TextSize = 20, TextColor3 = i == 1 and TEXT or DIM, TextXAlignment = Enum.TextXAlignment.Left }, board)
	if i == 1 then
		box({ Position = UDim2.fromOffset(x, 86), Size = UDim2.fromOffset(44, 3), BackgroundColor3 = GOLD }, board)
	end
end

-- your profile, top right
local profile = box({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(240, 52), BackgroundTransparency = 0.3 }, board)
local headshot = ui("ImageLabel", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = PANEL_2, BorderSizePixel = 0 }, profile)
corner(headshot, 20)
label({ Position = UDim2.fromOffset(56, 6), Size = UDim2.fromOffset(176, 22), Text = string.upper(player.DisplayName), Font = DISPLAY, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left }, profile)
label({ Position = UDim2.fromOffset(56, 28), Size = UDim2.fromOffset(176, 16), Text = "@" .. player.Name, Font = MEDIUM, TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, profile)
task.spawn(function()
	local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	if ok then
		headshot.Image = image
	end
end)

-- a selectable tile with a hover outline
local function tile(props)
	local t = ui("TextButton", {
		Position = props.pos,
		Size = props.size,
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
	}, board)
	ui("UIGradient", { Rotation = 25, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(70, 70, 80)) }, t)
	local stroke = ui("UIStroke", { Color = TEXT, Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, t)
	local scale = ui("UIScale", { Scale = 1 }, t)
	t.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1.015 }):Play()
	end)
	t.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)
	if props.watermark then
		label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 10, 0.45, 0), Size = UDim2.fromOffset(400, 200), Text = props.watermark, Font = DISPLAY, TextSize = props.watermarkSize or 150, TextTransparency = 0.82, TextXAlignment = Enum.TextXAlignment.Right }, t)
	end
	local chip = box({ Position = UDim2.fromOffset(22, 20), Size = UDim2.fromOffset(#props.chip * 8 + 22, 24), BackgroundColor3 = props.chipColor or GOLD }, t)
	corner(chip, 3)
	label({ Size = UDim2.fromScale(1, 1), Text = props.chip, Font = BOLD, TextSize = 11, TextColor3 = INK }, chip)
	label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -44), Size = UDim2.new(1, -44, 0, 60), Text = props.title, Font = DISPLAY, TextSize = props.titleSize or 56, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom }, t)
	label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 23, 1, -20), Size = UDim2.new(1, -44, 0, 18), Text = props.sub, Font = MEDIUM, TextSize = 13, TextColor3 = Color3.fromRGB(220, 225, 235), TextXAlignment = Enum.TextXAlignment.Left }, t)
	return t
end

local quickTile = tile({
	pos = UDim2.fromOffset(0, 112),
	size = UDim2.fromOffset(700, 384),
	color = COLORS[1],
	chip = "PLAY NOW",
	title = "QUICK MATCH",
	sub = "6v6 against the AI on a real-size court",
	watermark = "6v6",
	watermarkSize = 190,
})
local careerTile = tile({
	pos = UDim2.fromOffset(716, 112),
	size = UDim2.fromOffset(464, 184),
	color = Color3.fromRGB(46, 120, 90),
	chip = "COMING SOON",
	chipColor = TEXT,
	title = "CAREER",
	titleSize = 44,
	sub = "Pick a club and position, and rise from rookie to pro",
	watermark = "PRO",
	watermarkSize = 110,
})
local onlineTile = tile({
	pos = UDim2.fromOffset(716, 312),
	size = UDim2.fromOffset(464, 184),
	color = Color3.fromRGB(120, 60, 150),
	chip = "COMING SOON",
	chipColor = TEXT,
	title = "ONLINE",
	titleSize = 44,
	sub = "Ranked matches and seasons against other players",
	watermark = "VS",
	watermarkSize = 110,
})

-- match settings and the play button
local settingsBar = box({ Position = UDim2.fromOffset(0, 512), Size = UDim2.fromOffset(1180, 64), BackgroundTransparency = 0.15 }, board)
local LEVEL_NAMES = { "ROOKIE", "PRO", "LEGEND" }
local POINT_OPTIONS = { 15, 21, 25 }
local choice = { level = math.clamp(Config.AI_LEVEL or 2, 1, 3), points = 3 }
for i, p in POINT_OPTIONS do
	if p == Config.POINTS_TO_WIN then
		choice.points = i
	end
end

local selectors = {}
local function selector(x, title, getText, step)
	label({ Position = UDim2.fromOffset(x, 8), Size = UDim2.fromOffset(220, 14), Text = title, Font = BOLD, TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, settingsBar)
	local value = label({ Position = UDim2.fromOffset(x + 30, 24), Size = UDim2.fromOffset(130, 32), Font = DISPLAY, TextSize = 24 }, settingsBar)
	local arrows = {}
	for i, glyph in { "◀", "▶" } do
		local b = ui("TextButton", {
			Position = UDim2.fromOffset(i == 1 and x or x + 164, 26),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = PANEL_2,
			BorderSizePixel = 0,
			Text = glyph,
			Font = BOLD,
			TextSize = 12,
			TextColor3 = TEXT,
		}, settingsBar)
		corner(b, 4)
		b.Activated:Connect(function()
			step(i == 1 and -1 or 1)
			value.Text = getText()
		end)
		table.insert(arrows, b)
	end
	value.Text = getText()
	table.insert(selectors, { value = value, arrows = arrows })
end
selector(24, "DIFFICULTY", function()
	return LEVEL_NAMES[choice.level]
end, function(d)
	choice.level = (choice.level - 1 + d) % 3 + 1
end)
selector(250, "POINTS PER SET", function()
	return tostring(POINT_OPTIONS[choice.points])
end, function(d)
	choice.points = (choice.points - 1 + d) % 3 + 1
end)
label({ Position = UDim2.fromOffset(476, 8), Size = UDim2.fromOffset(200, 14), Text = "YOUR TEAM", Font = BOLD, TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, settingsBar)
local teamLabel = label({ Position = UDim2.fromOffset(476, 24), Size = UDim2.fromOffset(260, 32), Text = NAMES[1] .. "  ·  YOU + AI", Font = DISPLAY, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left }, settingsBar)
local note = label({ Position = UDim2.fromOffset(700, 0), Size = UDim2.fromOffset(240, 64), Font = MEDIUM, TextSize = 12, TextColor3 = DIM, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right }, settingsBar)

local playButton = ui("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(210, 48),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	Text = "PLAY",
	Font = DISPLAY,
	TextSize = 28,
	TextColor3 = INK,
	AutoButtonColor = true,
}, settingsBar)
corner(playButton, 4)

-- footer button hints
label({ Position = UDim2.fromOffset(0, 596), Size = UDim2.fromOffset(700, 20), Text = "CLICK  Select          M  Back to this menu during a match", Font = BOLD, TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left }, board)

local toast = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(320, 34), BackgroundColor3 = PANEL, BackgroundTransparency = 1, Font = BOLD, TextSize = 14, TextTransparency = 1 }, menuGui)
corner(toast, 4)
local function showToast(text)
	toast.Text = text
	toast.TextTransparency, toast.BackgroundTransparency = 0, 0.1
	TweenService:Create(toast, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
end

-- if people are already playing, you join them and their settings stand
local function matchInProgress()
	for t = 1, 2 do
		if #(state.roster[t] or {}) > 0 then
			return true
		end
	end
	return false
end

local function refreshMenu()
	local busy = matchInProgress()
	for _, sel in selectors do
		sel.value.TextTransparency = busy and 0.6 or 0
		for _, arrow in sel.arrows do
			arrow.Visible = not busy
		end
	end
	if busy then
		note.Text = "A match is on. You'll join it with its settings (" .. LEVEL_NAMES[state.level or 2] .. ", to " .. (state.points or 25) .. ")."
		teamLabel.Text = "JOIN THE MATCH"
	else
		note.Text = "Changing settings starts a fresh match."
		teamLabel.Text = NAMES[1] .. "  ·  YOU + AI"
	end
end

-- the camera slowly circles the court behind the menu
local orbit = 0
RunService.RenderStepped:Connect(function(dt)
	if not inMenu then
		return
	end
	orbit += dt * 0.06
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local radius = Config.COURT_LENGTH * 0.9
	cam.CFrame = CFrame.lookAt(C + Vector3.new(math.cos(orbit) * radius, 26, math.sin(orbit) * radius), C + Vector3.new(0, 3, 0))
end)

function openMenu()
	if inMenu then
		return
	end
	inMenu = true
	charging = false
	pending = nil
	remote:FireServer("leave")
	gui.Enabled = false
	blur.Enabled = true
	menuGui.Enabled = true
	refreshMenu()
end

function closeMenu()
	if not inMenu then
		return
	end
	inMenu = false
	menuGui.Enabled = false
	blur.Enabled = false
	gui.Enabled = true
	remote:FireServer("join", { level = choice.level, points = POINT_OPTIONS[choice.points] })
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = character()
	if hum then
		cam.CameraSubject = hum
	end
	task.delay(0.8, lookAtNet)
end

quickTile.Activated:Connect(closeMenu)
playButton.Activated:Connect(closeMenu)
careerTile.Activated:Connect(function()
	showToast("Career mode is coming soon")
end)
onlineTile.Activated:Connect(function()
	showToast("Online is coming soon")
end)

remote.OnClientEvent:Connect(function(kind)
	if kind == "state" and inMenu then
		refreshMenu()
	end
end)
refreshMenu()
