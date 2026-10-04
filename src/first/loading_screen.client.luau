--!strict
-- Custom loading screen styled after doha_hud.png and the boot recording:
--   1. "Signal lost" glitch phase: HUD fragments flash and tilt across a black
--      screen while ContentProvider:PreloadAsync loads the game's assets.
--   2. A [THE ZONE.MIS BRIEF] card confirms the connection.
--   3. The full HUD (SANDSTORM / HGT 5000FT header, THE ZONE centerpiece,
--      coordinate trackers, ETA timers) types itself in, then fades out.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

--------------------------------------------------------------------------------
-- Tuning
--------------------------------------------------------------------------------

local CENTER_PREFIX = "THE"
local CENTER_WORD = "ZONE"
local CENTER_SUBTITLE = "QATAR"
local BRIEF_TITLE = "[THE ZONE.MIS BRIEF]"

local MIN_GLITCH_TIME = 3.5 -- seconds of glitch phase even on instant loads
local BRIEF_HOLD_TIME = 1.2
local HUD_HOLD_TIME = 2.5
local FADE_TIME = 1.2
local PRELOAD_BATCH_SIZE = 20
local MAX_FRAGMENTS = 14

-- The HUD is laid out in doha_hud.png's pixel space and scaled to fit the screen.
local REF_SIZE = Vector2.new(2000, 1125)

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local DISPLAY = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)

local WHITE = Color3.new(1, 1, 1)
local DIM = Color3.fromRGB(125, 125, 125)
local DARK = Color3.fromRGB(70, 70, 70)
local BLACK = Color3.new(0, 0, 0)

local ASSET_CLASSES = {
	"Decal",
	"Texture",
	"Sound",
	"MeshPart",
	"SpecialMesh",
	"ImageLabel",
	"ImageButton",
	"Animation",
	"ParticleEmitter",
	"Beam",
	"Trail",
	"Sky",
	"SurfaceAppearance",
	"Shirt",
	"Pants",
}

local GLITCH_HEADLINES = {
	"< SIGNAL LOST >",
	"AUDIO DISCONNECTED//",
	"FEED LOST",
	"[OS DISABLED]",
	"< RESTARTING >",
	"COMMS LOCKED",
	"[ > | SIG.LOST | < ]",
	"CONNECTION LOST",
	"RECONNECTING...",
	"SAT TRACKER",
	"TROOP MOVEMENT GRID 01",
	"X: -120.0434° X",
}

local GLITCH_LINES = {
	"OFFLINE",
	"DISABLED",
	"SIGNAL",
	"UPLINK",
	"BUFFER",
	"DATA INPUT",
	"DOWNLOAD FAILED - DOWNLOAD FAILED",
	"AMC-18 : ARIANE 5",
	"TYPE-----",
	"COMMS",
	"LOST",
	"ATLAS - 5",
	"PURGED FOOTAGE",
	">>>>>>>",
	"LOC || 33.8890 | -120.0434°",
	"1.405 DIR",
	"SAT . IMP",
	"ERR 0x00A2",
}

--------------------------------------------------------------------------------
-- UI helpers
--------------------------------------------------------------------------------

type TextOpts = {
	size: number?,
	color: Color3?,
	right: boolean?,
	font: Font?,
}

local function makeText(parent: Instance, str: string, x: number, y: number, opts: TextOpts?): TextLabel
	local o: TextOpts = opts or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.FontFace = o.font or MONO
	l.Text = str
	l.TextSize = o.size or 10
	l.TextColor3 = o.color or WHITE
	l.TextXAlignment = if o.right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.AnchorPoint = if o.right then Vector2.new(1, 0) else Vector2.zero
	l.Position = UDim2.fromOffset(x, y)
	l.Parent = parent
	return l
end

-- White bar with black text (or an outlined box with white text).
local function makeTag(
	parent: Instance,
	str: string,
	x: number,
	y: number,
	w: number,
	outline: boolean?,
	h: number?,
	textSize: number?,
	align: Enum.TextXAlignment?
): (Frame, TextLabel)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = if outline then 1 else 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h or 11)
	if outline then
		local stroke = Instance.new("UIStroke")
		stroke.Color = WHITE
		stroke.Thickness = 1
		stroke.Parent = f
	end

	local l = makeText(f, str, 3, 0, { size = textSize or 9, color = if outline then WHITE else BLACK })
	l.AutomaticSize = Enum.AutomaticSize.None
	l.AnchorPoint = Vector2.zero
	l.Size = UDim2.new(1, -6, 1, 0)
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextXAlignment = align or Enum.TextXAlignment.Left

	f.Parent = parent
	return f, l
end

local function makeBox(parent: Instance, x: number, y: number, w: number, h: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = 1
	stroke.Parent = f
	f.Parent = parent
	return f
end

local function makeLine(parent: Instance, x: number, y: number, w: number, h: number, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or WHITE
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

--------------------------------------------------------------------------------
-- Effects
--------------------------------------------------------------------------------

local function typewrite(label: TextLabel, text: string, charDelay: number)
	local len = utf8.len(text) or #text
	for i = 1, len do
		local stop = (utf8.offset(text, i + 1) or (#text + 1)) - 1
		label.Text = string.sub(text, 1, stop) .. "_"
		task.wait(charDelay)
	end
	label.Text = text
end

local function flicker(target: GuiObject, times: number)
	for _ = 1, times do
		target.Visible = false
		task.wait(math.random(2, 7) / 100)
		target.Visible = true
		task.wait(math.random(3, 11) / 100)
	end
end

-- HH:MM:SS:CC
local function formatClock(seconds: number): string
	seconds = math.max(0, seconds)
	local whole = math.floor(seconds)
	local centis = math.floor((seconds - whole) * 100)
	return string.format("%02d:%02d:%02d:%02d", whole // 3600, (whole // 60) % 60, whole % 60, centis)
end

--------------------------------------------------------------------------------
-- Root layers
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = BLACK
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.Position = UDim2.fromScale(0.5, 0.5)
canvas.Size = UDim2.fromOffset(REF_SIZE.X, REF_SIZE.Y)
canvas.BackgroundTransparency = 1
canvas.Parent = overlay

local canvasScale = Instance.new("UIScale")
canvasScale.Parent = canvas

local function fitCanvas()
	local size = overlay.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		canvasScale.Scale = math.min(size.X / REF_SIZE.X, size.Y / REF_SIZE.Y)
	end
end
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCanvas)

local function makeLayer(name: string): Frame
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = canvas
	return layer
end

local glitchLayer = makeLayer("Glitch")
local statusLayer = makeLayer("Status")
local briefLayer = makeLayer("Brief")
local hudLayer = makeLayer("Hud")
briefLayer.Visible = false
hudLayer.Visible = false

--------------------------------------------------------------------------------
-- HUD (doha_hud.png)
--------------------------------------------------------------------------------

local function buildHud(p: Frame): { (number) -> () }
	local live: { (number) -> () } = {}

	local function T(str: string, x: number, y: number, size: number?, color: Color3?, right: boolean?): TextLabel
		return makeText(p, str, x, y, { size = size, color = color, right = right })
	end

	-- Only animate a readout once the reveal has finished typing it.
	local function liveText(label: TextLabel, fn: (number) -> string)
		table.insert(live, function(t)
			if label:GetAttribute("Revealed") then
				label.Text = fn(t)
			end
		end)
	end

	local function jitter(base: number): number
		return base + (math.random() - 0.5) * 0.0006
	end

	-- Top left: hazard header
	makeTag(p, "ALERT", 35, 38, 115, false, 9, 8)
	makeTag(p, "> HAZARD", 150, 38, 57, true, 9, 8)
	T("HAZARD", 43, 71, 9, DIM)
	T("SANDSTORM", 42, 88, 30)
	T("SPD25MPH", 228, 103, 8, DIM)
	T("HGT 5000FT", 298, 88, 30)
	T("VISIBILTY", 300, 158, 10)
	T("EST", 300, 175, 10, DIM)
	T("1-3 FEET", 324, 175, 10)
	T("DIRECTION", 300, 225, 10)
	makeTag(p, "SOUTH", 297, 258, 104)

	-- Top centre: operation
	T("OPERATION | SHEARWATER ||", 630, 96, 20)
	T("MISSION OBJECTIVE", 630, 129, 10)
	T("CLASSIFIED", 630, 142, 10)
	for _, row in { { "FORCE OPERATOR", "UNKNOWN", 160, 130 }, { "BLACK BOX CONTENT", "CLASSIFIED - LEVELALPHA", 160, 180 }, { "BREACH OF CONFIDENTIALITY", "COURT MARTIAL", 88, 230 }, { "PAYMENT UP COMPLETION", "DISCLOSED", 88, 280 } } :: { { any } } do
		T(row[1], 782, row[4], 10)
		makeTag(p, row[2], 778, row[4] + 12, row[3])
	end

	-- Top right: satellite travel time
	local _, satTimer = makeTag(p, formatClock(17 * 60 + 28.42), 1410, 85, 214, false, 26, 28)
	liveText(satTimer, function(t)
		return formatClock(17 * 60 + 28.42 - t)
	end)
	T("TEAM", 1645, 49, 8, DIM)
	T("TO", 1676, 49, 8)
	T("SAT TRVL TIME", 1694, 42, 19)
	makeTag(p, "LOCATE AND SECURE", 1643, 74, 162, true, 10, 8)
	makeTag(p, ">", 1805, 74, 11, false, 10, 8)
	T("> SPD 17.000MPH", 1645, 112, 10)
	T("> HEIGHT 242 KM", 1645, 125, 10)
	T("> CONTROL : LOST", 1645, 137, 10)
	T("CAUSE", 1750, 137, 10, DIM)
	T("- CONFIDENTIAL", 1786, 137, 10)

	T("DEST DOHA", 1630, 222, 19)
	makeTag(p, "QATAR -    M.EAST", 1628, 242, 137)
	local cityRows = {
		{ "AREA", "132 KM2" },
		{ "LOCAL TIME", "JPPG" },
		{ "> ESTABLISHED", "1825" },
		{ "CITY PROPER", "51 SQ M" },
		{ "POPULATION", "2.380.000" },
		{ "DENSITY", "18.000 / KM2" },
		{ "> LAT", "25.2854°" },
		{ "LONG", "51.5310°" },
		{ "", "UTC + 3 (AST_)" },
		{ "TIMEZONE", "" },
		{ "-- --", "" },
		{ ">>> RES", "" },
		{ "", "PUBLIC" },
		{ "DATA.READ", "" },
		{ "A775", "1.1" },
		{ "", "DISBAND" },
		{ ">", "300" },
	}
	for i, row in cityRows do
		local y = 241 + (i - 1) * 12.5
		if row[1] ~= "" then
			T(row[1], 1845, y, 9, DIM, true)
		end
		if row[2] ~= "" then
			T(row[2], 1853, y, 9)
		end
	end
	T(">>>", 1844, 518, 9, nil, true)

	-- Left: NO-PAT ETA
	T("NO-PAT", 74, 342, 28)
	T("D | QRF TEAM", 193, 357, 8, DIM)
	T("ETA", 282, 342, 28)
	T(">>>>>>>", 352, 346, 8)
	T(">>>", 376, 357, 8)
	local _, etaTimer = makeTag(p, formatClock(31.02), 401, 343, 213, false, 26, 28)
	liveText(etaTimer, function(t)
		return formatClock(31.02 - t)
	end)
	makeTag(p, "TO", 284, 382, 40, false, 9, 8, Enum.TextXAlignment.Right)
	T("H", 329, 381, 9)
	T("MISSION", 395, 381, 9, nil, true)
	T("AREA", 395, 394, 9, nil, true)
	T("-", 395, 418, 9, nil, true)
	makeTag(p, "RDY", 338, 432, 62, false, 9, 8, Enum.TextXAlignment.Right)
	T("0000A2", 395, 457, 9, nil, true)

	-- Left: SAT BEACON
	local function strength(t: number): number
		return math.clamp(0.64 + math.sin(t * 1.7) * 0.08 + (math.random() - 0.5) * 0.03, 0, 1)
	end
	T("SAT BEACON", 52, 550, 28)
	makeTag(p, "DIST TO TARGET", 141, 579, 99, false, 9, 8, Enum.TextXAlignment.Center)
	T("> SIGNAL STRENGTH", 238, 591, 9, nil, true)
	local strengthLabel = T("64%", 238, 603, 9, nil, true)
	liveText(strengthLabel, function(t)
		return string.format("%d%%", math.floor(strength(t) * 100))
	end)
	T("A", 238, 629, 9, nil, true)
	T("CLOSED", 238, 642, 9, nil, true)
	T("ENCRYPTION", 238, 654, 9, nil, true)
	makeBox(p, 257, 563, 272, 18)
	makeLine(p, 412, 563, 1, 18)
	T("INCOMING  |  SIGNAL", 418, 567, 9)
	makeBox(p, 257, 588, 272, 18)
	makeTag(p, "  >>", 263, 592, 38, false, 10, 8)
	makeLine(p, 301, 592, 106, 10, DARK)
	local signalFill = makeLine(p, 301, 592, 68, 10, DIM)
	local ticks = {}
	for i = 0, 13 do
		table.insert(ticks, makeLine(p, 415 + i * 5, 592, 2, 10))
	end
	table.insert(live, function(t)
		local s = strength(t)
		signalFill.Size = UDim2.fromOffset(math.floor(106 * s), 10)
		local lit = math.floor(#ticks * s + 0.5)
		for i, tick in ticks do
			tick.BackgroundColor3 = if i <= lit then WHITE else DARK
		end
	end)

	-- Left: SAT 7 / impact estimates
	makeBox(p, 49, 741, 135, 52)
	T("SAT", 63, 752, 28, DIM)
	makeLine(p, 130, 745, 1, 44, DARK)
	T("7", 150, 752, 28)
	T("MISSION AREA", 387, 745, 9, nil, true)
	T("SAT.IMPACT", 200, 752, 28, DIM)
	T("EST. LOCATION", 387, 795, 9, nil, true)
	T(">>>", 387, 808, 9, nil, true)
	for i, row in { { "ONAIZA", "68%" }, { "JELAIAH", "64%" }, { "AL QASSAN", "28%" }, { "DUHAIL", " 5%" } } do
		local y = 820 + (i - 1) * 12.5
		T(row[1], 292, y, 9)
		T("> " .. row[2], 387, y, 9, nil, true)
	end

	-- Bottom left: weather
	T("WIND", 73, 960, 28)
	T("25MPH", 167, 960, 28, DIM)
	T("EST DUR", 353, 952, 9, nil, true)
	T("4 DAYS 13", 284, 978, 9)
	T("H", 348, 978, 9, DIM)
	makeLine(p, 370, 940, 1, 60, DARK)
	T("TEMP", 384, 952, 9, DIM)
	T("45 C", 384, 978, 9, DIM)
	T("CAT 5", 359, 1015, 9, nil, true)
	T("SYS.CHK", 408, 1015, 9, DIM)
	makeTag(p, "SANDSTORM", 271, 1051, 104, false, 11, 9, Enum.TextXAlignment.Center)
	T("DATA", 408, 1040, 9, DIM)
	makeTag(p, "PR GEAR", 405, 1051, 110, false, 11, 9)

	-- Centre: brief column
	T("MIS BRIF", 721, 488, 9, nil, true)
	T("DISCLOSED", 721, 513, 9, nil, true)
	T(">", 634, 525, 9)
	makeTag(p, "ETA..", 644, 526, 82, false, 9, 8, Enum.TextXAlignment.Right)
	T("30 SEC", 721, 538, 9, nil, true)
	T("SRC + RET", 721, 576, 9, nil, true)
	T("QRF", 721, 601, 9, nil, true)
	T("CONFIRMED", 721, 626, 9, nil, true)

	-- Centre: THE ZONE
	makeText(p, CENTER_PREFIX, 742, 432, { size = 34, color = DIM, font = DISPLAY })
	local center = makeText(p, CENTER_WORD, 736, 470, { font = DISPLAY })
	center.Name = "Centerpiece"
	center.AutomaticSize = Enum.AutomaticSize.None
	center.Size = UDim2.fromOffset(436, 150)
	center.TextScaled = true
	center.TextYAlignment = Enum.TextYAlignment.Center
	center:SetAttribute("Display", true)
	makeText(p, CENTER_SUBTITLE, 1170, 606, { size = 38, color = DIM, right = true, font = DISPLAY })
	T("...", 1086, 426, 12)

	-- Centre right: location tracker
	local _, locTag = makeTag(p, "LOC", 1057, 462, 110, false, 9, 8)
	locTag.TextColor3 = DIM
	T("DIS 28", 1187, 438, 9)
	local coordLabel = T("25.2854° N 51.5310° E", 1187, 463, 9)
	liveText(coordLabel, function()
		return string.format("%.4f° N %.4f° E", jitter(25.2854), jitter(51.5310))
	end)
	T("AR", 1187, 513, 9)
	T("-", 1187, 526, 9)
	T("DIS 25", 1187, 600, 9)

	-- Bottom centre: tracking
	T("TRACKING", 615, 902, 9)
	makeTag(p, "SHEARWATER03", 611, 914, 88)
	T("SB", 709, 914, 9)
	T("SPD: 17.000 MPH", 721, 927, 9, nil, true)
	T("ORB:   300  KM", 721, 940, 9, nil, true)
	T("-", 721, 964, 9, nil, true)
	makeTag(p, "ETA:", 611, 989, 42, false, 11, 9, Enum.TextXAlignment.Right)
	local impactLabel = T("00:10 SEC", 665, 989, 9)
	liveText(impactLabel, function(t)
		return string.format("00:%02d SEC", 10 - math.floor(t % 10))
	end)
	T("TO IMPACT", 665, 1014, 9)
	makeBox(p, 740, 915, 30, 30)
	T("+", 750, 920, 14)
	makeLine(p, 788, 931, 120, 1, DARK)

	-- Bottom centre right: geo feed
	T("OBJ", 1170, 806, 8)
	T("LOC", 1168, 815, 28)
	T("DAT.FEED", 1247, 806, 8)
	T("GEO.SAT", 1243, 815, 28, DIM)
	T("LAT", 1245, 855, 9)
	local _, latTag = makeTag(p, "25.2854 ° N", 1242, 868, 106)
	liveText(latTag, function()
		return string.format("%.4f ° N", jitter(25.2854))
	end)
	T("LONG", 1402, 855, 9)
	local _, lonTag = makeTag(p, "51.5310° E", 1398, 868, 106)
	liveText(lonTag, function()
		return string.format("%.4f° E", jitter(51.5310))
	end)

	-- Right: insertion vehicle
	T("NO PAT", 1533, 570, 19, DIM)
	T("INSERTION VEH", 1621, 570, 19)
	makeTag(p, "EMH-7 TINY BIRD", 1529, 602, 117)
	for i, value in { "CAP", "4", "", "282 KM/H", "-", "WGHT", "722 KG", "-", "RANGE", "422 KM", "-", "FF", "1963" } do
		if value ~= "" then
			T(value, 1520, 616 + (i - 1) * 12.4, 9, nil, true)
		end
	end
	makeTag(p, "SPD", 1472, 640, 52, false, 10, 8, Enum.TextXAlignment.Right)

	-- Right: mission details
	T("MISSION", 1700, 700, 28)
	T("DETAILS", 1850, 708, 19)
	makeTag(p, "X", 1679, 742, 14, false, 14, 10, Enum.TextXAlignment.Center)
	T("→ SEC LVL A", 1698, 745, 9)
	makeTag(p, "CLASSIFIED", 1772, 742, 68, true, 14, 9)
	local details = {
		{ 1700, "TYPE" },
		{ 1723, "SRC AND RETRIEVE" },
		{ 1746, "RULES OF ENGAGEMENT", true },
		{ 1746, "WEAPONS FREE" },
		{ 0, "" },
		{ 1700, "→SAT DOWN" },
		{ 1746, "RETRIEVE SAT HARDWARE" },
		{ 1746, "SECURE SITE" },
		{ 1746, "DEFEND UNTIL EVAC" },
		{ 0, "" },
		{ 0, "" },
		{ 1700, "→INTEL" },
		{ 1752, "HOSTILES IN BOUNDS" },
		{ 1752, "USE FORCE TO WHEN NEEDED" },
		{ 1752, "LOCAL RESISTANCE POSSIBLE" },
		{ 1790, "↳S.O.P" },
		{ 0, "" },
		{ 1746, "SUMMARY" },
		{ 0, "" },
		{ 1754, "→.SRC AND RETRIVE" },
		{ 1754, "→.DEF" },
		{ 1754, "→.EXFIL" },
		{ 0, "" },
		{ 1700, "MISSION DEBRIEF - SUCCESRATE - 95.2%" },
	} :: { { any } }
	for i, row in details do
		if row[2] ~= "" then
			T(row[2], row[1], 770 + (i - 1) * 12.5, 9, if row[3] then DIM else nil)
		end
	end

	-- Bottom right: waypoints
	T("MISSION OBJ | WAYPOINTS", 1077, 955, 19)
	makeTag(p, ">> EXE ORDER S.O.P", 1072, 989, 208, false, 11, 9)
	makeTag(p, "TIME SCH", 1308, 987, 58, true, 16, 9)
	makeBox(p, 1482, 989, 12, 12)
	makeLine(p, 1485, 992, 6, 6)
	local waypoints = {
		{ "TOUCHDOWN", "06:00:00 . 3366204" },
		{ "LOC . ASSET", "06:10:00 . 3687737" },
		{ "", "" },
		{ "SEC . HARDWARE", "06:15:00 . 3684899" },
		{ "TRS . TO DEST", "06:55:00 . 3369877" },
		{ "", "" },
		{ "SEC . EXFIL AREA", "07:00:00 . 3369877" },
		{ "EVA . AREA", "07:05:00 . 3369877" },
	}
	for i, row in waypoints do
		local y = 1015 + (i - 1) * 12.6
		if row[1] == "" then
			T("→", 1195, y, 9)
			T("→", 1228, y, 9)
		else
			T(row[1], 1077, y, 9)
			T("D.", 1195, y, 9)
			T("(UTC)", 1228, y, 9)
			T("10/01/2042 " .. row[2], 1312, y, 9)
		end
	end

	return live
end

local hudUpdaters = buildHud(hudLayer)

-- Types every label and flickers every bar on in a left-to-right sweep.
-- Returns once the sweep has finished.
local function revealHud()
	local items: { { inst: GuiObject, text: string? } } = {}
	for _, inst in hudLayer:GetDescendants() do
		if inst:IsA("TextLabel") then
			table.insert(items, { inst = inst, text = inst.Text })
			inst.Text = ""
		elseif inst:IsA("Frame") then
			inst.Visible = false
			table.insert(items, { inst = inst })
		end
	end
	hudLayer.Visible = true

	local origin = canvas.AbsolutePosition
	local size = canvas.AbsoluteSize
	local finish = 0

	for _, item in items do
		local gui = item.inst
		local rel = gui.AbsolutePosition - origin
		local ax = if size.X > 0 then math.clamp(rel.X / size.X, 0, 1) else math.random()
		local ay = if size.Y > 0 then math.clamp(rel.Y / size.Y, 0, 1) else math.random()
		local startDelay = 0.1 + ax * 0.9 + ay * 0.35 + math.random() * 0.3

		local text = item.text
		local duration = 0.3
		if text and gui:IsA("TextLabel") then
			local label = gui :: TextLabel
			local len = math.max(utf8.len(text) or #text, 1)
			local isDisplay = label:GetAttribute("Display") == true
			local charDelay = if isDisplay then 0.1 else math.min(0.025, 0.45 / len)
			duration = len * charDelay + if isDisplay then 0.6 else 0.35
			task.delay(startDelay, function()
				typewrite(label, text, charDelay)
				label:SetAttribute("Revealed", true)
				if isDisplay then
					flicker(label, 4)
				end
			end)
		else
			task.delay(startDelay, function()
				gui.Visible = true
				flicker(gui, 2)
			end)
		end
		finish = math.max(finish, startDelay + duration)
	end

	task.wait(finish)
end

--------------------------------------------------------------------------------
-- Glitch phase ("signal lost" fragments)
--------------------------------------------------------------------------------

local activeFragments = 0

local function spawnFragment()
	activeFragments += 1

	local w, h = 420, 150
	local group = Instance.new("CanvasGroup")
	group.Name = "Fragment"
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.Size = UDim2.fromOffset(w, h)
	group.Position = UDim2.fromOffset(math.random(0, REF_SIZE.X - w), math.random(0, REF_SIZE.Y - h))
	group.Rotation = if math.random() < 0.35 then (math.random() * 2 - 1) * 12 else 0
	group.GroupTransparency = if math.random() < 0.35 then 0.5 else 0

	local top = math.random(6, 30)
	local cursor = top
	if math.random() < 0.7 then
		local size = math.random(12, 22)
		makeText(group, pick(GLITCH_HEADLINES), 90, top, { size = size, color = if math.random() < 0.5 then WHITE else DIM })
		cursor += size + 6
	end

	local tagWidth = math.random(60, 170)
	makeTag(group, pick(GLITCH_LINES), 90, cursor, tagWidth, math.random() < 0.3, 9, 7)
	if math.random() < 0.6 then
		makeLine(group, 90 + tagWidth + 4, cursor + 5, math.random(30, 120), 1, DIM)
	end

	for i = 0, math.random(1, 5) do
		makeText(group, pick(GLITCH_LINES), 84, top + i * 9, { size = 7, color = DIM, right = true })
	end

	if math.random() < 0.35 then
		makeBox(group, 90, cursor + 20, 220, 12)
		makeLine(group, 92, cursor + 22, math.random(20, 216), 8)
	end

	if math.random() < 0.4 then
		local bx, by = math.random(230, 390), math.random(10, 110)
		makeBox(group, bx, by, 12, 12)
		makeText(group, "x", bx + 3, by - 1, { size = 10 })
	end

	group.Parent = glitchLayer

	local life = math.random(8, 70) / 100
	task.spawn(function()
		local born = os.clock()
		while os.clock() - born < life do
			task.wait(math.random(3, 12) / 100)
			if math.random() < 0.25 then
				group.Visible = not group.Visible
			end
		end
		group:Destroy()
		activeFragments -= 1
	end)
end

--------------------------------------------------------------------------------
-- Mission brief card
--------------------------------------------------------------------------------

local briefTitle = makeText(briefLayer, "", REF_SIZE.X / 2, 520, { size = 22, color = BLACK })
briefTitle.AnchorPoint = Vector2.new(0.5, 0.5)
briefTitle.BackgroundColor3 = WHITE
briefTitle.BackgroundTransparency = 0
briefTitle.Visible = false
local briefPadding = Instance.new("UIPadding")
briefPadding.PaddingLeft = UDim.new(0, 4)
briefPadding.PaddingRight = UDim.new(0, 4)
briefPadding.Parent = briefTitle

local secureRow = Instance.new("Frame")
secureRow.BackgroundTransparency = 1
secureRow.AnchorPoint = Vector2.new(0.5, 0.5)
secureRow.Position = UDim2.fromOffset(REF_SIZE.X / 2, 600)
secureRow.AutomaticSize = Enum.AutomaticSize.XY
secureRow.Size = UDim2.fromOffset(0, 0)
secureRow.Visible = false
secureRow.Parent = briefLayer

local secureLayout = Instance.new("UIListLayout")
secureLayout.FillDirection = Enum.FillDirection.Horizontal
secureLayout.VerticalAlignment = Enum.VerticalAlignment.Center
secureLayout.Padding = UDim.new(0, 6)
secureLayout.SortOrder = Enum.SortOrder.LayoutOrder
secureLayout.Parent = secureRow

local secureBullet = makeLine(secureRow, 0, 0, 9, 9)
secureBullet.LayoutOrder = 1
local secureText = makeText(secureRow, "", 0, 0, { size = 11 })
secureText.LayoutOrder = 2

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

screenGui.Parent = playerGui
fitCanvas()

local startClock = os.clock()
local hudStart = 0
local hudConnection = RunService.Heartbeat:Connect(function()
	if hudStart == 0 then
		return
	end
	local t = os.clock() - hudStart
	for _, update in hudUpdaters do
		update(t)
	end
end)

local glitching = true
task.spawn(function()
	while glitching do
		if activeFragments < MAX_FRAGMENTS then
			spawnFragment()
		end
		task.wait(math.random(3, 18) / 100)
	end
end)

local statusLabel = makeText(statusLayer, "", 48, 1092, { size = 10, color = DIM })
typewrite(statusLabel, "> ESTABLISHING UPLINK", 0.03)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local function collectAssets(): { Instance }
	local assets = {}
	for _, root in { workspace, ReplicatedStorage, Lighting, SoundService, playerGui } :: { Instance } do
		for _, inst in root:GetDescendants() do
			for _, className in ASSET_CLASSES do
				if inst:IsA(className) then
					table.insert(assets, inst)
					break
				end
			end
		end
	end
	return assets
end

local function setStatus(loaded: number, total: number)
	local alpha = if total > 0 then loaded / total else 1
	local filled = math.floor(alpha * 20)
	statusLabel.Text = string.format(
		"> SYNC [%s%s] %03d%%   ASSETS %d/%d",
		string.rep("#", filled),
		string.rep(".", 20 - filled),
		math.floor(alpha * 100),
		loaded,
		total
	)
end

local assets = collectAssets()
local total = #assets
setStatus(0, total)

for i = 1, total, PRELOAD_BATCH_SIZE do
	local last = math.min(i + PRELOAD_BATCH_SIZE - 1, total)
	local batch = table.move(assets, i, last, 1, {})
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(batch, function(contentId: string, status: Enum.AssetFetchStatus)
			if status == Enum.AssetFetchStatus.Failure then
				warn("[LoadingScreen] Failed to preload", contentId)
			end
		end)
	end)
	if not ok then
		warn("[LoadingScreen] PreloadAsync error:", err)
	end
	setStatus(last, total)
end
setStatus(total, total)

local remaining = MIN_GLITCH_TIME - (os.clock() - startClock)
if remaining > 0 then
	task.wait(remaining)
end

-- Cut to black, then the mission brief card
glitching = false
glitchLayer:ClearAllChildren()
statusLayer.Visible = false
task.wait(0.3)

briefLayer.Visible = true
briefTitle.Visible = true
typewrite(briefTitle, BRIEF_TITLE, 0.04)
flicker(briefTitle, 3)
secureRow.Visible = true
typewrite(secureText, "CONNECTION SECURE", 0.03)
flicker(secureBullet, 4)
task.wait(BRIEF_HOLD_TIME)
flicker(briefLayer, 3)
briefLayer.Visible = false
task.wait(0.25)

-- Full HUD
hudStart = os.clock()
revealHud()
task.wait(HUD_HOLD_TIME)

--------------------------------------------------------------------------------
-- Fade out and clean up
--------------------------------------------------------------------------------

local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
for _, inst in screenGui:GetDescendants() do
	local goal: { [string]: any }? = nil
	if inst:IsA("TextLabel") then
		goal = { TextTransparency = 1, BackgroundTransparency = 1 }
	elseif inst:IsA("Frame") and inst.BackgroundTransparency < 1 then
		goal = { BackgroundTransparency = 1 }
	elseif inst:IsA("UIStroke") then
		goal = { Transparency = 1 }
	end
	if goal then
		TweenService:Create(inst, fadeInfo, goal):Play()
	end
end
task.wait(FADE_TIME)

hudConnection:Disconnect()
screenGui:Destroy()
