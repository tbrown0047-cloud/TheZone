
---------------------------------------------------------------- saved progress, career mode and online seasons

local DataStoreService = game:GetService("DataStoreService")

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("ArenaVolleyball_v1")
end)
local saving = store ~= nil -- turns false if saves fail (Studio without API access)
local profiles = {}
local ensureCareerLater -- set once the career code below is defined

local function storeFailed(err)
	if saving then
		saving = false
		warn("[Arena Volleyball] Progress can't be saved here (" .. tostring(err) .. "). In Studio, turn on Game Settings > Security > Enable Studio Access to API Services.")
	end
end

local function sendProfile(plr)
	if profiles[plr] then
		remote:FireClient(plr, "profile", profiles[plr], saving)
	end
end

local function saveProfile(plr)
	local data = profiles[plr]
	if not data or not store or not saving then
		return
	end
	local ok, err = pcall(store.SetAsync, store, "player_" .. plr.UserId, data)
	if not ok then
		storeFailed(err)
	end
end

local function loadProfile(plr)
	local data = nil
	if store and saving then
		local ok, result = pcall(store.GetAsync, store, "player_" .. plr.UserId)
		if ok then
			data = result
		else
			storeFailed(result)
		end
	end
	if type(data) ~= "table" then
		data = {}
	end
	data.version = 2
	data.online = data.online or { division = 10, points = 0, wins = 0, losses = 0 }
	data.custom = data.custom or { number = 7, role = "OH", wearKit = false, court = 1, kits = {} }
	if not plr.Parent then
		return
	end
	profiles[plr] = data
	pcall(ensureCareerLater, data.career)
	sendProfile(plr)
end

---------------------------------------------------------------- the league

local ROUNDS = math.clamp(math.floor(Config.SEASON_ROUNDS or 11), 1, #Teams.list - 1)

-- Round-robin pairings for a round (circle method)
local function pairings(round)
	local count = #Teams.list
	local order = { 1 }
	for k = 1, count - 1 do
		order[k + 1] = 2 + ((k - 1 + round - 1) % (count - 1))
	end
	local list = {}
	for i = 1, count // 2 do
		table.insert(list, { order[i], order[count + 1 - i] })
	end
	return list
end

local function opponentFor(club, round)
	for _, pair in pairings(round) do
		if pair[1] == club then
			return pair[2]
		elseif pair[2] == club then
			return pair[1]
		end
	end
	return club % #Teams.list + 1
end

local function freshTable()
	local t = {}
	for i = 1, #Teams.list do
		t[i] = { p = 0, w = 0, l = 0, pts = 0, sf = 0, sa = 0 }
	end
	return t
end

local function record(tableRows, home, away, homeScore, awayScore)
	local h, a = tableRows[home], tableRows[away]
	h.p += 1
	a.p += 1
	h.sf += homeScore
	h.sa += awayScore
	a.sf += awayScore
	a.sa += homeScore
	if homeScore > awayScore then
		h.w += 1
		a.l += 1
		h.pts += 3
	else
		a.w += 1
		h.l += 1
		a.pts += 3
	end
end

-- A match between two AI clubs: the better side usually wins
local function simulate(home, away)
	local diff = Teams.ratings(home).OVR - Teams.ratings(away).OVR
	local homeWins = rng:NextNumber() < 1 / (1 + math.exp(-diff / 4))
	local loser = rng:NextInteger(12, 23)
	if homeWins then
		return 25, loser
	end
	return loser, 25
end

local function standings(tableRows)
	local order = {}
	for i = 1, #tableRows do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local x, y = tableRows[a], tableRows[b]
		if x.pts ~= y.pts then
			return x.pts > y.pts
		end
		return (x.sf - x.sa) > (y.sf - y.sa)
	end)
	return order
end

---------------------------------------------------------------- career

local Career = {} -- the career functions, kept together
-- A season: eleven league rounds, then the top four play semi-finals and a final.
-- Every match gives you a rating out of 10. Ratings build your form, XP levels you up
-- (training points), and your training focus slowly raises one attribute. Clubs send
-- offers when you play well; objectives, awards and the inbox tell the story.

Career.INBOX_MAX = 30
Career.FOCUS_ATTRS = { "SRV", "ATK", "BLK", "REC", "SET", "PHY" }
Career.STATUS_ORDER = { "ROTATION", "STARTER", "KEY PLAYER", "CAPTAIN" }

function Career.careerOverall(career)
	return Teams.overall(career.role, career.attrs)
end

function Career.news(career, title, body, kind, extra)
	career.newsId = (career.newsId or 0) + 1
	local item = { id = career.newsId, title = title, body = body, kind = kind or "news", season = career.season, round = career.round, read = false }
	if extra then
		for k, v in extra do
			item[k] = v
		end
	end
	table.insert(career.inbox, 1, item)
	while #career.inbox > Career.INBOX_MAX do
		table.remove(career.inbox)
	end
	return item
end

-- the starting six's average overall at a club
function Career.clubLevel(club)
	return Teams.ratings(club).OVR
end

function Career.averageForm(career)
	local total = 0
	for _, r in career.form do
		total += r
	end
	return #career.form > 0 and total / #career.form or 6
end

-- Where you stand at your club, from how good you are next to the team and your form
function Career.updateStatus(career, quiet)
	local diff = career.ovr - Career.clubLevel(career.club)
	local form = Career.averageForm(career)
	local status = "ROTATION"
	if diff >= 3 and form >= 7.4 and career.seasonsAtClub >= 1 then
		status = "CAPTAIN"
	elseif diff >= 1 or (diff >= -2 and form >= 7.2) then
		status = "KEY PLAYER"
	elseif diff >= -6 or form >= 6.5 then
		status = "STARTER"
	end
	if status ~= career.status then
		local up = (table.find(Career.STATUS_ORDER, status) or 1) > (table.find(Career.STATUS_ORDER, career.status) or 1)
		if not quiet then
			Career.news(career, up and ("You're now a " .. string.lower(status)) or ("Status: " .. string.lower(status)),
				up and "The coach has noticed your performances. Keep it up." or "The coach wants more from you. Good ratings will win your place back.",
				"status")
		end
		career.status = status
	end
end

-- This season's targets: the board's for the club, and your own
function Career.newObjectives(career)
	local rank = Teams.rank(career.club)
	local target, text
	if rank <= 3 then
		target, text = 1, "Win the league"
	elseif rank <= 6 then
		target, text = 4, "Finish in the top four (playoffs)"
	elseif rank <= 9 then
		target, text = 6, "Finish in the top six"
	else
		target, text = 8, "Finish in the top eight"
	end
	local personal
	local role = career.role
	if role == "OH" or role == "OPP" then
		personal = { { stat = "kills", target = 35, text = "Score 35 kills" }, { stat = "aces", target = 6, text = "Serve 6 aces" } }
	elseif role == "MB" then
		personal = { { stat = "blocks", target = 14, text = "Make 14 blocks" }, { stat = "kills", target = 18, text = "Score 18 kills" } }
	elseif role == "L" then
		personal = { { stat = "digs", target = 45, text = "Make 45 digs" }, { stat = "good", target = 5, text = "Rate 7.5+ in 5 matches" } }
	else
		personal = { { stat = "good", target = 5, text = "Rate 7.5+ in 5 matches" }, { stat = "wins", target = 7, text = "Win 7 matches" } }
	end
	for _, o in personal do
		o.progress, o.done = 0, false
	end
	career.objectives = { club = { target = target, text = text }, personal = personal }
end

function Career.freshSeason(career)
	career.round = 1
	career.phase = "league"
	career.table = freshTable()
	career.results = {}
	career.playoff = nil
	career.season_stats = { matches = 0, wins = 0, kills = 0, aces = 0, blocks = 0, digs = 0, ratings = 0 }
	Career.newObjectives(career)
end

-- Older saves get the new fields
function Career.ensureCareer(career)
	if not career then
		return
	end
	career.attrs = career.attrs or {}
	for _, attr in Teams.ATTRS do
		career.attrs[attr] = career.attrs[attr] or 60
	end
	career.progress = career.progress or {}
	for _, attr in Teams.ATTRS do
		career.progress[attr] = career.progress[attr] or 0
	end
	career.focus = table.find(Career.FOCUS_ATTRS, career.focus) and career.focus or "ATK"
	career.form = career.form or {}
	career.morale = career.morale or 70
	career.money = career.money or 0
	career.contract = career.contract or { years = 2, salary = 400 }
	career.inbox = career.inbox or {}
	career.history = career.history or {}
	career.awards = career.awards or {}
	career.offers = career.offers or {}
	career.seasonsAtClub = career.seasonsAtClub or 0
	career.stats = career.stats or { matches = 0, wins = 0, kills = 0, aces = 0, blocks = 0, digs = 0 }
	career.trophies = career.trophies or 0
	career.season = career.season or 1
	if not career.season_stats or not career.objectives or not career.table then
		Career.freshSeason(career)
	end
	career.round = career.round or 1
	career.phase = career.phase or "league"
	career.results = career.results or {}
	career.ovr = Career.careerOverall(career)
	career.perks = Teams.perksFor(career.attrs)
	career.status = career.status or "STARTER"
end

function Career.createCareer(plr, data)
	local profile = profiles[plr]
	if not profile then
		return
	end
	local club = math.clamp(math.floor(tonumber(data.club) or 1), 1, #Teams.list)
	local role = table.find(Teams.ROLE_ORDER, data.role) and data.role or "OH"
	local number = math.clamp(math.floor(tonumber(data.number) or 7), 1, 99)
	local attrs = {}
	for _, attr in Teams.ATTRS do
		attrs[attr] = math.clamp(60 + Teams.TEMPLATE[role][attr], 40, 95)
	end
	local career = {
		club = club,
		role = role,
		number = number,
		attrs = attrs,
		xp = 0,
		level = 1,
		points = 3,
		season = 1,
		trophies = 0,
		stats = { matches = 0, wins = 0, kills = 0, aces = 0, blocks = 0, digs = 0 },
		contract = { years = 2, salary = 300 + (Teams.list[club].rating - 60) * 15 },
		status = "ROTATION",
	}
	Career.ensureCareer(career)
	Career.freshSeason(career)
	Career.updateStatus(career, true)
	Career.news(career, "Welcome to " .. Teams.list[club].name, "You've signed a " .. career.contract.years .. "-season deal. The coach sees you as a " .. string.lower(career.status) .. " for now. Win your place with good ratings.", "welcome")
	Career.news(career, "The board's target: " .. career.objectives.club.text, "Hit your personal targets too: " .. career.objectives.personal[1].text .. ", and " .. string.lower(career.objectives.personal[2].text) .. ".", "objective")
	profile.career = career
	sendProfile(plr)
	task.spawn(saveProfile, plr)
end

-- spend a training point (from levelling up) on an attribute
function Career.trainCareer(plr, attr)
	local career = profiles[plr] and profiles[plr].career
	if not career or career.points <= 0 or not table.find(Teams.ATTRS, attr) or career.attrs[attr] >= 99 then
		return
	end
	career.attrs[attr] += 1
	career.points -= 1
	career.ovr = Career.careerOverall(career)
	career.perks = Teams.perksFor(career.attrs)
	sendProfile(plr)
end

-- adds training progress to an attribute; every 100 raises it by one
function Career.addProgress(career, attr, amount)
	local gains = 0
	career.progress[attr] += amount
	while career.progress[attr] >= 100 and career.attrs[attr] < 99 do
		career.progress[attr] -= 100
		career.attrs[attr] += 1
		gains += 1
	end
	if career.attrs[attr] >= 99 then
		career.progress[attr] = 0
	end
	return gains
end

-- the opponent in your next match: the league fixture, or your playoff opponent
function Career.nextOpponent(career)
	if career.phase == "semi" or career.phase == "final" then
		return career.playoffOpp
	end
	return opponentFor(career.club, career.round)
end

function Career.startCareerMatch(plr)
	local profile = profiles[plr]
	local career = profile and profile.career
	if not career then
		return
	end
	if matchActive then
		remote:FireClient(plr, "notice", "A match is already on in this server. Join it from Quick Play, or wait for it to finish.")
		return
	end
	local lineup = Teams.defaultLineup()
	local squad = Teams.squad(career.club)
	local slot = 2
	for i, index in lineup do
		if squad[index].role == career.role then
			slot = i
			break
		end
	end
	if career.role == "L" then
		slot = 3 -- the libero takes a middle blocker's place
	end
	local custom = profile.custom or {}
	local attrs = table.clone(career.attrs)
	local playoff = career.phase == "semi" or career.phase == "final"
	beginMatch({
		mode = "career",
		home = career.club,
		away = Career.nextOpponent(career),
		plan = { lineup = lineup, tactics = career.tactics },
		kit = (custom.kits and custom.kits[tostring(career.club)]) or 1,
		court = custom.court,
		-- playoff matches are best of three
		sets = playoff and 2 or nil,
		players = {
			{
				player = plr,
				team = 1,
				slot = slot,
				custom = { number = career.number, wearKit = custom.wearKit == true },
				override = { first = "", last = string.upper(plr.DisplayName), number = career.number, role = career.role, attrs = attrs, ovr = career.ovr, hand = "Right", perks = Teams.perksFor(attrs) },
			},
		},
	})
end

-- A rating out of 10 from what you did and the result
function Career.matchRating(st, won)
	local r = 5.8 + (st.kills or 0) * 0.32 + (st.aces or 0) * 0.5 + (st.blocks or 0) * 0.45 + (st.digs or 0) * 0.18 + (won and 0.6 or -0.2)
	return math.floor(math.clamp(r, 3, 10) * 10 + 0.5) / 10
end

-- Clubs that want you: better clubs come in when your rating and form are high
function Career.makeOffers(career, count, reason)
	local form = Career.averageForm(career)
	local candidates = {}
	for id, def in Teams.list do
		if id ~= career.club then
			local gap = def.rating - career.ovr
			-- clubs a bit better than you need good form; much weaker clubs always ask
			if gap <= 4 + (form - 6.5) * 4 then
				table.insert(candidates, id)
			end
		end
	end
	local made = {}
	for _ = 1, math.min(count, #candidates) do
		local pick = table.remove(candidates, rng:NextInteger(1, #candidates))
		local def = Teams.list[pick]
		local offer = {
			id = (career.newsId or 0) + 1,
			club = pick,
			years = rng:NextInteger(1, 3),
			salary = math.floor(250 + (def.rating - 60) * 18 + math.max(career.ovr - 60, 0) * 22 + form * 20),
			status = def.rating > career.ovr + 2 and "ROTATION" or def.rating > career.ovr - 3 and "STARTER" or "KEY PLAYER",
			expires = career.season * 100 + career.round + 3,
		}
		Career.news(career, def.name .. " want to sign you", string.format("%s offer a %d-season deal at %d a match. You'd join as a %s. (%s)", def.name, offer.years, offer.salary, string.lower(offer.status), reason), "offer", { offer = offer })
		table.insert(made, offer)
	end
	return made
end

function Career.offerById(career, id)
	for _, item in career.inbox do
		if item.offer and item.offer.id == id and not item.answered then
			return item
		end
	end
	return nil
end

function Career.answerOffer(plr, data)
	local career = profiles[plr] and profiles[plr].career
	if not career or matchActive and slotOfPlayer[plr] then
		return
	end
	local item = Career.offerById(career, tonumber(data.id))
	if not item then
		return
	end
	item.answered = true
	item.read = true
	local offer = item.offer
	if offer.expires < career.season * 100 + career.round then
		Career.news(career, "Offer expired", Teams.list[offer.club].name .. " have moved on.", "news")
	elseif data.accept then
		local old = career.club
		career.club = offer.club
		career.contract = { years = offer.years, salary = offer.salary }
		career.seasonsAtClub = 0
		career.status = offer.status
		item.result = "ACCEPTED"
		Career.news(career, "Transfer complete: " .. Teams.list[offer.club].name, "You leave " .. Teams.list[old].name .. " and sign until the end of season " .. (career.season + offer.years - 1) .. ".", "transfer")
		-- other offers lapse
		for _, other in career.inbox do
			if other.offer and not other.answered then
				other.answered, other.result = true, "LAPSED"
			end
		end
		Career.updateStatus(career, true)
	else
		item.result = "DECLINED"
	end
	sendProfile(plr)
	task.spawn(saveProfile, plr)
end

-- extra training: costs career money (earned from your salary), never real money
Career.CAMP_COST = 4000
function Career.trainingCamp(plr)
	local career = profiles[plr] and profiles[plr].career
	if not career or career.money < Career.CAMP_COST then
		return
	end
	career.money -= Career.CAMP_COST
	local gains = Career.addProgress(career, career.focus, 70)
	career.ovr = Career.careerOverall(career)
	career.perks = Teams.perksFor(career.attrs)
	Career.news(career, "Training camp", "A week of extra " .. Teams.ATTR_NAMES[career.focus] .. " work" .. (gains > 0 and (": +" .. gains .. " " .. career.focus .. "!") or "."), "training")
	sendProfile(plr)
end

-- The season's end: champions, targets, awards, history, contract and offers
function Career.endSeason(career, summary)
	local order = standings(career.table)
	local position = table.find(order, career.club) or #order
	local champion = career.playoff and career.playoff.champion or order[1]
	summary.champion = champion
	summary.position = position
	if champion == career.club then
		career.trophies += 1
		table.insert(career.awards, { season = career.season, name = "ARENA LEAGUE CHAMPION", club = career.club })
		Career.news(career, "CHAMPIONS!", Teams.list[career.club].name .. " are the Arena League champions. Your name is on the trophy.", "trophy")
	else
		Career.news(career, Teams.list[champion].name .. " are champions", "Your club finished " .. position .. "th in the regular season.", "news")
	end
	-- the board's target
	local met = (career.objectives.club.target == 1 and champion == career.club) or (career.objectives.club.target > 1 and position <= career.objectives.club.target)
	career.morale = math.clamp(career.morale + (met and 12 or -12), 0, 100)
	Career.news(career, met and "Board target met" or "Board target missed", career.objectives.club.text .. (met and ": the board are delighted." or ": the board expected more."), "objective")
	-- awards
	local s = career.season_stats
	local avg = s.matches > 0 and s.ratings / s.matches or 0
	if s.matches >= 6 and avg >= 7.8 then
		table.insert(career.awards, { season = career.season, name = "PLAYER OF THE SEASON" })
		Career.news(career, "Player of the Season!", string.format("An average rating of %.1f made you the best player in the league.", avg), "trophy")
	elseif s.matches >= 6 and avg >= 7.1 then
		table.insert(career.awards, { season = career.season, name = "TEAM OF THE SEASON" })
		Career.news(career, "Team of the Season", string.format("Your %.1f average earned a place in the Team of the Season.", avg), "trophy")
	end
	table.insert(career.history, {
		season = career.season,
		club = career.club,
		position = position,
		champion = champion == career.club,
		matches = s.matches,
		wins = s.wins,
		kills = s.kills,
		aces = s.aces,
		blocks = s.blocks,
		digs = s.digs,
		avg = math.floor(avg * 10 + 0.5) / 10,
		ovr = career.ovr,
	})
	-- contract
	career.contract.years -= 1
	if career.contract.years <= 0 then
		career.contract = { years = 2, salary = math.floor(career.contract.salary * (avg >= 7 and 1.25 or 1.05)) }
		Career.news(career, "New contract", "You've signed a new 2-season deal at " .. career.contract.salary .. " a match.", "contract")
	end
	career.season += 1
	career.seasonsAtClub += 1
	Career.freshSeason(career)
	summary.seasonOver = true
	Career.makeOffers(career, rng:NextInteger(1, 3), "summer transfer window")
	Career.news(career, "Season " .. career.season .. " begins", "The board's target: " .. career.objectives.club.text .. ". Yours: " .. career.objectives.personal[1].text .. " and " .. string.lower(career.objectives.personal[2].text) .. ".", "objective")
end

-- after the league: the top four play semi-finals (1 v 4, 2 v 3) and a final
function Career.startPlayoffs(career, summary)
	local order = standings(career.table)
	local semis = { { order[1], order[4] }, { order[2], order[3] } }
	career.playoff = { semis = semis, winners = {} }
	local mine = nil
	for i, pair in semis do
		if pair[1] == career.club or pair[2] == career.club then
			mine = i
		else
			local h, a = simulate(pair[1], pair[2])
			career.playoff.winners[i] = h > a and pair[1] or pair[2]
		end
	end
	if mine then
		local pair = semis[mine]
		career.phase = "semi"
		career.playoffOpp = pair[1] == career.club and pair[2] or pair[1]
		career.playoff.mine = mine
		Career.news(career, "Playoffs!", "You finished in the top four. Semi-final (best of three) against " .. Teams.list[career.playoffOpp].name .. ".", "playoff")
	else
		local a, b = career.playoff.winners[1], career.playoff.winners[2]
		local h, x = simulate(a, b)
		career.playoff.champion = h > x and a or b
		Career.endSeason(career, summary)
	end
end

function Career.finishCareerMatch(plr, result, context)
	local profile = profiles[plr]
	local career = profile and profile.career
	if not career then
		return
	end
	Career.ensureCareer(career)
	local st = result.stats
	local opponent = context.away
	local myScore, theirScore = teams[1].score, teams[2].score
	local setsLine = (setsToWin > 1) and (teams[1].sets .. "-" .. teams[2].sets .. " sets") or (myScore .. " - " .. theirScore)
	local rating = Career.matchRating(st, result.won)

	-- XP, levels and training points
	local xp = 40 + (result.won and 30 or 0) + math.floor(rating * 8) + (st.kills or 0) * 8 + (st.aces or 0) * 12 + (st.blocks or 0) * 10 + (st.digs or 0) * 4
	career.xp += xp
	local levels = 0
	while career.xp >= 100 * career.level do
		career.xp -= 100 * career.level
		career.level += 1
		career.points += 3
		levels += 1
	end
	-- training focus
	local before = career.attrs[career.focus]
	local gains = Career.addProgress(career, career.focus, math.floor(10 + rating * 3))
	-- form, morale and money
	table.insert(career.form, rating)
	while #career.form > 5 do
		table.remove(career.form, 1)
	end
	career.morale = math.clamp(career.morale + (result.won and 4 or -4) + math.floor((rating - 6.5) * 2), 0, 100)
	career.money += career.contract.salary + (result.won and math.floor(career.contract.salary * 0.5) or 0)
	-- stats
	for _, bucket in { career.stats, career.season_stats } do
		bucket.matches += 1
		bucket.wins += result.won and 1 or 0
		bucket.kills += st.kills or 0
		bucket.aces += st.aces or 0
		bucket.blocks += st.blocks or 0
		bucket.digs += st.digs or 0
	end
	career.season_stats.ratings += rating
	-- personal targets
	for _, o in career.objectives.personal do
		if not o.done then
			if o.stat == "good" then
				o.progress += rating >= 7.5 and 1 or 0
			elseif o.stat == "wins" then
				o.progress += result.won and 1 or 0
			else
				o.progress += st[o.stat] or 0
			end
			if o.progress >= o.target then
				o.done = true
				career.xp += 150
				Career.news(career, "Target reached: " .. o.text, "+150 XP. The fans love it.", "objective")
			end
		end
	end
	career.ovr = Career.careerOverall(career)
	career.perks = Teams.perksFor(career.attrs)

	local summary = {
		opponent = opponent,
		won = result.won,
		score = setsLine,
		xp = xp,
		levels = levels,
		round = career.round,
		phase = career.phase,
		rating = rating,
		stats = { kills = st.kills or 0, aces = st.aces or 0, blocks = st.blocks or 0, digs = st.digs or 0 },
		focus = career.focus,
		focusGain = gains,
		focusFrom = before,
		money = career.contract.salary,
	}
	table.insert(career.results, { round = career.round, phase = career.phase, opponent = opponent, won = result.won, score = setsLine, rating = rating })
	Career.news(career, (result.won and "Win" or "Defeat") .. " against " .. Teams.list[opponent].name, string.format("%s. Your rating: %.1f (%d kills, %d aces, %d blocks, %d digs).", setsLine, rating, st.kills or 0, st.aces or 0, st.blocks or 0, st.digs or 0), "match")
	if rating >= 8.5 then
		Career.news(career, "Player of the Match", string.format("A %.1f rating. The papers are full of you.", rating), "award")
	end

	if career.phase == "league" then
		-- this round: our match plus every other one
		record(career.table, career.club, opponent, myScore, theirScore)
		for _, pair in pairings(career.round) do
			if pair[1] ~= career.club and pair[2] ~= career.club then
				local h, a = simulate(pair[1], pair[2])
				record(career.table, pair[1], pair[2], h, a)
			end
		end
		career.round += 1
		if career.round == math.floor(ROUNDS / 2) + 1 then
			Career.makeOffers(career, (Career.averageForm(career) >= 7 and 2 or 1), "mid-season transfer window")
		end
		if career.round > ROUNDS then
			Career.startPlayoffs(career, summary)
		end
	elseif career.phase == "semi" then
		local playoff = career.playoff
		local other = playoff.mine == 1 and 2 or 1
		if result.won then
			playoff.winners[playoff.mine] = career.club
			career.phase = "final"
			career.playoffOpp = playoff.winners[other]
			Career.news(career, "Into the final!", "The final (best of three) is against " .. Teams.list[career.playoffOpp].name .. ".", "playoff")
		else
			playoff.winners[playoff.mine] = opponent
			local a, b = playoff.winners[1], playoff.winners[2]
			local h, x = simulate(a, b)
			playoff.champion = h > x and a or b
			Career.endSeason(career, summary)
		end
	elseif career.phase == "final" then
		career.playoff.champion = result.won and career.club or opponent
		Career.endSeason(career, summary)
	end
	Career.updateStatus(career)
	career.last = summary
	remote:FireClient(plr, "career_result", summary)
	sendProfile(plr)
	task.spawn(saveProfile, plr)
end

ensureCareerLater = Career.ensureCareer
for _, profile in profiles do
	pcall(Career.ensureCareer, profile.career)
end

function Career.setFocus(plr, attr)
	local career = profiles[plr] and profiles[plr].career
	if career and table.find(Career.FOCUS_ATTRS, attr) then
		career.focus = attr
		sendProfile(plr)
	end
end

function Career.markRead(plr)
	local career = profiles[plr] and profiles[plr].career
	if career then
		for _, item in career.inbox do
			item.read = true
		end
		sendProfile(plr)
	end
end

-- Edit Player, kits and courts (saved with your profile)
function Career.saveCustom(plr, data)
	local profile = profiles[plr]
	if not profile then
		return
	end
	local custom = profile.custom or {}
	custom.number = math.clamp(math.floor(tonumber(data.number) or custom.number or 7), 1, 99)
	custom.role = table.find(Teams.ROLE_ORDER, data.role) and data.role or custom.role or "OH"
	custom.wearKit = data.wearKit == true
	custom.court = math.clamp(math.floor(tonumber(data.court) or custom.court or 1), 1, #Teams.COURTS)
	custom.kits = custom.kits or {}
	if type(data.kits) == "table" then
		for id = 1, #Teams.list do
			local k = tonumber(data.kits[tostring(id)])
			if k then
				custom.kits[tostring(id)] = math.clamp(math.floor(k), 1, 3)
			end
		end
	end
	profile.custom = custom
	sendProfile(plr)
	task.spawn(saveProfile, plr)
end

---------------------------------------------------------------- online seasons (players in this server)

local queue = {}
local DIVISION_TARGET = 9 -- points needed to go up a division

local function queueStatus()
	for _, entry in queue do
		remote:FireClient(entry.player, "online_queue", true, #queue)
	end
end

local function leaveQueue(plr)
	for i, entry in queue do
		if entry.player == plr then
			table.remove(queue, i)
			remote:FireClient(plr, "online_queue", false, #queue)
			break
		end
	end
	queueStatus()
end

local function tryOnlineMatch()
	if matchActive or #queue < 2 then
		queueStatus()
		return
	end
	local a = table.remove(queue, 1)
	local b = table.remove(queue, 1)
	local away = b.club
	if away == a.club then
		away = a.club % #Teams.list + 1
	end
	for _, entry in { a, b } do
		remote:FireClient(entry.player, "online_queue", false, 0)
	end
	beginMatch({
		mode = "online",
		home = a.club,
		away = away,
		plan = a.plan,
		awayPlan = away == b.club and b.plan or nil,
		kit = a.kit,
		awayKit = b.kit,
		court = a.court,
		players = {
			{ player = a.player, team = 1, slot = 2, custom = a.custom },
			{ player = b.player, team = 2, slot = 2, custom = b.custom },
		},
	})
end

local function finishOnlineMatch(plr, result)
	local online = profiles[plr] and profiles[plr].online
	if not online then
		return
	end
	if result.won then
		online.wins += 1
		online.points += 3
		if online.points >= DIVISION_TARGET and online.division > 1 then
			online.division -= 1
			online.points = 0
		end
	else
		online.losses += 1
		if online.points == 0 and online.division < 10 then
			online.division += 1
			online.points = DIVISION_TARGET // 2
		else
			online.points = math.max(0, online.points - 1)
		end
	end
	remote:FireClient(plr, "online_result", result.won, online.division, online.points)
	sendProfile(plr)
	task.spawn(saveProfile, plr)
end

function onMatchFinished(context, results, _winner)
	for _, result in results do
		if result.player.Parent then
			if context.mode == "career" then
				Career.finishCareerMatch(result.player, result, context)
			elseif context.mode == "online" then
				finishOnlineMatch(result.player, result)
			end
		end
	end
	task.delay(2, tryOnlineMatch)
end

---------------------------------------------------------------- requests from the menus

remote.OnServerEvent:Connect(function(plr, action, data)
	if type(data) ~= "table" then
		data = {}
	end
	if action == "profile" then
		sendProfile(plr)
	elseif action == "career_create" then
		Career.createCareer(plr, data)
	elseif action == "career_train" then
		Career.trainCareer(plr, data.attr)
	elseif action == "career_tactics" then
		-- the team tactics you play with in your career
		local career = profiles[plr] and profiles[plr].career
		if career and type(data.tactics) == "table" then
			career.tactics = Teams.cleanPlan(career.club, { tactics = data.tactics }).tactics
			sendProfile(plr)
		end
	elseif action == "career_focus" then
		Career.setFocus(plr, data.attr)
	elseif action == "career_offer" then
		Career.answerOffer(plr, data)
	elseif action == "career_camp" then
		Career.trainingCamp(plr)
	elseif action == "career_read" then
		Career.markRead(plr)
	elseif action == "custom_save" then
		Career.saveCustom(plr, data)
	elseif action == "career_save" then
		task.spawn(saveProfile, plr)
	elseif action == "career_retire" then
		if profiles[plr] then
			profiles[plr].career = nil
			sendProfile(plr)
			task.spawn(saveProfile, plr)
		end
	elseif action == "start" and data.mode == "career" then
		if not controllers[plr] then
			Career.startCareerMatch(plr)
		end
	elseif action == "start" and data.mode == "online" then
		if not controllers[plr] then
			leaveQueue(plr)
			local club = math.clamp(math.floor(tonumber(data.club) or 1), 1, #Teams.list)
			local custom = profiles[plr] and profiles[plr].custom or {}
			table.insert(queue, {
				player = plr,
				club = club,
				plan = type(data.plan) == "table" and data.plan or nil,
				kit = custom.kits and custom.kits[tostring(club)] or 1,
				court = custom.court,
				custom = { number = custom.number or 7, wearKit = custom.wearKit == true },
			})
			tryOnlineMatch()
		end
	elseif action == "online_cancel" then
		leaveQueue(plr)
	end
end)

Players.PlayerAdded:Connect(loadProfile)
for _, plr in Players:GetPlayers() do
	task.spawn(loadProfile, plr)
end
Players.PlayerRemoving:Connect(function(plr)
	leaveQueue(plr)
	saveProfile(plr)
	profiles[plr] = nil
end)
game:BindToClose(function()
	for plr in profiles do
		saveProfile(plr)
	end
end)
