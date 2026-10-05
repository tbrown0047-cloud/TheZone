
---------------------------------------------------------------- customise: edit player, kits and courts

local function saveCustom()
	remote:FireServer("custom_save", Menu.custom)
end

local function customPanel(parent, x, y, w, h)
	local f = frame({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.12 }, parent)
	outline(f, COL.line, 1, 0.45)
	return f
end

local function customHeader(screenFrame, title, subtitle)
	text({ Position = UDim2.fromOffset(72, 30), Size = UDim2.fromOffset(700, 44), Text = title, FontFace = FONT.body, TextSize = 40, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left }, screenFrame)
	text({ Position = UDim2.fromOffset(74, 76), Size = UDim2.fromOffset(900, 22), Text = subtitle, FontFace = FONT.head, TextSize = 18, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, screenFrame)
end

local function stepper(parent, y, label, value, onStep)
	text({ Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(260, 40), Text = label, FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, glyph in { "◀", "▶" } do
		local arrow = secondaryButton({ Position = UDim2.fromOffset(k == 1 and 300 or 480, y), Size = UDim2.fromOffset(44, 40) }, parent, glyph, 18)
		arrow.Activated:Connect(function()
			onStep(k == 1 and -1 or 1)
		end)
	end
	text({ Position = UDim2.fromOffset(344, y), Size = UDim2.fromOffset(136, 40), Text = value, FontFace = FONT.num, TextSize = 26 }, parent)
end

---------------------------------------------------------------- EDIT PLAYER

do
	local screenFrame = Menu.screen("editplayer")
	customHeader(screenFrame, "EDIT PLAYER", "YOUR SHIRT NUMBER, POSITION AND KIT   ·   SAVED AUTOMATICALLY")
	Menu.epArt = Menu.avatar(screenFrame, { Position = UDim2.fromOffset(60, 104), Size = UDim2.fromOffset(380, 520) }, 0.3)
	Menu.epBody = customPanel(screenFrame, 460, 116, 750, 500)
	Menu.hints(screenFrame, { { "BACK", "Back", Menu.back } }, UDim2.fromOffset(460, 636))
end

function Menu.refreshEditPlayer()
	local c = Menu.epBody
	c:ClearAllChildren()
	outline(c, COL.line, 1, 0.45)
	local custom = Menu.custom
	local def = Teams.list[sel.home]
	shirt(c, def.primary, custom.number, 110, UDim2.fromOffset(650, 90))
	text({ Position = UDim2.fromOffset(580, 150), Size = UDim2.fromOffset(140, 22), Text = string.upper(player.DisplayName), FontFace = FONT.title, TextSize = 16 }, c)

	stepper(c, 24, "SHIRT NUMBER", tostring(custom.number), function(d)
		custom.number = (custom.number - 1 + d) % 99 + 1
		saveCustom()
		Menu.refreshEditPlayer()
	end)

	text({ Position = UDim2.fromOffset(24, 96), Size = UDim2.fromOffset(300, 30), Text = "PREFERRED POSITION", FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, c)
	for i, role in Teams.ROLE_ORDER do
		local chosen = custom.role == role
		local b = button({ Position = UDim2.fromOffset(24 + (i - 1) * 104, 132), Size = UDim2.fromOffset(96, 44), BackgroundTransparency = chosen and 0 or 0.4, BackgroundColor3 = chosen and COL.violet or COL.panelHi }, c)
		text({ Size = UDim2.fromScale(1, 1), Text = role, FontFace = FONT.title, TextSize = 20 }, b)
		b.Activated:Connect(function()
			custom.role = role
			saveCustom()
			Menu.refreshEditPlayer()
		end)
	end
	text({ Position = UDim2.fromOffset(24, 182), Size = UDim2.fromOffset(520, 40), Text = Teams.ROLES[custom.role] .. ". In Quick Play you take this position unless you pick a player with P on the squad screen.", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, c)

	text({ Position = UDim2.fromOffset(24, 244), Size = UDim2.fromOffset(300, 30), Text = "WEAR THE TEAM KIT", FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, c)
	for k, label in { "ON", "OFF" } do
		local on = (k == 1) == custom.wearKit
		local b = button({ Position = UDim2.fromOffset(300 + (k - 1) * 112, 238), Size = UDim2.fromOffset(104, 42), BackgroundTransparency = on and 0 or 0.4, BackgroundColor3 = on and COL.violet or COL.panelHi }, c)
		text({ Size = UDim2.fromScale(1, 1), Text = label, FontFace = FONT.title, TextSize = 18 }, b)
		b.Activated:Connect(function()
			custom.wearKit = k == 1
			saveCustom()
			Menu.refreshEditPlayer()
		end)
	end
	text({ Position = UDim2.fromOffset(24, 290), Size = UDim2.fromOffset(700, 40), Text = "On: during matches your avatar's clothes are swapped for your team's shirt and shorts with your number on the back. You get them back after the match.", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, c)

	-- what your squad looks like with you in it
	text({ Position = UDim2.fromOffset(24, 352), Size = UDim2.fromOffset(300, 30), Text = "YOUR KIT  ·  " .. def.name, FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, c)
	local kit = Teams.kits(sel.home)[custom.kits[tostring(sel.home)] or 1]
	for i, part in { { "SHIRT", kit.shirt }, { "SHORTS", kit.shorts } } do
		local swatch = frame({ Position = UDim2.fromOffset(24 + (i - 1) * 150, 392), Size = UDim2.fromOffset(136, 64), BackgroundColor3 = part[2] }, c)
		outline(swatch, COL.line, 1, 0.3)
		text({ Size = UDim2.fromScale(1, 1), Text = part[1], FontFace = FONT.title, TextSize = 16, TextColor3 = contrast(part[2]) }, swatch)
	end
	local change = secondaryButton({ Position = UDim2.fromOffset(330, 404), Size = UDim2.fromOffset(220, 40) }, c, "CHANGE KITS AND COURTS", 15)
	change.Activated:Connect(function()
		Menu.openKits()
	end)
end
Menu.onShow.editplayer = function()
	Menu.refreshEditPlayer()
	Menu.epArt.set("me")
end

function Menu.openEditPlayer()
	Menu.show("editplayer")
end

---------------------------------------------------------------- KITS AND COURTS

Menu.kitClub = 1
do
	local screenFrame = Menu.screen("kits")
	customHeader(screenFrame, "KITS AND COURTS", "PICK A KIT FOR ANY CLUB AND THE COURT YOUR MATCHES ARE PLAYED ON")
	Menu.kitsLeft = customPanel(screenFrame, 72, 116, 560, 500)
	Menu.kitsRight = customPanel(screenFrame, 648, 116, 560, 500)
	Menu.hints(screenFrame, { { "BACK", "Back", Menu.back } }, UDim2.fromOffset(72, 636))
end

function Menu.refreshKits()
	local custom = Menu.custom
	local id = Menu.kitClub
	local l = Menu.kitsLeft
	l:ClearAllChildren()
	outline(l, COL.line, 1, 0.45)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = "CLUB KITS", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, l)
	badge(l, id, 84, UDim2.fromOffset(280, 46), Vector2.new(0.5, 0))
	for k, glyph in { "◀", "▶" } do
		local arrow = secondaryButton({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(k == 1 and 150 or 410, 88), Size = UDim2.fromOffset(44, 56) }, l, glyph, 20)
		arrow.Activated:Connect(function()
			Menu.kitClub = (Menu.kitClub - 1 + (k == 1 and -1 or 1)) % #Teams.list + 1
			Menu.refreshKits()
		end)
	end
	text({ Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 28), Text = Teams.list[id].name, FontFace = FONT.title, TextSize = 24 }, l)
	local chosenKit = custom.kits[tostring(id)] or 1
	for k, kit in Teams.kits(id) do
		local x = 24 + (k - 1) * 176
		local on = k == chosenKit
		local card = button({ Position = UDim2.fromOffset(x, 186), Size = UDim2.fromOffset(160, 250), BackgroundTransparency = on and 0.2 or 0.5, BackgroundColor3 = on and COL.panelHi or COL.bg2 }, l)
		outline(card, on and COL.teal or COL.line, on and 2 or 1, on and 0 or 0.5)
		text({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 22), Text = kit.name, FontFace = FONT.title, TextSize = 18, TextColor3 = on and COL.teal or COL.text }, card)
		shirt(card, kit.shirt, (id == sel.home) and custom.number or 10, 100, UDim2.fromOffset(80, 100))
		local shorts = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(80, 160), Size = UDim2.fromOffset(70, 34), BackgroundColor3 = kit.shorts }, card)
		outline(shorts, COL.ink, 1, 0.6)
		if on then
			Menu.chip(card, "SELECTED", UDim2.fromOffset(38, 210), COL.teal)
		end
		card.Activated:Connect(function()
			custom.kits[tostring(id)] = k
			saveCustom()
			Menu.refreshKits()
		end)
	end
	text({ Position = UDim2.fromOffset(20, 448), Size = UDim2.fromOffset(520, 40), Text = "Your club wears this kit when you play as them. If the away side's kit clashes, they change into another.", FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, l)

	local r = Menu.kitsRight
	r:ClearAllChildren()
	outline(r, COL.line, 1, 0.45)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = "COURTS", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, r)
	for i, style in Teams.COURTS do
		local y = 52 + (i - 1) * 86
		local on = (custom.court or 1) == i
		local row = button({ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(520, 78), BackgroundTransparency = on and 0.2 or 0.55, BackgroundColor3 = on and COL.panelHi or COL.bg2 }, r)
		outline(row, on and COL.teal or COL.line, on and 2 or 1, on and 0 or 0.5)
		-- a little court in the style's colours
		local free = frame({ Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(120, 60), BackgroundColor3 = style.free }, row)
		local court = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(90, 44), BackgroundColor3 = style.court }, free)
		outline(court, style.lines, 2, 0)
		frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = style.lines }, court)
		text({ Position = UDim2.fromOffset(150, 0), Size = UDim2.fromOffset(250, 78), Text = style.name, FontFace = FONT.title, TextSize = 22, TextColor3 = on and COL.teal or COL.text, TextXAlignment = Enum.TextXAlignment.Left }, row)
		if on then
			Menu.chip(row, "SELECTED", UDim2.fromOffset(420, 27), COL.teal)
		end
		row.Activated:Connect(function()
			custom.court = i
			saveCustom()
			Menu.refreshKits()
		end)
	end
end
Menu.onShow.kits = Menu.refreshKits

function Menu.openKits()
	Menu.kitClub = sel.home
	Menu.show("kits")
end

-- your saved choices arrive with your profile
remote.OnClientEvent:Connect(function(kind, a)
	if kind == "profile" and type(a) == "table" then
		Menu.profileLoaded = true
		local c = a.custom
		if type(c) == "table" then
			Menu.custom.number = c.number or Menu.custom.number
			Menu.custom.role = c.role or Menu.custom.role
			Menu.custom.wearKit = c.wearKit == true
			Menu.custom.court = c.court or Menu.custom.court
			Menu.custom.kits = type(c.kits) == "table" and c.kits or Menu.custom.kits
		end
	end
end)

---------------------------------------------------------------- PRACTICE ARENA

local DRILLS = {
	{ key = "SERVE", name = "SERVING", info = "You serve every point. Practise power and the green zone, and jump serves. Counts serves that land in." },
	{ key = "RECEIVE", name = "RECEIVING", info = "The other side serves straight at you. Read it and pass to the setter. Counts good passes." },
	{ key = "ATTACK", name = "ATTACKING", info = "The coach throws a pass, your setter sets you. Jump and spike past the block. Counts kills." },
	{ key = "FREE", name = "FREE PLAY", info = "Normal rallies with no score limit. Play as long as you like." },
}
Menu.drill = "SERVE"

do
	local screenFrame = Menu.screen("practice")
	customHeader(screenFrame, "PRACTICE ARENA", "PICK A DRILL   ·   QUIT FROM THE PAUSE MENU WHEN YOU'RE DONE")
	Menu.practiceBody = frame({ Position = UDim2.fromOffset(72, 116), Size = UDim2.fromOffset(1136, 500), BackgroundTransparency = 1 }, screenFrame)
	Menu.hints(screenFrame, { { "BACK", "Back", Menu.back } }, UDim2.fromOffset(72, 636))
end

function Menu.refreshPractice()
	local body = Menu.practiceBody
	body:ClearAllChildren()
	for i, d in DRILLS do
		local x = (i - 1) * 284
		local on = Menu.drill == d.key
		local card = button({ Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(272, 330), BackgroundTransparency = on and 0.05 or 0.12, BackgroundColor3 = on and COL.panelHi or COL.panel }, body)
		outline(card, on and COL.teal or COL.line, on and 2 or 1, on and 0 or 0.45)
		Menu.icon(card, ({ SERVE = "ball", RECEIVE = "court", ATTACK = "bars", FREE = "clock" })[d.key], 64, on and COL.teal or COL.violet, UDim2.fromOffset(136, 86))
		text({ Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 34), Text = d.name, FontFace = FONT.title, TextSize = 28, TextColor3 = on and COL.teal or COL.text }, card)
		text({ Position = UDim2.fromOffset(20, 196), Size = UDim2.fromOffset(232, 110), Text = d.info, FontFace = FONT.head, TextSize = 16, TextColor3 = COL.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top }, card)
		card.Activated:Connect(function()
			Menu.drill = d.key
			Menu.refreshPractice()
		end)
	end
	local club = customPanel(body, 0, 348, 700, 150)
	text({ Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(300, 24), Text = "YOUR CLUB", FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, club)
	badge(club, sel.home, 80, UDim2.fromOffset(130, 46))
	for k, glyph in { "◀", "▶" } do
		local arrow = secondaryButton({ Position = UDim2.fromOffset(k == 1 and 70 or 226, 66), Size = UDim2.fromOffset(44, 44) }, club, glyph, 18)
		arrow.Activated:Connect(function()
			local count = #Teams.list
			repeat
				sel.home = (sel.home - 1 + (k == 1 and -1 or 1)) % count + 1
			until sel.home ~= sel.away
			sel.plan = Teams.cleanPlan(sel.home, nil)
			sel.lineup = sel.plan.lineup
			sel.slotPicked = false
			Menu.refreshPractice()
		end)
	end
	text({ Position = UDim2.fromOffset(290, 50), Size = UDim2.fromOffset(390, 30), Text = Teams.list[sel.home].name, FontFace = FONT.title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left }, club)
	text({ Position = UDim2.fromOffset(290, 84), Size = UDim2.fromOffset(390, 40), Text = "You play your preferred position (" .. Teams.ROLES[Menu.custom.role] .. "). Change it in Edit Player.", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, club)
	local go = primaryButton({ Position = UDim2.fromOffset(880, 420), Size = UDim2.fromOffset(256, 60) }, body, "START DRILL  ▸", 22)
	go.Activated:Connect(function()
		Menu.startMatch({ mode = "practice", drill = Menu.drill })
	end)
end
Menu.onShow.practice = Menu.refreshPractice

function Menu.openPractice()
	if state.active then
		Menu.toast("A match is on in this server. Practice when it's finished.")
		return
	end
	Menu.show("practice")
end
