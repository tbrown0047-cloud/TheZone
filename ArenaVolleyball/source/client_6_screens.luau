
---------------------------------------------------------------- MATCH PREVIEW

local POSITION_NAMES = { "RIGHT BACK", "RIGHT FRONT", "MIDDLE FRONT", "LEFT FRONT", "LEFT BACK", "MIDDLE BACK" }

-- the clubs as they will line up: yours on the left
local function previewTeams()
	if state.active then
		return state.teamIds[sel.side], state.teamIds[3 - sel.side]
	end
	return sel.home, sel.away
end

local function headToHead(a, b)
	local winsA, winsB = 0, 0
	for _, h in history do
		if (h.home == a and h.away == b) or (h.home == b and h.away == a) then
			local winner = h.winner == 1 and h.home or h.away
			if winner == a then
				winsA += 1
			else
				winsB += 1
			end
		end
	end
	return winsA, winsB
end

do
	local pv = Menu.screen("preview")
	Menu.pvTabsHolder = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pv)
	Menu.pvCenter = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pv)
	Menu.pvLeft = Menu.avatar(pv, { Position = UDim2.fromOffset(10, 110), Size = UDim2.fromOffset(280, 430) }, 0.35)
	Menu.pvRight = Menu.avatar(pv, { Position = UDim2.fromOffset(990, 110), Size = UDim2.fromOffset(280, 430) }, -0.35)

	-- the bar along the bottom
	local bar = frame({ Position = UDim2.fromOffset(74, 540), Size = UDim2.fromOffset(1132, 82), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.2 }, pv)
	outline(bar, COL.line, 1, 0.5)
	local items = {
		{ "PLAY MATCH", "ball", function()
			Menu.startMatch()
		end },
		{ "TEAM MANAGEMENT", "court", function()
			Menu.openSquad()
		end },
		{ "GAME SETTINGS", "sliders", function()
			Menu.openSettings()
		end },
		{ "CONTROLLER SETTINGS", "pad", function()
			Menu.openControls()
		end },
		{ "DETAILED STATS", "bars", function()
			Menu.openStats()
		end },
	}
	local cells = {}
	local w = 1132 / #items
	local function highlight(index)
		for i, cell in cells do
			cell.fill.Visible = i == index
			cell.icon.Visible = i ~= index
			cell.iconOn.Visible = i == index
		end
	end
	for i, item in items do
		local b = button({ Position = UDim2.fromOffset((i - 1) * w, 0), Size = UDim2.fromOffset(w, 82) }, bar)
		local fill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, b)
		gradient(fill, COL.violet, Color3.fromRGB(120, 76, 236), 90)
		if i > 1 then
			frame({ Position = UDim2.fromOffset(0, 14), Size = UDim2.new(0, 1, 1, -28), BackgroundColor3 = COL.line, BackgroundTransparency = 0.5 }, b)
		end
		text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 22), Text = item[1], FontFace = FONT.head, TextSize = 18 }, b)
		local icon = Menu.icon(b, item[2], 30, COL.violet, UDim2.fromOffset(w / 2, 54))
		local iconOn = Menu.icon(b, item[2], 30, COL.teal, UDim2.fromOffset(w / 2, 54))
		cells[i] = { fill = fill, icon = icon, iconOn = iconOn }
		b.MouseEnter:Connect(function()
			highlight(i)
		end)
		b.Activated:Connect(item[3])
	end
	highlight(1)
	Menu.hints(pv, { { "CLICK", "Advance" }, { "BACK", "Back", Menu.back } }, UDim2.fromOffset(74, 634))
end

local function comparisonRows(parent, rows, a, b, top)
	local ra, rb = Teams.ratings(a, a == sel.home and not state.active and sel.lineup or nil), Teams.ratings(b)
	for i, row in rows do
		local y = top + (i - 1) * 46
		local va, vb = ra[row[1]], rb[row[1]]
		text({ Position = UDim2.fromOffset(370, y), Size = UDim2.fromOffset(80, 30), Text = tostring(va), FontFace = FONT.num, TextSize = 26, TextColor3 = va >= vb and COL.text or COL.dim }, parent)
		text({ Position = UDim2.fromOffset(830, y), Size = UDim2.fromOffset(80, 30), Text = tostring(vb), FontFace = FONT.num, TextSize = 26, TextColor3 = vb >= va and COL.text or COL.dim }, parent)
		text({ Position = UDim2.fromOffset(540, y - 4), Size = UDim2.fromOffset(200, 20), Text = row[2], FontFace = FONT.head, TextSize = 16 }, parent)
		local back = frame({ Position = UDim2.fromOffset(450, y + 20), Size = UDim2.fromOffset(380, 6), BackgroundColor3 = COL.bg2 }, parent)
		local share = va / math.max(va + vb, 1)
		frame({ Size = UDim2.fromScale(share, 1), BackgroundColor3 = COL.violet }, back)
		frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(1 - share, 1), BackgroundColor3 = COL.coral }, back)
	end
end

function Menu.refreshPreview()
	local mine, theirs = previewTeams()
	-- tabs
	Menu.pvTabsHolder:ClearAllChildren()
	Menu.tabs(Menu.pvTabsHolder, UDim2.fromOffset(370, 20), { "MATCH PREVIEW", "ATTACK", "RECEPTION" }, Menu.pvTab, function(i)
		Menu.pvTab = i
		Menu.refreshPreview()
	end, 180)
	local c = Menu.pvCenter
	c:ClearAllChildren()
	local defA, defB = Teams.list[mine], Teams.list[theirs]
	local ovrA, ovrB = Teams.ratings(mine).OVR, Teams.ratings(theirs).OVR
	if Menu.pvTab == 1 then
		text({ Position = UDim2.fromOffset(340, 64), Size = UDim2.fromOffset(600, 20), Text = string.format("%s★ vs %s★   |   %s   |   Indoor   |   Arena Dome", Teams.stars(ovrA), Teams.stars(ovrB), os.date("%I:%M %p")), FontFace = FONT.head, TextSize = 15 }, c)
		local facts = { { "arena", "ARENA DOME" }, { "ball", (state.active and "JOIN MATCH" or "CLASSIC MATCH") }, { "clock", "TO " .. (state.active and state.points or sel.points) .. " POINTS" } }
		for i, f in facts do
			local x = 430 + (i - 1) * 170
			Menu.icon(c, f[1], 22, COL.text, UDim2.fromOffset(x, 104))
			text({ Position = UDim2.fromOffset(x + 18, 92), Size = UDim2.fromOffset(150, 24), Text = f[2], FontFace = FONT.head, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, c)
		end
		text({ Position = UDim2.fromOffset(540, 130), Size = UDim2.fromOffset(200, 20), Text = "OVERALL H2H", FontFace = FONT.head, TextSize = 16 }, c)
		local wa, wb = headToHead(mine, theirs)
		text({ Position = UDim2.fromOffset(360, 152), Size = UDim2.fromOffset(120, 24), Text = "<font color=\"#9662ff\">" .. wa .. "</font>  WINS", RichText = true, FontFace = FONT.head, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, c)
		text({ Position = UDim2.fromOffset(560, 152), Size = UDim2.fromOffset(160, 24), Text = "<font color=\"#9662ff\">" .. (wa + wb) .. "</font>  PLAYED", RichText = true, FontFace = FONT.head, TextSize = 17 }, c)
		text({ Position = UDim2.fromOffset(800, 152), Size = UDim2.fromOffset(120, 24), Text = "WINS  <font color=\"#9662ff\">" .. wb .. "</font>", RichText = true, FontFace = FONT.head, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right }, c)
		local h2h = frame({ Position = UDim2.fromOffset(360, 180), Size = UDim2.fromOffset(560, 10), BackgroundColor3 = Color3.fromRGB(150, 150, 175) }, c)
		round(h2h, 5)
		if wa + wb > 0 then
			local left = frame({ Size = UDim2.fromScale(wa / (wa + wb), 1), BackgroundColor3 = COL.violet }, h2h)
			round(left, 5)
		end
		badge(c, mine, 80, UDim2.fromOffset(300, 140), Vector2.new(0.5, 0))
		badge(c, theirs, 80, UDim2.fromOffset(980, 140), Vector2.new(0.5, 0))
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(300, 226), Size = UDim2.fromOffset(220, 20), Text = defA.name, FontFace = FONT.title, TextSize = 17 }, c)
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(980, 226), Size = UDim2.fromOffset(220, 20), Text = defB.name, FontFace = FONT.title, TextSize = 17 }, c)
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(300, 262), Size = UDim2.fromOffset(240, 20), Text = player.DisplayName, FontFace = FONT.head, TextSize = 17, TextColor3 = COL.violet }, c)
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(980, 262), Size = UDim2.fromOffset(240, 20), Text = Teams.stars(ovrB) .. "★ AI   ·   OVR " .. ovrB, FontFace = FONT.head, TextSize = 17, TextColor3 = COL.violet }, c)
		text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 270), Size = UDim2.fromOffset(200, 90), Text = "VS", FontFace = FONT.num, TextSize = 76, TextColor3 = COL.dim, TextTransparency = 0.45 }, c)
		text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 390), Size = UDim2.fromOffset(600, 40), Text = state.active and "A MATCH IS ON: YOU'LL JOIN IT" or "WELCOME TO QUICK PLAY!", FontFace = FONT.head, TextSize = 28 }, c)
	elseif Menu.pvTab == 2 then
		text({ Position = UDim2.fromOffset(340, 70), Size = UDim2.fromOffset(600, 24), Text = defA.name .. "   v   " .. defB.name, FontFace = FONT.title, TextSize = 20, TextColor3 = COL.cyan }, c)
		comparisonRows(c, { { "OVR", "OVERALL" }, { "ATK", "ATTACK" }, { "SRV", "SERVE" }, { "PHY", "ATHLETICISM" } }, mine, theirs, 130)
	else
		text({ Position = UDim2.fromOffset(340, 70), Size = UDim2.fromOffset(600, 24), Text = defA.name .. "   v   " .. defB.name, FontFace = FONT.title, TextSize = 20, TextColor3 = COL.cyan }, c)
		comparisonRows(c, { { "REC", "RECEPTION" }, { "BLK", "BLOCK" }, { "SET", "SETTING" }, { "OVR", "OVERALL" } }, mine, theirs, 130)
	end
	Menu.pvLeft.set("me")
	Menu.pvRight.set({ team = theirs, number = Teams.squad(theirs)[2].number })
end
Menu.onShow.preview = Menu.refreshPreview

function Menu.openPreview()
	Menu.pvTab = 1
	Menu.show("preview")
end

---------------------------------------------------------------- TEAM MANAGEMENT: lineup and the position you play

-- court spots for rotation positions 1-6 (net at the top)
local COURT_SPOTS = { { 0.8, 0.74 }, { 0.8, 0.26 }, { 0.5, 0.26 }, { 0.2, 0.26 }, { 0.2, 0.74 }, { 0.5, 0.8 } }

do
	local sq = Menu.screen("squad")
	local plans = frame({ Position = UDim2.fromOffset(72, 24), Size = UDim2.fromOffset(420, 28), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.3 }, sq)
	text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(200, 28), Text = "EDIT GAME PLANS", FontFace = FONT.head, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, plans)
	text({ Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(170, 28), Text = "5-1 SYSTEM", FontFace = FONT.head, TextSize = 17 }, plans)
	Menu.tabs(sq, UDim2.fromOffset(72, 56), { "SQUAD", "ROTATION", "TACTICS", "ROLES" }, 1, function(i)
		if i ~= 1 then
			Menu.toast("Coming soon")
		end
	end, 140)
	-- recolour the active tab in the squad screen's lime
	local left = frame({ Position = UDim2.fromOffset(72, 92), Size = UDim2.fromOffset(566, 530), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.2 }, sq)
	outline(left, COL.line, 1, 0.55)
	local court = frame({ Position = UDim2.fromOffset(40, 20), Size = UDim2.fromOffset(486, 300), BackgroundColor3 = Color3.fromRGB(60, 50, 150), BackgroundTransparency = 0.5 }, left)
	outline(court, Color3.new(1, 1, 1), 2, 0.5)
	frame({ Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2 }, court)
	for k = 0, 23 do
		frame({ Position = UDim2.new(k / 24, 2, 0.33, 0), Size = UDim2.new(1 / 48, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6 }, court)
	end
	text({ Position = UDim2.new(0, 0, 0, -18), Size = UDim2.new(1, 0, 0, 16), Text = "NET", FontFace = FONT.title, TextSize = 12, TextColor3 = COL.dim }, court)
	Menu.squadCourt = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, court) -- player markers go here
	text({ Position = UDim2.fromOffset(28, 336), Size = UDim2.fromOffset(300, 30), Text = "SUBSTITUTES", FontFace = FONT.title, TextSize = 26, TextColor3 = COL.lime, TextXAlignment = Enum.TextXAlignment.Left }, left)
	Menu.squadBench = frame({ Position = UDim2.fromOffset(28, 372), Size = UDim2.fromOffset(510, 140), BackgroundTransparency = 1 }, left)

	local right = frame({ Position = UDim2.fromOffset(648, 92), Size = UDim2.fromOffset(560, 530), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.2 }, sq)
	outline(right, COL.line, 1, 0.55)
	Menu.squadCard = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, right)

	Menu.hints(sq, {
		{ "BACK", "Back", Menu.back },
		{ "CLICK", "Select" },
		{ "P", "Play as this player", function()
			Menu.playAs()
		end },
		{ "S", "Swap", function()
			Menu.startSwap()
		end },
	}, UDim2.fromOffset(72, 634))
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not inMenu or processed or Menu.current ~= "squad" then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		Menu.playAs()
	elseif input.KeyCode == Enum.KeyCode.S then
		Menu.startSwap()
	end
end)

local function squadTeam()
	if state.active then
		return state.teamIds[sel.side], state.lineups[sel.side] or Teams.defaultLineup()
	end
	return sel.home, sel.lineup
end

function Menu.playAs()
	local _, lineup = squadTeam()
	local slot = table.find(lineup, Menu.squadSel)
	if slot then
		sel.slot = slot
		Menu.toast("You'll play as " .. Teams.squad((squadTeam()))[Menu.squadSel].last .. " (" .. Teams.ROLES[Teams.squad((squadTeam()))[Menu.squadSel].role] .. ")")
	else
		Menu.toast("Bring him into the starting six first (S to swap)")
	end
	Menu.refreshSquad()
end

function Menu.startSwap()
	if state.active then
		Menu.toast("The lineup is fixed once the match has started")
		return
	end
	Menu.swapFrom = Menu.squadSel
	Menu.toast("Now pick the player to swap with")
end

local function pickSquadPlayer(index)
	if Menu.swapFrom and Menu.swapFrom ~= index then
		local a, b = Menu.swapFrom, index
		local ia, ib = table.find(sel.lineup, a), table.find(sel.lineup, b)
		if ia and ib then
			sel.lineup[ia], sel.lineup[ib] = b, a
		elseif ia then
			sel.lineup[ia] = b
		elseif ib then
			sel.lineup[ib] = a
		end
	end
	Menu.swapFrom = nil
	Menu.squadSel = index
	Menu.refreshSquad()
end

local function squadMarker(parent, p, index, teamId, pos, isMe)
	local def = Teams.list[teamId]
	local selected = Menu.squadSel == index
	local b = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(120, 92) }, parent)
	shirt(b, def.primary, p.number, 44, UDim2.fromOffset(60, 28))
	text({ Position = UDim2.fromOffset(84, 10), Size = UDim2.fromOffset(34, 20), Text = tostring(p.ovr), FontFace = FONT.num, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left }, b)
	text({ Position = UDim2.fromOffset(2, 10), Size = UDim2.fromOffset(34, 18), Text = p.role, FontFace = FONT.title, TextSize = 13, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Right }, b)
	local tag = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(60, 56), Size = UDim2.fromOffset(#p.last * 10 + 16, 22), BackgroundColor3 = COL.lime, BackgroundTransparency = selected and 0 or 1 }, b)
	text({ Size = UDim2.fromScale(1, 1), Text = p.last, FontFace = FONT.title, TextSize = 16, TextColor3 = selected and COL.ink or COL.text }, tag)
	if isMe then
		Menu.chip(b, "YOU", UDim2.fromOffset(42, -14), COL.gold)
	end
	if Menu.swapFrom == index then
		outline(b, COL.lime, 2, 0)
	end
	b.Activated:Connect(function()
		pickSquadPlayer(index)
	end)
end

local function radarChart(parent, center, radius, values)
	local n = #Teams.ATTRS
	local function point(i, r)
		local angle = math.rad(-90 + (i - 1) * 360 / n)
		return center + Vector2.new(math.cos(angle), math.sin(angle)) * r
	end
	for i = 1, n do
		lineBetween(parent, point(i, radius), point(i % n + 1, radius), 1, COL.dim, 0.5)
		lineBetween(parent, center, point(i, radius), 1, COL.dim, 0.75)
		local labelPos = point(i, radius + 20)
		text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(labelPos.X, labelPos.Y), Size = UDim2.fromOffset(60, 18), Text = Teams.ATTRS[i], FontFace = FONT.head, TextSize = 14 }, parent)
	end
	for i = 1, n do
		local a = point(i, radius * math.clamp(values[i] / 100, 0.05, 1))
		local b = point(i % n + 1, radius * math.clamp(values[i % n + 1] / 100, 0.05, 1))
		lineBetween(parent, a, b, 2, COL.lime, 0)
	end
end

function Menu.refreshSquad()
	local teamId, lineup = squadTeam()
	local squad = Teams.squad(teamId)
	local court, bench, card = Menu.squadCourt, Menu.squadBench, Menu.squadCard
	court:ClearAllChildren()
	for slot = 1, 6 do
		local index = lineup[slot]
		local spot = COURT_SPOTS[slot]
		squadMarker(court, squad[index], index, teamId, UDim2.fromScale(spot[1], spot[2]), slot == sel.slot)
	end
	bench:ClearAllChildren()
	local column = 0
	for index, p in squad do
		if not table.find(lineup, index) then
			local cardFrame = frame({ Position = UDim2.fromOffset(column * 150, 0), Size = UDim2.fromOffset(140, 128), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.2 }, bench)
			outline(cardFrame, Menu.squadSel == index and COL.lime or COL.line, Menu.squadSel == index and 2 or 1, Menu.squadSel == index and 0 or 0.5)
			squadMarker(cardFrame, p, index, teamId, UDim2.fromOffset(70, 64), false)
			column += 1
		end
	end

	-- the player card on the right
	card:ClearAllChildren()
	local index = Menu.squadSel
	local p = squad[index] or squad[1]
	local slot = table.find(lineup, index)
	local def = Teams.list[teamId]
	shirt(card, def.primary, p.number, 92, UDim2.fromOffset(92, 92))
	local dot = frame({ Position = UDim2.fromOffset(28, 26), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = slot and COL.teal or COL.dim }, card)
	round(dot, 5)
	text({ Position = UDim2.fromOffset(44, 16), Size = UDim2.fromOffset(80, 30), Text = p.role, FontFace = FONT.num, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left }, card)
	text({ Position = UDim2.fromOffset(150, 20), Size = UDim2.fromOffset(120, 74), Text = tostring(p.ovr), FontFace = FONT.num, TextSize = 70, TextXAlignment = Enum.TextXAlignment.Left }, card)
	text({ Position = UDim2.fromOffset(24, 150), Size = UDim2.fromOffset(280, 30), Text = p.first .. " " .. p.last, FontFace = FONT.title, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left }, card)
	local ovrBar = frame({ Position = UDim2.fromOffset(24, 184), Size = UDim2.fromOffset(240, 5), BackgroundColor3 = COL.ink }, card)
	frame({ Size = UDim2.fromScale(p.ovr / 100, 1), BackgroundColor3 = ratingColor(p.ovr) }, ovrBar)
	local values = {}
	for i, attr in Teams.ATTRS do
		values[i] = p.attrs[attr]
	end
	radarChart(card, Vector2.new(420, 104), 62, values)

	text({ Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 0, 30), Text = "PLAYER INFO", FontFace = FONT.title, TextSize = 26, TextColor3 = COL.lime }, card)
	local rows = {
		{ slot and (slot == sel.slot and "YOU  ·  " or "") .. "POS " .. slot .. " " .. POSITION_NAMES[slot] or "BENCH", "Position" },
		{ Teams.ROLES[p.role], "Role" },
		{ "100  ⚡", "Fitness" },
	}
	for i, row in rows do
		local y = 238 + (i - 1) * 26
		frame({ Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(528, 24), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.7 or 0.85 }, card)
		text({ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(250, 24), Text = row[1], FontFace = FONT.head, TextSize = 17, TextColor3 = i == 3 and COL.win or COL.text, TextXAlignment = Enum.TextXAlignment.Right }, card)
		text({ Position = UDim2.fromOffset(300, y), Size = UDim2.fromOffset(240, 24), Text = row[2], FontFace = FONT.head, TextSize = 17 }, card)
	end
	for i, attr in Teams.ATTRS do
		local y = 324 + (i - 1) * 26
		local v = p.attrs[attr]
		local back = frame({ Position = UDim2.fromOffset(40, y + 8), Size = UDim2.fromOffset(180, 9), BackgroundTransparency = 1 }, card)
		frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(v / 100, 1), BackgroundColor3 = ratingColor(v) }, back)
		text({ Position = UDim2.fromOffset(226, y), Size = UDim2.fromOffset(44, 24), Text = tostring(v), FontFace = FONT.num, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Right }, card)
		text({ Position = UDim2.fromOffset(300, y), Size = UDim2.fromOffset(240, 24), Text = Teams.ATTR_NAMES[attr], FontFace = FONT.head, TextSize = 18 }, card)
	end
	local y = 324 + #Teams.ATTRS * 26
	starRow(card, math.clamp(math.floor((p.attrs.SRV - 50) / 10 + 0.5), 1, 5), 20, UDim2.fromOffset(170, y + 2))
	text({ Position = UDim2.fromOffset(300, y), Size = UDim2.fromOffset(240, 24), Text = "Jump Serve", FontFace = FONT.head, TextSize = 18 }, card)
	text({ Position = UDim2.fromOffset(20, y + 26), Size = UDim2.fromOffset(250, 24), Text = p.hand, FontFace = FONT.head, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right }, card)
	text({ Position = UDim2.fromOffset(300, y + 26), Size = UDim2.fromOffset(240, 24), Text = "Hand", FontFace = FONT.head, TextSize = 18 }, card)
end
Menu.onShow.squad = Menu.refreshSquad

function Menu.openSquad()
	local _, lineup = squadTeam()
	Menu.squadSel = lineup[sel.slot] or lineup[1]
	Menu.swapFrom = nil
	Menu.show("squad")
end

---------------------------------------------------------------- pop-up panels: settings, controls, stats

local function modal(title, height)
	local shade = button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.45, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 20 }, board)
	local panel = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(680, height), BackgroundColor3 = COL.bg2, ZIndex = 21 }, shade)
	outline(panel, COL.line, 1, 0.3)
	frame({ Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.teal, ZIndex = 22 }, panel)
	text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(500, 36), Text = title, FontFace = FONT.body, TextSize = 32, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, panel)
	local body = frame({ Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 1, -124), BackgroundTransparency = 1, ZIndex = 22 }, panel)
	local done = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -16), Size = UDim2.fromOffset(150, 40), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22 }, panel)
	gradient(done, COL.violet, Color3.fromRGB(110, 70, 230), 0)
	text({ Size = UDim2.fromScale(1, 1), Text = "DONE", FontFace = FONT.title, TextSize = 18, ZIndex = 23 }, done)
	done.Activated:Connect(function()
		shade.Visible = false
	end)
	return shade, body
end

local function zify(root, z)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = z
		end
	end
end

do
	local shade, body = modal("GAME SETTINGS", 470)
	Menu.settingsShade, Menu.settingsBody = shade, body
end

local SETTING_ROWS = {
	{ "Points per set", function()
		return tostring(sel.points)
	end, function(d)
		local options = { 15, 21, 25 }
		local i = table.find(options, sel.points) or 3
		sel.points = options[(i - 1 + d) % 3 + 1]
	end },
	{ "Sets", function()
		return ({ "ONE SET", "BEST OF 3", "BEST OF 5" })[sel.sets] or "ONE SET"
	end, function(d)
		sel.sets = (sel.sets - 1 + d) % 3 + 1
	end },
	{ "Camera", function()
		return settings.camera == "broadcast" and "BROADCAST" or "BEHIND PLAYER"
	end, function()
		settings.camera = settings.camera == "broadcast" and "player" or "broadcast"
	end },
	{ "Aim marker", function()
		return settings.aimMarker and "ON" or "OFF"
	end, function()
		settings.aimMarker = not settings.aimMarker
	end },
	{ "Radar", function()
		return settings.radar and "ON" or "OFF"
	end, function()
		settings.radar = not settings.radar
	end },
	{ "Control hints", function()
		return settings.hints and "ON" or "OFF"
	end, function()
		settings.hints = not settings.hints
	end },
}

function Menu.openSettings()
	local body = Menu.settingsBody
	body:ClearAllChildren()
	for i, row in SETTING_ROWS do
		local y = (i - 1) * 46
		local locked = state.active and i <= 2
		frame({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = COL.panelHi, BackgroundTransparency = 0.6 }, body)
		text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(260, 40), Text = row[1], FontFace = FONT.head, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left }, body)
		local value = text({ Position = UDim2.fromOffset(380, y), Size = UDim2.fromOffset(180, 40), Text = row[2](), FontFace = FONT.title, TextSize = 19, TextColor3 = locked and COL.dim or COL.teal }, body)
		if not locked then
			for k, glyph in { "◀", "▶" } do
				local arrow = button({ Position = UDim2.fromOffset(k == 1 and 340 or 566, y + 4), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 0.3, BackgroundColor3 = COL.panelHi }, body)
				round(arrow, 4)
				text({ Size = UDim2.fromScale(1, 1), Text = glyph, FontFace = FONT.title, TextSize = 14 }, arrow)
				arrow.Activated:Connect(function()
					row[3](k == 1 and -1 or 1)
					value.Text = row[2]()
				end)
			end
		end
	end
	if state.active then
		text({ Position = UDim2.fromOffset(0, 6 * 46 + 4), Size = UDim2.new(1, 0, 0, 22), Text = "Points and sets are set by the match that's already on.", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim }, body)
	end
	zify(body, 23)
	Menu.settingsShade.Visible = true
end

do
	local shade, body = modal("CONTROLLER SETTINGS", 520)
	Menu.controlsShade = shade
	local rows = {
		{ "Move", "W A S D", "LEFT STICK", "THUMBSTICK" },
		{ "Pass  /  spike in the air", "CLICK", "R2", "HIT" },
		{ "Set  /  tip in the air", "E", "X", "SET" },
		{ "Jump  ·  block at the net", "SPACE", "A", "JUMP" },
		{ "Dive", "Q or C", "B", "DIVE" },
		{ "Serve: hold, let go in the green", "HOLD CLICK", "HOLD R2", "HOLD HIT" },
		{ "Aim", "MOUSE", "CAMERA", "CAMERA" },
		{ "Camera  /  zoom", "V  /  WHEEL", "", "" },
		{ "Pause", "M", "START", "" },
	}
	text({ Position = UDim2.fromOffset(300, 0), Size = UDim2.fromOffset(100, 20), Text = "KEYBOARD", FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim }, body)
	text({ Position = UDim2.fromOffset(410, 0), Size = UDim2.fromOffset(100, 20), Text = "GAMEPAD", FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim }, body)
	text({ Position = UDim2.fromOffset(520, 0), Size = UDim2.fromOffset(100, 20), Text = "TOUCH", FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim }, body)
	for i, row in rows do
		local y = 24 + (i - 1) * 36
		frame({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.6 or 0.8 }, body)
		text({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(290, 32), Text = row[1], FontFace = FONT.head, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, body)
		for k = 2, 4 do
			text({ Position = UDim2.fromOffset(300 + (k - 2) * 110, y), Size = UDim2.fromOffset(100, 32), Text = row[k], FontFace = FONT.title, TextSize = 14, TextColor3 = COL.teal }, body)
		end
	end
	zify(body, 23)
end

function Menu.openControls()
	Menu.controlsShade.Visible = true
end

do
	local shade, body = modal("DETAILED STATS", 470)
	Menu.statsShade, Menu.statsBody = shade, body
end

function Menu.openStats()
	local body = Menu.statsBody
	body:ClearAllChildren()
	local a, b = previewTeams()
	local ra, rb = Teams.ratings(a, (not state.active and a == sel.home) and sel.lineup or nil), Teams.ratings(b)
	badge(body, a, 44, UDim2.fromOffset(40, 0))
	badge(body, b, 44, UDim2.new(1, -84, 0, 0))
	text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 30), Text = Teams.list[a].short .. "   v   " .. Teams.list[b].short, FontFace = FONT.title, TextSize = 24 }, body)
	local rows = { { "OVR", "Overall" }, { "ATK", "Attack" }, { "BLK", "Block" }, { "SRV", "Serve" }, { "REC", "Reception" }, { "SET", "Setting" }, { "PHY", "Athleticism" } }
	for i, row in rows do
		local y = 58 + (i - 1) * 36
		local va, vb = ra[row[1]], rb[row[1]]
		text({ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(60, 28), Text = tostring(va), FontFace = FONT.num, TextSize = 22, TextColor3 = va >= vb and COL.text or COL.dim }, body)
		text({ Position = UDim2.new(1, -80, 0, y), Size = UDim2.fromOffset(60, 28), Text = tostring(vb), FontFace = FONT.num, TextSize = 22, TextColor3 = vb >= va and COL.text or COL.dim }, body)
		text({ Position = UDim2.fromOffset(0, y - 2), Size = UDim2.new(1, 0, 0, 18), Text = row[2], FontFace = FONT.head, TextSize = 15 }, body)
		local back = frame({ Position = UDim2.fromOffset(100, y + 18), Size = UDim2.new(1, -200, 0, 6), BackgroundColor3 = COL.panel }, body)
		local share = va / math.max(va + vb, 1)
		frame({ Size = UDim2.fromScale(share, 1), BackgroundColor3 = COL.violet }, back)
		frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(1 - share, 1), BackgroundColor3 = COL.coral }, back)
	end
	zify(body, 23)
	Menu.statsShade.Visible = true
end

---------------------------------------------------------------- loading, pause, and moving between the menus and a match

do
	local shade = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, ZIndex = 30 }, Menu.gui)
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 40), Text = "PREPARING MATCH", FontFace = FONT.title, TextSize = 30, ZIndex = 31 }, shade)
	local spinner = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 52), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, ZIndex = 31 }, shade)
	round(spinner, 17)
	make("UIStroke", { Color = COL.teal, Thickness = 3 }, spinner)
	frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = COL.pink, ZIndex = 32 }, spinner)
	Menu.loading = shade
	task.spawn(function()
		while true do
			task.wait(0.03)
			if shade.Visible then
				spinner.Rotation = (spinner.Rotation + 9) % 360
			end
		end
	end)
end

function Menu.startMatch()
	if Menu.waiting then
		return
	end
	Menu.waiting = true
	Menu.loading.Visible = true
	remote:FireServer("start", {
		home = sel.home,
		away = sel.away,
		lineup = sel.lineup,
		slot = sel.slot,
		points = sel.points,
		sets = sel.sets,
		team = sel.side,
	})
	task.delay(15, function()
		if Menu.waiting and inMenu then
			Menu.waiting = false
			Menu.loading.Visible = false
			Menu.toast("Couldn't start the match. Try again.")
		end
	end)
end

-- pause screen over the match (the match keeps going: it's live)
do
	local shade = button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.4, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 20 }, HUD.gui)
	local panel = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 300), BackgroundColor3 = COL.bg2, ZIndex = 21 }, shade)
	outline(panel, COL.line, 1, 0.3)
	frame({ Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.teal, ZIndex = 22 }, panel)
	text({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 40), Text = "PAUSE", FontFace = FONT.body, TextSize = 34, TextColor3 = COL.cyan, ZIndex = 22 }, panel)
	text({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 20), Text = "The match carries on while this is open", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, ZIndex = 22 }, panel)
	local function option(i, label, onClick)
		local b = button({ Position = UDim2.fromOffset(40, 90 + (i - 1) * 62), Size = UDim2.fromOffset(300, 50), BackgroundTransparency = 0, BackgroundColor3 = i == 1 and Color3.new(1, 1, 1) or COL.panelHi, ZIndex = 22 }, panel)
		if i == 1 then
			gradient(b, COL.violet, Color3.fromRGB(110, 70, 230), 0)
		end
		text({ Size = UDim2.fromScale(1, 1), Text = label, FontFace = FONT.title, TextSize = 20, ZIndex = 23 }, b)
		b.Activated:Connect(onClick)
	end
	option(1, "RESUME", function()
		shade.Visible = false
	end)
	option(2, "CAMERA: SWITCH VIEW", function()
		settings.camera = settings.camera == "broadcast" and "player" or "broadcast"
		shade.Visible = false
	end)
	option(3, "QUIT TO MAIN MENU", function()
		shade.Visible = false
		remote:FireServer("leave", {})
		openMenu("home")
	end)
	Menu.pause = shade
	showPause = function()
		shade.Visible = not shade.Visible
	end
end

-- your character can't wander off while you're in the menus
local function setControls(enabled)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controls = module:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

function openMenu(screenName)
	inMenu = true
	task.spawn(setControls, false)
	Controls.charging = false
	Controls.pending = nil
	HUD.power = nil
	Menu.pause.Visible = false
	HUD.gui.Enabled = false
	Menu.gui.Enabled = true
	Menu.loading.Visible = false
	Menu.waiting = false
	Menu.stack = {}
	Menu.show(screenName or "home", false)
	-- park the camera over the court (the menus cover it)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(C + Vector3.new(HALF_W + 40, 30, 0), C)
end

function closeMenu()
	inMenu = false
	task.spawn(setControls, true)
	Menu.gui.Enabled = false
	Menu.loading.Visible = false
	Menu.waiting = false
	HUD.gui.Enabled = true
	Cam.focus = nil
	HUD.refresh()
end
