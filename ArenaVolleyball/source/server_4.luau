
---------------------------------------------------------------- match flow

local matchContext = nil -- how the current match was started (quick play, career or online)
local courtStyle = 1
local pausedBy = ""

function currentServer()
	local team = teams[servingTeam]
	return team.slots[math.max(team.serveIndex, 1)]
end

function sendState(plr)
	local srv = (phase == "serve") and currentServer() or nil
	-- who is playing, by user id as text (remote tables need text keys)
	local controls = {}
	for person, ctrl in controllers do
		controls[tostring(person.UserId)] = { team = ctrl.team, home = ctrl.home }
	end
	local roster = { {}, {} }
	for t = 1, 2 do
		for _, s in teams[t].slots do
			local p = playerOf(s)
			local st = s.stats or {}
			local index = teams[t].lineup[s.index]
			table.insert(roster[t], {
				index = s.index,
				squad = index,
				name = s.player and string.upper(s.player.DisplayName) or (p and p.last or "PLAYER"),
				ctrl = s.player and s.player.DisplayName or nil,
				captain = teams[t].plan and index == teams[t].plan.captain and p and p.role ~= "L" or nil,
				rot = rotationPos(s),
				front = isFrontRow(s),
				number = (s.custom and s.custom.number) or (p and p.number) or s.index,
				role = p and p.role or "OH",
				ovr = p and p.ovr or 70,
				id = s.player and s.player.UserId or 0,
				model = s.model,
				k = st.kills or 0,
				a = st.aces or 0,
				b = st.blocks or 0,
				d = st.digs or 0,
				meter = math.floor(s.meter or 0),
				ability = abilityOf(s),
				boost = (s.boost and s.boost.untilT > now()) and s.boost.kind or nil,
			})
		end
	end
	if matchActive and teams[1].def then
		local setNo = teams[1].sets + teams[2].sets + 1
		updateScoreboards(
			practice and ("PRACTICE  ·  " .. practice.drill) or ("SET " .. setNo .. "  ·  FIRST TO " .. setTarget()),
			teams[1].def.short .. "   " .. teams[1].score .. " - " .. teams[2].score .. "   " .. teams[2].def.short,
			practice and (practice.made .. " / " .. practice.attempts) or ("SETS  " .. teams[1].sets .. " - " .. teams[2].sets)
		)
	else
		updateScoreboards("ARENA VOLLEYBALL", "WELCOME", Teams.LEAGUE)
	end
	local data = {
		active = matchActive,
		phase = phase,
		score = { teams[1].score, teams[2].score },
		sets = { teams[1].sets, teams[2].sets },
		serving = servingTeam,
		server = srv and srv.player and srv.player.UserId or 0,
		serverTeam = srv and srv.team or 0,
		serverIndex = srv and srv.index or 0,
		touches = ball.touches,
		touchTeam = ball.lastTeam,
		roster = roster,
		deadline = serveDeadline,
		serveIndex = { teams[1].serveIndex, teams[2].serveIndex },
		teamIds = { teams[1].defId, teams[2].defId },
		lineups = { teams[1].lineup, teams[2].lineup },
		points = setTarget(),
		setScores = { teams[1].setScores or {}, teams[2].setScores or {} },
		timeouts = { teams[1].timeouts or 2, teams[2].timeouts or 2 },
		setsToWin = setsToWin,
		teamSize = TEAM_SIZE,
		paused = paused,
		pausedAt = pausedAt,
		pausedBy = pausedBy,
		mode = matchContext and matchContext.mode or "quick",
		plans = { teams[1].plan, teams[2].plan },
		subs = { teams[1].subs, teams[2].subs },
		subsMax = Config.SUBS_PER_SET or 6,
		kits = { teams[1].kitIndex, teams[2].kitIndex },
		court = courtStyle,
		controls = controls,
		practice = practice,
	}
	if plr then
		remote:FireClient(plr, "state", data)
	else
		remote:FireAllClients("state", data)
	end
end

-- the person in a practice session (there's only one)
local function practiceSlot()
	for t = 1, 2 do
		for _, s in teams[t].slots do
			if s.player then
				return s
			end
		end
	end
	return nil
end

function setupServe()
	-- practice drills decide who serves: you (serving), the other side (receiving)
	local me = practice and practiceSlot()
	if me and practice.drill == "SERVE" then
		servingTeam = me.team
		teams[me.team].serveIndex = me.index
	elseif me and practice.drill == "RECEIVE" then
		servingTeam = 3 - me.team
	end
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
		for _, s in teams[t].slots do
			dressBot(s) -- the libero comes on or off as players rotate
		end
	end
	-- an AI server who has already walked to the line isn't teleported
	if not (srv.isAI and srv.root and flatDist(srv.root.Position, serveSpot(srv)) < 4) then
		placeSlot(srv, serveSpot(srv))
	end
	local style = tactic(srv.team, "serve")
	local styleJump = style == "AGGRESSIVE" and 1.6 or style == "SAFE" and 0.5 or 1
	srv.ai.jumpServe = rng:NextNumber() < teamAI(srv.team).jumpServe * styleJump * (0.6 + 0.8 * attr01(srv, "SRV"))
	srv.ai.serveJumped = false
	srv.ai.prepped = false
	sendBall()
	sendState()
end

local matchNo = 0
local function startMatch()
	matchNo += 1
	servingTeam = (matchNo % 2 == 1) and 1 or 2 -- take turns serving first
	for t = 1, 2 do
		teams[t].score, teams[t].sets = 0, 0
		teams[t].setScores, teams[t].timeouts, teams[t].run = {}, 2, 0
		teams[t].serveIndex = (t == servingTeam) and 1 or 0
		for _, s in teams[t].slots do
			s.stats = { kills = 0, aces = 0, blocks = 0, digs = 0 }
			placeSlot(s, homeSpot(s))
		end
	end
	setupServe()
	local format = setsToWin > 1 and ("BEST OF " .. (setsToWin * 2 - 1) .. " SETS") or "ONE SET"
	banner("FIRST TO " .. pointsToWin, format, 0)
end

local function moveOffCourt(plr)
	local char = plr.Character
	if char and char.PrimaryPart then
		local spot = Vector3.new(C.X + HALF_W + 10, GY + 4, C.Z + HALF_L + 12)
		char:PivotTo(CFrame.lookAt(spot, Vector3.new(C.X, spot.Y, C.Z)))
	end
end

-- Ends the match: people go back to the menu, AI bodies are removed, the court goes quiet
function stopMatch()
	local finished = phase == "matchover"
	local winner = teams[1].sets > teams[2].sets and 1 or 2
	local results = {}
	for plr, ctrl in controllers do
		local home = teams[ctrl.team].slots[ctrl.home]
		table.insert(results, { player = plr, team = ctrl.team, stats = home and home.stats or {}, won = ctrl.team == winner })
	end
	local context = matchContext
	matchContext = nil
	practice = nil
	paused = false
	matchActive = false
	phase = "idle"
	ball.live = false
	ball.mode = "hidden"
	ball.holder = nil
	for t = 1, 2 do
		for _, s in teams[t].slots do
			local plr = s.player
			if plr then
				if charConnections[plr] then
					charConnections[plr]:Disconnect()
					charConnections[plr] = nil
				end
				-- clothes back, then forget the character so it isn't destroyed
				pcall(undressCharacter, s)
				s.player, s.model, s.humanoid, s.root, s.align = nil, nil, nil, nil, nil
				s.custom = nil
				s.isAI = true
				moveOffCourt(plr)
			end
			s.override, s.meter, s.boost = nil, 0, nil
			clearBody(s)
		end
	end
	table.clear(controllers)
	table.clear(slotOfPlayer)
	sendBall()
	sendState()
	if finished and context and onMatchFinished then
		task.spawn(onMatchFinished, context, results, winner)
	end
end

-- The pause menu stops everything; on resume the ball and every timer pick up where they were
local function setPaused(on, who)
	if on == paused or not matchActive then
		return
	end
	local t = now()
	if on then
		paused, pausedAt, pausedBy = true, t, who or ""
		for team = 1, 2 do
			for _, s in teams[team].slots do
				if s.isAI and s.humanoid then
					s.humanoid:Move(Vector3.zero)
					s.ai.vel = Vector3.zero
				end
			end
		end
	else
		local gap = t - pausedAt
		paused = false
		ball.t0 += gap
		serveAt += gap
		serveDeadline += gap
		phaseUntil += gap
		for team = 1, 2 do
			teams[team].brain = {}
			if teams[team].call then
				teams[team].call.untilT += gap
			end
			for _, s in teams[team].slots do
				if s.boost then
					s.boost.untilT += gap
				end
			end
		end
		sendBall()
	end
	sendState()
end

local function aiServe(slot, jumped)
	local ai = teamAI(slot.team)
	local serve = attr01(slot, "SRV")
	-- serve strategy: safe serves are softer and rarely missed, aggressive ones the opposite
	local style = tactic(slot.team, "serve")
	local shift = style == "AGGRESSIVE" and 0.06 or style == "SAFE" and -0.09 or 0
	local faults = style == "AGGRESSIVE" and 1.6 or style == "SAFE" and 0.45 or 1
	local margin = ai.margin + 1 + (style == "AGGRESSIVE" and -0.8 or style == "SAFE" and 1 or 0)
	local lo = math.clamp(ai.serveLo + shift + (serve - 0.5) * 0.15, 0.2, 0.88)
	local hi = math.clamp(ai.serveHi + shift + (serve - 0.5) * 0.15, lo + 0.05, 0.93)
	local power = rng:NextNumber(lo, hi)
	if rng:NextNumber() < ai.fault * faults * (1.5 - serve) then
		power = rng:NextNumber() < 0.5 and 0.05 or 0.99
	end
	local target = smartTarget(slot.team, math.max(margin, 1))
	local me = practice and practice.drill == "RECEIVE" and practiceSlot()
	if me and me.root then
		-- receiving drill: every serve comes at you
		target = Vector3.new(me.root.Position.X, FLOOR, me.root.Position.Z) + jitter(3)
		power = math.clamp(power, 0.45, 0.85)
	end
	doServe(slot, target, power, jumped == true, slot.root.Position)
end

-- A serve that breaks the rules: the point goes to the other team
function serveFault(slot, reason)
	ball.live = true
	ball.lastTeam, ball.lastSlot, ball.lastKind = slot.team, slot, "serve"
	ball.mode = "rest"
	ball.holder = nil
	ball.restPos = serveSpot(slot) + Vector3.new(0, R, 0)
	phase = "rally"
	sendBall()
	awardPoint(3 - slot.team, reason)
end

-- Timeouts: two per team per set. The AI calls one when the other side goes on a run.
local function callTimeout(team, who)
	local tm = teams[team]
	if (tm.timeouts or 0) <= 0 or (phase ~= "point" and phase ~= "serve") then
		return false
	end
	tm.timeouts -= 1
	local extra = 8
	phaseUntil += extra
	serveAt += extra
	serveDeadline += extra
	banner("TIMEOUT", tm.def.name .. (who and ("   ·   " .. who) or "") .. "   ·   " .. tm.timeouts .. " LEFT", team)
	sendState()
	return true
end

function afterPoint(winner, bigMoment)
	-- the scorers celebrate, the others drop their heads
	local cheered = 0
	for _, s in teams[winner].slots do
		if s.isAI and s.model and (bigMoment or rng:NextNumber() < 0.45) and cheered < (bigMoment and 6 or 3) then
			cheered += 1
			task.delay(rng:NextNumber(0.05, 0.4), act, s, "celebrate")
		end
	end
	for _, s in teams[3 - winner].slots do
		if s.isAI and s.model and rng:NextNumber() < (bigMoment and 0.8 or 0.25) then
			task.delay(rng:NextNumber(0.2, 0.7), act, s, "dejected")
		end
	end
	remote:FireAllClients("crowd", winner, bigMoment == true)
	if bigMoment or practice then
		return
	end
	local loser = teams[3 - winner]
	local hasPerson = false
	for _, s in loser.slots do
		hasPerson = hasPerson or s.player ~= nil
	end
	-- three in a row against them, mid-set: the AI coach stops the game
	if not hasPerson and (teams[winner].run or 0) >= 3 and teams[winner].score >= 8 and rng:NextNumber() < 0.6 then
		task.defer(callTimeout, 3 - winner)
	end
end

local function updateMatch(t)
	if phase == "point" and t >= phaseUntil then
		setupServe()
	elseif phase == "setover" and t >= phaseUntil then
		teams[1].score, teams[2].score = 0, 0
		teams[1].subs, teams[2].subs = 0, 0 -- substitutions and timeouts are counted per set
		teams[1].timeouts, teams[2].timeouts = 2, 2
		if setTarget() ~= pointsToWin then
			banner("DECIDING SET", "FIRST TO " .. setTarget(), 0)
		end
		setupServe()
	elseif phase == "matchover" and t >= phaseUntil then
		stopMatch()
	elseif phase == "serve" and practice and practice.drill == "ATTACK" then
		-- attacking drill: the coach throws a pass to your setter, who sets you
		local me = practiceSlot()
		if me and t >= serveAt then
			local spot = setSpot(me.team)
			local p = floorPoint(me.team, 0, 14) + Vector3.new(0, 3, 0)
			ball.live = true
			ball.lastTeam, ball.lastSlot, ball.lastKind, ball.touches = me.team, nil, "bump", 1
			ball.holder = nil
			phase = "rally"
			launch(p, solve(p, spot, 1.25), t)
			sendState()
		end
	elseif phase == "serve" then
		local srv = currentServer()
		if srv.root then
			if srv.isAI then
				if not srv.ai.prepped and t >= serveAt - 0.5 then
					srv.ai.prepped = true
					act(srv, "serveprep")
				end
				if t >= serveAt then
					if (srv.meter or 0) >= 100 and not srv.boost then
						activateAbility(srv)
					end
					if srv.ai.jumpServe and not srv.ai.serveJumped and srv.humanoid then
						-- jump serve: leave the ground, hit it a moment later
						srv.ai.serveJumped = true
						srv.humanoid.Jump = true
						serveAt = t + 0.25
					else
						aiServe(srv, srv.ai.serveJumped)
					end
				end
			elseif t >= serveDeadline then
				serveFault(srv, "SERVE DELAY") -- 8 seconds to serve, like the real rule
			end
		end
	elseif phase == "rally" and ball.live then
		-- touching the net between the antennas is a fault
		for team = 1, 2 do
			for _, s in teams[team].slots do
				if s.player and s.root and s.humanoid then
					local rp = s.root.Position
					if math.abs(rp.Z - C.Z) < 0.85 and math.abs(rp.X - C.X) < HALF_W + 0.5 and rp.Y > standHeight(s) + 0.6 then
						awardPoint(3 - team, "NET TOUCH")
						return
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- AI movement
-- AI players steer instead of walking on rails: they speed up and slow down, keep a
-- little space from teammates, react a beat apart, and shuffle facing the ball.

local function steer(slot, order, t, dt, lookAt)
	local hum, hrp, mem = slot.humanoid, slot.root, slot.ai
	local ai = teamAI(slot.team)
	local s = side(slot.team)
	local here = hrp.Position
	local grounded = hum.FloorMaterial ~= Enum.Material.Air

	-- take up a new target after a short personal delay; small corrections are instant
	if order.pos then
		local lz = math.clamp((order.pos.Z - C.Z) * s, 1.4, HALF_L + 8)
		local lx = math.clamp(order.pos.X - C.X, -HALF_W - 8, HALF_W + 8)
		local want = Vector3.new(C.X + lx, GY, C.Z + s * lz)
		if not mem.target or flatDist(want, mem.target) < 1.5 or order.sprint then
			mem.target, mem.switchAt = want, nil
		elseif not mem.switchAt then
			-- each player reacts in his own time
			mem.switchAt = t + (mem.reactBase or 0) + rng:NextNumber(0.03, order.run and 0.12 or 0.35)
		elseif t >= mem.switchAt then
			mem.target, mem.switchAt = want, nil
		end
	end

	local vel = mem.vel or Vector3.zero
	if (slot.diveUntil or 0) > t then
		vel = vel * (1 - math.min(dt * 2.5, 1)) -- sliding out of a dive
	else
		local maxSpeed = ai.speed * (mem.pace or 1)
		-- the back row covers the most ground, so it moves quicker
		local backRow = TEAM_SIZE == 6 and not isFrontRow(slot)
		if backRow and not order.walk then
			maxSpeed += 3
		end
		if order.sprint then
			maxSpeed += 6
		elseif order.run then
			maxSpeed += 3
		elseif order.walk then
			maxSpeed = 8.5 * (mem.pace or 1) * (mem.walkMul or 1)
		end
		if (mem.recoverUntil or 0) > t then
			maxSpeed *= 0.35 -- getting up after a dive
		end
		local desired = Vector3.zero
		if mem.target and not order.hold then
			local offset = Vector3.new(mem.target.X - here.X, 0, mem.target.Z - here.Z)
			local dist = offset.Magnitude
			if dist > 0.35 then
				desired = offset.Unit * math.min(maxSpeed, 1.5 + dist * 3) -- ease into the spot
			end
		end
		-- keep a little space from teammates
		for _, other in teams[slot.team].slots do
			if other ~= slot and other.root then
				local away = Vector3.new(here.X - other.root.Position.X, 0, here.Z - other.root.Position.Z)
				local d = away.Magnitude
				if d > 0.01 and d < 2.6 then
					desired += away.Unit * (2.6 - d) * 2
				end
			end
		end
		-- accelerate towards it instead of snapping
		local accel = (grounded and ((order.sprint or order.run) and (backRow and 58 or 46) or (backRow and 32 or 24)) or 6) * (mem.accelMul or 1)
		local change = desired - vel
		local maxChange = accel * dt
		if change.Magnitude > maxChange then
			change = change.Unit * maxChange
		end
		vel += change
	end
	mem.vel = vel

	local speed = vel.Magnitude
	if speed > 0.3 then
		hum.WalkSpeed = speed
		hum:Move(vel.Unit)
	else
		hum:Move(Vector3.zero)
	end

	-- watch the ball while shuffling; turn into the run when sprinting
	local toBall = Vector3.new(lookAt.X - here.X, 0, lookAt.Z - here.Z)
	local face = toBall.Magnitude > 0.5 and toBall.Unit or Vector3.new(0, 0, -s)
	if speed > 11 then
		local w = math.clamp((speed - 11) / 8, 0, 0.85)
		face = face * (1 - w) + vel.Unit * w
	end
	if grounded or (slot.diveUntil or 0) > t then
		faceTowards(slot, face)
	end
end

---------------------------------------------------------------- AI decisions

local deferredTouches = {}

local function aiTouch(slot, kind, t)
	local ai = teamAI(slot.team)
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
	-- touch quality: the team's level and the player's own rating for that skill
	local skill = attr01(slot, (use == "set") and "SET" or (use == "bump") and "REC" or "ATK")
	local level = ai.quality * 0.55 + skill * 0.45
	q = math.clamp(q * 0.35 + level * 0.65 + rng:NextNumber(-0.12, 0.08), 0.1, 1)
	if use ~= "spike" and rng:NextNumber() < ai.shank * (1.5 - skill) then
		q = 0.08 -- shanked pass
	end
	local aim = nil
	if use == "spike" then
		aim = smartTarget(slot.team, ai.margin)
		if rng:NextNumber() < ai.attackErr * (1.5 - skill) then
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
		aim = randomOpp(slot.team, ai.margin + 2)
	end
	-- applied after both teams have thought this frame, so neither side reacts a frame early
	table.insert(deferredTouches, { slot = slot, use = use, bp = bp, t = t, aim = aim, q = q, id = ball.id })
end

local function flushTouches()
	for _, d in deferredTouches do
		if ball.id == d.id and ball.live and ball.mode == "fly" then
			touch(d.slot, d.use, d.bp, d.t, d.aim, d.q)
		end
	end
	table.clear(deferredTouches)
end

-- Where a hitter waits to start his run-up: behind his lane
local function approachSpot(slot)
	local s = side(slot.team)
	local lane = LANE[roleOf(slot)] or -1
	return Vector3.new(C.X + s * HALF_W * 0.62 * lane, GY, C.Z + s * 9)
end

-- Decides what each AI on a team does while the ball is in play
local function planRally(team, t, brain)
	local orders = {}
	local tm = teams[team]
	local ai = tm.ai
	local s = side(team)
	local n = nextTouchNo(team)
	local land = ballPos(landTime())
	local mine = (land.Z - C.Z) * s > 0 and n <= 3
	if mine and ball.lastTeam ~= team then
		local out = math.abs(land.X - C.X) > HALF_W + 1.5 or math.abs(land.Z - C.Z) > HALF_L + 1.5
		if out then
			if brain.letGoId ~= ball.id then
				brain.letGoId = ball.id
				brain.letGo = rng:NextNumber() < ai.letGo
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
					local role = roleOf(sl)
					if not sl.isAI then
						d -= 3 -- leave it to a nearby person
					end
					if kind == "spike" and TEAM_SIZE == 6 then
						-- the front row attacks; the libero never does
						d += (role == "L" and 20) or (isFrontRow(sl) and -4) or 4
					end
					if kind == "set" and role == "S" then
						d -= 12 -- the setter takes the second ball
					elseif kind == "bump" and n == 1 then
						if role == "S" then
							d += 5 -- keep the setter free to set
						elseif role == "MB" then
							d += 3
						elseif role == "L" then
							d -= 2
						end
					end
					if d < bestD then
						who, bestD = sl, d
					end
				end
			end
			-- an AI in the back row (or the libero) plays it over instead of attacking at the net
			if who and who.isAI and kind == "spike" and TEAM_SIZE == 6 and (not isFrontRow(who) or roleOf(who) == "L") then
				kind = "bump"
				tc = math.max(heightTime(GY + 3) or t, t)
				cp = ballPos(tc)
			end
			brain.kind, brain.tc, brain.cp, brain.who = kind, tc, cp, who
			if who and who.player then
				remote:FireClient(who.player, "cue", (n == 3 and kind == "bump") and "over" or kind, tc, cp)
			end
		end
		local who, kind, tc, cp = brain.who, brain.kind, brain.tc, brain.cp
		if who and who.isAI and (who.meter or 0) >= 100 and not who.boost then
			local role = roleOf(who)
			if (kind == "spike" and (role == "OH" or role == "OPP")) or (kind == "set" and role == "S") or (kind == "bump" and role == "L") then
				activateAbility(who)
			end
		end
		if who and who.isAI and who.root and who.humanoid then
			local stand = Vector3.new(cp.X, GY, cp.Z)
			if kind == "spike" then
				-- run-up: wait behind and outside the ball, then attack it and jump
				local lane = (cp.X - C.X) >= 0 and 1 or -1
				local start = Vector3.new(cp.X + lane * 2.5, GY, cp.Z + s * 6)
				local runTime = flatDist(start, cp) / (ai.speed + 6) + 0.3
				if t < tc - runTime then
					orders[who] = { pos = start, run = true }
				else
					orders[who] = { pos = stand + Vector3.new(0, 0, s * 0.8), sprint = true }
				end
				if who.ai.jumpId ~= ball.id and tc - t < 0.32 and flatDist(who.root.Position, cp) < 4.5 then
					who.ai.jumpId = ball.id
					who.humanoid.Jump = true
				end
			else
				-- a long way to go: sprint for it
				orders[who] = { pos = stand, run = true, sprint = flatDist(who.root.Position, stand) > 7 }
				-- dive only for a ball he can't reach by running
				local far = flatDist(who.root.Position, cp)
				local short = far - (ai.speed + 3) * math.max(tc - t, 0)
				if who.ai.diveId ~= ball.id and tc - t < 0.35 and tc - t > 0.05 and short > REACH - 1 and far < REACH + 4.5 then
					who.ai.diveId = ball.id
					who.diveUntil = t + 0.7
					who.ai.recoverUntil = t + 1.5
					local dir = Vector3.new(cp.X - who.root.Position.X, 0, cp.Z - who.root.Position.Z)
					if dir.Magnitude > 0.1 then
						who.ai.vel = dir.Unit * 30
						who.root.AssemblyLinearVelocity = dir.Unit * 30 + Vector3.new(0, 9, 0)
						faceTowards(who, dir)
					end
					act(who, "dive")
				end
			end
			if t >= tc - 0.05 then
				aiTouch(who, kind, t)
			end
		end
		-- teammates get ready for the next touch
		local setter
		for _, sl in tm.slots do
			if sl ~= who and sl.isAI and sl.root and roleOf(sl) == "S" then
				setter = sl
			end
		end
		if n == 1 then
			local spot = setSpot(team)
			local runner = setter
			if not runner then
				local best = math.huge
				for _, sl in tm.slots do
					if sl ~= who and sl.isAI and sl.root and flatDist(sl.root.Position, spot) < best then
						runner, best = sl, flatDist(sl.root.Position, spot)
					end
				end
			end
			if runner then
				orders[runner] = { pos = Vector3.new(spot.X, GY, spot.Z), run = true }
			end
		end
		if n <= 2 then
			-- front-row hitters back off to start their run-ups
			for _, sl in tm.slots do
				if sl ~= who and sl.isAI and sl.root and not orders[sl] and isFrontRow(sl) and LANE[roleOf(sl)] then
					orders[sl] = { pos = approachSpot(sl), run = true }
				end
			end
		end
	elseif ball.lastTeam == 3 - team and ball.touches == 2 and ball.lastKind == "set" then
		-- the other team has set up an attack: block, and shift the defence towards it
		local tco = heightTime(GY + ATTACK_H)
		local cpo = tco and ballPos(tco)
		if cpo and math.abs(cpo.Z - C.Z) < 9 then
			if brain.blockId ~= ball.id then
				brain.blockId = ball.id
				brain.blockGo = rng:NextNumber() < ai.blockTry
			end
			local blockers = {}
			if brain.blockGo then
				local front = {}
				for _, sl in tm.slots do
					if sl.isAI and sl.root and sl.humanoid and isFrontRow(sl) then
						table.insert(front, sl)
					end
				end
				table.sort(front, function(a, b)
					return math.abs(a.root.Position.X - cpo.X) < math.abs(b.root.Position.X - cpo.X)
				end)
				local count = math.min(#front, TEAM_SIZE >= 6 and 2 or 1)
				for i = 1, count do
					local blk = front[i]
					blockers[blk] = true
					if (blk.meter or 0) >= 100 and not blk.boost and roleOf(blk) == "MB" then
						activateAbility(blk)
					end
					local bx = cpo.X + (count == 2 and (i == 1 and -1.6 or 1.6) or 0)
					orders[blk] = { pos = Vector3.new(bx, GY, C.Z + s * 1.6), run = true }
					if blk.ai.jumpId ~= ball.id and tco - t < 0.24 and math.abs(blk.root.Position.X - bx) < 3.5 then
						blk.ai.jumpId = ball.id
						blk.humanoid.Jump = true
					end
				end
			end
			local shift = (cpo.X - C.X) * 0.25
			for _, sl in tm.slots do
				if sl.isAI and not blockers[sl] then
					orders[sl] = { pos = homeSpot(sl) + Vector3.new(shift, 0, 0) }
				end
			end
		end
	end
	return orders
end

local function aiTeam(team, t, dt)
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
	local serving = servingTeam == team
	-- when the phase changes, everyone starts moving in his own time
	if tm.seenPhase ~= phase then
		tm.seenPhase = phase
		for _, sl in tm.slots do
			if sl.ai then
				sl.ai.restUntil = t + rng:NextNumber(0.1, phase == "point" and 1.5 or 0.5)
			end
		end
	end
	-- a little life around a spot: shifting weight, a step this way or that
	local function around(sl, spot, walk)
		local mem = sl.ai
		if not mem.idleAt or t >= mem.idleAt then
			mem.idleAt = t + rng:NextNumber(1.2, 3.2)
			mem.idleOffset = Vector3.new(rng:NextNumber(-0.9, 0.9), 0, rng:NextNumber(-0.7, 0.7))
		end
		if t < (mem.restUntil or 0) then
			return { hold = true }
		end
		return { pos = spot + mem.idleOffset, walk = walk }
	end
	if phase == "serve" then
		local srv = currentServer()
		for _, sl in tm.slots do
			if sl == srv then
				orders[sl] = { hold = true }
			elseif sl.ai then
				orders[sl] = around(sl, homeSpot(sl, serving and "serving" or "receive"), true)
			end
		end
	elseif phase == "rally" and ball.mode == "fly" and ball.live then
		if brain.seenId ~= ball.id then
			brain.seenId, brain.seenAt, brain.lag = ball.id, t, rng:NextNumber(0, 0.08)
		end
		if t - brain.seenAt < tm.ai.react + brain.lag then
			orders = brain.orders or orders -- still reacting: carry on as before
		else
			orders = planRally(team, t, brain)
		end
	else
		-- between points: walk back; the next server heads for the end line
		local nextServer = (phase == "point" and serving) and currentServer() or nil
		for _, sl in tm.slots do
			if sl == nextServer then
				orders[sl] = { pos = serveSpot(sl), run = true }
			elseif sl.ai then
				orders[sl] = around(sl, homeSpot(sl, serving and "serving" or "receive"), true)
			end
		end
	end
	brain.orders = orders
	for _, sl in tm.slots do
		if sl.isAI and sl.humanoid and sl.root then
			steer(sl, orders[sl] or { pos = homeSpot(sl) }, t, dt, lookAt)
			animateBot(sl)
		end
	end
end

---------------------------------------------------------------- starting and joining from the menu

-- spec: { mode, home, away, plan, points, sets, players = { { player, team, slot, override } } }
local function beginMatch(spec)
	for t = 1, 2 do
		for _, sl in teams[t].slots do
			sl.override, sl.meter, sl.boost = nil, 0, nil
		end
	end
	configureTeams(spec.home, spec.away, spec.plan, spec.awayPlan, spec.kit, spec.awayKit)
	practice = spec.mode == "practice" and { drill = spec.drill or "FREE", attempts = 0, made = 0 } or nil
	pcall(dressStadium, teams[1].kit, teams[2].kit)
	courtStyle = math.clamp(math.floor(tonumber(spec.court) or 1), 1, #Teams.COURTS)
	applyCourtStyle(courtStyle)
	pointsToWin = spec.points or Config.POINTS_TO_WIN
	setsToWin = spec.sets or Config.SETS_TO_WIN
	matchContext = spec
	matchActive = true
	phase = "setup"
	for _, entry in spec.players do
		local slot = addPlayer(entry.player, entry.team, entry.slot, entry.custom)
		if slot then
			slot.override = entry.override
		end
	end

	-- AI bodies for everyone else, built together
	local building = 0
	for t = 1, 2 do
		for _, sl in teams[t].slots do
			if sl.isAI then
				clearBody(sl)
				building += 1
				task.spawn(function()
					makeBot(sl)
					building -= 1
				end)
			end
		end
	end
	sendState()
	local waited = 0
	while building > 0 and waited < 12 do
		waited += task.wait(0.1)
	end
	if not matchActive then
		return
	end
	startMatch()
end

-- your Edit Player choices: shirt number and whether you wear the team kit
function cleanCustom(custom)
	if type(custom) ~= "table" then
		return nil
	end
	return { number = math.clamp(math.floor(tonumber(custom.number) or 7), 1, 99), wearKit = custom.wearKit == true }
end

local function quickPlay(plr, data)
	local count = #Teams.list
	local home = math.clamp(math.floor(tonumber(data.home) or 1), 1, count)
	local away = math.clamp(math.floor(tonumber(data.away) or 2), 1, count)
	if away == home then
		away = home % count + 1
	end
	local points, sets = tonumber(data.points), tonumber(data.sets)
	local drills = { SERVE = true, RECEIVE = true, ATTACK = true, FREE = true }
	beginMatch({
		mode = data.mode == "practice" and "practice" or "quick",
		drill = drills[data.drill] and data.drill or "FREE",
		kit = tonumber(data.kit),
		court = tonumber(data.court),
		home = home,
		away = away,
		plan = type(data.plan) == "table" and data.plan or { lineup = data.lineup },
		points = (points == 15 or points == 21 or points == 25) and points or nil,
		sets = (sets == 1 or sets == 2 or sets == 3) and sets or nil,
		players = { {
			player = plr,
			team = 1,
			slot = math.clamp(math.floor(tonumber(data.slot) or 2), 1, TEAM_SIZE),
			custom = cleanCustom(data.custom),
		} },
	})
end

-- Substitution: a bench player comes on for one on the court (his body is rebuilt)
local function substitute(plr, data)
	local ctrl = controllers[plr]
	if not ctrl then
		return
	end
	local team = teams[ctrl.team]
	local outIndex, inIndex = tonumber(data.out), tonumber(data.into)
	local at = outIndex and table.find(team.lineup, outIndex)
	local squad = Teams.squad(team.defId)
	if not at or not inIndex or not squad[inIndex] or table.find(team.lineup, inIndex) or inIndex == team.plan.libero then
		return
	end
	if team.subs >= (Config.SUBS_PER_SET or 6) then
		remote:FireClient(plr, "notice", "No substitutions left this set")
		return
	end
	local target = team.slots[at]
	if not target.isAI then
		remote:FireClient(plr, "notice", "People can't be substituted")
		return
	end
	local lineup = table.clone(team.lineup)
	lineup[at] = inIndex
	local plan = table.clone(team.plan)
	plan.lineup = lineup
	team.plan = Teams.cleanPlan(team.defId, plan)
	applyPlan(ctrl.team)
	team.subs += 1
	target.meter, target.boost = 0, nil
	clearBody(target)
	task.spawn(makeBot, target)
	banner("SUBSTITUTION", "ON " .. squad[inIndex].last .. "   ·   OFF " .. squad[outIndex].last, ctrl.team)
	sendState()
end

---------------------------------------------------------------- input from players

remote.OnServerEvent:Connect(function(plr, action, data)
	if action == "sync" then
		sendState(plr)
		sendBall(plr)
		return
	end
	if type(data) ~= "table" then
		return
	end
	if action == "start" then
		if data.mode == "career" or data.mode == "online" then
			return -- handled with the career and online code
		end
		if not controllers[plr] then
			if matchActive then
				addPlayer(plr, tonumber(data.team) == 2 and 2 or 1, tonumber(data.slot), cleanCustom(data.custom))
			else
				quickPlay(plr, data)
			end
		end
		return
	elseif action == "leave" then
		if controllers[plr] then
			removePlayer(plr)
			moveOffCourt(plr)
		end
		return
	end

	local ctrl = controllers[plr]
	if not matchActive or not ctrl then
		return
	end
	-- things you can do from the pause menu
	if action == "pause" then
		setPaused(data.on == true, plr.DisplayName)
		return
	elseif action == "sub" then
		substitute(plr, data)
		return
	elseif action == "timeout" then
		if not callTimeout(ctrl.team, plr.DisplayName) then
			remote:FireClient(plr, "notice", "Timeouts can only be called between rallies (two per set)")
		end
		return
	elseif action == "plan" then
		-- tactics and roles during the match (the lineup changes only by substitution)
		local team = teams[ctrl.team]
		local plan = table.clone(team.plan)
		if type(data.tactics) == "table" then
			plan.tactics = data.tactics
		end
		for _, r in Teams.ROLE_SLOTS do
			if data[r.key] ~= nil then
				plan[r.key] = data[r.key]
			end
		end
		team.plan = Teams.cleanPlan(team.defId, plan)
		applyPlan(ctrl.team)
		sendState()
		return
	end
	local slot = slotOfPlayer[plr]
	if not slot or not slot.root or not slot.humanoid then
		return
	elseif paused then
		return -- nothing moves while the match is paused
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
			-- serving from inside the court is a foot fault (a jump serve may land inside)
			if not air and (rootPos.Z - C.Z) * side(slot.team) < HALF_L - 0.3 then
				serveFault(slot, "FOOT FAULT")
				return
			end
			local fallback = floorPoint(3 - slot.team, 0, HALF_L * 0.5)
			doServe(slot, aim or fallback, tonumber(data.power) or 0.5, air, rootPos)
		end
	elseif action == "prep" then
		if phase == "serve" and currentServer() == slot and t - (slot.lastPrep or 0) > 1 then
			slot.lastPrep = t
			act(slot, "serveprep")
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
		if t - (slot.lastDive or 0) > 1 then
			slot.lastDive = t
			slot.diveUntil = t + 0.7
			act(slot, "dive")
		end
	elseif action == "ability" then
		activateAbility(slot)
	elseif action == "call" then
		-- calling for a quick set: the next set comes to you, fast and low
		teams[slot.team].call = { slot = slot, untilT = t + 4 }
		remote:FireClient(plr, "called")
	end
end)

---------------------------------------------------------------- start

-- nobody plays until they start a match from the menu
Players.PlayerRemoving:Connect(removePlayer)

-- controls, menus and HUD for everyone
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

-- shift lock for the "behind player" camera
pcall(function()
	StarterPlayer.EnableMouseLockOption = true
end)
local function allowShiftLock(plr)
	pcall(function()
		plr.DevEnableMouseLock = true
	end)
end

-- The animation pack (Config.ANIMATION_PACK): read the bundle's outfit for its animation
-- assets, build one body with them, and take the animation IDs Roblox puts in it
local PACK_FIELDS = { "IdleAnimation", "WalkAnimation", "RunAnimation", "JumpAnimation", "FallAnimation", "ClimbAnimation", "SwimAnimation" }
local packDescription = nil -- the pack's animation assets, put on people's characters too

local function applyPackTo(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not packDescription or not hum then
		return
	end
	pcall(function()
		local desc = hum:GetAppliedDescription()
		for _, field in PACK_FIELDS do
			if packDescription[field] ~= 0 then
				desc[field] = packDescription[field]
			end
		end
		hum:ApplyDescription(desc)
	end)
end

task.spawn(function()
	local bundleId = tonumber(Config.ANIMATION_PACK) or 0
	if bundleId <= 0 then
		return
	end
	local AssetService = game:GetService("AssetService")
	local ok, details = pcall(AssetService.GetBundleDetailsAsync, AssetService, bundleId)
	if not ok or type(details) ~= "table" then
		warn("[Arena Volleyball] Couldn't read the animation pack: " .. tostring(details))
		return
	end
	local desc = nil
	for _, item in details.Items or {} do
		if item.Type == "UserOutfit" then
			local got, outfit = pcall(Players.GetHumanoidDescriptionFromOutfitId, Players, item.Id)
			if got and outfit then
				desc = outfit
				break
			end
		end
	end
	if not desc then
		-- no outfit in the bundle: match its animations by name
		desc = Instance.new("HumanoidDescription")
		local words = { idle = "IdleAnimation", walk = "WalkAnimation", run = "RunAnimation", jump = "JumpAnimation", fall = "FallAnimation", climb = "ClimbAnimation", swim = "SwimAnimation" }
		for _, item in details.Items or {} do
			if item.Type == "Asset" then
				for word, field in words do
					if string.find(string.lower(item.Name or ""), word) then
						desc[field] = item.Id
					end
				end
			end
		end
	end
	local probe = Instance.new("HumanoidDescription")
	for _, field in PACK_FIELDS do
		probe[field] = desc[field]
	end
	local built, model = pcall(Players.CreateHumanoidModelFromDescription, Players, probe, Enum.HumanoidRigType.R15)
	local animate = built and model and model:FindFirstChild("Animate")
	if not animate then
		warn("[Arena Volleyball] Couldn't load the animation pack's animations")
		return
	end
	local found = 0
	for _, name in { "idle", "walk", "run", "jump", "fall" } do
		local holder = animate:FindFirstChild(name)
		local anim = holder and holder:FindFirstChildWhichIsA("Animation")
		if anim and anim.AnimationId ~= "" then
			PACK[name] = anim.AnimationId
			found += 1
		end
	end
	model:Destroy()
	packDescription = probe
	shared:SetAttribute("PackIdle", PACK.idle)
	print("[Arena Volleyball] Animation pack loaded (" .. found .. " animations)")
	for _, plr in Players:GetPlayers() do
		applyPackTo(plr.Character)
	end
end)

-- people's own characters move with the pack too
local function watchPlayer(plr)
	allowShiftLock(plr)
	plr.CharacterAppearanceLoaded:Connect(applyPackTo)
	if plr.Character then
		task.spawn(applyPackTo, plr.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, plr in Players:GetPlayers() do
	watchPlayer(plr)
end

-- a plain body the menus dress in team kits
task.spawn(function()
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = SKIN[3], SKIN[3], SKIN[3]
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if ok and model then
		model.Name = "MenuModel"
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		model.Parent = shared
	end
end)

ball.mode = "hidden"
local lastError = 0
RunService.Heartbeat:Connect(function(dt)
	if not matchActive or paused then
		return
	end
	local ok, err = pcall(function()
		local t = now()
		stepBall(t)
		updateMatch(t)
		-- take turns going first, and apply AI touches once both teams have decided
		local first = (math.floor(t * 60) % 2) + 1
		aiTeam(first, t, dt)
		aiTeam(3 - first, t, dt)
		flushTouches()
	end)
	if not ok and os.clock() - lastError > 3 then
		lastError = os.clock()
		warn("[Arena Volleyball] " .. tostring(err))
	end
end)

print("[Arena Volleyball] Ready. Start a match from the menu.")
