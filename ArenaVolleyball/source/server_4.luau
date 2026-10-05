
---------------------------------------------------------------- match flow

function currentServer()
	local team = teams[servingTeam]
	return team.slots[math.max(team.serveIndex, 1)]
end

function sendState(plr)
	local srv = (phase == "serve") and currentServer() or nil
	local roster = { {}, {} }
	for t = 1, 2 do
		for _, s in teams[t].slots do
			if s.player then
				local st = s.stats or {}
				table.insert(roster[t], { id = s.player.UserId, index = s.index, k = st.kills or 0, a = st.aces or 0, b = st.blocks or 0, d = st.digs or 0 })
			end
		end
	end
	local data = {
		phase = phase,
		score = { teams[1].score, teams[2].score },
		sets = { teams[1].sets, teams[2].sets },
		serving = servingTeam,
		server = srv and srv.player and srv.player.UserId or 0,
		touches = ball.touches,
		touchTeam = ball.lastTeam,
		roster = roster,
		deadline = serveDeadline,
		serveIndex = { teams[1].serveIndex, teams[2].serveIndex },
		level = LEVEL,
		points = pointsToWin,
		teamSize = TEAM_SIZE,
	}
	if plr then
		remote:FireClient(plr, "state", data)
	else
		remote:FireAllClients("state", data)
	end
end

function setupServe()
	phase = "serve"
	local srv = currentServer()
	ball.live = false
	ball.mode = "hold"
	ball.holder = srv
	ball.lastTeam, ball.lastSlot, ball.lastKind, ball.touches = 0, nil, nil, 0
	ball.id += 1
	ball.restPos = serveSpot(srv) + Vector3.new(0, 3, 0)
	serveAt = now() + rng:NextNumber(1.4, 2.4)
	serveDeadline = now() + Config.SERVE_TIME
	for t = 1, 2 do
		teams[t].brain = {}
	end
	placeSlot(srv, serveSpot(srv))
	srv.ai.jumpServe = rng:NextNumber() < AI.jumpServe
	srv.ai.serveJumped = false
	sendBall()
	sendState()
end

local matchNo = 0
local function startMatch()
	matchNo += 1
	servingTeam = (matchNo % 2 == 1) and 1 or 2 -- take turns serving first
	for t = 1, 2 do
		teams[t].score, teams[t].sets = 0, 0
		for _, s in teams[t].slots do
			s.stats = { kills = 0, aces = 0, blocks = 0, digs = 0 }
		end
		teams[t].serveIndex = (t == servingTeam) and 1 or 0
		for _, s in teams[t].slots do
			placeSlot(s, homeSpot(s))
		end
	end
	setupServe()
	local format = Config.SETS_TO_WIN > 1 and ("BEST OF " .. (Config.SETS_TO_WIN * 2 - 1) .. " SETS") or "ONE SET"
	banner("FIRST TO " .. pointsToWin, format, 0)
end

local function aiServe(slot, jumped)
	local power = rng:NextNumber(AI.serveLo, AI.serveHi)
	if rng:NextNumber() < AI.fault then
		power = rng:NextNumber() < 0.5 and 0.05 or 0.99
	end
	doServe(slot, smartTarget(slot.team, AI.margin + 1), power, jumped == true, slot.root.Position)
end

local function updateMatch(t)
	if phase == "point" and t >= phaseUntil then
		setupServe()
	elseif phase == "setover" and t >= phaseUntil then
		teams[1].score, teams[2].score = 0, 0
		setupServe()
	elseif phase == "matchover" and t >= phaseUntil then
		startMatch()
	elseif phase == "serve" then
		local srv = currentServer()
		if srv.root then
			if srv.isAI and t >= serveAt then
				if srv.ai.jumpServe and not srv.ai.serveJumped and srv.humanoid then
					-- jump serve: leave the ground, hit it a moment later
					srv.ai.serveJumped = true
					srv.humanoid.Jump = true
					serveAt = t + 0.25
				else
					aiServe(srv, srv.ai.serveJumped)
				end
			elseif not srv.isAI and t >= serveDeadline then
				doServe(srv, floorPoint(3 - srv.team, 0, HALF_L * 0.5), 0.5, false, srv.root.Position)
			end
		end
	end
end

---------------------------------------------------------------- AI

local function face(slot, target)
	local hrp = slot.root
	local look = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
	if look.Magnitude > 0.5 then
		hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, hrp.Position + look), 0.2)
	end
end

local function moveSlot(slot, order, t, lookAt)
	local hum, hrp, mem = slot.humanoid, slot.root, slot.ai
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	if order.hold then
		if mem.goal then
			hum:MoveTo(hrp.Position)
			mem.goal = nil
		end
		if grounded then
			face(slot, lookAt)
		end
		return
	end
	local s = side(slot.team)
	local lz = math.clamp((order.pos.Z - C.Z) * s, 1.4, HALF_L + 8)
	local lx = math.clamp(order.pos.X - C.X, -HALF_W - 8, HALF_W + 8)
	local pos = Vector3.new(C.X + lx, GY, C.Z + s * lz)
	hum.WalkSpeed = AI.speed + (order.run and 3 or 0)
	if flatDist(hrp.Position, pos) > 0.9 then
		if not mem.goal or flatDist(mem.goal, pos) > 0.6 or t - (mem.moveAt or 0) > 2 then
			hum:MoveTo(pos)
			mem.goal, mem.moveAt = pos, t
		end
	else
		if mem.goal then
			hum:MoveTo(hrp.Position)
			mem.goal = nil
		end
		if grounded then
			face(slot, lookAt)
		end
	end
end

local function aiTouch(slot, kind, t)
	local bp = ballPos(t)
	local use = kind
	if kind == "spike" and rng:NextNumber() < 0.15 then
		use = "tip"
	end
	local ok, q = reachCheck(slot, use, slot.root.Position, bp, true, t)
	if not ok and kind == "spike" then
		use = "bump"
		ok, q = reachCheck(slot, use, slot.root.Position, bp, true, t)
	end
	if not ok then
		return
	end
	q = math.clamp(q * 0.35 + AI.quality * 0.65 + rng:NextNumber(-0.12, 0.08), 0.1, 1)
	if use ~= "spike" and rng:NextNumber() < AI.shank then
		q = 0.08 -- shanked pass
	end
	local aim = nil
	if use == "spike" then
		aim = smartTarget(slot.team, AI.margin)
		if rng:NextNumber() < AI.attackErr then
			-- attack error: just past a line
			local opp = 3 - slot.team
			if rng:NextNumber() < 0.5 then
				local sx = rng:NextNumber() < 0.5 and -1 or 1
				aim = floorPoint(opp, sx * (HALF_W + rng:NextNumber(1.5, 3)), rng:NextNumber(6, HALF_L - 2))
			else
				aim = floorPoint(opp, rng:NextNumber(-HALF_W + 2, HALF_W - 2), HALF_L + rng:NextNumber(1.5, 3))
			end
		end
	elseif nextTouchNo(slot.team) >= 3 then
		aim = randomOpp(slot.team, AI.margin + 2)
	end
	touch(slot, use, bp, t, aim, q)
end

-- Decides what each AI on a team does while the ball is in play
local function planRally(team, t, brain)
	local orders = {}
	local tm = teams[team]
	local s = side(team)
	local n = nextTouchNo(team)
	local land = ballPos(landTime())
	local mine = (land.Z - C.Z) * s > 0 and n <= 3
	if mine and ball.lastTeam ~= team then
		local out = math.abs(land.X - C.X) > HALF_W + 1.5 or math.abs(land.Z - C.Z) > HALF_L + 1.5
		if out then
			if brain.letGoId ~= ball.id then
				brain.letGoId = ball.id
				brain.letGo = rng:NextNumber() < AI.letGo
			end
			if brain.letGo then
				mine = false
			end
		end
	end

	if mine then
		-- choose the shot and the player once per flight
		if brain.planId ~= ball.id then
			brain.planId = ball.id
			local kind, h = "bump", GY + 3
			if n == 2 then
				kind, h = "set", GY + 6.2
			elseif n == 3 then
				kind, h = "spike", GY + ATTACK_H
			end
			local tc = heightTime(h)
			if kind == "spike" and (not tc or (ballPos(tc).Z - C.Z) * s > 14) then
				kind, h = "bump", GY + 3 -- too low or too deep to attack: free ball
				tc = heightTime(h)
			elseif kind == "set" and not tc then
				kind, h = "bump", GY + 3
				tc = heightTime(h)
			end
			tc = math.max(tc or t, t)
			local cp = ballPos(tc)
			local who, bestD = nil, math.huge
			for _, sl in tm.slots do
				if sl.root and not (TEAM_SIZE > 1 and ball.lastSlot == sl) then
					local d = flatDist(sl.root.Position, cp)
					if not sl.isAI then
						d -= 3 -- leave it to a nearby person
					end
					if d < bestD then
						who, bestD = sl, d
					end
				end
			end
			brain.kind, brain.tc, brain.cp, brain.who = kind, tc, cp, who
			if who and who.player then
				remote:FireClient(who.player, "cue", (n == 3 and kind == "bump") and "over" or kind, tc)
			end
		end
		local who, kind, tc, cp = brain.who, brain.kind, brain.tc, brain.cp
		if who and who.isAI and who.root and who.humanoid then
			local stand = Vector3.new(cp.X, GY, cp.Z)
			if kind == "spike" then
				stand += Vector3.new(0, 0, s * 1.0)
			end
			orders[who] = { pos = stand, run = true }
			if kind == "spike" and who.ai.jumpId ~= ball.id and tc - t < 0.32 and flatDist(who.root.Position, cp) < 4.5 then
				who.ai.jumpId = ball.id
				who.humanoid.Jump = true
			end
			if t >= tc - 0.05 then
				aiTouch(who, kind, t)
			end
		end
		-- teammates get ready for the next touch
		local helpers = {}
		for _, sl in tm.slots do
			if sl.isAI and sl.root and sl ~= who then
				table.insert(helpers, sl)
			end
		end
		if #helpers > 0 and n == 1 then
			local spot = setSpot(team)
			table.sort(helpers, function(a, b)
				return flatDist(a.root.Position, spot) < flatDist(b.root.Position, spot)
			end)
			orders[helpers[1]] = { pos = Vector3.new(spot.X, GY, spot.Z), run = true }
		elseif n == 2 then
			-- the two helpers nearest the net run in to attack; the rest cover
			table.sort(helpers, function(a, b)
				return math.abs(a.root.Position.Z - C.Z) < math.abs(b.root.Position.Z - C.Z)
			end)
			for i, sl in helpers do
				if i > 2 then
					break
				end
				local lx = (sl.root.Position.X - C.X >= 0) and HALF_W * 0.55 or -HALF_W * 0.55
				orders[sl] = { pos = Vector3.new(C.X + lx, GY, C.Z + s * 10) }
			end
		end
	elseif ball.lastTeam == 3 - team and ball.touches == 2 and ball.lastKind == "set" then
		-- the other team has set up an attack: maybe put up a block
		local tco = heightTime(GY + ATTACK_H)
		local cpo = tco and ballPos(tco)
		if cpo and math.abs(cpo.Z - C.Z) < 9 then
			if brain.blockId ~= ball.id then
				brain.blockId = ball.id
				brain.blockGo = rng:NextNumber() < AI.blockTry
			end
			if brain.blockGo then
				-- one blocker, or a double block with six players
				local front = {}
				for _, sl in tm.slots do
					if sl.isAI and sl.root and sl.humanoid then
						table.insert(front, sl)
					end
				end
				table.sort(front, function(a, b)
					return math.abs(a.root.Position.Z - C.Z) < math.abs(b.root.Position.Z - C.Z)
				end)
				local count = math.min(#front, TEAM_SIZE >= 6 and 2 or 1)
				for i = 1, count do
					local blk = front[i]
					local bx = cpo.X + (count == 2 and (i == 1 and -1.6 or 1.6) or 0)
					orders[blk] = { pos = Vector3.new(bx, GY, C.Z + s * 1.6), run = true }
					if blk.ai.jumpId ~= ball.id and tco - t < 0.24 and math.abs(blk.root.Position.X - bx) < 3.5 then
						blk.ai.jumpId = ball.id
						blk.humanoid.Jump = true
					end
				end
			end
		end
	end
	return orders
end

local function aiTeam(team, t)
	local tm = teams[team]
	local brain = tm.brain
	if not brain then
		brain = {}
		tm.brain = brain
	end
	local lookAt = ball.restPos
	if ball.mode == "fly" then
		lookAt = ballPos(t)
	elseif ball.mode == "hold" and ball.holder and ball.holder.root then
		lookAt = ball.holder.root.Position
	end

	local orders = {}
	if phase == "serve" then
		local srv = currentServer()
		for _, sl in tm.slots do
			if sl == srv then
				orders[sl] = { hold = true }
			else
				orders[sl] = { pos = homeSpot(sl, servingTeam == team and "serving" or "receive") }
			end
		end
	elseif phase == "rally" and ball.mode == "fly" and ball.live then
		if brain.seenId ~= ball.id then
			brain.seenId, brain.seenAt = ball.id, t
		end
		if t - brain.seenAt < AI.react then
			orders = brain.orders or orders -- still reacting: carry on as before
		else
			orders = planRally(team, t, brain)
		end
	end
	brain.orders = orders
	for _, sl in tm.slots do
		if sl.isAI and sl.humanoid and sl.root then
			moveSlot(sl, orders[sl] or { pos = homeSpot(sl) }, t, lookAt)
			animateBot(sl)
		end
	end
end

---------------------------------------------------------------- input from players

remote.OnServerEvent:Connect(function(plr, action, data)
	if action == "sync" then
		sendState(plr)
		sendBall(plr)
		return
	end
	local slot = slotOfPlayer[plr]
	if not slot or not slot.root or not slot.humanoid or type(data) ~= "table" then
		return
	end
	local t = now()
	local rootPos = slot.root.Position
	if typeof(data.root) == "Vector3" and (data.root - rootPos).Magnitude < 14 then
		rootPos = data.root -- what the player saw, within reason
	end
	local aim = typeof(data.aim) == "Vector3" and data.aim or nil
	local air = data.air == true and rootPos.Y > standHeight(slot) + 0.3

	if action == "serve" then
		if phase == "serve" and currentServer() == slot and ball.mode == "hold" then
			local fallback = floorPoint(3 - slot.team, 0, HALF_L * 0.5)
			doServe(slot, aim or fallback, tonumber(data.power) or 0.5, air, rootPos)
		end
	elseif action == "hit" then
		if phase ~= "rally" or not ball.live or ball.mode ~= "fly" then
			return
		end
		if t - (slot.lastTouch or 0) < 0.45 then
			return
		end
		local kind = data.kind
		if kind ~= "bump" and kind ~= "set" and kind ~= "spike" and kind ~= "tip" then
			return
		end
		if kind == "spike" and not air then
			kind = "bump"
		elseif kind == "tip" and not air then
			kind = "set"
		end
		-- judge the touch at the moment the player clicked (up to 0.3 s ago)
		local ht = t
		if data.id == ball.id and type(data.t) == "number" and t - data.t >= 0 and t - data.t < 0.3 and data.t >= ball.t0 then
			ht = data.t
		end
		local bp = ballPos(ht)
		local ok, q = reachCheck(slot, kind, rootPos, bp, air, ht)
		if not ok and (kind == "spike" or kind == "tip") then
			kind = "set"
			ok, q = reachCheck(slot, kind, rootPos, bp, air, ht)
		end
		if not ok then
			remote:FireClient(plr, "miss")
			return
		end
		touch(slot, kind, bp, ht, aim, q)
	elseif action == "dive" then
		slot.diveUntil = t + 0.7
	end
end)

-- From the main menu: play (with match settings) or go back to the menu
local function anyPeople()
	for t = 1, 2 do
		for _, s in teams[t].slots do
			if s.player then
				return true
			end
		end
	end
	return false
end

remote.OnServerEvent:Connect(function(plr, action, data)
	if action == "join" and not slotOfPlayer[plr] then
		local first = not anyPeople()
		addPlayer(plr)
		if first and slotOfPlayer[plr] and type(data) == "table" then
			-- the first person in picks the difficulty and the target score
			local lvl = tonumber(data.level)
			if lvl and AI_LEVELS[math.floor(lvl)] then
				LEVEL = math.floor(lvl)
				AI = AI_LEVELS[LEVEL]
			end
			local pts = tonumber(data.points)
			if pts == 15 or pts == 21 or pts == 25 then
				pointsToWin = pts
			end
			startMatch()
		end
		sendState()
	elseif action == "leave" and slotOfPlayer[plr] then
		removePlayer(plr)
		local char = plr.Character
		if char and char.PrimaryPart then
			-- off the court, by the sideline
			local spot = Vector3.new(C.X + HALF_W + 24, GY + 4, C.Z)
			char:PivotTo(CFrame.lookAt(spot, Vector3.new(C.X, spot.Y, C.Z)))
		end
	end
end)

---------------------------------------------------------------- start

-- people join from the main menu; until then they watch
Players.PlayerRemoving:Connect(removePlayer)

-- controls and HUD for everyone
local function giveClient(plr)
	local holder = Instance.new("ScreenGui")
	holder.Name = "ArenaVolleyballLoader"
	holder.ResetOnSpawn = false
	clientTemplate:Clone().Parent = holder
	holder.Parent = plr:WaitForChild("PlayerGui")
end
clientTemplate:Clone().Parent = StarterPlayer:WaitForChild("StarterPlayerScripts")
for _, plr in Players:GetPlayers() do
	task.spawn(giveClient, plr)
end

-- AI bodies for every empty spot, built at the same time
local building = 0
for t = 1, 2 do
	for _, sl in teams[t].slots do
		if sl.isAI and not sl.model then
			building += 1
			task.spawn(function()
				makeBot(sl)
				building -= 1
			end)
		end
	end
end
local waited = 0
while building > 0 and waited < 10 do
	waited += task.wait(0.1)
end

startMatch()

local lastError = 0
RunService.Heartbeat:Connect(function()
	local ok, err = pcall(function()
		local t = now()
		stepBall(t)
		updateMatch(t)
		aiTeam(1, t)
		aiTeam(2, t)
	end)
	if not ok and os.clock() - lastError > 3 then
		lastError = os.clock()
		warn("[Arena Volleyball] " .. tostring(err))
	end
end)

print("[Arena Volleyball] Ready. Change the rules in ArenaVolleyball > Config.")
