
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
	local bar = frame({ Position = UDim2.fromOffset(74, 540), Size = UDim2.fromOffset(1132, 82), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.2, ClipsDescendants = true }, pv)
	outline(bar, COL.line, 1, 0.6)
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
		local fill = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.panelHi, Visible = false }, b)
		frame({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.teal }, fill)
		if i > 1 then
			frame({ Position = UDim2.fromOffset(0, 14), Size = UDim2.new(0, 1, 1, -28), BackgroundColor3 = COL.line, BackgroundTransparency = 0.5 }, b)
		end
		text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 22), Text = item[1], FontFace = FONT.head, TextSize = 18 }, b)
		local icon = Menu.icon(b, item[2], 30, COL.dim, UDim2.fromOffset(w / 2, 54))
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
	local ra, rb = Teams.ratings(a, a == sel.home and not state.active and sel.plan.lineup or nil), Teams.ratings(b)
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

---------------------------------------------------------------- TEAM MANAGEMENT: squad, rotation, tactics and roles

-- court spots for rotation positions 1-6 (net at the top)
local COURT_SPOTS = { { 0.83, 0.74 }, { 0.83, 0.27 }, { 0.5, 0.27 }, { 0.17, 0.27 }, { 0.17, 0.74 }, { 0.5, 0.74 } }
local SQUAD_TABS = { "SQUAD", "ROTATION", "TACTICS", "ROLES" }
Menu.squadTab = 1

-- the club and game plan the squad screen shows: yours before the match, or the side
-- you're joining (read-only) once a match is on
local function squadData()
	if state.active then
		local t = sel.side
		local id = state.teamIds[t]
		local plan = state.plans and state.plans[t] or Teams.cleanPlan(id, { lineup = state.lineups[t] })
		return id, plan, false
	end
	return sel.home, sel.plan, true
end

-- after any change: fill in roles that no longer fit, keep the lineup alias in step
local function commitPlan()
	sel.plan = Teams.cleanPlan(sel.home, sel.plan)
	sel.lineup = sel.plan.lineup
	Menu.refreshSquad()
end

local function panelBox(parent, x, y, w, h)
	local f = frame({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.08 }, parent)
	outline(f, COL.line, 1, 0.65)
	return f
end

local function sectionTitle(parent, str, x, y, w)
	return text({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w or 300, 24), Text = str, FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, parent)
end

do
	local sq = Menu.screen("squad")
	text({ Position = UDim2.fromOffset(72, 20), Size = UDim2.fromOffset(600, 40), Text = "TEAM MANAGEMENT", FontFace = FONT.title, TextSize = 32, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left }, sq)
	Menu.sqSub = text({ Position = UDim2.fromOffset(74, 58), Size = UDim2.fromOffset(900, 20), FontFace = FONT.head, TextSize = 16, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, sq)
	Menu.sqTabs = frame({ Position = UDim2.fromOffset(72, 88), Size = UDim2.fromOffset(640, 34), BackgroundTransparency = 1 }, sq)
	Menu.sqBody = frame({ Position = UDim2.fromOffset(72, 132), Size = UDim2.fromOffset(1136, 492), BackgroundTransparency = 1 }, sq)
	Menu.hints(sq, {
		{ "BACK", "Back", Menu.back },
		{ "DRAG", "Move players" },
		{ "P", "Your player", function()
			Menu.playAs()
		end },
	}, UDim2.fromOffset(72, 640))
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not inMenu or processed or Menu.current ~= "squad" then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		Menu.playAs()
	end
end)

-- P: the player (and position) you play as
function Menu.playAs()
	local teamId, plan, editable = squadData()
	local slot = table.find(plan.lineup, Menu.squadSel)
	if not slot then
		Menu.toast("Put him in the starting six first")
	elseif editable or state.active then
		sel.slot = slot
		sel.slotPicked = true
		local p = Teams.squad(teamId)[Menu.squadSel]
		Menu.toast("You'll play as " .. p.last .. " (" .. Teams.ROLES[p.role] .. ")")
	end
	Menu.refreshSquad()
end

-- what a dragged player looks like
local function ghostFor(teamId, p)
	return function()
		local g = frame({ Size = UDim2.fromOffset(76, 76), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.1 }, nil)
		round(g, 38)
		outline(g, COL.teal, 2, 0)
		shirt(g, Teams.list[teamId].primary, p.number, 46, UDim2.fromOffset(38, 34))
		text({ Position = UDim2.new(0, -20, 1, 2), Size = UDim2.new(1, 40, 0, 18), Text = p.last, FontFace = FONT.title, TextSize = 14, TextStrokeTransparency = 0.4 }, g)
		return g
	end
end

-- moving players around: court <-> court swaps places, bench <-> court swaps who plays,
-- and a libero dropped on the libero card becomes the libero
local function dropPlayer(from, to)
	local plan = sel.plan
	local lineup = plan.lineup
	if from.index == to.index then
		return
	end
	local squad = Teams.squad(sel.home)
	if to.kind == "libero" or from.kind == "libero" then
		local other = to.kind == "libero" and from or to
		if squad[other.index].role ~= "L" then
			Menu.toast("Only a libero (L) can be the libero")
			return
		end
		if other.kind == "court" then
			if not plan.libero then
				Menu.toast("Put another player on the court first")
				return
			end
			lineup[other.slot] = plan.libero
		end
		plan.libero = other.index
	elseif from.kind == "court" and to.kind == "court" then
		lineup[from.slot], lineup[to.slot] = lineup[to.slot], lineup[from.slot]
		if sel.slot == from.slot then
			sel.slot = to.slot
		elseif sel.slot == to.slot then
			sel.slot = from.slot
		end
	elseif from.kind == "court" or to.kind == "court" then
		local court = from.kind == "court" and from or to
		local bench = from.kind == "court" and to or from
		lineup[court.slot] = bench.index
	end
	Menu.squadSel = to.kind == "court" and lineup[to.slot] or from.index
	commitPlan()
end

-- a player on the court: shirt, role, rating and name
local function courtMarker(parent, p, index, slot, teamId, pos, plan, editable)
	local def = Teams.list[teamId]
	local selected = Menu.squadSel == index
	local b = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(112, 86), BackgroundColor3 = COL.teal, BackgroundTransparency = selected and 0.82 or 1 }, parent)
	if selected then
		outline(b, COL.teal, 2, 0)
	end
	shirt(b, def.primary, p.number, 42, UDim2.fromOffset(56, 26))
	text({ Position = UDim2.fromOffset(80, 6), Size = UDim2.fromOffset(30, 20), Text = tostring(p.ovr), FontFace = FONT.num, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }, b)
	text({ Position = UDim2.fromOffset(2, 6), Size = UDim2.fromOffset(32, 18), Text = p.role, FontFace = FONT.title, TextSize = 13, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Right }, b)
	local tag = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(56, 52), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = selected and COL.teal or COL.bg2, BackgroundTransparency = selected and 0 or 0.3 }, b)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tag)
	text({ Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = p.last, FontFace = FONT.title, TextSize = 14, TextColor3 = selected and COL.ink or COL.text }, tag)
	if plan.captain == index then
		local c = frame({ Position = UDim2.fromOffset(84, 30), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = COL.gold }, b)
		round(c, 9)
		text({ Size = UDim2.fromScale(1, 1), Text = "C", FontFace = FONT.title, TextSize = 12, TextColor3 = COL.ink }, c)
	end
	if slot == sel.slot then
		Menu.chip(b, "YOU", UDim2.fromOffset(4, 30), COL.gold)
	end
	local payload = { kind = "court", slot = slot, index = index }
	if editable then
		Drag.target(b, payload)
		Drag.source(b, payload, ghostFor(teamId, p), function()
			Menu.squadSel = index
			Menu.refreshSquad()
		end, dropPlayer)
	else
		b.Activated:Connect(function()
			Menu.squadSel = index
			Menu.refreshSquad()
		end)
	end
	return b
end

-- a bench card (the first one is the libero's)
local function benchCard(parent, p, index, x, teamId, kind, editable)
	local def = Teams.list[teamId]
	local selected = Menu.squadSel == index
	local b = button({ Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(86, 118), BackgroundTransparency = 0.1, BackgroundColor3 = kind == "libero" and COL.panelHi or COL.bg2 }, parent)
	outline(b, selected and COL.teal or COL.line, selected and 2 or 1, selected and 0 or 0.6)
	text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Text = kind == "libero" and "LIBERO" or p.role, FontFace = FONT.title, TextSize = 11, TextColor3 = kind == "libero" and COL.gold or COL.teal }, b)
	shirt(b, kind == "libero" and def.secondary or def.primary, p.number, 40, UDim2.fromOffset(43, 42))
	text({ Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 18), Text = p.last, FontFace = FONT.title, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd }, b)
	text({ Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 24), Text = tostring(p.ovr), FontFace = FONT.num, TextSize = 20, TextColor3 = ratingColor(p.ovr) }, b)
	local payload = { kind = kind, index = index }
	if editable then
		Drag.target(b, payload)
		Drag.source(b, payload, ghostFor(teamId, p), function()
			Menu.squadSel = index
			Menu.refreshSquad()
		end, dropPlayer)
	else
		b.Activated:Connect(function()
			Menu.squadSel = index
			Menu.refreshSquad()
		end)
	end
end

-- a six-sided ratings chart
local function radarChart(parent, center, radius, values)
	local n = #Teams.ATTRS
	local function point(i, r)
		local angle = math.rad(-90 + (i - 1) * 360 / n)
		return center + Vector2.new(math.cos(angle), math.sin(angle)) * r
	end
	for i = 1, n do
		lineBetween(parent, point(i, radius), point(i % n + 1, radius), 1, COL.dim, 0.6)
		lineBetween(parent, center, point(i, radius), 1, COL.dim, 0.8)
		local labelPos = point(i, radius + 18)
		text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(labelPos.X, labelPos.Y), Size = UDim2.fromOffset(60, 18), Text = Teams.ATTRS[i], FontFace = FONT.head, TextSize = 13, TextColor3 = COL.dim }, parent)
	end
	for i = 1, n do
		local a = point(i, radius * math.clamp(values[i] / 100, 0.05, 1))
		local b = point(i % n + 1, radius * math.clamp(values[i % n + 1] / 100, 0.05, 1))
		lineBetween(parent, a, b, 2, COL.teal, 0)
	end
end

-- the selected player's card
local function playerCard(card, teamId, plan, index)
	local squad = Teams.squad(teamId)
	local p = squad[index] or squad[1]
	local slot = table.find(plan.lineup, index)
	local def = Teams.list[teamId]
	shirt(card, def.primary, p.number, 84, UDim2.fromOffset(70, 70))
	text({ Position = UDim2.fromOffset(130, 22), Size = UDim2.fromOffset(80, 26), Text = p.role, FontFace = FONT.num, TextSize = 24, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, card)
	text({ Position = UDim2.fromOffset(130, 46), Size = UDim2.fromOffset(110, 66), Text = tostring(p.ovr), FontFace = FONT.num, TextSize = 58, TextXAlignment = Enum.TextXAlignment.Left }, card)
	text({ Position = UDim2.fromOffset(24, 124), Size = UDim2.fromOffset(300, 28), Text = p.first .. " " .. p.last, FontFace = FONT.title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left }, card)
	local roles = {}
	if slot then
		table.insert(roles, "POS " .. slot .. " · " .. POSITION_NAMES[slot])
	elseif plan.libero == index then
		table.insert(roles, "LIBERO")
	else
		table.insert(roles, "BENCH")
	end
	for _, r in Teams.ROLE_SLOTS do
		if r.key ~= "libero" and plan[r.key] == index then
			table.insert(roles, r.name)
		end
	end
	text({ Position = UDim2.fromOffset(24, 152), Size = UDim2.fromOffset(330, 20), Text = table.concat(roles, "   ·   "), FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, card)
	local values = {}
	for i, attr in Teams.ATTRS do
		values[i] = p.attrs[attr]
	end
	radarChart(card, Vector2.new(410, 96), 56, values)
	text({ Position = UDim2.fromOffset(24, 186), Size = UDim2.fromOffset(300, 22), Text = Teams.ROLES[p.role] .. "   ·   " .. p.hand .. " handed", FontFace = FONT.title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }, card)
	for i, attr in Teams.ATTRS do
		local y = 222 + (i - 1) * 36
		local v = p.attrs[attr]
		frame({ Position = UDim2.fromOffset(16, y - 4), Size = UDim2.fromOffset(492, 32), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.75 or 0.9 }, card)
		text({ Position = UDim2.fromOffset(28, y), Size = UDim2.fromOffset(140, 24), Text = Teams.ATTR_NAMES[attr], FontFace = FONT.head, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, card)
		local back = frame({ Position = UDim2.fromOffset(170, y + 8), Size = UDim2.fromOffset(260, 8), BackgroundColor3 = COL.bg2 }, card)
		frame({ Size = UDim2.fromScale(v / 100, 1), BackgroundColor3 = ratingColor(v) }, back)
		text({ Position = UDim2.fromOffset(440, y), Size = UDim2.fromOffset(50, 24), Text = tostring(v), FontFace = FONT.num, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right }, card)
	end
	text({ Position = UDim2.fromOffset(24, 444), Size = UDim2.fromOffset(480, 36), Text = "Drag players between the court and the bench. Press P to play as this player.", FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, card)
end

local function squadTab(body, teamId, plan, editable)
	local squad = Teams.squad(teamId)
	local left = panelBox(body, 0, 0, 600, 492)
	local court = frame({ Position = UDim2.fromOffset(24, 30), Size = UDim2.fromOffset(552, 290), BackgroundColor3 = Color3.fromRGB(196, 116, 58), BackgroundTransparency = 0.55 }, left)
	outline(court, Color3.new(1, 1, 1), 2, 0.4)
	frame({ Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1 }, court)
	frame({ Position = UDim2.new(0, 0, 0.42, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55 }, court)
	text({ Position = UDim2.fromOffset(0, -24), Size = UDim2.new(1, 0, 0, 20), Text = "NET", FontFace = FONT.title, TextSize = 12, TextColor3 = COL.dim }, court)
	for slot = 1, 6 do
		local index = plan.lineup[slot]
		local spot = COURT_SPOTS[slot]
		courtMarker(court, squad[index], index, slot, teamId, UDim2.fromScale(spot[1], spot[2]), plan, editable)
	end
	sectionTitle(left, "LIBERO AND BENCH", 24, 330)
	local bench = frame({ Position = UDim2.fromOffset(24, 360), Size = UDim2.fromOffset(552, 118), BackgroundTransparency = 1 }, left)
	local x = 0
	if plan.libero and squad[plan.libero] then
		benchCard(bench, squad[plan.libero], plan.libero, x, teamId, "libero", editable)
		x += 93
	end
	for index, p in squad do
		if not table.find(plan.lineup, index) and index ~= plan.libero then
			benchCard(bench, p, index, x, teamId, "bench", editable)
			x += 93
		end
	end
	local right = panelBox(body, 612, 0, 524, 492)
	playerCard(right, teamId, plan, Menu.squadSel)
end

-- six little courts: who stands where in each rotation
local function rotationTab(body, teamId, plan, editable)
	local squad = Teams.squad(teamId)
	local def = Teams.list[teamId]
	for k = 1, 6 do
		local col, row = (k - 1) % 3, (k - 1) // 3
		local box = button({ Position = UDim2.fromOffset(col * 384, row * 250), Size = UDim2.fromOffset(368, 238), BackgroundTransparency = 0.08, BackgroundColor3 = COL.panel }, body)
		local stroke = outline(box, k == 1 and COL.teal or COL.line, k == 1 and 2 or 1, k == 1 and 0 or 0.65)
		text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(200, 22), Text = "ROTATION " .. k, FontFace = FONT.title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }, box)
		if k == 1 then
			Menu.chip(box, "START", UDim2.fromOffset(140, 9), COL.teal)
		end
		local court = frame({ Position = UDim2.fromOffset(16, 40), Size = UDim2.fromOffset(336, 150), BackgroundColor3 = Color3.fromRGB(196, 116, 58), BackgroundTransparency = 0.6 }, box)
		frame({ Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1 }, court)
		frame({ Position = UDim2.new(0, 0, 0.45, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5 }, court)
		local front = {}
		local setterFront = false
		for pos = 1, 6 do
			-- in rotation k, slot k serves from position 1
			local slot = (pos - 1 + k - 1) % 6 + 1
			local p = squad[plan.lineup[slot]]
			local spot = COURT_SPOTS[pos]
			local holder = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(spot[1], spot[2]), Size = UDim2.fromOffset(60, 52), BackgroundTransparency = 1 }, court)
			shirt(holder, def.primary, p.number, 30, UDim2.fromOffset(30, 16))
			text({ Position = UDim2.fromOffset(0, 32), Size = UDim2.fromOffset(60, 16), Text = p.role .. " " .. p.last, FontFace = FONT.title, TextSize = 10, TextStrokeTransparency = 0.5, TextTruncate = Enum.TextTruncate.AtEnd }, holder)
			if slot == sel.slot then
				outline(holder, COL.gold, 1, 0)
			end
			if pos >= 2 and pos <= 4 then
				table.insert(front, p.role)
				setterFront = setterFront or p.role == "S"
			end
		end
		text({ Position = UDim2.fromOffset(16, 196), Size = UDim2.fromOffset(336, 18), Text = "FRONT ROW: " .. table.concat(front, " · "), FontFace = FONT.head, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }, box)
		text({ Position = UDim2.fromOffset(16, 214), Size = UDim2.fromOffset(336, 18), Text = setterFront and "Setter at the net: two front-row hitters" or "Setter in the back row: three front-row hitters", FontFace = FONT.head, TextSize = 13, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, box)
		box.MouseEnter:Connect(function()
			if editable and k ~= 1 then
				stroke.Color, stroke.Transparency = COL.teal, 0.3
			end
		end)
		box.MouseLeave:Connect(function()
			if k ~= 1 then
				stroke.Color, stroke.Transparency = COL.line, 0.65
			end
		end)
		box.Activated:Connect(function()
			if not editable or k == 1 then
				return
			end
			-- start the match in this rotation: everyone moves round k - 1 places
			local old = table.clone(plan.lineup)
			for pos = 1, 6 do
				plan.lineup[pos] = old[(pos - 1 + k - 1) % 6 + 1]
			end
			sel.slot = (sel.slot - k) % 6 + 1
			Menu.toast("You'll start in what was rotation " .. k)
			commitPlan()
		end)
	end
end

-- a row of options to pick from
local function segmented(parent, pos, options, chosen, width, onPick, enabled)
	local holder = frame({ Position = pos, Size = UDim2.fromOffset(#options * width, 34), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.2 }, parent)
	for i, option in options do
		local on = option == chosen
		local b = button({ Position = UDim2.fromOffset((i - 1) * width + 2, 2), Size = UDim2.fromOffset(width - 4, 30), BackgroundTransparency = on and 0 or 1, BackgroundColor3 = COL.teal }, holder)
		text({ Size = UDim2.fromScale(1, 1), Text = option, FontFace = FONT.title, TextSize = 14, TextColor3 = on and COL.ink or (enabled and COL.text or COL.dim) }, b)
		b.Activated:Connect(function()
			if enabled and not on then
				onPick(option)
			end
		end)
	end
	return holder
end

local function tacticRows(parent, tactics, enabled, onChange, width)
	width = width or 680
	for i, t in Teams.TACTICS do
		local y = (i - 1) * 96
		local row = frame({ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(width, 88), BackgroundColor3 = COL.panelHi, BackgroundTransparency = 0.82 }, parent)
		text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(240, 22), Text = t.name, FontFace = FONT.title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local segWidth = math.min(110, math.floor((width - 290) / #t.options))
		segmented(row, UDim2.new(1, -(#t.options * segWidth) - 14, 0, 8), t.options, tactics[t.key], segWidth, function(option)
			tactics[t.key] = option
			onChange()
		end, enabled)
		text({ Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 30), Text = t.info[tactics[t.key]] or "", FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, row)
	end
end

local function tacticsTab(body, teamId, plan, editable)
	local left = frame({ Size = UDim2.fromOffset(720, 492), BackgroundTransparency = 1 }, body)
	tacticRows(left, plan.tactics, editable, commitPlan, 720)
	-- the opponent's style, so you can plan against it
	local right = panelBox(body, 736, 0, 400, 492)
	local oppId = state.active and state.teamIds[3 - sel.side] or sel.away
	local opp = (state.active and state.plans and state.plans[3 - sel.side]) and state.plans[3 - sel.side].tactics or Teams.defaultTactics(oppId)
	sectionTitle(right, "SCOUTING REPORT", 20, 16)
	badge(right, oppId, 56, UDim2.fromOffset(20, 50))
	text({ Position = UDim2.fromOffset(88, 54), Size = UDim2.fromOffset(300, 24), Text = Teams.list[oppId].name, FontFace = FONT.title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left }, right)
	text({ Position = UDim2.fromOffset(88, 80), Size = UDim2.fromOffset(300, 20), Text = Teams.stars(Teams.ratings(oppId).OVR) .. "★   ·   OVR " .. Teams.ratings(oppId).OVR, FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, right)
	for i, t in Teams.TACTICS do
		local y = 128 + (i - 1) * 48
		frame({ Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(368, 40), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.75 or 0.88 }, right)
		text({ Position = UDim2.fromOffset(28, y), Size = UDim2.fromOffset(200, 40), Text = t.name, FontFace = FONT.head, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }, right)
		text({ Position = UDim2.fromOffset(200, y), Size = UDim2.fromOffset(172, 40), Text = opp[t.key] or "BALANCED", FontFace = FONT.title, TextSize = 15, TextColor3 = opp[t.key] == "BALANCED" and COL.text or COL.coral, TextXAlignment = Enum.TextXAlignment.Right }, right)
	end
	text({ Position = UDim2.fromOffset(20, 384), Size = UDim2.fromOffset(360, 90), Text = "Tip: against aggressive servers, a deep defensive line helps. Against a committed block, fast sets get the ball past it.", FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, right)
end

local function rolesTab(body, teamId, plan, editable)
	local squad = Teams.squad(teamId)
	local def = Teams.list[teamId]
	for i, r in Teams.ROLE_SLOTS do
		local y = (i - 1) * 122
		local row = panelBox(body, 0, y, 720, 110)
		text({ Position = UDim2.fromOffset(20, 16), Size = UDim2.fromOffset(260, 24), Text = r.name, FontFace = FONT.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left }, row)
		text({ Position = UDim2.fromOffset(20, 44), Size = UDim2.fromOffset(260, 50), Text = r.info, FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, row)
		local options = Teams.eligible(teamId, plan, r.key)
		local index = plan[r.key]
		local p = index and squad[index]
		if p then
			shirt(row, r.key == "libero" and def.secondary or def.primary, p.number, 56, UDim2.fromOffset(392, 55))
			text({ Position = UDim2.fromOffset(430, 26), Size = UDim2.fromOffset(180, 26), Text = p.last, FontFace = FONT.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left }, row)
			text({ Position = UDim2.fromOffset(430, 54), Size = UDim2.fromOffset(180, 22), Text = Teams.ROLES[p.role] .. "   ·   " .. p.ovr, FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, row)
		else
			text({ Position = UDim2.fromOffset(360, 40), Size = UDim2.fromOffset(250, 30), Text = "Nobody can take this role", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim }, row)
		end
		if editable and #options > 1 then
			for k, glyph in { "◀", "▶" } do
				local arrow = secondaryButton({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(k == 1 and 330 or 670, 55), Size = UDim2.fromOffset(40, 48) }, row, glyph, 18)
				arrow.Activated:Connect(function()
					local at = table.find(options, index) or 1
					plan[r.key] = options[(at - 1 + (k == 1 and -1 or 1)) % #options + 1]
					commitPlan()
				end)
			end
		end
	end
	local right = panelBox(body, 736, 0, 400, 488)
	sectionTitle(right, "HOW ROTATION WORKS", 20, 16)
	text({
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.fromOffset(360, 420),
		Text = "Every time your team wins the serve back, everyone moves round one place (clockwise), and the player who moves to the back right serves.\n\nOnly the three players at the net can block or attack above the net from in front of the 3 m line. Back-row players can still attack from behind it.\n\nThe libero comes on for the middle blocker when he's in the back row. He can't serve, block or attack above the net.\n\nYou can make " .. (Config.SUBS_PER_SET or 6) .. " substitutions a set from the pause menu.",
		FontFace = FONT.head,
		TextSize = 15,
		TextColor3 = COL.dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, right)
end

function Menu.refreshSquad()
	local teamId, plan, editable = squadData()
	local ratings = Teams.ratings(teamId, plan.lineup)
	Menu.sqSub.Text = string.format("%s   ·   5-1 SYSTEM   ·   OVR %d   ·   %s★%s", Teams.list[teamId].name, ratings.OVR, Teams.stars(ratings.OVR), editable and "" or "   ·   MATCH IN PROGRESS")
	Menu.sqTabs:ClearAllChildren()
	Menu.tabs(Menu.sqTabs, UDim2.new(), SQUAD_TABS, Menu.squadTab, function(i)
		Menu.squadTab = i
		Menu.refreshSquad()
	end, 150)
	local body = Menu.sqBody
	body:ClearAllChildren()
	if not Teams.squad(teamId)[Menu.squadSel] then
		Menu.squadSel = plan.lineup[1]
	end
	if Menu.squadTab == 1 then
		squadTab(body, teamId, plan, editable)
	elseif Menu.squadTab == 2 then
		rotationTab(body, teamId, plan, editable)
	elseif Menu.squadTab == 3 then
		tacticsTab(body, teamId, plan, editable)
	else
		rolesTab(body, teamId, plan, editable)
	end
end
Menu.onShow.squad = Menu.refreshSquad

function Menu.openSquad()
	local _, plan = squadData()
	Menu.squadSel = plan.lineup[sel.slot] or plan.lineup[1]
	Menu.squadTab = 1
	Menu.show("squad")
end

---------------------------------------------------------------- pop-up panels

local function zify(root, z)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = z
		end
	end
end

-- a centred panel with a title and a DONE button; returns the shade and its body
local function modal(parent, title, width, height, z)
	z = z or 20
	local shade = button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.45, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = z }, parent)
	local panel = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), BackgroundColor3 = COL.bg2, ZIndex = z + 1 }, shade)
	outline(panel, COL.line, 1, 0.4)
	text({ Position = UDim2.fromOffset(24, 16), Size = UDim2.fromOffset(width - 48, 34), Text = title, FontFace = FONT.title, TextSize = 26, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 2 }, panel)
	local body = frame({ Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 1, -128), BackgroundTransparency = 1, ZIndex = z + 2 }, panel)
	local done = primaryButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -16), Size = UDim2.fromOffset(150, 42), ZIndex = z + 2 }, panel, "DONE", 18)
	done.Activated:Connect(function()
		shade.Visible = false
	end)
	return shade, body, panel
end

-- rows of settings: { label, current value, change(step) }
local function settingRows(body, rows, z)
	body:ClearAllChildren()
	for i, row in rows do
		local y = (i - 1) * 44
		local locked = row.locked
		frame({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.7 or 0.85 }, body)
		text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(250, 38), Text = row[1], FontFace = FONT.head, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, body)
		local value = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, y), Size = UDim2.fromOffset(240, 38), Text = row[2](), FontFace = FONT.title, TextSize = 16, TextColor3 = locked and COL.dim or COL.teal }, body)
		if not locked then
			for k, glyph in { "◀", "▶" } do
				local arrow = button({ AnchorPoint = Vector2.new(1, 0), Position = k == 1 and UDim2.new(1, -296, 0, y + 4) or UDim2.new(1, -6, 0, y + 4), Size = UDim2.fromOffset(34, 30), BackgroundTransparency = 0.2, BackgroundColor3 = COL.panelHi }, body)
				text({ Size = UDim2.fromScale(1, 1), Text = glyph, FontFace = FONT.title, TextSize = 14 }, arrow)
				arrow.Activated:Connect(function()
					row[3](k == 1 and -1 or 1)
					value.Text = row[2]()
				end)
			end
		end
	end
	zify(body, z)
end

local CONTROL_ROWS = {
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

do
	local shade, body = modal(board, "GAME SETTINGS", 700, 440)
	Menu.settingsShade, Menu.settingsBody = shade, body
end

function Menu.openSettings()
	local rows = {
		{ "Points per set", function()
			return tostring(state.active and state.points or sel.points)
		end, function(d)
			local options = { 15, 21, 25 }
			local i = table.find(options, sel.points) or 3
			sel.points = options[(i - 1 + d) % 3 + 1]
		end, locked = state.active },
		{ "Sets", function()
			return ({ "ONE SET", "BEST OF 3", "BEST OF 5" })[state.active and state.setsToWin or sel.sets] or "ONE SET"
		end, function(d)
			sel.sets = (sel.sets - 1 + d) % 3 + 1
		end, locked = state.active },
	}
	for _, row in CONTROL_ROWS do
		table.insert(rows, row)
	end
	settingRows(Menu.settingsBody, rows, 23)
	Menu.settingsShade.Visible = true
end

do
	local shade, body = modal(board, "CONTROLS", 760, 560)
	Menu.controlsShade = shade
	local rows = {
		{ "Move", "W A S D", "LEFT STICK", "THUMBSTICK" },
		{ "Pass  /  spike in the air", "CLICK", "R2", "HIT" },
		{ "Set  /  tip in the air", "E", "X", "SET" },
		{ "Jump  ·  block at the net", "SPACE", "A", "JUMP" },
		{ "Dive", "Q or C", "B", "DIVE" },
		{ "Ability  /  call quick set", "R  /  F", "Y  /  UP", "POWER" },
		{ "Serve: hold, let go in the green", "HOLD CLICK", "HOLD R2", "HOLD HIT" },
		{ "Camera  /  shift lock", "V  /  SHIFT", "", "" },
		{ "Free cam (fly with W A S D, Q / E)", "G", "BACK", "" },
		{ "Pause", "M", "START", "" },
	}
	for k, title in { "KEYBOARD", "GAMEPAD", "TOUCH" } do
		text({ Position = UDim2.fromOffset(330 + (k - 1) * 120, 0), Size = UDim2.fromOffset(110, 20), Text = title, FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim }, body)
	end
	for i, row in rows do
		local y = 24 + (i - 1) * 40
		frame({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.7 or 0.85 }, body)
		text({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(310, 36), Text = row[1], FontFace = FONT.head, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, body)
		for k = 2, 4 do
			text({ Position = UDim2.fromOffset(330 + (k - 2) * 120, y), Size = UDim2.fromOffset(110, 36), Text = row[k], FontFace = FONT.title, TextSize = 14, TextColor3 = COL.teal }, body)
		end
	end
	zify(body, 23)
end

function Menu.openControls()
	Menu.controlsShade.Visible = true
end

do
	local shade, body = modal(board, "DETAILED STATS", 700, 500)
	Menu.statsShade, Menu.statsBody = shade, body
end

function Menu.openStats()
	local body = Menu.statsBody
	body:ClearAllChildren()
	local a, b = previewTeams()
	local ra, rb = Teams.ratings(a, (not state.active and a == sel.home) and sel.plan.lineup or nil), Teams.ratings(b)
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
		frame({ Size = UDim2.fromScale(share, 1), BackgroundColor3 = COL.teal }, back)
		frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(1 - share, 1), BackgroundColor3 = COL.coral }, back)
	end
	zify(body, 23)
	Menu.statsShade.Visible = true
end

---------------------------------------------------------------- loading, pause, and moving between the menus and a match

do
	local shade = frame({ Position = UDim2.new(0, -300, 0, -300), Size = UDim2.new(1, 600, 1, 600), BackgroundColor3 = COL.bg2, BackgroundTransparency = 0.25, Visible = false, ZIndex = 30 }, Menu.gui)
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(500, 40), Text = "PREPARING MATCH", FontFace = FONT.title, TextSize = 28, ZIndex = 31 }, shade)
	local spinner = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 52), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, ZIndex = 31 }, shade)
	round(spinner, 17)
	make("UIStroke", { Color = COL.teal, Thickness = 3 }, spinner)
	frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = COL.text, ZIndex = 32 }, spinner)
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
	-- unless you picked someone with P, you play your preferred position
	if not sel.slotPicked and not state.active then
		local squad = Teams.squad(sel.home)
		for slot, index in sel.plan.lineup do
			if squad[index].role == Menu.custom.role then
				sel.slot = slot
				break
			end
		end
	end
	remote:FireServer("start", {
		kit = Menu.custom.kits[tostring(sel.home)] or 1,
		court = Menu.custom.court,
		custom = { number = Menu.custom.number, wearKit = Menu.custom.wearKit },
		home = sel.home,
		away = sel.away,
		plan = sel.plan,
		lineup = sel.plan.lineup,
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

-- your controls are off in the menus and while the match is paused
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

-- in-match panels live on the HUD (scaled like it)
local matchLayer = HUD.root

-- substitutions: drag a bench player onto a player on the court (or click one, then the other)
do
	local shade, body, panel = modal(matchLayer, "SUBSTITUTIONS", 660, 560, 30)
	Menu.subsShade, Menu.subsList = shade, body
	Menu.subsHint = text({ Position = UDim2.fromOffset(250, 22), Size = UDim2.fromOffset(386, 24), FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 32 }, panel)
end

function Menu.openSubs()
	local team = myTeam()
	if team == 0 then
		return
	end
	local list = Menu.subsList
	list:ClearAllChildren()
	local teamId = state.teamIds[team]
	local plan = state.plans and state.plans[team] or { lineup = state.lineups[team] }
	local lineup = plan.lineup
	local squad = Teams.squad(teamId)
	local def = Teams.list[teamId]
	local used, max = state.subs and state.subs[team] or 0, state.subsMax or 6
	Menu.subsHint.Text = string.format("%d OF %d LEFT THIS SET   ·   DRAG A BENCH PLAYER ONTO THE COURT", math.max(max - used, 0), max)
	local function sub(outIndex, inIndex)
		remote:FireServer("sub", { out = outIndex, into = inIndex })
		Menu.subOut = nil
		task.delay(0.3, function()
			if Menu.subsShade.Visible then
				Menu.openSubs()
			end
		end)
	end
	local function onDrop(from, to)
		if from.bench and not to.bench then
			sub(to.index, from.index)
		elseif to.bench and not from.bench then
			sub(from.index, to.index)
		end
	end
	local function row(y, p, index, x, bench, tag)
		local b = button({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(296, 50), BackgroundTransparency = 0.2, BackgroundColor3 = Menu.subOut == index and COL.panelHi:Lerp(COL.teal, 0.4) or COL.panelHi, ZIndex = 33 }, list)
		shirt(b, def.primary, p.number, 36, UDim2.fromOffset(28, 25))
		text({ Position = UDim2.fromOffset(54, 0), Size = UDim2.fromOffset(150, 50), Text = p.last, FontFace = FONT.title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, b)
		text({ Position = UDim2.fromOffset(196, 0), Size = UDim2.fromOffset(50, 50), Text = tag or p.role, FontFace = FONT.title, TextSize = 13, TextColor3 = tag and COL.gold or COL.teal }, b)
		text({ Position = UDim2.fromOffset(246, 0), Size = UDim2.fromOffset(42, 50), Text = tostring(p.ovr), FontFace = FONT.num, TextSize = 20, TextColor3 = ratingColor(p.ovr) }, b)
		local payload = { index = index, bench = bench }
		Drag.target(b, payload)
		Drag.source(b, payload, function()
			local g = frame({ Size = UDim2.fromOffset(200, 44), BackgroundColor3 = COL.teal }, nil)
			text({ Size = UDim2.fromScale(1, 1), Text = "#" .. p.number .. "  " .. p.last, FontFace = FONT.title, TextSize = 17, TextColor3 = COL.ink }, g)
			return g
		end, function()
			-- click: pick the player going off, then the one coming on
			if not bench then
				Menu.subOut = index
				Menu.openSubs()
			elseif Menu.subOut then
				sub(Menu.subOut, index)
			end
		end, onDrop)
		zify(b, 34)
	end
	text({ Size = UDim2.fromOffset(296, 20), Text = "ON THE COURT", FontFace = FONT.title, TextSize = 14, TextColor3 = COL.teal, ZIndex = 33 }, list)
	text({ Position = UDim2.fromOffset(316, 0), Size = UDim2.fromOffset(296, 20), Text = "BENCH", FontFace = FONT.title, TextSize = 14, TextColor3 = COL.teal, ZIndex = 33 }, list)
	for slot, index in lineup do
		local e = entryAt(team, slot)
		row(26 + (slot - 1) * 56, squad[index], index, 0, false, e and e.ctrl and "YOU" or nil)
	end
	local y = 26
	for index, p in squad do
		if not table.find(lineup, index) and index ~= plan.libero then
			row(y, p, index, 316, true)
			y += 56
		end
	end
	Menu.subsShade.Visible = true
end

-- tactics during the match: changes go to the server straight away
do
	local shade, body = modal(matchLayer, "TACTICS", 760, 620, 30)
	Menu.tacticsShade, Menu.tacticsBody = shade, body
end

function Menu.openMatchTactics()
	local team = myTeam()
	local plan = state.plans and state.plans[team]
	if not plan then
		return
	end
	local tactics = table.clone(plan.tactics)
	local body = Menu.tacticsBody
	body:ClearAllChildren()
	tacticRows(body, tactics, true, function()
		remote:FireServer("plan", { tactics = tactics })
		task.delay(0.25, Menu.openMatchTactics)
	end, 712)
	zify(body, 33)
	Menu.tacticsShade.Visible = true
end

do
	local shade, body = modal(matchLayer, "MATCH SETTINGS", 700, 330, 30)
	Menu.matchSettingsShade, Menu.matchSettingsBody = shade, body
end

function Menu.openMatchSettings()
	settingRows(Menu.matchSettingsBody, CONTROL_ROWS, 33)
	Menu.matchSettingsShade.Visible = true
end

-- pause screen: stops the match for everyone in it
do
	local shade = button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.4, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 20 }, matchLayer)
	local panel = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 554), BackgroundColor3 = COL.bg2, ZIndex = 21 }, shade)
	outline(panel, COL.line, 1, 0.4)
	text({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 40), Text = "PAUSED", FontFace = FONT.title, TextSize = 32, TextColor3 = COL.cyan, ZIndex = 22 }, panel)
	Menu.pauseBy = text({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 20), FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, ZIndex = 22 }, panel)
	local options = {
		{ "RESUME", function()
			remote:FireServer("pause", { on = false })
		end },
		{ "TACTICS", function()
			Menu.openMatchTactics()
		end },
		{ "SUBSTITUTIONS", function()
			Menu.subOut = nil
			Menu.openSubs()
		end },
		{ "CAMERA AND DISPLAY", function()
			Menu.openMatchSettings()
		end },
		{ "FREE CAM", function()
			Cam.toggleFree()
		end },
		{ "QUIT TO MAIN MENU", function()
			remote:FireServer("pause", { on = false })
			remote:FireServer("leave", {})
			openMenu("home")
		end },
	}
	for i, option in options do
		local make_ = i == 1 and primaryButton or secondaryButton
		local b = make_({ Position = UDim2.fromOffset(40, 92 + (i - 1) * 64), Size = UDim2.fromOffset(320, 52), ZIndex = 22 }, panel, option[1], 18)
		b.Activated:Connect(option[2])
	end
	Menu.pause = shade
	showPause = function()
		if myTeam() ~= 0 then
			remote:FireServer("pause", { on = not state.paused })
		end
	end
end

-- shows or hides the pause screen to match the server
local wasPaused = false
function Menu.syncPause()
	local show = state.paused == true and not inMenu and myTeam() ~= 0
	Menu.pause.Visible = show and not Cam.free
	if not show then
		Menu.subsShade.Visible = false
		Menu.tacticsShade.Visible = false
		Menu.matchSettingsShade.Visible = false
	elseif Menu.subsShade.Visible then
		Menu.openSubs() -- keep the bench up to date
	end
	Menu.pauseBy.Text = (state.pausedBy and state.pausedBy ~= "") and ("Paused by " .. state.pausedBy) or ""
	if show ~= wasPaused and not inMenu then
		task.spawn(setControls, not show)
	end
	wasPaused = show
end

function openMenu(screenName)
	inMenu = true
	wasPaused = false
	task.spawn(setControls, false)
	Controls.charging = false
	Controls.pending = nil
	HUD.power = nil
	Menu.pause.Visible = false
	Menu.subsShade.Visible = false
	Menu.tacticsShade.Visible = false
	Menu.matchSettingsShade.Visible = false
	HUD.gui.Enabled = false
	HUD.touchGui.Enabled = false
	Menu.gui.Enabled = true
	Menu.loading.Visible = false
	Menu.waiting = false
	Menu.stack = {}
	Menu.show(screenName or "home", false)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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
	Menu.queued = false
	HUD.gui.Enabled = true
	HUD.touchGui.Enabled = HUD.touchMode
	Cam.focus = nil
	Cam.ready = false
	Cam.mode = nil
	Stamina.value = 100
	HUD.refresh()
end
