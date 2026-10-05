
---------------------------------------------------------------- menus: the front end

local Menu = { screens = {}, onShow = {}, current = nil, stack = {}, waiting = false, pvTab = 1, squadSel = 2 }
-- what you've picked: your club, the opponent, your lineup and the player you control
local sel = {
	home = 1,
	away = 2,
	slot = 2,
	plan = Teams.cleanPlan(1, nil), -- lineup, tactics and roles for your club
	points = Config.POINTS_TO_WIN,
	sets = Config.SETS_TO_WIN,
	side = 1,
}
sel.lineup = sel.plan.lineup
local history = {} -- results this session: { home, away, winner, score }

-- your Edit Player, kit and court choices (saved with your profile)
Menu.custom = { number = 7, role = "OH", wearKit = false, court = 1, kits = {} }

-- a fresh game plan when you pick another club
local function resetPlan()
	sel.plan = Teams.cleanPlan(sel.home, nil)
	sel.lineup = sel.plan.lineup
	sel.slot = 2
	sel.slotPicked = false
end

Menu.gui = make("ScreenGui", {
	Name = "VolleyballMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
-- the menus sit below Roblox's own buttons along the top
pcall(function()
	Menu.gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)

-- background: deep purple with neon swooshes, on its own full-screen layer
do
	local bgGui = make("ScreenGui", { Name = "VolleyballMenuBackground", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
	Menu.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		bgGui.Enabled = Menu.gui.Enabled
	end)
	local bg = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, bgGui)
	gradient(bg, COL.bg1, COL.bg2, 35)
	local floorGlow = frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = Color3.fromRGB(10, 8, 40) }, bg)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.25) }, floorGlow)
	local streaks = {
		{ 0.16, 0.2, 0.8, 0.04, COL.teal, 0.2 },
		{ 0.06, 0.32, 0.7, 0.07, COL.pink, 0.4 },
		{ 0.22, 0.1, 0.95, 0.012, COL.cyan, 0.3 },
		{ 0.66, 0.12, 0.7, 0.025, COL.violet, 0.5 },
		{ 0.8, 0.74, 0.6, 0.016, COL.teal, 0.55 },
		{ 0.3, 0.9, 0.9, 0.01, COL.pink, 0.5 },
	}
	for _, st in streaks do
		local f = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(st[1], st[2]), Size = UDim2.fromScale(st[3], st[4]), Rotation = -28, BackgroundColor3 = st[5], BackgroundTransparency = st[6] }, bg)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
		round(f, 40)
	end
end

-- everything is laid out on a 1280 x 720 board scaled to the screen
local board = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1280, 720), BackgroundTransparency = 1 }, Menu.gui)
do
	local scale = make("UIScale", { Scale = 1 }, board)
	local function fit()
		local size = Menu.gui.AbsoluteSize
		if size.X < 10 then
			size = workspace.CurrentCamera.ViewportSize
		end
		scale.Scale = math.min(size.X / 1280, size.Y / 720)
	end
	fit()
	Menu.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end
Menu.board = board

function Menu.screen(name)
	local f = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, board)
	Menu.screens[name] = f
	return f
end

local FRONT = { home = true, play = true, online = true, customise = true }
function Menu.show(name, push)
	if Menu.current and push ~= false and Menu.current ~= name then
		table.insert(Menu.stack, Menu.current)
	end
	for n, f in Menu.screens do
		f.Visible = n == name
	end
	local changed = Menu.current ~= name
	Menu.current = name
	if Menu.profileCard then
		Menu.profileCard.Visible = FRONT[name] == true
		if FRONT[name] and Menu.refreshProfileCard then
			Menu.refreshProfileCard()
		end
	end
	-- a quick fade between screens
	if changed and Menu.fader then
		Menu.fader.BackgroundTransparency = 0.35
		TweenService:Create(Menu.fader, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end
	local hook = Menu.onShow[name]
	if hook then
		hook()
	end
end

function Menu.back()
	local previous = table.remove(Menu.stack)
	if previous then
		Menu.show(previous, false)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if inMenu and not processed and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB) then
		Menu.back()
	end
end)

---------------------------------------------------------------- menu building blocks

function Menu.tile(parent, pos, size, onClick)
	local t = button({ Position = pos, Size = size, BackgroundTransparency = 0.12, BackgroundColor3 = COL.panel, ClipsDescendants = true }, parent)
	local stroke = outline(t, COL.line, 1, 0.45)
	t.MouseEnter:Connect(function()
		stroke.Color, stroke.Transparency, stroke.Thickness = COL.teal, 0, 2
	end)
	t.MouseLeave:Connect(function()
		stroke.Color, stroke.Transparency, stroke.Thickness = COL.line, 0.45, 1
	end)
	if onClick then
		t.Activated:Connect(onClick)
	end
	return t
end

function Menu.title(parent, str, size, pos)
	return text({
		Position = pos or UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, (size or 30) * 2 + 8),
		Text = str,
		FontFace = FONT.body,
		TextSize = size or 30,
		TextColor3 = COL.cyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 0.95,
	}, parent)
end

function Menu.chip(parent, label, pos, color, textColor)
	local c = frame({ Position = pos, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color or COL.gold }, parent)
	round(c, 3)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, c)
	text({ Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = label, FontFace = FONT.title, TextSize = 12, TextColor3 = textColor or COL.ink }, c)
	return c
end

local TABS = { "HOME", "PLAY", "ONLINE", "CUSTOMISE" }
local TAB_SCREEN = { "home", "play", "online", "customise" }
function Menu.tabs(parent, pos, names, active, onPick, width)
	width = width or 112
	local bar = frame({ Position = pos, Size = UDim2.fromOffset(#names * width, 32), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.35 }, parent)
	for i, name in names do
		local b = button({ Position = UDim2.fromOffset((i - 1) * width, 0), Size = UDim2.fromOffset(width, 32), BackgroundColor3 = COL.bg2, BackgroundTransparency = i == active and 0.05 or 1 }, bar)
		text({ Size = UDim2.fromScale(1, 1), Text = name, FontFace = FONT.head, TextSize = 19, TextColor3 = i == active and COL.teal or COL.text }, b)
		if i == active then
			frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.coral }, b)
		end
		b.Activated:Connect(function()
			onPick(i)
		end)
	end
	return bar
end

function Menu.frontTabs(parent, active)
	return Menu.tabs(parent, UDim2.fromOffset(268, 160), TABS, active, function(i)
		Menu.show(TAB_SCREEN[i], false)
	end)
end

-- button hints along the bottom: { key, label, onClick }
function Menu.hints(parent, items, pos)
	local holder = frame({ Position = pos or UDim2.fromOffset(268, 632), Size = UDim2.fromOffset(1000, 28), BackgroundTransparency = 1 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 22), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	for i, item in items do
		-- each hint sizes itself to its text, so nothing overlaps or gets cut off
		local b = button({ Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i }, holder)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, b)
		local chip = frame({ Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = COL.text, LayoutOrder = 1 }, b)
		round(chip, 12)
		make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chip)
		text({ Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = item[1], FontFace = FONT.title, TextSize = 12, TextColor3 = COL.ink }, chip)
		text({ Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Text = item[2], FontFace = FONT.head, TextSize = 17, LayoutOrder = 2 }, b)
		if item[3] then
			b.Activated:Connect(item[3])
		end
	end
	return holder
end

-- simple line icons
function Menu.icon(parent, kind, size, color, pos)
	local box = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local s = size
	if kind == "ball" then
		local c = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, box)
		round(c, s)
		make("UIStroke", { Color = color, Thickness = 2 }, c)
		lineBetween(box, Vector2.new(s * 0.1, s * 0.5), Vector2.new(s * 0.9, s * 0.5), 2, color)
		lineBetween(box, Vector2.new(s * 0.5, s * 0.08), Vector2.new(s * 0.5, s * 0.92), 2, color)
		local inner = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, box)
		round(inner, s)
		make("UIStroke", { Color = color, Thickness = 2 }, inner)
	elseif kind == "court" then
		local c = frame({ Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0, 0.15), BackgroundTransparency = 1 }, box)
		make("UIStroke", { Color = color, Thickness = 2 }, c)
		frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = color }, c)
		for _, x in { 0.25, 0.75 } do
			local d = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = color }, c)
			round(d, 3)
		end
	elseif kind == "sliders" then
		for i, x in { 0.3, 0.7, 0.45 } do
			local y = s * (0.2 + (i - 1) * 0.3)
			lineBetween(box, Vector2.new(0, y), Vector2.new(s, y), 2, color)
			local k = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(s * x, y), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = color }, box)
			round(k, 4)
		end
	elseif kind == "pad" then
		local body = frame({ Size = UDim2.fromScale(1, 0.62), Position = UDim2.fromScale(0, 0.2), BackgroundTransparency = 1 }, box)
		round(body, math.floor(s * 0.3))
		make("UIStroke", { Color = color, Thickness = 2 }, body)
		lineBetween(box, Vector2.new(s * 0.18, s * 0.5), Vector2.new(s * 0.38, s * 0.5), 2, color)
		lineBetween(box, Vector2.new(s * 0.28, s * 0.4), Vector2.new(s * 0.28, s * 0.6), 2, color)
		for _, p in { { 0.7, 0.42 }, { 0.8, 0.55 } } do
			local d = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = color }, box)
			round(d, 3)
		end
	elseif kind == "bars" then
		for i, h in { 0.45, 0.75, 1 } do
			frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) * 0.36, 0, 1, 0), Size = UDim2.new(0.24, 0, h, 0), BackgroundColor3 = color }, box)
		end
	elseif kind == "arena" then
		local c = frame({ Position = UDim2.fromScale(0.1, 0.45), Size = UDim2.fromScale(0.8, 0.5), BackgroundTransparency = 1 }, box)
		make("UIStroke", { Color = color, Thickness = 2 }, c)
		lineBetween(box, Vector2.new(s * 0.05, s * 0.48), Vector2.new(s * 0.5, s * 0.12), 2, color)
		lineBetween(box, Vector2.new(s * 0.5, s * 0.12), Vector2.new(s * 0.95, s * 0.48), 2, color)
	elseif kind == "clock" then
		local c = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, box)
		round(c, s)
		make("UIStroke", { Color = color, Thickness = 2 }, c)
		lineBetween(box, Vector2.new(s * 0.5, s * 0.5), Vector2.new(s * 0.5, s * 0.2), 2, color)
		lineBetween(box, Vector2.new(s * 0.5, s * 0.5), Vector2.new(s * 0.72, s * 0.6), 2, color)
	end
	return box
end

local toast = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(0, 38),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = COL.bg1,
	BackgroundTransparency = 1,
	FontFace = FONT.head,
	TextSize = 18,
	TextTransparency = 1,
	ZIndex = 40,
}, Menu.gui)
round(toast, 6)
make("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }, toast)
function Menu.toast(message)
	toast.Text = message
	toast.TextTransparency, toast.BackgroundTransparency = 0, 0.05
	TweenService:Create(toast, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
end

---------------------------------------------------------------- 3D players in the menus

-- the space where menu art would go: left blank on purpose
function Menu.avatar(parent, props, _yaw)
	local holder = frame({ BackgroundTransparency = 1 }, parent)
	for key, value in props do
		holder[key] = value
	end
	return { vp = holder, set = function() end }
end

---------------------------------------------------------------- shared front-screen pieces

-- the ARENA VOLLEYBALL wordmark, bottom right
local WORDMARK = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
Menu.logo = text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(1240, 692), Size = UDim2.fromOffset(320, 42), Text = "ARENA VOLLEYBALL", FontFace = WORDMARK, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Right }, board)

-- your profile, down the left of the front screens
do
	local card = frame({ Position = UDim2.fromOffset(76, 202), Size = UDim2.fromOffset(180, 326), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.12, Visible = false }, board)
	outline(card, COL.line, 1, 0.45)
	Menu.profileCard = card
	Menu.profileBody = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, card)
end

-- fades between screens
Menu.fader = frame({ Position = UDim2.new(0, -300, 0, -300), Size = UDim2.new(1, 600, 1, 600), BackgroundColor3 = COL.bg2, BackgroundTransparency = 1, ZIndex = 45, Active = false }, Menu.gui)

---------------------------------------------------------------- the title screen (shown while the game loads)

do
	local ts = Menu.screen("title")
	-- a big ball behind the wordmark
	local orb = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 300), Size = UDim2.fromOffset(420, 420), BackgroundTransparency = 1 }, ts)
	round(orb, 210)
	make("UIStroke", { Color = COL.teal, Thickness = 3, Transparency = 0.75 }, orb)
	local inner = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundTransparency = 1 }, orb)
	round(inner, 210)
	make("UIStroke", { Color = COL.pink, Thickness = 2, Transparency = 0.8 }, inner)
	Menu.titleOrb = orb
	local mark = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 160), Size = UDim2.fromOffset(760, 230), BackgroundTransparency = 1 }, ts)
	text({ Size = UDim2.new(1, 0, 0, 60), Text = "ARENA", FontFace = WORDMARK, TextSize = 64, TextColor3 = COL.teal }, mark)
	text({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 120), Text = "VOLLEYBALL", FontFace = WORDMARK, TextSize = 118, TextColor3 = COL.teal }, mark)
	Menu.titlePrompt = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 400), Size = UDim2.fromOffset(640, 30), BackgroundTransparency = 1 }, ts)
	local key = frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -48, 0.5, 0), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = COL.teal }, Menu.titlePrompt)
	round(key, 11)
	text({ Size = UDim2.fromScale(1, 1), Text = "A", FontFace = FONT.title, TextSize = 13, TextColor3 = COL.ink }, key)
	Menu.titlePromptText = text({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -40, 0.5, 0), Size = UDim2.fromOffset(200, 30), Text = "PRESS ANY BUTTON", FontFace = FONT.head, TextSize = 22, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, Menu.titlePrompt)
	Menu.titleKey = key
	text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(640, 480),
		Size = UDim2.fromOffset(640, 70),
		Text = "ARENA VOLLEYBALL   ·   SEASON 1\nThis game saves your progress automatically. Please don't leave\nwhile the saving icon is showing.",
		FontFace = FONT.head,
		TextSize = 14,
		LineHeight = 1.15,
	}, ts)
	-- the spinning loading / saving icon
	Menu.titleSpinner = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 630), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1 }, ts)
	round(Menu.titleSpinner, 15)
	make("UIStroke", { Color = COL.text, Thickness = 2 }, Menu.titleSpinner)
	frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 0, 2), BackgroundColor3 = COL.text }, Menu.titleSpinner)
	Menu.titleLoaded = false
	Menu.onShow.title = function()
		Menu.logo.Visible = false
	end
	-- loading: wait for the game's pieces (and your profile, briefly), then ask for a button
	task.spawn(function()
		shared:WaitForChild("MenuModel", 10)
		local started = os.clock()
		while not Menu.profileLoaded and os.clock() - started < 4 do
			task.wait(0.1)
		end
		task.wait(0.8)
		Menu.titleLoaded = true
	end)
	RunService.RenderStepped:Connect(function(dt)
		if Menu.current ~= "title" or not Menu.gui.Enabled then
			return
		end
		Menu.titleSpinner.Rotation = (Menu.titleSpinner.Rotation + dt * 240) % 360
		Menu.titleOrb.Rotation = (Menu.titleOrb.Rotation + dt * 6) % 360
		local blink = Menu.titleLoaded and (0.5 + 0.5 * math.sin(os.clock() * 4)) or 0.85
		Menu.titlePromptText.TextTransparency = 1 - blink
		Menu.titleKey.BackgroundTransparency = 1 - blink
		Menu.titlePromptText.Text = Menu.titleLoaded and "PRESS ANY BUTTON" or "LOADING"
	end)
	local function leave(input)
		if Menu.current ~= "title" or not Menu.titleLoaded then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseWheel or input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
			return
		end
		Menu.logo.Visible = true
		Menu.show("home", false)
	end
	UserInputService.InputBegan:Connect(leave)
end

local function firstWord(name)
	return string.match(name, "^(%S+)") or name
end

-- last five results for a club this session (most recent first)
local function formOf(teamId)
	local form = {}
	for i = #history, 1, -1 do
		local h = history[i]
		if h.home == teamId or h.away == teamId then
			local won = (h.winner == 1 and h.home == teamId) or (h.winner == 2 and h.away == teamId)
			table.insert(form, won and "W" or "L")
			if #form == 5 then
				break
			end
		end
	end
	return form
end

---------------------------------------------------------------- HOME

do
	local home = Menu.screen("home")
	Menu.frontTabs(home, 1)

	-- QUICK PLAY: the next fixture
	local qp = Menu.tile(home, UDim2.fromOffset(268, 202), UDim2.fromOffset(224, 398), function()
		Menu.openTeamSelect()
	end)
	Menu.title(qp, "QUICK PLAY")
	Menu.qpDate = text({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 16), FontFace = FONT.head, TextSize = 14 }, qp)
	Menu.qpTime = text({ Position = UDim2.fromOffset(0, 75), Size = UDim2.new(1, 0, 0, 16), FontFace = FONT.head, TextSize = 14 }, qp)
	Menu.qpContent = frame({ Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1 }, qp)
	local league = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(150, 38), BackgroundTransparency = 1 }, qp)
	Menu.icon(league, "ball", 30, COL.text, UDim2.fromOffset(16, 19))
	text({ Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(110, 38), Text = "ARENA\nLEAGUE", FontFace = FONT.title, TextSize = 16, LineHeight = 0.9, TextXAlignment = Enum.TextXAlignment.Left }, league)

	-- CAREER: a player in kit with a ball
	local career = Menu.tile(home, UDim2.fromOffset(500, 202), UDim2.fromOffset(224, 398), function()
		Menu.openCareer()
	end)
	career.BackgroundColor3 = Color3.new(1, 1, 1)
	career.BackgroundTransparency = 0
	gradient(career, Color3.fromRGB(30, 150, 160), COL.bg1, 115)
	Menu.careerArt = Menu.avatar(career, { Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(224, 280) }, -0.25)
	text({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 46), Text = "CAREER", FontFace = FONT.num, TextSize = 46, TextColor3 = COL.teal, TextStrokeTransparency = 0.6 }, career)
	text({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 14), Text = "M  O  D  E", FontFace = FONT.title, TextSize = 12 }, career)
	Menu.careerInfo = text({ Position = UDim2.fromOffset(12, 300), Size = UDim2.fromOffset(200, 40), FontFace = FONT.head, TextSize = 14, TextWrapped = true }, career)
	Menu.careerChip = Menu.chip(career, "NEW", UDim2.new(0, 16, 1, -40))

	-- ONLINE: seasons
	local online = Menu.tile(home, UDim2.fromOffset(732, 202), UDim2.fromOffset(480, 262), function()
		Menu.openOnline()
	end)
	Menu.title(online, "PLAY ONLINE\nSEASONS", 40)
	text({
		Position = UDim2.fromOffset(16, 116),
		Size = UDim2.fromOffset(230, 90),
		Text = "Play ranked 6v6 matches against players from around the world and climb the divisions!",
		FontFace = FONT.head,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, online)
	Menu.onlineChip = Menu.chip(online, "NEW", UDim2.fromOffset(16, 218))
	Menu.onlineArt = Menu.avatar(online, { Position = UDim2.fromOffset(250, 4), Size = UDim2.fromOffset(226, 256) }, 0.5)

	-- LIVE CONTENT: tips and news
	local live = Menu.tile(home, UDim2.fromOffset(732, 472), UDim2.fromOffset(480, 128))
	Menu.title(live, "ARENA LIVE CONTENT", 28)
	Menu.liveText = text({
		Position = UDim2.fromOffset(16, 54),
		Size = UDim2.fromOffset(448, 64),
		Text = "Check here for the latest news and updates!",
		FontFace = FONT.head,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, live)

	-- settings, where the accessibility button sits
	local settingsButton = button({ Position = UDim2.fromOffset(76, 540), Size = UDim2.fromOffset(180, 60), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, home)
	gradient(settingsButton, COL.violet, Color3.fromRGB(110, 70, 230), 0)
	local disc = frame({ Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = COL.teal }, settingsButton)
	round(disc, 18)
	Menu.icon(disc, "sliders", 20, COL.ink, UDim2.fromScale(0.5, 0.5))
	text({ Position = UDim2.fromOffset(58, 0), Size = UDim2.fromOffset(110, 60), Text = "SETTINGS", FontFace = FONT.head, TextSize = 19, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, settingsButton)
	settingsButton.Activated:Connect(function()
		Menu.openSettings()
	end)

	Menu.hints(home, { { "CLICK", "Select" } })
end

local TIPS = {
	"Season 1 is live: 6v6 on a real-size court. Pick from twelve Arena League clubs in Quick Play.",
	"TIP: Jump and press E at the net to tip the ball over a big block.",
	"TIP: Let go of a serve in the green zone. Too much power and it sails long.",
	"TIP: Stars matter. A five-star club's AI reads the game faster and hits harder.",
	"TIP: Press a touch a moment early: it's played as soon as the ball arrives.",
	"TIP: Jumping and diving use stamina. Tired legs don't jump as high.",
}
task.spawn(function()
	local i = 1
	while true do
		task.wait(6)
		i = i % #TIPS + 1
		Menu.liveText.Text = TIPS[i]
	end
end)

function Menu.refreshHome()
	Menu.qpDate.Text = os.date("%d %B %Y")
	Menu.qpTime.Text = os.date("%H:%M")
	local c = Menu.qpContent
	c:ClearAllChildren()
	lineBetween(c, Vector2.new(94, 100), Vector2.new(130, 46), 2, COL.violet, 0.2)
	for i, id in { sel.home, sel.away } do
		local x = (i == 1) and 56 or 168
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(100, 34), Text = ordinal(Teams.rank(id)), FontFace = FONT.body, TextSize = 32 }, c)
		badge(c, id, 60, UDim2.fromOffset(x, 42), Vector2.new(0.5, 0))
		local form = formOf(id)
		for k = 1, 5 do
			local r = form[k]
			local dot = frame({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(x - 32 + (k - 1) * 16, 112),
				Size = UDim2.fromOffset(14, 14),
				BackgroundColor3 = r == "W" and COL.win or r == "L" and COL.loss or Color3.fromRGB(110, 110, 145),
			}, c)
			round(dot, 7)
			text({ Size = UDim2.fromScale(1, 1), Text = r or "-", FontFace = FONT.title, TextSize = 9 }, dot)
		end
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 132), Size = UDim2.fromOffset(110, 18), Text = firstWord(Teams.list[id].name), FontFace = FONT.head, TextSize = 15 }, c)
	end
	local v = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(112, 72), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = COL.bg2 }, c)
	round(v, 17)
	make("UIStroke", { Color = COL.violet, Thickness = 2 }, v)
	text({ Size = UDim2.fromScale(1, 1), Text = "V", FontFace = FONT.head, TextSize = 18 }, v)
	Menu.careerArt.set({ team = sel.home, number = 10, ball = true })
	Menu.onlineArt.set({ team = sel.away, number = 7 })
end
Menu.onShow.home = Menu.refreshHome

---------------------------------------------------------------- PLAY / ONLINE / CUSTOMISE tabs

do
	local play = Menu.screen("play")
	Menu.frontTabs(play, 2)
	local qp = Menu.tile(play, UDim2.fromOffset(268, 202), UDim2.fromOffset(470, 398), function()
		Menu.openTeamSelect()
	end)
	qp.BackgroundColor3 = Color3.new(1, 1, 1)
	qp.BackgroundTransparency = 0
	gradient(qp, COL.panelHi, COL.bg2, 120)
	Menu.title(qp, "QUICK PLAY", 40)
	text({ Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(300, 60), Text = "Pick any two Arena League clubs and play a 6v6 match against the AI.", FontFace = FONT.head, TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, qp)
	Menu.playArt = Menu.avatar(qp, { Position = UDim2.fromOffset(200, 60), Size = UDim2.fromOffset(270, 336) }, -0.3)
	Menu.chip(qp, "PLAY NOW", UDim2.new(0, 16, 1, -40))
	local career = Menu.tile(play, UDim2.fromOffset(746, 202), UDim2.fromOffset(466, 195), function()
		Menu.openCareer()
	end)
	Menu.title(career, "CAREER", 34)
	text({ Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(430, 50), Text = "Choose your club and position and work your way up from rookie to pro.", FontFace = FONT.head, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, career)
	Menu.chip(career, "PLAY NOW", UDim2.new(0, 16, 1, -40))
	local practice = Menu.tile(play, UDim2.fromOffset(746, 405), UDim2.fromOffset(466, 195), function()
		Menu.openPractice()
	end)
	Menu.title(practice, "PRACTICE ARENA", 34)
	text({ Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(430, 50), Text = "Serving, receiving and attacking drills, or free play with no score.", FontFace = FONT.head, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, practice)
	Menu.chip(practice, "OPEN", UDim2.new(0, 16, 1, -40))
	Menu.hints(play, { { "CLICK", "Select" } })
	Menu.onShow.play = function()
		Menu.playArt.set({ team = sel.home, number = 9, ball = true })
	end

	for i, info in {
		{ "online", "ONLINE SEASONS", "Ranked 6v6 against other players. Win matches to climb ten divisions.", "CO-OP SEASONS", "Team up with a friend against other duos." },
		{ "customise", "EDIT PLAYER", "Your shirt number, your preferred position, and whether you wear the team kit.", "KITS AND COURTS", "Home, away and third kits for every club, and five court styles." },
	} do
		local page = Menu.screen(info[1])
		Menu.frontTabs(page, i + 2)
		for k = 0, 1 do
			local live = info[1] == "customise" or k == 0
			local t = Menu.tile(page, UDim2.fromOffset(268 + k * 476, 202), UDim2.fromOffset(468, 398), function()
				if info[1] == "customise" then
					if k == 0 then
						Menu.openEditPlayer()
					else
						Menu.openKits()
					end
				elseif live then
					Menu.openOnline()
				else
					Menu.toast("Coming soon")
				end
			end)
			Menu.title(t, info[2 + k * 2], 36)
			text({ Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(430, 60), Text = info[3 + k * 2], FontFace = FONT.head, TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, t)
			if live then
				Menu.chip(t, info[1] == "customise" and "OPEN" or "PLAY NOW", UDim2.new(0, 16, 1, -40))
			else
				Menu.chip(t, "COMING SOON", UDim2.new(0, 16, 1, -40), COL.text)
			end
		end
		Menu.hints(page, { { "CLICK", "Select" } })
	end
end

---------------------------------------------------------------- TEAM SELECT

do
	local ts = Menu.screen("teams")
	text({ Position = UDim2.fromOffset(70, 34), Size = UDim2.fromOffset(500, 44), Text = "QUICK PLAY", FontFace = FONT.body, TextSize = 40, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left }, ts)
	Menu.tsSub = text({ Position = UDim2.fromOffset(72, 80), Size = UDim2.fromOffset(700, 22), Text = "TEAM SELECT", FontFace = FONT.head, TextSize = 18, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, ts)

	local function panel(x)
		local p = button({ Position = UDim2.fromOffset(x, 124), Size = UDim2.fromOffset(460, 440), BackgroundTransparency = 0.12, BackgroundColor3 = COL.panel }, ts)
		local stroke = outline(p, COL.line, 1, 0.45)
		local content = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, p)
		return { button = p, stroke = stroke, content = content }
	end
	Menu.tsLeft = panel(120)
	Menu.tsRight = panel(700)
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 300), Size = UDim2.fromOffset(120, 80), Text = "VS", FontFace = FONT.num, TextSize = 64, TextColor3 = COL.dim, TextTransparency = 0.3 }, ts)
	local swap = secondaryButton({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 380), Size = UDim2.fromOffset(104, 36) }, ts, "⇄  SWAP", 15)
	swap.Activated:Connect(function()
		if state.active then
			sel.side = 3 - sel.side
		else
			sel.home, sel.away = sel.away, sel.home
			resetPlan()
		end
		Menu.refreshTeams()
	end)
	Menu.tsLeft.button.Activated:Connect(function()
		if state.active then
			sel.side = 1
			Menu.refreshTeams()
		end
	end)
	Menu.tsRight.button.Activated:Connect(function()
		if state.active then
			sel.side = 2
			Menu.refreshTeams()
		end
	end)

	local continue = primaryButton({ Position = UDim2.fromOffset(930, 588), Size = UDim2.fromOffset(230, 52) }, ts, "CONTINUE  ▸", 21)
	continue.Activated:Connect(function()
		Menu.openPreview()
	end)
	Menu.hints(ts, { { "BACK", "Back", Menu.back }, { "CLICK", "Change teams" } }, UDim2.fromOffset(120, 600))
end

local STAT_ROWS = { { "ATK", "ATTACK" }, { "BLK", "BLOCK" }, { "SRV", "SERVE" }, { "REC", "RECEPTION" } }

local function fillTeamPanel(panel, id, header, accent, canChange, onStep, chosen)
	local c = panel.content
	c:ClearAllChildren()
	panel.stroke.Color = chosen and COL.teal or COL.line
	panel.stroke.Transparency = chosen and 0 or 0.45
	panel.stroke.Thickness = chosen and 2 or 1
	local def = Teams.list[id]
	local ratings = Teams.ratings(id)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = header, FontFace = FONT.title, TextSize = 20, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Left }, c)
	badge(c, id, 116, UDim2.fromOffset(230, 50), Vector2.new(0.5, 0))
	if canChange then
		for k, glyph in { "◀", "▶" } do
			local arrow = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(k == 1 and 60 or 400, 108), Size = UDim2.fromOffset(46, 60), BackgroundTransparency = 0.3, BackgroundColor3 = COL.panelHi }, c)
			round(arrow, 6)
			text({ Size = UDim2.fromScale(1, 1), Text = glyph, FontFace = FONT.title, TextSize = 24 }, arrow)
			arrow.Activated:Connect(function()
				onStep(k == 1 and -1 or 1)
			end)
		end
	end
	text({ Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 34), Text = def.name, FontFace = FONT.title, TextSize = 30 }, c)
	text({ Position = UDim2.fromOffset(0, 210), Size = UDim2.new(1, 0, 0, 18), Text = Teams.LEAGUE .. "   ·   " .. ordinal(Teams.rank(id)), FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim }, c)
	starRow(c, Teams.stars(ratings.OVR), 26, UDim2.fromOffset(230, 234), Vector2.new(0.5, 0))
	local ovr = frame({ Position = UDim2.fromOffset(372, 14), Size = UDim2.fromOffset(68, 58), BackgroundColor3 = ratingColor(ratings.OVR) }, c)
	round(ovr, 4)
	text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 34), Text = tostring(ratings.OVR), FontFace = FONT.num, TextSize = 32, TextColor3 = COL.ink }, ovr)
	text({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 14), Text = "OVR", FontFace = FONT.title, TextSize = 12, TextColor3 = COL.ink }, ovr)
	for i, row in STAT_ROWS do
		local y = 282 + (i - 1) * 34
		local value = ratings[row[1]]
		text({ Position = UDim2.fromOffset(30, y), Size = UDim2.fromOffset(110, 24), Text = row[2], FontFace = FONT.head, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, c)
		local back = frame({ Position = UDim2.fromOffset(140, y + 9), Size = UDim2.fromOffset(230, 7), BackgroundColor3 = COL.bg2 }, c)
		frame({ Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1), BackgroundColor3 = ratingColor(value) }, back)
		text({ Position = UDim2.fromOffset(380, y), Size = UDim2.fromOffset(50, 24), Text = tostring(value), FontFace = FONT.num, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right }, c)
	end
end

local function stepTeam(field, other, d)
	local count = #Teams.list
	local id = sel[field]
	repeat
		id = (id - 1 + d) % count + 1
	until id ~= sel[other]
	sel[field] = id
	if field == "home" then
		resetPlan()
	end
	Menu.refreshTeams()
end

function Menu.refreshTeams()
	if state.active then
		-- a match is already on: join it, on the side you choose
		Menu.tsSub.Text = "A MATCH IS IN PROGRESS   ·   CHOOSE YOUR SIDE"
		local a, b = state.teamIds[1], state.teamIds[2]
		fillTeamPanel(Menu.tsLeft, a, sel.side == 1 and "YOUR SIDE" or "HOME", sel.side == 1 and COL.teal or COL.dim, false, nil, sel.side == 1)
		fillTeamPanel(Menu.tsRight, b, sel.side == 2 and "YOUR SIDE" or "AWAY", sel.side == 2 and COL.teal or COL.dim, false, nil, sel.side == 2)
	else
		Menu.tsSub.Text = "TEAM SELECT   ·   LEFT IS YOUR TEAM"
		fillTeamPanel(Menu.tsLeft, sel.home, "YOUR TEAM", COL.teal, true, function(d)
			stepTeam("home", "away", d)
		end, true)
		fillTeamPanel(Menu.tsRight, sel.away, "OPPONENT", COL.coral, true, function(d)
			stepTeam("away", "home", d)
		end, false)
	end
end
Menu.onShow.teams = Menu.refreshTeams

function Menu.openTeamSelect()
	sel.side = 1
	Menu.show("teams")
end
