
---------------------------------------------------------------- in-match HUD (broadcast style)

local HUD = { stamina = 1, power = nil }
HUD.gui = make("ScreenGui", {
	Name = "VolleyballHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
}, player:WaitForChild("PlayerGui"))
-- keep clear of Roblox's own buttons along the top
pcall(function()
	HUD.gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)
-- everything is laid out for a 1280 x 720 screen and scaled to fit the real one
HUD.root = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, HUD.gui)
do
	local scale = make("UIScale", { Scale = 1 }, HUD.root)
	local function fit()
		local size = HUD.gui.AbsoluteSize
		if size.X < 10 then
			return
		end
		local s = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1.3)
		scale.Scale = s
		HUD.root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	HUD.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
end
local hud = HUD.root
HUD.touchMode = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right

-- scorebug, top left:  SET 1 | ACV | 12 - 9 | NPT
do
	local bug = frame({ Position = UDim2.fromOffset(28, 22), Size = UDim2.fromOffset(294, 52), BackgroundTransparency = 1 }, hud)
	local setBox = frame({ Size = UDim2.fromOffset(70, 30), BackgroundColor3 = Color3.new(1, 1, 1) }, bug)
	gradient(setBox, COL.teal, COL.violet, 0)
	HUD.setLabel = text({ Size = UDim2.fromScale(1, 1), Text = "SET 1", FontFace = FONT.num, TextSize = 17, TextColor3 = COL.ink }, setBox)
	local function teamBox(x)
		local box = frame({ Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(74, 30), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.05 }, bug)
		local name = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.title, TextSize = 18 }, box)
		local stripe = frame({ Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3) }, box)
		local dot = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = COL.gold, Visible = false }, box)
		round(dot, 4)
		return name, stripe, dot
	end
	HUD.homeName, HUD.homeStripe, HUD.homeServe = teamBox(70)
	HUD.homeServe.Position = UDim2.new(0, 9, 0.5, 0)
	local scoreBox = frame({ Position = UDim2.fromOffset(144, 0), Size = UDim2.fromOffset(76, 30), BackgroundColor3 = COL.panelHi }, bug)
	HUD.scorePop = make("UIScale", { Scale = 1 }, scoreBox)
	HUD.score = text({ Size = UDim2.fromScale(1, 1), Text = "0 - 0", FontFace = FONT.num, TextSize = 21 }, scoreBox)
	HUD.awayName, HUD.awayStripe, HUD.awayServe = teamBox(220)
	HUD.awayServe.Position = UDim2.new(1, -9, 0.5, 0)
	local strip = frame({ Position = UDim2.fromOffset(0, 32), Size = UDim2.fromOffset(294, 18), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.25 }, bug)
	HUD.target = text({ Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(220, 18), FontFace = FONT.head, TextSize = 11, TextColor3 = COL.dim, TextXAlignment = LEFT }, strip)
	HUD.dots = {}
	for i = 1, 3 do
		HUD.dots[i] = frame({ Position = UDim2.new(1, -62 + (i - 1) * 18, 0.5, -4), Size = UDim2.fromOffset(12, 8), BackgroundColor3 = COL.text, BackgroundTransparency = 0.8 }, strip)
	end
end

-- court radar, bottom centre: your half at the bottom
do
	local W, H = 84, 156
	-- on phones the bottom corners belong to your thumbs, so the radar goes top right
	local radar = frame({
		AnchorPoint = HUD.touchMode and Vector2.new(1, 0) or Vector2.new(0.5, 1),
		Position = HUD.touchMode and UDim2.new(1, -20, 0, 16) or UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(W + 18, H + 18),
		BackgroundColor3 = COL.bg2,
		BackgroundTransparency = 0.3,
	}, hud)
	outline(radar, COL.line, 1, 0.5)
	local court = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(214, 128, 62), BackgroundTransparency = 0.5 }, radar)
	outline(court, Color3.new(1, 1, 1), 1, 0.3)
	frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1) }, court)
	for _, y in { 0.5 - 1 / 6, 0.5 + 1 / 6 } do
		frame({ Position = UDim2.new(0, 0, y, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55 }, court)
	end
	HUD.radar, HUD.radarCourt = radar, court
	HUD.radarDots = {}
	HUD.radarBall = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(255, 222, 70), ZIndex = 3 }, court)
	round(HUD.radarBall, 3)
end

-- player panels: you bottom left, the opponent on the ball bottom right
local function playerPanel(right)
	local holder = frame({
		AnchorPoint = Vector2.new(right and 1 or 0, 1),
		Position = right and UDim2.new(1, -28, 1, -24) or UDim2.new(0, 28, 1, -24),
		Size = UDim2.fromOffset(290, 40),
		BackgroundTransparency = 1,
	}, hud)
	local crest = frame({ Position = right and UDim2.new(1, -38, 0, 0) or UDim2.new(), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = COL.teal }, holder)
	round(crest, 19)
	local crestStroke = make("UIStroke", { Thickness = 2, Color = COL.ink }, crest)
	local crestText = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.title, TextSize = 11 }, crest)
	local plate = frame({ Position = right and UDim2.new(1, -286, 0, 3) or UDim2.fromOffset(42, 3), Size = UDim2.fromOffset(244, 25), BackgroundColor3 = Color3.new(1, 1, 1) }, holder)
	gradient(plate, COL.bg2, COL.panelHi, right and 180 or 0)
	local name = text({
		Position = UDim2.fromOffset(right and 46 or 10, 0),
		Size = UDim2.new(1, -56, 1, 0),
		FontFace = FONT.title,
		TextSize = 16,
		RichText = true,
		TextXAlignment = right and RIGHT or LEFT,
	}, plate)
	local ovr = frame({ Position = right and UDim2.fromOffset(4, 3) or UDim2.new(1, -40, 0, 3), Size = UDim2.fromOffset(36, 19), BackgroundColor3 = COL.teal }, plate)
	local ovrText = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.num, TextSize = 14, TextColor3 = COL.ink }, ovr)
	local barBack = frame({ Position = right and UDim2.new(1, -286, 0, 31) or UDim2.fromOffset(42, 31), Size = UDim2.fromOffset(244, 5), BackgroundColor3 = COL.ink, BackgroundTransparency = 0.3 }, holder)
	local bar = frame({ AnchorPoint = Vector2.new(right and 1 or 0, 0), Position = right and UDim2.fromScale(1, 0) or UDim2.new(), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 150, 255) }, barBack)
	return { holder = holder, crest = crest, crestStroke = crestStroke, crestText = crestText, name = name, ovr = ovr, ovrText = ovrText, bar = bar }
end
HUD.me = playerPanel(false)
HUD.them = playerPanel(true)

local function fillPanel(panel, entry, team)
	if not entry then
		panel.holder.Visible = false
		return
	end
	local def = teamDef(team)
	panel.holder.Visible = true
	panel.crest.BackgroundColor3 = def.primary
	panel.crestStroke.Color = def.secondary
	panel.crestText.Text = def.short
	panel.crestText.TextColor3 = contrast(def.primary)
	panel.name.Text = "<font transparency=\"0.35\">" .. entry.number .. "</font>  " .. entry.name
	panel.ovrText.Text = tostring(entry.ovr)
	panel.ovr.BackgroundColor3 = ratingColor(entry.ovr)
end

-- name, arrow, stamina and serve power over your player
do
	local tag = make("BillboardGui", {
		Name = "VolleyballTag",
		Size = UDim2.fromOffset(130, 62),
		StudsOffset = Vector3.new(0, 4.4, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	HUD.tag = tag
	HUD.tagName = text({ Size = UDim2.new(1, 0, 0, 16), FontFace = FONT.title, TextSize = 14, TextStrokeTransparency = 0.4, Text = string.upper(player.DisplayName) }, tag)
	local stamBack = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 17), Size = UDim2.fromOffset(46, 4), BackgroundColor3 = COL.ink, BackgroundTransparency = 0.25 }, tag)
	HUD.tagStamina = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 150, 255) }, stamBack)
	HUD.tagArrow = text({ Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 18), Text = "▼", FontFace = FONT.title, TextSize = 19, TextStrokeTransparency = 0.55 }, tag)
	local powerBack = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(90, 9), BackgroundColor3 = COL.ink, BackgroundTransparency = 0.2, Visible = false }, tag)
	frame({ Position = UDim2.fromScale(0.65, 0), Size = UDim2.fromScale(0.25, 1), BackgroundColor3 = Color3.fromRGB(90, 220, 140), BackgroundTransparency = 0.25 }, powerBack)
	HUD.powerFill = frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.gold }, powerBack)
	HUD.powerBack = powerBack
end

-- point banner: sweeps across, broadcast style
do
	local holder = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromOffset(640, 80), BackgroundTransparency = 1, ClipsDescendants = true }, hud)
	local plate = frame({ Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(-1.05, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, holder)
	gradient(plate, COL.bg1, COL.panelHi, 0)
	frame({ Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.teal }, plate)
	frame({ Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.pink }, plate)
	HUD.bannerCrest = frame({ Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1 }, plate)
	HUD.bannerTitle = text({ Position = UDim2.fromOffset(92, 6), Size = UDim2.new(1, -110, 0, 46), FontFace = FONT.num, TextSize = 42, TextXAlignment = LEFT }, plate)
	HUD.bannerSub = text({ Position = UDim2.fromOffset(94, 52), Size = UDim2.new(1, -110, 0, 18), FontFace = FONT.head, TextSize = 14, TextColor3 = COL.cyan, TextXAlignment = LEFT }, plate)
	HUD.bannerPlate = plate
end

local bannerToken = 0
function HUD.showBanner(title, sub, team)
	bannerToken += 1
	local token = bannerToken
	local big, small = title, sub
	local s, e = string.find(title, " POINT")
	if s and e == #title then
		big, small = sub, title
		local scorer = lastTouch.team == team and entryAt(team, lastTouch.index)
		if scorer and big ~= "OUT" and big ~= "DROPPED" and big ~= "INTO THE NET" then
			small ..= "   ·   #" .. scorer.number .. " " .. scorer.name
		end
	end
	HUD.bannerTitle.Text = string.upper(big)
	HUD.bannerSub.Text = string.upper(small)
	HUD.bannerCrest:ClearAllChildren()
	if team == 1 or team == 2 then
		badge(HUD.bannerCrest, state.teamIds[team], 56)
	end
	local plate = HUD.bannerPlate
	plate.Position = UDim2.fromScale(-1.05, 0)
	TweenService:Create(plate, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }):Play()
	task.delay(2.4, function()
		if bannerToken == token then
			TweenService:Create(plate, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.05, 0) }):Play()
		end
	end)
end

-- button prompts, top right (can be turned off in settings)
do
	HUD.prompts = frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 22), Size = UDim2.fromOffset(240, 150), BackgroundTransparency = 1 }, hud)
	make("UIListLayout", { Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }, HUD.prompts)
	HUD.promptRows = {}
	for i = 1, 5 do
		local row = frame({ Size = UDim2.fromOffset(240, 22), BackgroundTransparency = 1, LayoutOrder = i, Visible = false }, HUD.prompts)
		local label = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(150, 22), FontFace = FONT.head, TextSize = 13, TextXAlignment = RIGHT, TextStrokeTransparency = 0.6 }, row)
		local chip = frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -156, 0, 0), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = COL.text }, row)
		round(chip, 11)
		local key = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.title, TextSize = 12, TextColor3 = COL.ink }, chip)
		HUD.promptRows[i] = { row = row, label = label, chip = chip, key = key }
	end
end

function HUD.setPrompts(list)
	for i, r in HUD.promptRows do
		local item = list[i]
		r.row.Visible = item ~= nil
		if item then
			r.key.Text = item[1]
			r.label.Text = string.upper(item[2])
			r.chip.Size = UDim2.fromOffset(math.max(26, #item[1] * 8 + 14), 22)
		end
	end
end

-- "your ball" cue
HUD.cue = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -210), Size = UDim2.fromOffset(380, 30), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, hud)
gradient(HUD.cue, COL.violet, COL.bg1, 0)
HUD.cueText = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.title, TextSize = 15, RichText = true }, HUD.cue)
HUD.cueUntil = 0

-- PERFECT / GOOD / OK / POOR after your touches
HUD.feedback = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(260, 34), FontFace = FONT.num, TextSize = 28, TextTransparency = 1, TextStrokeTransparency = 1 }, hud)
function HUD.flash(message, color)
	local l = HUD.feedback
	l.Text = message
	l.TextColor3 = color
	l.TextTransparency = 0
	l.TextStrokeTransparency = 0.55
	l.Position = UDim2.fromScale(0.5, 0.58)
	TweenService:Create(l, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.54),
	}):Play()
end

function HUD.quality(q)
	if q >= 0.85 then
		HUD.flash("PERFECT", Color3.fromRGB(120, 255, 170))
	elseif q >= 0.65 then
		HUD.flash("GOOD", COL.text)
	elseif q >= 0.4 then
		HUD.flash("OK", COL.dim)
	else
		HUD.flash("POOR", Color3.fromRGB(255, 140, 120))
	end
end

-- touch-screen buttons, in an arc around Roblox's jump button (bottom right)
HUD.touchGui = make("ScreenGui", { Name = "VolleyballTouch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2, Enabled = false }, player:WaitForChild("PlayerGui"))
local function touchButton(label, primary)
	local b = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = primary and COL.teal or COL.bg1,
		BackgroundTransparency = primary and 0.1 or 0.25,
		Text = label,
		FontFace = FONT.title,
		TextSize = 14,
		TextColor3 = primary and COL.ink or COL.text,
		AutoButtonColor = false,
		Visible = HUD.touchMode,
	}, HUD.touchGui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	outline(b, COL.teal, 2, 0.3)
	return b
end
HUD.hitButton = touchButton("HIT", true)
HUD.setButton = touchButton("SET")
HUD.diveButton = touchButton("DIVE")
HUD.abilityButton = touchButton("POWER")
-- same sizes and places Roblox uses for its jump button
local function layoutTouch()
	local vp = workspace.CurrentCamera.ViewportSize
	local small = math.min(vp.X, vp.Y) <= 500
	local jump = small and 70 or 120
	local center = small and Vector2.new(vp.X - 95 + 35, vp.Y - 90 + 35) or Vector2.new(vp.X - 170 + 60, vp.Y - 210 + 60)
	local k = jump / 120
	local function place(b, size, angle, radius)
		local a = math.rad(angle)
		local pos = center + Vector2.new(math.cos(a), math.sin(a)) * radius
		b.Size = UDim2.fromOffset(size, size)
		b.Position = UDim2.fromOffset(pos.X, pos.Y)
		b.TextSize = math.max(11, math.floor(14 * math.max(k, 0.8)))
	end
	local hit, small2, outer = math.max(64, 84 * k), math.max(50, 62 * k), math.max(44, 56 * k)
	local inner = jump / 2 + 12
	place(HUD.hitButton, hit, 180, inner + hit / 2)
	place(HUD.setButton, small2, 228, inner + small2 / 2)
	place(HUD.diveButton, small2, 274, inner + small2 / 2)
	local ring = inner + hit + 14 + outer / 2
	place(HUD.abilityButton, outer, 220, ring)
end
layoutTouch()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouch)
if HUD.touchMode then
	HUD.prompts.Visible = false
	HUD.me.holder.Visible = false
	HUD.them.holder.Visible = false
end

-- ability meter and stamina bar: above your player panel (top centre on phones)
do
	local box = frame({
		AnchorPoint = HUD.touchMode and Vector2.new(0.5, 0) or Vector2.new(0, 1),
		Position = HUD.touchMode and UDim2.new(0.5, 0, 0, 12) or UDim2.new(0, 70, 1, -72),
		Size = UDim2.fromOffset(244, 54),
		BackgroundTransparency = 1,
	}, hud)
	-- stamina: jumping and diving use it, it comes back while you're on the ground
	local stam = frame({ Position = UDim2.fromOffset(0, HUD.touchMode and 30 or 0), Size = UDim2.fromOffset(244, 22), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.15 }, box)
	round(stam, 4)
	HUD.staminaStroke = outline(stam, COL.coral, 2, 1)
	HUD.staminaFill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.win }, stam)
	round(HUD.staminaFill, 4)
	HUD.staminaText = text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = "STAMINA", FontFace = FONT.title, TextSize = 13, TextXAlignment = LEFT, TextStrokeTransparency = 0.6 }, stam)
	HUD.staminaValue = text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = "100", FontFace = FONT.num, TextSize = 14, TextXAlignment = RIGHT, TextStrokeTransparency = 0.6 }, stam)
	HUD.staminaBox = stam

	local pill = frame({ Position = UDim2.fromOffset(0, HUD.touchMode and 0 or 28), Size = UDim2.fromOffset(244, 22), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.15 }, box)
	round(pill, 4)
	HUD.abilityStroke = outline(pill, COL.gold, 2, 1)
	HUD.abilityFill = frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = COL.violet }, pill)
	round(HUD.abilityFill, 4)
	HUD.abilityName = text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -50, 1, 0), FontFace = FONT.title, TextSize = 13, TextXAlignment = LEFT, TextStrokeTransparency = 0.6 }, pill)
	local chip = frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(30, 16), BackgroundColor3 = COL.gold, Visible = false }, pill)
	round(chip, 8)
	HUD.abilityKey = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.title, TextSize = 11, TextColor3 = COL.ink, Text = "R" }, chip)
	HUD.abilityChip = chip
	HUD.abilityPill = box
end


-- "POWER SPIKE · #7 SILVA" when anyone uses an ability
do
	local notice = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, HUD.touchMode and 76 or 24), Size = UDim2.fromOffset(400, 34), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, hud)
	HUD.noticeGradient = gradient(notice, COL.violet, COL.bg1, 0)
	HUD.noticeText = text({ Size = UDim2.fromScale(1, 1), FontFace = FONT.title, TextSize = 18 }, notice)
	HUD.notice = notice
end
local noticeToken = 0
function HUD.showNotice(message, color)
	noticeToken += 1
	local token = noticeToken
	HUD.noticeText.Text = message
	HUD.noticeGradient.Color = ColorSequence.new(color or COL.violet, COL.bg1)
	HUD.notice.Visible = true
	task.delay(2, function()
		if noticeToken == token then
			HUD.notice.Visible = false
		end
	end)
end

---------------------------------------------------------------- refreshing the HUD

local lastScore = ""
function HUD.refresh()
	local home, away = teamDef(1), teamDef(2)
	HUD.homeName.Text, HUD.awayName.Text = home.short, away.short
	HUD.homeStripe.BackgroundColor3, HUD.awayStripe.BackgroundColor3 = home.primary, away.primary
	local score = state.score[1] .. " - " .. state.score[2]
	HUD.score.Text = score
	if score ~= lastScore and lastScore ~= "" then
		HUD.scorePop.Scale = 1.2
		TweenService:Create(HUD.scorePop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	lastScore = score
	HUD.homeServe.Visible = state.serving == 1
	HUD.awayServe.Visible = state.serving == 2
	HUD.setLabel.Text = "SET " .. (state.sets[1] + state.sets[2] + 1)
	local target = "FIRST TO " .. (state.points or 25)
	if (state.setsToWin or 1) > 1 then
		target ..= "   ·   SETS " .. state.sets[1] .. "-" .. state.sets[2]
	end
	local mine = myTeam()
	if mine ~= 0 and state.serveIndex then
		-- which rotation your team is in (1 = the lineup as it started)
		local rotation = ((state.serveIndex[mine] or 1) - 1) % 6 + 1
		target ..= "   ·   ROTATION " .. rotation
	end
	HUD.target.Text = target
	local showDots = state.phase == "rally" and state.touchTeam ~= 0 and state.touches > 0
	for i = 1, 3 do
		local used = showDots and i <= state.touches
		HUD.dots[i].BackgroundColor3 = used and teamDef(state.touchTeam).primary or COL.text
		HUD.dots[i].BackgroundTransparency = used and 0 or 0.8
	end

	local me = myEntry()
	local team = myTeam()
	if not HUD.touchMode then
		fillPanel(HUD.me, me, team)
		-- the opponent on the ball: their server, or whoever touched it last
		local opp = 3 - team
		local focus
		if state.serverTeam == opp then
			focus = entryAt(opp, state.serverIndex)
		elseif lastTouch.team == opp then
			focus = entryAt(opp, lastTouch.index)
		end
		fillPanel(HUD.them, focus or entryAt(opp, 1), opp)
	end
	if me then
		HUD.tagArrow.TextColor3 = teamDef(team).primary
	end
end

local function radarPoint(pos, s)
	local x = 0.5 + (pos.X - C.X) * s / (2 * HALF_W)
	local y = 0.5 + (pos.Z - C.Z) * s / (2 * HALF_L)
	return UDim2.fromScale(math.clamp(x, -0.15, 1.15), math.clamp(y, -0.08, 1.08))
end

function HUD.update(t, ballPos)
	local me = myEntry()
	local team = myTeam()
	local s = team == 2 and -1 or 1
	-- radar
	HUD.radar.Visible = settings.radar
	if settings.radar then
		local seen = {}
		for tm = 1, 2 do
			for _, e in state.roster[tm] or {} do
				local model = e.model
				local hrp = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
				if hrp then
					local key = tm * 10 + e.index
					seen[key] = true
					local dot = HUD.radarDots[key]
					if not dot then
						dot = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), ZIndex = 2 }, HUD.radarCourt)
						round(dot, 4)
						make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Enabled = false }, dot)
						HUD.radarDots[key] = dot
					end
					local isMe = e == me
					dot.Visible = true
					dot.BackgroundColor3 = teamDef(tm).primary
					dot.Size = isMe and UDim2.fromOffset(10, 10) or UDim2.fromOffset(7, 7)
					dot.UIStroke.Enabled = isMe
					dot.Position = radarPoint(hrp.Position, s)
				end
			end
		end
		for key, dot in HUD.radarDots do
			if not seen[key] then
				dot.Visible = false
			end
		end
		HUD.radarBall.Visible = ballState.mode ~= "hidden"
		HUD.radarBall.Position = radarPoint(ballPos, s)
	end

	-- the indicator over the player you control, with his name like a football game
	local _, hrp = character()
	local show = not inMenu and me ~= nil and hrp ~= nil
	HUD.tag.Enabled = show
	if show then
		HUD.tag.Adornee = hrp
		HUD.tagName.Text = me.name
	end
	local stamina = math.clamp(HUD.stamina or 1, 0, 1)
	local lowColor = stamina < 0.25 and COL.coral or Color3.fromRGB(70, 150, 255)
	HUD.tagStamina.Size = UDim2.fromScale(stamina, 1)
	HUD.tagStamina.BackgroundColor3 = lowColor
	HUD.me.bar.Size = UDim2.fromScale(stamina, 1)
	HUD.me.bar.BackgroundColor3 = lowColor
	-- the big stamina bar: green, then yellow, then flashing red
	HUD.staminaFill.Size = UDim2.fromScale(math.max(stamina, 0.02), 1)
	HUD.staminaFill.BackgroundColor3 = stamina < 0.25 and COL.loss or stamina < 0.55 and COL.gold or COL.win
	HUD.staminaValue.Text = tostring(math.floor(stamina * 100 + 0.5))
	HUD.staminaStroke.Transparency = stamina < 0.25 and (0.3 + 0.3 * math.sin(t * 10)) or 1
	HUD.staminaText.Text = stamina < 0.25 and "STAMINA  ·  TIRED" or "STAMINA"
	HUD.powerBack.Visible = HUD.power ~= nil
	if HUD.power then
		HUD.powerFill.Size = UDim2.fromScale(HUD.power, 1)
	end
	HUD.cue.Visible = state.phase == "rally" and t < HUD.cueUntil
	HUD.prompts.Visible = settings.hints and not HUD.touchMode
	-- ability meter
	HUD.abilityPill.Visible = me ~= nil
	if me then
		local meter = math.clamp((me.meter or 0) / 100, 0, 1)
		local ready = meter >= 1
		HUD.abilityFill.Size = UDim2.fromScale(meter, 1)
		HUD.abilityFill.BackgroundColor3 = ready and COL.gold or COL.violet
		HUD.abilityName.Text = me.boost and (me.boost .. "  ACTIVE") or (me.ability or "ABILITY")
		HUD.abilityName.TextColor3 = ready and COL.ink or COL.text
		HUD.abilityChip.Visible = ready and not me.boost
		HUD.abilityKey.Text = lastInput == "pad" and "Y" or (HUD.touchMode and "TAP" or "R")
		HUD.abilityStroke.Transparency = (ready or me.boost) and (0.3 + 0.3 * math.sin(t * 8)) or 1
	end
end
