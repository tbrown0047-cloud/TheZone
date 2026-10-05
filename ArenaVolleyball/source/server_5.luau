
---------------------------------------------------------------- saved progress, career mode and online seasons

local DataStoreService = game:GetService("DataStoreService")

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("ArenaVolleyball_v1")
end)
local saving = store ~= nil -- turns false if saves fail (Studio without API access)
local profiles = {}

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
	data.version = 1
	data.online = data.online or { division = 10, points = 0, wins = 0, losses = 0 }
	if not plr.Parent then
		return
	end
	profiles[plr] = data
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

local function careerOverall(career)
	return Teams.overall(career.role, career.attrs)
end

local function createCareer(plr, data)
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
	profile.career = {
		club = club,
		role = role,
		number = number,
		attrs = attrs,
		xp = 0,
		level = 1,
		points = 3,
		season = 1,
		round = 1,
		trophies = 0,
		table = freshTable(),
		stats = { matches = 0, wins = 0, kills = 0, aces = 0, blocks = 0, digs = 0 },
	}
	profile.career.ovr = careerOverall(profile.career)
	sendProfile(plr)
	task.spawn(saveProfile, plr)
end

local function trainCareer(plr, attr)
	local career = profiles[plr] and profiles[plr].career
	if not career or career.points <= 0 or not table.find(Teams.ATTRS, attr) or career.attrs[attr] >= 99 then
		return
	end
	career.attrs[attr] += 1
	career.points -= 1
	career.ovr = careerOverall(career)
	sendProfile(plr)
end

local function startCareerMatch(plr)
	local career = profiles[plr] and profiles[plr].career
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
	local attrs = table.clone(career.attrs)
	beginMatch({
		mode = "career",
		home = career.club,
		away = opponentFor(career.club, career.round),
		plan = { lineup = lineup, tactics = career.tactics },
		players = {
			{
				player = plr,
				team = 1,
				slot = slot,
				control = "lock", -- in your career you are one player
				override = { first = "", last = string.upper(plr.DisplayName), number = career.number, role = career.role, attrs = attrs, ovr = career.ovr, hand = "Right" },
			},
		},
	})
end

local function finishCareerMatch(plr, result, context)
	local profile = profiles[plr]
	local career = profile and profile.career
	if not career then
		return
	end
	local st = result.stats
	local opponent = context.away
	local myScore, theirScore = teams[1].score, teams[2].score
	local xp = 40 + (result.won and 30 or 0) + (st.kills or 0) * 10 + (st.aces or 0) * 15 + (st.blocks or 0) * 12 + (st.digs or 0) * 5
	career.xp += xp
	local levels = 0
	while career.xp >= 100 * career.level do
		career.xp -= 100 * career.level
		career.level += 1
		career.points += 3
		levels += 1
	end
	career.stats.matches += 1
	career.stats.wins += result.won and 1 or 0
	for key, field in { kills = "kills", aces = "aces", blocks = "blocks", digs = "digs" } do
		career.stats[key] += st[field] or 0
	end
	-- this round: our match plus every other one
	record(career.table, career.club, opponent, myScore, theirScore)
	for _, pair in pairings(career.round) do
		if pair[1] ~= career.club and pair[2] ~= career.club then
			local h, a = simulate(pair[1], pair[2])
			record(career.table, pair[1], pair[2], h, a)
		end
	end
	local summary = {
		opponent = opponent,
		won = result.won,
		score = myScore .. " - " .. theirScore,
		xp = xp,
		levels = levels,
		round = career.round,
	}
	career.round += 1
	if career.round > ROUNDS then
		local order = standings(career.table)
		summary.champion = order[1]
		summary.position = table.find(order, career.club)
		if order[1] == career.club then
			career.trophies += 1
		end
		career.season += 1
		career.round = 1
		career.table = freshTable()
	end
	career.last = summary
	remote:FireClient(plr, "career_result", summary)
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
		players = {
			{ player = a.player, team = 1, slot = 2, control = "switch" },
			{ player = b.player, team = 2, slot = 2, control = "switch" },
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
				finishCareerMatch(result.player, result, context)
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
		createCareer(plr, data)
	elseif action == "career_train" then
		trainCareer(plr, data.attr)
	elseif action == "career_tactics" then
		-- the team tactics you play with in your career
		local career = profiles[plr] and profiles[plr].career
		if career and type(data.tactics) == "table" then
			career.tactics = Teams.cleanPlan(career.club, { tactics = data.tactics }).tactics
			sendProfile(plr)
		end
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
			startCareerMatch(plr)
		end
	elseif action == "start" and data.mode == "online" then
		if not controllers[plr] then
			leaveQueue(plr)
			table.insert(queue, { player = plr, club = math.clamp(math.floor(tonumber(data.club) or 1), 1, #Teams.list), plan = type(data.plan) == "table" and data.plan or nil })
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
