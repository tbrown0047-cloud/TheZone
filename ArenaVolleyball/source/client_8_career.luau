
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

do
	local screenFrame = Menu.screen("career")
	Menu.chSub = header(screenFrame, "CAREER", "")
	Menu.chCard = panel(screenFrame, 72, 110, 372, 510)
	Menu.chNext = panel(screenFrame, 456, 110, 372, 510)
	Menu.chTable = panel(screenFrame, 840, 110, 372, 510)
	Menu.chSaving = text({ Position = UDim2.fromOffset(456, 630), Size = UDim2.fromOffset(760, 20), FontFace = FONT.head, TextSize = 14, TextColor3 = COL.coral, TextXAlignment = Enum.TextXAlignment.Right }, screenFrame)
	Menu.hints(screenFrame, {
		{ "BACK", "Back", Menu.back },
		{ "R", "Retire (press twice)", function()
			Menu.retire()
		end },
	}, UDim2.fromOffset(72, 630))
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

function Menu.refreshCareer()
	local career = profile and profile.career
	if not career then
		return
	end
	local def = Teams.list[career.club]
	Menu.chSub.Text = string.format("SEASON %d   ·   ROUND %d OF %d   ·   %d TROPH%s", career.season, career.round, ROUNDS, career.trophies, career.trophies == 1 and "Y" or "IES")
	Menu.chSaving.Text = savingOk and "" or "Progress isn't being saved here (in Studio, turn on API access in Game Settings)."

	-- your player
	local c = Menu.chCard
	c:ClearAllChildren()
	outline(c, COL.line, 1, 0.65)
	shirt(c, def.primary, career.number, 70, UDim2.fromOffset(60, 60))
	text({ Position = UDim2.fromOffset(110, 18), Size = UDim2.fromOffset(150, 28), Text = career.role, FontFace = FONT.num, TextSize = 24, TextColor3 = COL.cyan, TextXAlignment = Enum.TextXAlignment.Left }, c)
	text({ Position = UDim2.fromOffset(110, 44), Size = UDim2.fromOffset(250, 22), Text = string.upper(player.DisplayName), FontFace = FONT.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left }, c)
	text({ Position = UDim2.fromOffset(110, 66), Size = UDim2.fromOffset(250, 20), Text = def.name, FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, c)
	local ovrBox = frame({ Position = UDim2.fromOffset(290, 16), Size = UDim2.fromOffset(66, 60), BackgroundColor3 = ratingColor(career.ovr) }, c)
	round(ovrBox, 4)
	text({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 38), Text = tostring(career.ovr), FontFace = FONT.num, TextSize = 34, TextColor3 = COL.ink }, ovrBox)
	text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 14), Text = "OVR", FontFace = FONT.title, TextSize = 12, TextColor3 = COL.ink }, ovrBox)
	local need = 100 * career.level
	text({ Position = UDim2.fromOffset(20, 104), Size = UDim2.fromOffset(200, 20), Text = "LEVEL " .. career.level, FontFace = FONT.title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, c)
	text({ Position = UDim2.fromOffset(150, 104), Size = UDim2.fromOffset(200, 20), Text = career.xp .. " / " .. need .. " XP", FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Right }, c)
	local xpBack = frame({ Position = UDim2.fromOffset(20, 128), Size = UDim2.fromOffset(332, 8), BackgroundColor3 = COL.bg2 }, c)
	frame({ Size = UDim2.fromScale(math.clamp(career.xp / need, 0, 1), 1), BackgroundColor3 = COL.teal }, xpBack)
	text({ Position = UDim2.fromOffset(20, 148), Size = UDim2.fromOffset(332, 22), Text = career.points > 0 and ("TRAINING: " .. career.points .. " POINT" .. (career.points == 1 and "" or "S") .. " TO SPEND") or "TRAINING: LEVEL UP TO EARN POINTS", FontFace = FONT.title, TextSize = 16, TextColor3 = career.points > 0 and COL.lime or COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, c)
	for i, attr in Teams.ATTRS do
		local y = 180 + (i - 1) * 40
		local v = career.attrs[attr]
		text({ Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(110, 30), Text = Teams.ATTR_NAMES[attr], FontFace = FONT.head, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left }, c)
		local back = frame({ Position = UDim2.fromOffset(130, y + 11), Size = UDim2.fromOffset(150, 8), BackgroundColor3 = COL.bg2 }, c)
		frame({ Size = UDim2.fromScale(v / 100, 1), BackgroundColor3 = ratingColor(v) }, back)
		text({ Position = UDim2.fromOffset(284, y), Size = UDim2.fromOffset(32, 30), Text = tostring(v), FontFace = FONT.num, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Right }, c)
		if career.points > 0 and v < 99 then
			local plus = button({ Position = UDim2.fromOffset(322, y + 2), Size = UDim2.fromOffset(30, 26), BackgroundTransparency = 0, BackgroundColor3 = COL.lime }, c)
			round(plus, 4)
			text({ Size = UDim2.fromScale(1, 1), Text = "+", FontFace = FONT.title, TextSize = 20, TextColor3 = COL.ink }, plus)
			plus.Activated:Connect(function()
				remote:FireServer("career_train", { attr = attr })
			end)
		end
	end
	local st = career.stats
	text({ Position = UDim2.fromOffset(20, 428), Size = UDim2.fromOffset(332, 60), Text = string.format("MATCHES %d   WINS %d\nKILLS %d   ACES %d   BLOCKS %d   DIGS %d", st.matches, st.wins, st.kills, st.aces, st.blocks, st.digs), FontFace = FONT.head, TextSize = 15, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, c)

	-- next match
	local n = Menu.chNext
	n:ClearAllChildren()
	outline(n, COL.line, 1, 0.65)
	local opp = opponentFor(career.club, career.round)
	Menu.title(n, "NEXT MATCH", 30)
	text({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 20), Text = "ROUND " .. career.round .. " OF " .. ROUNDS .. "   ·   " .. os.date("%d %B"), FontFace = FONT.head, TextSize = 15 }, n)
	for i, id in { career.club, opp } do
		local x = i == 1 and 96 or 276
		local r = Teams.ratings(id)
		badge(n, id, 92, UDim2.fromOffset(x, 92), Vector2.new(0.5, 0))
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 192), Size = UDim2.fromOffset(170, 20), Text = Teams.list[id].name, FontFace = FONT.title, TextSize = 15 }, n)
		starRow(n, Teams.stars(r.OVR), 16, UDim2.fromOffset(x, 216), Vector2.new(0.5, 0))
		text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, 236), Size = UDim2.fromOffset(170, 18), Text = "OVR " .. r.OVR .. "   ·   " .. ordinal(table.find(standings(career.table), id) or 12), FontFace = FONT.head, TextSize = 14, TextColor3 = COL.dim }, n)
	end
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(186, 138), Size = UDim2.fromOffset(60, 40), Text = "V", FontFace = FONT.num, TextSize = 34, TextColor3 = COL.dim }, n)
	bigButton(n, "PLAY MATCH  ▸", UDim2.fromOffset(40, 276), UDim2.fromOffset(292, 54), function()
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
	end)
	local last = career.last
	if last then
		local line = string.format("LAST: %s %s v %s   ·   +%d XP", last.won and "WON" or "LOST", last.score, Teams.list[last.opponent].short, last.xp)
		text({ Position = UDim2.fromOffset(20, 350), Size = UDim2.fromOffset(332, 22), Text = line, FontFace = FONT.title, TextSize = 16, TextColor3 = last.won and COL.win or COL.coral }, n)
		if last.levels and last.levels > 0 then
			text({ Position = UDim2.fromOffset(20, 374), Size = UDim2.fromOffset(332, 20), Text = "LEVEL UP!  +" .. (3 * last.levels) .. " TRAINING POINTS", FontFace = FONT.title, TextSize = 15, TextColor3 = COL.lime }, n)
		end
		if last.champion then
			text({ Position = UDim2.fromOffset(20, 400), Size = UDim2.fromOffset(332, 44), Text = last.champion == career.club and "CHAMPIONS! The trophy is yours." or ("Season over: you finished " .. ordinal(last.position or 12) .. ". Champions: " .. Teams.list[last.champion].name), FontFace = FONT.head, TextSize = 15, TextWrapped = true, TextColor3 = COL.gold }, n)
		end
	end
	text({ Position = UDim2.fromOffset(20, 452), Size = UDim2.fromOffset(332, 46), Text = "You play as " .. ROLE_WORDS[career.role] .. ". XP comes from playing, winning and your kills, aces, blocks and digs.", FontFace = FONT.head, TextSize = 14, TextWrapped = true, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, n)

	-- league table
	local tbl = Menu.chTable
	tbl:ClearAllChildren()
	outline(tbl, COL.line, 1, 0.65)
	Menu.title(tbl, Teams.LEAGUE, 26)
	local headers = { { "#", 14 }, { "CLUB", 44 }, { "P", 214 }, { "W", 250 }, { "L", 286 }, { "PTS", 322 } }
	for _, h in headers do
		text({ Position = UDim2.fromOffset(h[2], 48), Size = UDim2.fromOffset(40, 18), Text = h[1], FontFace = FONT.title, TextSize = 13, TextColor3 = COL.dim, TextXAlignment = Enum.TextXAlignment.Left }, tbl)
	end
	for position, id in standings(career.table) do
		local y = 70 + (position - 1) * 36
		local row = career.table[id]
		local mine = id == career.club
		frame({ Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(356, 32), BackgroundColor3 = mine and COL.lime or COL.panelHi, BackgroundTransparency = mine and 0.75 or (position % 2 == 0 and 0.75 or 0.9) }, tbl)
		local color = mine and COL.lime or COL.text
		text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(30, 32), Text = tostring(position), FontFace = FONT.num, TextSize = 17, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }, tbl)
		local dot = frame({ Position = UDim2.fromOffset(44, y + 10), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Teams.list[id].primary }, tbl)
		round(dot, 6)
		text({ Position = UDim2.fromOffset(62, y), Size = UDim2.fromOffset(150, 32), Text = Teams.list[id].name, FontFace = FONT.title, TextSize = 14, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }, tbl)
		for k, value in { row.p, row.w, row.l, row.pts } do
			text({ Position = UDim2.fromOffset(({ 214, 250, 286, 322 })[k], y), Size = UDim2.fromOffset(36, 32), Text = tostring(value), FontFace = FONT.num, TextSize = 17, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left }, tbl)
		end
	end
end
Menu.onShow.career = Menu.refreshCareer

function Menu.openCareer()
	if not profile then
		Menu.toast("Loading your profile...")
		remote:FireServer("profile", {})
		return
	end
	if profile.career then
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

---------------------------------------------------------------- messages for these screens

remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "profile" then
		profile = a
		savingOk = b ~= false
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
		local r = a
		local message = string.format("%s %s v %s   ·   +%d XP", r.won and "WIN" or "DEFEAT", r.score, Teams.list[r.opponent].short, r.xp)
		if r.levels and r.levels > 0 then
			message ..= "   ·   LEVEL UP!"
		end
		task.delay(0.6, function()
			Menu.toast(message)
		end)
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
