
---------------------------------------------------------------- career and online screens

local profile = nil -- your saved progress, from the server
local savingOk = true
local newCareer = { club = 1, role = "OH", number = 7 }
local onlineClub = 1
local queueCount = 0
local ROUNDS = math.clamp(math.floor(Config.SEASON_ROUNDS or 11), 1, #Teams.list - 1)
local ROLE_WORDS = { S = "SETTER", OH = "OUTSIDE HITTER", MB = "MIDDLE BLOCKER", OPP = "OPPOSITE", L = "LIBERO" }

-- the same round-robin fixtures the server uses
local function opponentFor(club, round)
	local count = #Teams.list
	local order = { 1 }
	for k = 1, count - 1 do
		order[k + 1] = 2 + ((k - 1 + round - 1) % (count - 1))
	end
	for i = 1, count // 2 do
		local a, b = order[i], order[count + 1 - i]
		if a == club then
			return b
		elseif b == club then
			return a
		end
	end
	return club % count + 1
end

local function standings(rows)
	local order = {}
	for i = 1, #rows do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local x, y = rows[a], rows[b]
		if x.pts ~= y.pts then
			return x.pts > y.pts
		end
		return (x.sf - x.sa) > (y.sf - y.sa)
	end)
	return order
end

local function panel(parent, x, y, w, h)
	local p = frame({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = COL.panel, BackgroundTransparency = 0.08 }, parent)
	outline(p, COL.line, 1, 0.65)
	return p
end

local function bigButton(parent, label, pos, size, onClick)
	local b, l = primaryButton({ Position = pos, Size = size }, parent, label, 20)
	b.Activated:Connect(onClick)
	return b, l
end

local function arrows(parent, y, leftX, rightX, onStep)
	for k, glyph in { "◀", "▶" } do
		local arrow = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(k == 1 and leftX or rightX, y), Size = UDim2.fromOffset(42, 52), BackgroundTransparency = 0.3, BackgroundColor3 = COL.panelHi }, parent)
		round(arrow, 6)
		text({ Size = UDim2.fromScale(1, 1), Text = glyph, FontFace = FONT.title, TextSize = 22 }, arrow)
		arrow.Activated:Connect(function()
			onStep(k == 1 and -1 or 1)
		end)
	end
end

local function header(screenFrame, title, subtitle)
	text({ Position = UDim2.fromOffset(72, 30), Size = UDim2.fromOffset(700, 44), Text = title, FontFace = FONT.body, TextSize = 40, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left }, screenFrame)
	return text({ Position = UDim2.fromOffset(74, 76), Size = UDim2.fromOffset(900, 22), Text = subtitle, FontFace = FONT.head, TextSize = 18, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, screenFrame)
end

---------------------------------------------------------------- creating your player

do
	local screenFrame = Menu.screen("career_new")
	header(screenFrame, "CAREER", "CREATE YOUR PLAYER   ·   PICK A CLUB, A POSITION AND A NUMBER")
	Menu.cnClub = panel(screenFrame, 120, 124, 460, 440)
	Menu.cnPlayer = panel(screenFrame, 700, 124, 460, 440)
	bigButton(screenFrame, "CREATE CAREER  ▸", UDim2.fromOffset(950, 588), UDim2.fromOffset(260, 52), function()
		remote:FireServer("career_create", newCareer)
		Menu.toast("Creating your player...")
	end)
	Menu.hints(screenFrame, { { "BACK", "Back", Menu.back } }, UDim2.fromOffset(120, 600))
end

function Menu.refreshCareerNew()
	local c = Menu.cnClub
	c:ClearAllChildren()
	outline(c, COL.line, 1, 0.65)
	local def = Teams.list[newCareer.club]
	local ratings = Teams.ratings(newCareer.club)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = "YOUR CLUB", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, c)
	badge(c, newCareer.club, 120, UDim2.fromOffset(230, 56), Vector2.new(0.5, 0))
	arrows(c, 116, 60, 400, function(d)
		newCareer.club = (newCareer.club - 1 + d) % #Teams.list + 1
		Menu.refreshCareerNew()
	end)
	text({ Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 34), Text = def.name, FontFace = FONT.title, TextSize = 30 }, c)
	text({ Position = UDim2.fromOffset(0, 226), Size = UDim2.new(1, 0, 0, 18), Text = Teams.LEAGUE .. "   ·   OVR " .. ratings.OVR, FontFace = FONT.head, TextSize = 16, TextColor3 = COL.dim }, c)
	starRow(c, Teams.stars(ratings.OVR), 26, UDim2.fromOffset(230, 252), Vector2.new(0.5, 0))
	text({ Position = UDim2.fromOffset(30, 300), Size = UDim2.fromOffset(400, 110), Text = "A five-star club wins more, so you'll fight for the title; a smaller club makes every win count. Your player starts at the same level either way.", FontFace = FONT.head, TextSize = 16, TextWrapped = true, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, c)

	local p = Menu.cnPlayer
	p:ClearAllChildren()
	outline(p, COL.line, 1, 0.65)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = "POSITION", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, p)
	for i, role in Teams.ROLE_ORDER do
		local chosen = newCareer.role == role
		local b = button({ Position = UDim2.fromOffset(20 + (i - 1) * 84, 46), Size = UDim2.fromOffset(78, 40), BackgroundTransparency = chosen and 0 or 0.4, BackgroundColor3 = chosen and COL.violet or COL.panelHi }, p)
		round(b, 4)
		text({ Size = UDim2.fromScale(1, 1), Text = role, FontFace = FONT.title, TextSize = 18 }, b)
		b.Activated:Connect(function()
			newCareer.role = role
			Menu.refreshCareerNew()
		end)
	end
	text({ Position = UDim2.fromOffset(20, 92), Size = UDim2.fromOffset(420, 20), Text = ROLE_WORDS[newCareer.role], FontFace = FONT.head, TextSize = 16, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, p)
	text({ Position = UDim2.fromOffset(20, 122), Size = UDim2.fromOffset(200, 24), Text = "SHIRT NUMBER", FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, p)
	shirt(p, def.primary, newCareer.number, 64, UDim2.fromOffset(330, 140))
	arrows(p, 140, 250, 410, function(d)
		newCareer.number = (newCareer.number - 1 + d) % 99 + 1
		Menu.refreshCareerNew()
	end)
	local attrs = {}
	for _, attr in Teams.ATTRS do
		attrs[attr] = math.clamp(60 + Teams.TEMPLATE[newCareer.role][attr], 40, 95)
	end
	text({ Position = UDim2.fromOffset(20, 186), Size = UDim2.fromOffset(300, 24), Text = "STARTING RATINGS   ·   OVR " .. Teams.overall(newCareer.role, attrs), FontFace = FONT.title, TextSize = 18, TextColor3 = COL.lime, TextXAlignment = Enum.TextXAlignment.Left }, p)
	for i, attr in Teams.ATTRS do
		local y = 218 + (i - 1) * 34
		local v = attrs[attr]
		text({ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(120, 26), Text = Teams.ATTR_NAMES[attr], FontFace = FONT.head, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, p)
		local back = frame({ Position = UDim2.fromOffset(150, y + 9), Size = UDim2.fromOffset(230, 8), BackgroundColor3 = COL.bg2 }, p)
		frame({ Size = UDim2.fromScale(v / 100, 1), BackgroundColor3 = ratingColor(v) }, back)
		text({ Position = UDim2.fromOffset(390, y), Size = UDim2.fromOffset(50, 26), Text = tostring(v), FontFace = FONT.num, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right }, p)
	end
end
Menu.onShow.career_new = Menu.refreshCareerNew

---------------------------------------------------------------- the career hub

local CAREER_TABS = { "OVERVIEW", "TRAINING", "LEAGUE", "INBOX", "HISTORY" }
local CAMP_COST = 4000
local KIND_COLORS = { offer = COL.gold, trophy = COL.gold, award = COL.gold, transfer = COL.teal, match = COL.cyan, objective = COL.lime, status = COL.pink, playoff = COL.coral }
Menu.careerTab = 1

-- colour for a 0-10 match rating
local function rateColor(r)
	if r >= 8 then
		return COL.win
	elseif r >= 7 then
		return Color3.fromRGB(170, 220, 70)
	elseif r >= 6 then
		return COL.gold
	end
	return COL.coral
end

local function phaseLabel(career)
	if career.phase == "semi" then
		return "PLAYOFF SEMI-FINAL   ·   BEST OF THREE"
	elseif career.phase == "final" then
		return "PLAYOFF FINAL   ·   BEST OF THREE"
	end
	return "ROUND " .. career.round .. " OF " .. ROUNDS
end

local function nextOpponent(career)
	if career.phase == "semi" or career.phase == "final" then
		return career.playoffOpp or opponentFor(career.club, 1)
	end
	return opponentFor(career.club, career.round)
end

local function unread(career)
	local n = 0
	for _, item in career.inbox or {} do
		if not item.read then
			n += 1
		end
	end
	return n
end

local function label(parent, props)
	props.FontFace = props.FontFace or FONT.head
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return text(props, parent)
end

local function bar(parent, x, y, w, h, fraction, color)
	local back = frame({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = COL.bg2 }, parent)
	frame({ Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color }, back)
	return back
end

do
	local screenFrame = Menu.screen("career")
	Menu.chSub = header(screenFrame, "CAREER", "")
	Menu.chTabs = frame({ Position = UDim2.fromOffset(72, 104), Size = UDim2.fromOffset(760, 32), BackgroundTransparency = 1 }, screenFrame)
	Menu.chBody = frame({ Position = UDim2.fromOffset(72, 146), Size = UDim2.fromOffset(1136, 476), BackgroundTransparency = 1 }, screenFrame)
	Menu.chSaving = text({ Position = UDim2.fromOffset(600, 640), Size = UDim2.fromOffset(608, 20), FontFace = FONT.head, TextSize = 14, TextColor3 = COL.coral, TextXAlignment = Enum.TextXAlignment.Right }, screenFrame)
	Menu.hints(screenFrame, {
		{ "BACK", "Back", Menu.back },
		{ "R", "Retire (press twice)", function()
			Menu.retire()
		end },
	}, UDim2.fromOffset(72, 636))
end

function Menu.retire()
	if Menu.retireArmed and os.clock() - Menu.retireArmed < 3 then
		Menu.retireArmed = nil
		remote:FireServer("career_retire", {})
		Menu.toast("Career ended")
	else
		Menu.retireArmed = os.clock()
		Menu.toast("Press retire again to end this career")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if inMenu and not processed and Menu.current == "career" and input.KeyCode == Enum.KeyCode.R then
		Menu.retire()
	end
end)

local function playCareerMatch()
	if Menu.waiting then
		return
	end
	Menu.waiting = true
	Menu.loading.Visible = true
	remote:FireServer("start", { mode = "career" })
	task.delay(15, function()
		if Menu.waiting and inMenu then
			Menu.waiting = false
			Menu.loading.Visible = false
		end
	end)
end

---------------------------------------------------------------- OVERVIEW

local function overviewTab(body, career)
	local def = Teams.list[career.club]
	-- your player
	local c = panel(body, 0, 0, 360, 476)
	shirt(c, def.primary, career.number, 70, UDim2.fromOffset(60, 58))
	label(c, { Position = UDim2.fromOffset(110, 16), Size = UDim2.fromOffset(160, 26), Text = career.role, FontFace = FONT.num, TextSize = 24, TextColor3 = COL.cyan })
	label(c, { Position = UDim2.fromOffset(110, 42), Size = UDim2.fromOffset(170, 22), Text = string.upper(player.DisplayName), FontFace = FONT.title, TextSize = 19 })
	label(c, { Position = UDim2.fromOffset(110, 64), Size = UDim2.fromOffset(170, 20), Text = def.name, TextSize = 15, TextColor3 = COL.dim })
	local ovrBox = frame({ Position = UDim2.fromOffset(282, 14), Size = UDim2.fromOffset(62, 58), BackgroundColor3 = ratingColor(career.ovr) }, c)
	text({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 36), Text = tostring(career.ovr), FontFace = FONT.num, TextSize = 32, TextColor3 = COL.ink }, ovrBox)
	text({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 14), Text = "OVR", FontFace = FONT.title, TextSize = 12, TextColor3 = COL.ink }, ovrBox)
	Menu.chip(c, career.status or "STARTER", UDim2.fromOffset(110, 90), COL.teal)

	local need = 100 * career.level
	label(c, { Position = UDim2.fromOffset(20, 128), Size = UDim2.fromOffset(160, 20), Text = "LEVEL " .. career.level, FontFace = FONT.title, TextSize = 16 })
	label(c, { Position = UDim2.fromOffset(160, 128), Size = UDim2.fromOffset(180, 20), Text = career.xp .. " / " .. need .. " XP", TextSize = 14, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right })
	bar(c, 20, 152, 320, 8, career.xp / need, COL.teal)
	label(c, { Position = UDim2.fromOffset(20, 170), Size = UDim2.fromOffset(160, 20), Text = "MORALE", FontFace = FONT.title, TextSize = 16 })
	label(c, { Position = UDim2.fromOffset(160, 170), Size = UDim2.fromOffset(180, 20), Text = career.morale >= 75 and "BUZZING" or career.morale >= 50 and "CONTENT" or career.morale >= 30 and "LOW" or "UNHAPPY", TextSize = 14, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right })
	bar(c, 20, 194, 320, 8, career.morale / 100, career.morale >= 50 and COL.win or COL.coral)

	label(c, { Position = UDim2.fromOffset(20, 214), Size = UDim2.fromOffset(200, 20), Text = "FORM (LAST 5)", FontFace = FONT.title, TextSize = 16 })
	for i = 1, 5 do
		local r = career.form[i]
		local box = frame({ Position = UDim2.fromOffset(20 + (i - 1) * 66, 240), Size = UDim2.fromOffset(58, 36), BackgroundColor3 = r and rateColor(r) or COL.bg2, BackgroundTransparency = r and 0 or 0.4 }, c)
		text({ Size = UDim2.fromScale(1, 1), Text = r and string.format("%.1f", r) or "-", FontFace = FONT.num, TextSize = 19, TextColor3 = r and COL.ink or COL.dim }, box)
	end

	label(c, { Position = UDim2.fromOffset(20, 294), Size = UDim2.fromOffset(320, 20), Text = "CONTRACT", FontFace = FONT.title, TextSize = 16 })
	label(c, { Position = UDim2.fromOffset(20, 316), Size = UDim2.fromOffset(320, 40), Text = string.format("%d a match   ·   %d season%s left\nBank: %d", career.contract.salary, career.contract.years, career.contract.years == 1 and "" or "s", career.money), TextSize = 15, TextColor3 = COL.dim, TextYAlignment = Enum.TextYAlignment.Top })

	label(c, { Position = UDim2.fromOffset(20, 368), Size = UDim2.fromOffset(320, 20), Text = "PERKS", FontFace = FONT.title, TextSize = 16 })
	local px, py = 20, 394
	local any = false
	for _, perk in Teams.PERKS do
		if career.perks and career.perks[perk.name] then
			any = true
			local chip = Menu.chip(c, perk.name, UDim2.fromOffset(px, py), COL.gold)
			px += #perk.name * 9 + 34
			if px > 280 then
				px, py = 20, py + 30
			end
			chip.ZIndex = 2
		end
	end
	if not any then
		label(c, { Position = UDim2.fromOffset(20, 392), Size = UDim2.fromOffset(320, 40), Text = "Reach " .. Teams.PERK_LEVEL .. " in any attribute to unlock a perk.", TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	end

	-- next match
	local n = panel(body, 372, 0, 380, 476)
	Menu.title(n, career.phase == "league" and "NEXT MATCH" or "PLAYOFFS", 30)
	text({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 20), Text = phaseLabel(career), FontFace = FONT.head, TextSize = 15 }, n)
	local opp = nextOpponent(career)
	local order = standings(career.table)
	for i, id in { career.club, opp } do
		local cx = i == 1 and 100 or 280
		local row = career.table[id]
		badge(n, id, 88, UDim2.fromOffset(cx, 88), Vector2.new(0.5, 0))
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 184), Size = UDim2.fromOffset(170, 20), Text = Teams.list[id].name, FontFace = FONT.title, TextSize = 15 }, n)
		starRow(n, Teams.stars(Teams.ratings(id).OVR), 16, UDim2.fromOffset(cx, 208), Vector2.new(0.5, 0))
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 228), Size = UDim2.fromOffset(170, 18), Text = ordinal(table.find(order, id) or 12) .. "   ·   " .. row.w .. "W " .. row.l .. "L", FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim }, n)
	end
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(190, 132), Size = UDim2.fromOffset(60, 40), Text = "V", FontFace = FONT.num, TextSize = 34, TextColor3 = COL.dim }, n)
	bigButton(n, "PLAY MATCH  ▸", UDim2.fromOffset(44, 264), UDim2.fromOffset(292, 54), playCareerMatch)
	local last = career.last
	if last then
		local line = string.format("LAST: %s %s v %s", last.won and "WON" or "LOST", last.score, Teams.list[last.opponent].short)
		text({ Position = UDim2.fromOffset(20, 336), Size = UDim2.fromOffset(340, 22), Text = line, FontFace = FONT.title, TextSize = 16, TextColor3 = last.won and COL.win or COL.coral }, n)
		if last.rating then
			text({ Position = UDim2.fromOffset(20, 360), Size = UDim2.fromOffset(340, 20), Text = string.format("RATING %.1f   ·   +%d XP", last.rating, last.xp), FontFace = FONT.head, TextSize = 15, TextColor3 = rateColor(last.rating) }, n)
		end
	end
	text({ Position = UDim2.fromOffset(20, 396), Size = UDim2.fromOffset(340, 60), Text = career.phase == "league" and "The top four after " .. ROUNDS .. " rounds play semi-finals and a final for the title." or "Win and you're one step closer to the trophy.", FontFace = FONT.head, TextSize = 14, TextWrapped = true, TextColor3 = COL.dim }, n)

	-- objectives
	local o = panel(body, 764, 0, 372, 250)
	Menu.title(o, "OBJECTIVES", 24)
	local position = table.find(order, career.club) or 12
	label(o, { Position = UDim2.fromOffset(16, 46), Size = UDim2.fromOffset(340, 20), Text = "BOARD: " .. string.upper(career.objectives.club.text), FontFace = FONT.title, TextSize = 14 })
	local onTrack = (career.objectives.club.target == 1 and position == 1) or (career.objectives.club.target > 1 and position <= career.objectives.club.target)
	label(o, { Position = UDim2.fromOffset(16, 66), Size = UDim2.fromOffset(340, 18), Text = "Currently " .. ordinal(position) .. (onTrack and "   ·   ON TRACK" or "   ·   BEHIND"), TextSize = 14, TextColor3 = onTrack and COL.win or COL.coral })
	for i, obj in career.objectives.personal do
		local y = 100 + (i - 1) * 66
		label(o, { Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(260, 20), Text = string.upper(obj.text), FontFace = FONT.title, TextSize = 14, TextColor3 = obj.done and COL.win or COL.text })
		label(o, { Position = UDim2.fromOffset(250, y), Size = UDim2.fromOffset(106, 20), Text = obj.done and "DONE" or (obj.progress .. " / " .. obj.target), TextSize = 14, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right })
		bar(o, 16, y + 26, 340, 8, obj.progress / obj.target, obj.done and COL.win or COL.teal)
	end

	-- latest news
	local nw = panel(body, 764, 262, 372, 214)
	Menu.title(nw, "INBOX" .. (unread(career) > 0 and ("  (" .. unread(career) .. " NEW)") or ""), 24)
	for i = 1, math.min(3, #career.inbox) do
		local item = career.inbox[i]
		local y = 46 + (i - 1) * 46
		local dot = frame({ Position = UDim2.fromOffset(16, y + 6), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = item.read and COL.dim or (KIND_COLORS[item.kind] or COL.teal) }, nw)
		round(dot, 4)
		label(nw, { Position = UDim2.fromOffset(32, y), Size = UDim2.fromOffset(324, 20), Text = item.title, FontFace = FONT.title, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd })
		label(nw, { Position = UDim2.fromOffset(32, y + 18), Size = UDim2.fromOffset(324, 18), Text = item.body, TextSize = 13, TextColor3 = COL.dim, TextTruncate = Enum.TextTruncate.AtEnd })
	end
	local open = secondaryButton({ Position = UDim2.fromOffset(16, 180), Size = UDim2.fromOffset(160, 26) }, nw, "OPEN INBOX", 14)
	open.Activated:Connect(function()
		Menu.careerTab = 4
		Menu.refreshCareer()
	end)
end

---------------------------------------------------------------- TRAINING

local function trainingTab(body, career)
	local l = panel(body, 0, 0, 640, 476)
	Menu.title(l, "TRAINING", 28)
	label(l, { Position = UDim2.fromOffset(16, 48), Size = UDim2.fromOffset(608, 36), Text = "Pick a focus: every match adds progress to it (more for a good rating). At 100 the attribute goes up by one. Level-up points (+) raise any attribute straight away.", TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	label(l, { Position = UDim2.fromOffset(16, 88), Size = UDim2.fromOffset(608, 20), Text = career.points > 0 and (career.points .. " TRAINING POINT" .. (career.points == 1 and "" or "S") .. " TO SPEND") or "LEVEL UP TO EARN TRAINING POINTS", FontFace = FONT.title, TextSize = 15, TextColor3 = career.points > 0 and COL.lime or COL.dim })
	for i, attr in Teams.ATTRS do
		local y = 120 + (i - 1) * 58
		local v = career.attrs[attr]
		local focus = career.focus == attr
		local row = frame({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(616, 52), BackgroundColor3 = focus and COL.panelHi or COL.bg2, BackgroundTransparency = focus and 0.2 or 0.6 }, l)
		if focus then
			outline(row, COL.teal, 1, 0.2)
		end
		label(row, { Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(150, 22), Text = Teams.ATTR_NAMES[attr], FontFace = FONT.title, TextSize = 16 })
		text({ Position = UDim2.fromOffset(160, 4), Size = UDim2.fromOffset(44, 44), Text = tostring(v), FontFace = FONT.num, TextSize = 26, TextColor3 = ratingColor(v) }, row)
		label(row, { Position = UDim2.fromOffset(12, 28), Size = UDim2.fromOffset(150, 18), Text = "progress " .. math.floor(career.progress[attr] or 0) .. "%", TextSize = 13, TextColor3 = COL.dim })
		bar(row, 214, 22, 220, 8, (career.progress[attr] or 0) / 100, focus and COL.teal or COL.violet)
		local fb = button({ Position = UDim2.fromOffset(446, 10), Size = UDim2.fromOffset(110, 32), BackgroundTransparency = focus and 0 or 0.3, BackgroundColor3 = focus and COL.teal or COL.panelHi }, row)
		text({ Size = UDim2.fromScale(1, 1), Text = focus and "FOCUS" or "SET FOCUS", FontFace = FONT.title, TextSize = 14, TextColor3 = focus and COL.ink or COL.text }, fb)
		fb.Activated:Connect(function()
			remote:FireServer("career_focus", { attr = attr })
		end)
		if career.points > 0 and v < 99 then
			local plus = button({ Position = UDim2.fromOffset(566, 10), Size = UDim2.fromOffset(38, 32), BackgroundTransparency = 0, BackgroundColor3 = COL.lime }, row)
			text({ Size = UDim2.fromScale(1, 1), Text = "+", FontFace = FONT.title, TextSize = 22, TextColor3 = COL.ink }, plus)
			plus.Activated:Connect(function()
				remote:FireServer("career_train", { attr = attr })
			end)
		end
	end

	local r = panel(body, 652, 0, 484, 476)
	Menu.title(r, "PERKS", 28)
	for i, perk in Teams.PERKS do
		local y = 50 + (i - 1) * 44
		local have = career.perks and career.perks[perk.name]
		local v = career.attrs[perk.attr]
		local tag = frame({ Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = have and COL.gold or COL.bg2, BackgroundTransparency = have and 0 or 0.4 }, r)
		text({ Size = UDim2.fromScale(1, 1), Text = perk.name, FontFace = FONT.title, TextSize = 14, TextColor3 = have and COL.ink or COL.dim }, tag)
		label(r, { Position = UDim2.fromOffset(136, y), Size = UDim2.fromOffset(240, 34), Text = perk.info, TextSize = 14, TextColor3 = have and COL.text or COL.dim })
		label(r, { Position = UDim2.fromOffset(370, y), Size = UDim2.fromOffset(100, 34), Text = have and "UNLOCKED" or (perk.attr .. " " .. v .. " / " .. Teams.PERK_LEVEL), FontFace = FONT.title, TextSize = 13, TextColor3 = have and COL.win or COL.dim, TextXAlignment = Enum.TextXAlignment.Right })
	end
	label(r, { Position = UDim2.fromOffset(16, 324), Size = UDim2.fromOffset(450, 22), Text = "TRAINING CAMP", FontFace = FONT.title, TextSize = 18, TextColor3 = COL.teal })
	label(r, { Position = UDim2.fromOffset(16, 348), Size = UDim2.fromOffset(450, 40), Text = string.format("A week of extra work on your focus (%s): +70 progress. Costs %d from your bank (you have %d). Paid from your salary.", Teams.ATTR_NAMES[career.focus], CAMP_COST, career.money), TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local camp = bigButton(r, career.money >= CAMP_COST and "BOOK TRAINING CAMP" or "NOT ENOUGH MONEY", UDim2.fromOffset(16, 400), UDim2.fromOffset(300, 48), function()
		if career.money >= CAMP_COST then
			remote:FireServer("career_camp", {})
		else
			Menu.toast("Play more matches to earn your salary")
		end
	end)
	camp.AutoButtonColor = false
end

---------------------------------------------------------------- LEAGUE

local function leagueTab(body, career)
	local tbl = panel(body, 0, 0, 560, 476)
	Menu.title(tbl, Teams.LEAGUE .. "   ·   SEASON " .. career.season, 24)
	local headers = { { "#", 14 }, { "CLUB", 50 }, { "P", 300 }, { "W", 344 }, { "L", 388 }, { "+/-", 428 }, { "PTS", 492 } }
	for _, h in headers do
		label(tbl, { Position = UDim2.fromOffset(h[2], 44), Size = UDim2.fromOffset(50, 18), Text = h[1], FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim })
	end
	for position, id in standings(career.table) do
		local y = 66 + (position - 1) * 33
		local row = career.table[id]
		local mine = id == career.club
		frame({ Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(544, 30), BackgroundColor3 = mine and COL.lime or (position <= 4 and COL.teal or COL.panelHi), BackgroundTransparency = mine and 0.75 or (position <= 4 and 0.85 or (position % 2 == 0 and 0.8 or 0.92)) }, tbl)
		local color = mine and COL.lime or COL.text
		label(tbl, { Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(30, 30), Text = tostring(position), FontFace = FONT.num, TextSize = 16, TextColor3 = color })
		local dot = frame({ Position = UDim2.fromOffset(50, y + 9), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Teams.list[id].primary }, tbl)
		round(dot, 6)
		label(tbl, { Position = UDim2.fromOffset(70, y), Size = UDim2.fromOffset(220, 30), Text = Teams.list[id].name, FontFace = FONT.title, TextSize = 14, TextColor3 = color })
		for k, value in { row.p, row.w, row.l, row.sf - row.sa, row.pts } do
			label(tbl, { Position = UDim2.fromOffset(({ 300, 344, 388, 428, 492 })[k], y), Size = UDim2.fromOffset(50, 30), Text = tostring(value), FontFace = FONT.num, TextSize = 16, TextColor3 = color })
		end
	end
	label(tbl, { Position = UDim2.fromOffset(14, 466 - 12), Size = UDim2.fromOffset(530, 16), Text = "Top four (highlighted) go to the playoffs.", TextSize = 12, TextColor3 = COL.dim })

	local f = panel(body, 572, 0, 564, 476)
	Menu.title(f, "FIXTURES AND RESULTS", 24)
	local results = {}
	for _, r in career.results or {} do
		if r.phase == "league" then
			results[r.round] = r
		end
	end
	for round = 1, ROUNDS do
		local y = 46 + (round - 1) * 30
		local opp = opponentFor(career.club, round)
		local r = results[round]
		local current = career.phase == "league" and round == career.round
		frame({ Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(548, 27), BackgroundColor3 = current and COL.violet or COL.panelHi, BackgroundTransparency = current and 0.5 or (round % 2 == 0 and 0.8 or 0.92) }, f)
		label(f, { Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(60, 27), Text = "R" .. round, FontFace = FONT.title, TextSize = 14, TextColor3 = COL.dim })
		label(f, { Position = UDim2.fromOffset(64, y), Size = UDim2.fromOffset(240, 27), Text = Teams.list[opp].name, FontFace = FONT.title, TextSize = 14 })
		if r then
			label(f, { Position = UDim2.fromOffset(300, y), Size = UDim2.fromOffset(140, 27), Text = (r.won and "W  " or "L  ") .. r.score, FontFace = FONT.title, TextSize = 14, TextColor3 = r.won and COL.win or COL.coral })
			local box = frame({ Position = UDim2.fromOffset(490, y + 3), Size = UDim2.fromOffset(52, 21), BackgroundColor3 = rateColor(r.rating) }, f)
			text({ Size = UDim2.fromScale(1, 1), Text = string.format("%.1f", r.rating), FontFace = FONT.num, TextSize = 15, TextColor3 = COL.ink }, box)
		else
			label(f, { Position = UDim2.fromOffset(300, y), Size = UDim2.fromOffset(240, 27), Text = current and "NEXT" or "", FontFace = FONT.title, TextSize = 14, TextColor3 = COL.teal })
		end
	end
	-- playoffs
	local y = 46 + ROUNDS * 30 + 8
	if career.playoff then
		local p = career.playoff
		local function name(id)
			return id and Teams.list[id].short or "?"
		end
		local semis = p.semis or {}
		local line = string.format("PLAYOFFS:  %s v %s  ·  %s v %s", name(semis[1] and semis[1][1]), name(semis[1] and semis[1][2]), name(semis[2] and semis[2][1]), name(semis[2] and semis[2][2]))
		label(f, { Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(530, 20), Text = line, FontFace = FONT.title, TextSize = 14, TextColor3 = COL.coral })
		local final = (p.winners and p.winners[1] and p.winners[2]) and ("FINAL:  " .. name(p.winners[1]) .. " v " .. name(p.winners[2])) or "FINAL:  to be decided"
		label(f, { Position = UDim2.fromOffset(16, y + 22), Size = UDim2.fromOffset(530, 20), Text = final, FontFace = FONT.title, TextSize = 14, TextColor3 = COL.gold })
	else
		label(f, { Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(530, 40), Text = "After round " .. ROUNDS .. ": semi-finals (1st v 4th, 2nd v 3rd) and a final, each best of three.", TextSize = 14, TextColor3 = COL.dim, TextWrapped = true })
	end
end

---------------------------------------------------------------- INBOX

local function inboxTab(body, career)
	local p = panel(body, 0, 0, 1136, 476)
	Menu.title(p, "INBOX", 26)
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COL.line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, p)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	if #career.inbox == 0 then
		label(list, { Size = UDim2.new(1, 0, 0, 30), Text = "No messages yet.", TextColor3 = COL.dim, TextSize = 16 })
	end
	for i, item in career.inbox do
		local isOffer = item.offer ~= nil and not item.answered
		local row = frame({ Size = UDim2.new(1, -10, 0, isOffer and 84 or 62), BackgroundColor3 = item.read and COL.bg2 or COL.panelHi, BackgroundTransparency = item.read and 0.5 or 0.2, LayoutOrder = i }, list)
		local color = KIND_COLORS[item.kind] or COL.teal
		frame({ Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = color }, row)
		label(row, { Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(120, 18), Text = string.upper(item.kind or "NEWS") .. "  ·  S" .. (item.season or 1) .. " R" .. (item.round or 1), FontFace = FONT.title, TextSize = 12, TextColor3 = color })
		label(row, { Position = UDim2.fromOffset(150, 6), Size = UDim2.new(1, -170, 0, 22), Text = item.title, FontFace = FONT.title, TextSize = 17 })
		label(row, { Position = UDim2.fromOffset(150, 30), Size = UDim2.new(1, -170, 0, 28), Text = item.body, TextSize = 14, TextColor3 = COL.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		if item.offer and item.answered then
			label(row, { Position = UDim2.new(1, -150, 0, 6), Size = UDim2.fromOffset(130, 18), Text = item.result or "", FontFace = FONT.title, TextSize = 13, TextColor3 = item.result == "ACCEPTED" and COL.win or COL.dim, TextXAlignment = Enum.TextXAlignment.Right })
		end
		if isOffer then
			for k, word in { "ACCEPT", "DECLINE" } do
				local b = button({ Position = UDim2.fromOffset(150 + (k - 1) * 130, 52), Size = UDim2.fromOffset(120, 26), BackgroundTransparency = 0, BackgroundColor3 = k == 1 and COL.win or COL.panel }, row)
				text({ Size = UDim2.fromScale(1, 1), Text = word, FontFace = FONT.title, TextSize = 14, TextColor3 = k == 1 and COL.ink or COL.text }, b)
				b.Activated:Connect(function()
					remote:FireServer("career_offer", { id = item.offer.id, accept = k == 1 })
				end)
			end
		end
	end
	if unread(career) > 0 then
		remote:FireServer("career_read", {})
	end
end

---------------------------------------------------------------- HISTORY

local function historyTab(body, career)
	local l = panel(body, 0, 0, 420, 476)
	Menu.title(l, "CAREER TOTALS", 26)
	local st = career.stats
	local rows = {
		{ "Seasons", tostring(#career.history) },
		{ "Matches", tostring(st.matches) },
		{ "Wins", tostring(st.wins) },
		{ "Kills", tostring(st.kills) },
		{ "Aces", tostring(st.aces) },
		{ "Blocks", tostring(st.blocks) },
		{ "Digs", tostring(st.digs) },
		{ "Trophies", tostring(career.trophies) },
	}
	for i, row in rows do
		local y = 46 + (i - 1) * 30
		frame({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(396, 27), BackgroundColor3 = COL.panelHi, BackgroundTransparency = i % 2 == 0 and 0.75 or 0.9 }, l)
		label(l, { Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(200, 27), Text = row[1], TextSize = 15 })
		label(l, { Position = UDim2.fromOffset(200, y), Size = UDim2.fromOffset(196, 27), Text = row[2], FontFace = FONT.num, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right })
	end
	label(l, { Position = UDim2.fromOffset(16, 300), Size = UDim2.fromOffset(390, 22), Text = "AWARDS", FontFace = FONT.title, TextSize = 18, TextColor3 = COL.gold })
	if #career.awards == 0 then
		label(l, { Position = UDim2.fromOffset(16, 326), Size = UDim2.fromOffset(390, 22), Text = "None yet. Titles, Team of the Season and more go here.", TextSize = 14, TextColor3 = COL.dim })
	end
	for i, award in career.awards do
		if i > 5 then
			break
		end
		label(l, { Position = UDim2.fromOffset(16, 326 + (i - 1) * 26), Size = UDim2.fromOffset(390, 22), Text = "★  " .. award.name .. "   ·   SEASON " .. award.season, FontFace = FONT.title, TextSize = 14 })
	end

	local r = panel(body, 432, 0, 704, 476)
	Menu.title(r, "SEASON BY SEASON", 26)
	local headers = { { "SEASON", 16 }, { "CLUB", 96 }, { "POS", 330 }, { "P", 384 }, { "W", 430 }, { "K", 476 }, { "B", 522 }, { "AVG", 566 }, { "OVR", 630 } }
	for _, h in headers do
		label(r, { Position = UDim2.fromOffset(h[2], 46), Size = UDim2.fromOffset(70, 18), Text = h[1], FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim })
	end
	if #career.history == 0 then
		label(r, { Position = UDim2.fromOffset(16, 76), Size = UDim2.fromOffset(660, 22), Text = "Your first season is under way.", TextSize = 15, TextColor3 = COL.dim })
	end
	for i, h in career.history do
		local y = 70 + (i - 1) * 32
		if y > 440 then
			break
		end
		frame({ Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(688, 29), BackgroundColor3 = h.champion and COL.gold or COL.panelHi, BackgroundTransparency = h.champion and 0.75 or (i % 2 == 0 and 0.8 or 0.92) }, r)
		local values = { tostring(h.season), Teams.list[h.club].name .. (h.champion and "  ★" or ""), ordinal(h.position), tostring(h.matches), tostring(h.wins), tostring(h.kills), tostring(h.blocks), string.format("%.1f", h.avg or 0), tostring(h.ovr or "") }
		for k, value in values do
			label(r, { Position = UDim2.fromOffset(headers[k][2], y), Size = UDim2.fromOffset(k == 2 and 230 or 60, 29), Text = value, FontFace = k == 2 and FONT.title or FONT.num, TextSize = 14 })
		end
	end
end

---------------------------------------------------------------- the hub and the match report

function Menu.refreshCareer()
	local career = profile and profile.career
	if not career then
		return
	end
	local def = Teams.list[career.club]
	Menu.chSub.Text = string.format("%s   ·   SEASON %d   ·   %s   ·   %d TROPH%s", def.name, career.season, phaseLabel(career), career.trophies, career.trophies == 1 and "Y" or "IES")
	Menu.chSaving.Text = savingOk and "" or "Progress isn't being saved here (in Studio, turn on API access in Game Settings)."
	Menu.chTabs:ClearAllChildren()
	local names = table.clone(CAREER_TABS)
	if unread(career) > 0 then
		names[4] = "INBOX (" .. unread(career) .. ")"
	end
	Menu.tabs(Menu.chTabs, UDim2.new(), names, Menu.careerTab, function(i)
		Menu.careerTab = i
		Menu.refreshCareer()
	end, 150)
	local body = Menu.chBody
	body:ClearAllChildren()
	local builders = { overviewTab, trainingTab, leagueTab, inboxTab, historyTab }
	builders[Menu.careerTab](body, career)
end
Menu.onShow.career = function()
	Menu.refreshCareer()
	if Menu.pendingReport then
		Menu.showReport(Menu.pendingReport)
		Menu.pendingReport = nil
	end
end

-- after a career match: rating, stats, XP and progress
do
	local shade = button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.45, BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 25 }, board)
	local reportPanel = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 470), BackgroundColor3 = COL.bg2, ZIndex = 26 }, shade)
	outline(reportPanel, COL.line, 1, 0.3)
	frame({ Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = COL.teal, ZIndex = 27 }, reportPanel)
	Menu.reportBody = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 27 }, reportPanel)
	Menu.reportShade = shade
end

function Menu.showReport(r)
	local body = Menu.reportBody
	body:ClearAllChildren()
	local career = profile and profile.career
	text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(400, 34), Text = "MATCH REPORT", FontFace = FONT.body, TextSize = 30, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left }, body)
	text({ Position = UDim2.fromOffset(24, 52), Size = UDim2.fromOffset(420, 26), Text = (r.won and "WIN  " or "DEFEAT  ") .. r.score .. "  v  " .. Teams.list[r.opponent].name, FontFace = FONT.title, TextSize = 20, TextColor3 = r.won and COL.win or COL.coral, TextXAlignment = Enum.TextXAlignment.Left }, body)
	local rate = frame({ Position = UDim2.fromOffset(500, 18), Size = UDim2.fromOffset(116, 92), BackgroundColor3 = rateColor(r.rating or 6) }, body)
	text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 60), Text = string.format("%.1f", r.rating or 6), FontFace = FONT.num, TextSize = 52, TextColor3 = COL.ink }, rate)
	text({ Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 20), Text = "RATING", FontFace = FONT.title, TextSize = 14, TextColor3 = COL.ink }, rate)
	local stats = r.stats or {}
	for i, s in { { "KILLS", stats.kills }, { "ACES", stats.aces }, { "BLOCKS", stats.blocks }, { "DIGS", stats.digs } } do
		local x = 24 + (i - 1) * 118
		local box = frame({ Position = UDim2.fromOffset(x, 128), Size = UDim2.fromOffset(108, 74), BackgroundColor3 = COL.panelHi, BackgroundTransparency = 0.4 }, body)
		text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 40), Text = tostring(s[2] or 0), FontFace = FONT.num, TextSize = 34 }, box)
		text({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 18), Text = s[1], FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim }, box)
	end
	local lines = {
		"+" .. r.xp .. " XP" .. ((r.levels or 0) > 0 and ("   ·   LEVEL UP! +" .. (3 * r.levels) .. " TRAINING POINTS") or ""),
		r.focus and (Teams.ATTR_NAMES[r.focus] .. " training" .. ((r.focusGain or 0) > 0 and ("   ·   " .. r.focus .. " " .. r.focusFrom .. " → " .. (r.focusFrom + r.focusGain) .. "!") or ("   ·   progress " .. math.floor(career and career.progress[r.focus] or 0) .. "%"))) or "",
		"+" .. (r.money or 0) .. " salary" .. (r.won and " (and a win bonus)" or ""),
	}
	if r.seasonOver then
		table.insert(lines, r.champion == (career and career.history[#career.history] and career.history[#career.history].club) and "SEASON OVER: CHAMPIONS!" or ("SEASON OVER: " .. Teams.list[r.champion].name .. " are champions. Check your inbox for offers."))
	end
	for i, line in lines do
		text({ Position = UDim2.fromOffset(24, 222 + (i - 1) * 32), Size = UDim2.fromOffset(592, 28), Text = line, FontFace = FONT.title, TextSize = 17, TextColor3 = i == 4 and COL.gold or COL.text, TextXAlignment = Enum.TextXAlignment.Left }, body)
	end
	local done = primaryButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -18), Size = UDim2.fromOffset(170, 44) }, body, "CONTINUE", 18)
	done.Activated:Connect(function()
		Menu.reportShade.Visible = false
	end)
	for _, d in body:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 28
		end
	end
	Menu.reportShade.Visible = true
end

function Menu.openCareer()
	if not profile then
		Menu.toast("Loading your profile...")
		remote:FireServer("profile", {})
		return
	end
	if profile.career then
		Menu.careerTab = 1
		Menu.show("career")
	else
		newCareer.club = sel.home
		Menu.show("career_new")
	end
end

---------------------------------------------------------------- online seasons

do
	local screenFrame = Menu.screen("onlinehub")
	header(screenFrame, "ONLINE SEASONS", "RANKED 6V6 AGAINST OTHER PLAYERS IN THIS SERVER   ·   WIN TO CLIMB FROM DIVISION 10 TO 1")
	Menu.ohDivision = panel(screenFrame, 120, 124, 460, 440)
	Menu.ohSearch = panel(screenFrame, 700, 124, 460, 440)
	Menu.hints(screenFrame, { { "BACK", "Back", function()
		if Menu.queued then
			remote:FireServer("online_cancel", {})
		end
		Menu.back()
	end } }, UDim2.fromOffset(120, 600))
end

function Menu.refreshOnline()
	local online = profile and profile.online or { division = 10, points = 0, wins = 0, losses = 0 }
	local d = Menu.ohDivision
	d:ClearAllChildren()
	outline(d, COL.line, 1, 0.65)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = "YOUR DIVISION", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, d)
	local disc = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(230, 56), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = Color3.new(1, 1, 1) }, d)
	round(disc, 75)
	gradient(disc, COL.violet, COL.teal, 45)
	text({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 70), Text = tostring(online.division), FontFace = FONT.num, TextSize = 70, TextColor3 = COL.ink }, disc)
	text({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 18), Text = online.division == 1 and "ELITE" or "DIVISION", FontFace = FONT.title, TextSize = 15, TextColor3 = COL.ink }, disc)
	text({ Position = UDim2.fromOffset(0, 222), Size = UDim2.new(1, 0, 0, 22), Text = online.division > 1 and (online.points .. " / 9 POINTS TO PROMOTION") or (online.points .. " POINTS IN THE ELITE DIVISION"), FontFace = FONT.title, TextSize = 18 }, d)
	local back = frame({ Position = UDim2.fromOffset(60, 254), Size = UDim2.fromOffset(340, 10), BackgroundColor3 = COL.bg2 }, d)
	frame({ Size = UDim2.fromScale(math.clamp(online.points / 9, 0, 1), 1), BackgroundColor3 = COL.teal }, back)
	text({ Position = UDim2.fromOffset(0, 284), Size = UDim2.new(1, 0, 0, 24), Text = "WON " .. online.wins .. "   ·   LOST " .. online.losses, FontFace = FONT.head, TextSize = 19 }, d)
	text({ Position = UDim2.fromOffset(30, 330), Size = UDim2.fromOffset(400, 90), Text = "A win is worth 3 points, a loss costs 1. Nine points takes you up a division; losing with none left drops you down.", FontFace = FONT.head, TextSize = 15, TextWrapped = true, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, d)

	local s = Menu.ohSearch
	s:ClearAllChildren()
	outline(s, COL.line, 1, 0.65)
	text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(300, 24), Text = "PLAY AS", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, s)
	badge(s, onlineClub, 110, UDim2.fromOffset(230, 52), Vector2.new(0.5, 0))
	if not Menu.queued then
		arrows(s, 107, 60, 400, function(step)
			onlineClub = (onlineClub - 1 + step) % #Teams.list + 1
			Menu.refreshOnline()
		end)
	end
	text({ Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 0, 30), Text = Teams.list[onlineClub].name, FontFace = FONT.title, TextSize = 26 }, s)
	starRow(s, Teams.stars(Teams.ratings(onlineClub).OVR), 22, UDim2.fromOffset(230, 210), Vector2.new(0.5, 0))
	local label = Menu.queued and "CANCEL SEARCH" or "FIND MATCH  ▸"
	bigButton(s, label, UDim2.fromOffset(84, 260), UDim2.fromOffset(292, 54), function()
		if Menu.queued then
			remote:FireServer("online_cancel", {})
		else
			remote:FireServer("start", { mode = "online", club = onlineClub, plan = onlineClub == sel.home and sel.plan or nil })
			Menu.queued = true
			Menu.refreshOnline()
		end
	end)
	local status = Menu.queued and ("SEARCHING FOR AN OPPONENT...   " .. queueCount .. " IN THE QUEUE") or (#Players:GetPlayers() > 1 and "Other players are in this server." or "You're the only player here: invite a friend to play online.")
	text({ Position = UDim2.fromOffset(20, 330), Size = UDim2.fromOffset(420, 40), Text = status, FontFace = FONT.head, TextSize = 16, TextWrapped = true, TextColor3 = Menu.queued and COL.teal or COL.dim }, s)
end
Menu.onShow.onlinehub = Menu.refreshOnline

function Menu.openOnline()
	onlineClub = sel.home
	Menu.show("onlinehub")
end

---------------------------------------------------------------- your profile on the front screens

function Menu.refreshProfileCard()
	local body = Menu.profileBody
	if not body then
		return
	end
	body:ClearAllChildren()
	text({ Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(156, 18), Text = "WELCOME BACK", FontFace = FONT.title, TextSize = 13, TextColor3 = COL.teal, TextXAlignment = Enum.TextXAlignment.Left }, body)
	text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.fromOffset(156, 24), Text = string.upper(player.DisplayName), FontFace = FONT.title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, body)
	shirt(body, Teams.list[sel.home].primary, Menu.custom.number, 56, UDim2.fromOffset(140, 30))
	local career = profile and profile.career
	local online = profile and profile.online
	local wins, losses = 0, 0
	for _, h in history do
		if h.mine == h.winner then
			wins += 1
		else
			losses += 1
		end
	end
	local rows = {
		{ "CAREER", career and (Teams.list[career.club].short .. "  ·  OVR " .. career.ovr) or "Not started" },
		{ "", career and ("Season " .. career.season .. "  ·  " .. (career.phase == "league" and ("Round " .. career.round) or "Playoffs")) or "" },
		{ "ONLINE", online and ("Division " .. online.division .. "  ·  " .. online.points .. " pts") or "Division 10" },
		{ "", online and (online.wins .. "W  " .. online.losses .. "L") or "" },
		{ "THIS SESSION", wins .. "W  " .. losses .. "L" },
		{ "POSITION", Teams.ROLES[Menu.custom.role] },
	}
	local y = 70
	for _, row in rows do
		if row[1] ~= "" then
			y += 8
			text({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(156, 16), Text = row[1], FontFace = FONT.title, TextSize = 12, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, body)
			y += 16
		end
		text({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(156, 20), Text = row[2], FontFace = FONT.head, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, body)
		y += 20
	end
	-- the career and online tiles on HOME show where you are
	if Menu.careerInfo then
		Menu.careerInfo.Text = career and (Teams.list[career.club].name .. "\nSEASON " .. career.season .. "  ·  OVR " .. career.ovr) or "Create your pro"
	end
end

---------------------------------------------------------------- messages for these screens

remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "profile" then
		profile = a
		savingOk = b ~= false
		if inMenu and Menu.profileCard and Menu.profileCard.Visible then
			Menu.refreshProfileCard()
		end
		if inMenu then
			if Menu.current == "career_new" and profile.career then
				Menu.show("career", false)
			elseif Menu.current == "career" and not profile.career then
				Menu.show("home", false)
			elseif Menu.current == "career" or Menu.current == "onlinehub" then
				Menu.onShow[Menu.current]()
			end
		end
	elseif kind == "career_result" then
		-- the match report shows when you're back in the career hub
		if inMenu and Menu.current == "career" then
			Menu.showReport(a)
		else
			Menu.pendingReport = a
		end
	elseif kind == "online_queue" then
		Menu.queued = a == true
		queueCount = b or 0
		if inMenu and Menu.current == "onlinehub" then
			Menu.refreshOnline()
		end
	elseif kind == "online_result" then
		task.delay(0.6, function()
			Menu.toast(string.format("%s   ·   DIVISION %d   ·   %d POINTS", a and "WIN +3" or "DEFEAT -1", b or 10, c or 0))
		end)
	end
end)
remote:FireServer("profile", {})
