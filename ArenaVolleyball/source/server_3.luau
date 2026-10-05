
---------------------------------------------------------------- the ball
-- The ball is pure maths: a start point, a velocity and a start time. Clients draw it
-- from the same numbers, so it looks smooth for everyone and the server decides points.

local ball = {
	id = 0,
	mode = "rest", -- hold, fly, rest
	p0 = C + Vector3.new(0, R, 0),
	v0 = Vector3.zero,
	t0 = 0,
	netDone = false,
	bounces = 0,
	live = false,
	lastTeam = 0,
	lastSlot = nil,
	lastKind = nil,
	touches = 0,
	holder = nil,
	restPos = C + Vector3.new(0, R, 0),
}

local GV = Vector3.new(0, -G, 0)
local FLOOR = GY + R -- ball centre height when it touches the floor

local function ballPos(t)
	local dt = t - ball.t0
	return ball.p0 + ball.v0 * dt + GV * (0.5 * dt * dt)
end

local function ballVel(t)
	return ball.v0 + GV * (t - ball.t0)
end

-- Time when the ball comes down through height h, or nil if it never gets that high
local function heightTime(h)
	local vy = ball.v0.Y
	local disc = vy * vy + 2 * G * (ball.p0.Y - h)
	if disc < 0 then
		return nil
	end
	return ball.t0 + (vy + math.sqrt(disc)) / G
end

local function landTime()
	return math.max(heightTime(FLOOR) or ball.t0, ball.t0)
end

local function netTime()
	if ball.netDone or math.abs(ball.v0.Z) < 1e-3 then
		return math.huge
	end
	local s = (C.Z - ball.p0.Z) / ball.v0.Z
	if s <= 1e-4 then
		return math.huge
	end
	return ball.t0 + s
end

local function ballPacket()
	local holder = nil
	if ball.mode == "hold" and ball.holder then
		holder = ball.holder.model
	end
	return {
		id = ball.id,
		mode = ball.mode,
		p0 = ball.p0,
		v0 = ball.v0,
		t0 = ball.t0,
		rest = ball.restPos,
		holder = holder,
	}
end

function sendBall(plr)
	if plr then
		remote:FireClient(plr, "ball", ballPacket())
	else
		remote:FireAllClients("ball", ballPacket())
	end
end

local function launch(p, v, t, netDone, keepBounces)
	if p.Y < FLOOR + 0.05 then
		p = Vector3.new(p.X, FLOOR + 0.05, p.Z)
	end
	ball.id += 1
	ball.mode = "fly"
	ball.p0, ball.v0, ball.t0 = p, v, t
	ball.netDone = netDone == true
	if not keepBounces then
		ball.bounces = 0
		ball.netHit = false
	end
	sendBall()
end

local function banner(title, sub, team)
	remote:FireAllClients("banner", title, sub or "", team or 0)
end

---------------------------------------------------------------- aiming helpers

-- Velocity that carries the ball from p to target in tau seconds
local function solve(p, target, tau)
	return (target - p) / tau + Vector3.new(0, 0.5 * G * tau, 0)
end

local function clearsNet(p, v)
	if math.abs(v.Z) < 1e-3 then
		return true
	end
	local s = (C.Z - p.Z) / v.Z
	if s <= 0 then
		return true
	end
	local y = p.Y + v.Y * s - 0.5 * G * s * s
	return y >= GY + NET_H + R + 0.25
end

-- Like solve, but floats the ball a little higher until it clears the net
local function solveOver(p, target, tau, maxTau)
	local v = solve(p, target, tau)
	while not clearsNet(p, v) and tau < maxTau do
		tau += 0.05
		v = solve(p, target, tau)
	end
	return v
end

local function jitter(radius)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = radius * math.sqrt(rng:NextNumber())
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

-- A point on team's half: lx across the court, lz = distance from the net
local function floorPoint(team, lx, lz)
	return Vector3.new(C.X + lx, FLOOR, C.Z + side(team) * lz)
end

local function setSpot(team)
	return floorPoint(team, 0, 4.5) + Vector3.new(0, 6, 0)
end

-- The teammate a set goes to: people first, then whoever is nearest the net
-- Lanes hitters attack from, across the court from the team's point of view
local LANE = { OH = -1, OPP = 1, MB = 0 }
local SET_WEIGHT = { OH = 4, OPP = 3, MB = 2 }

-- The teammate a set goes to: a person if there is one, otherwise a front-row hitter
-- (outside hitters most often, then the opposite, then a quick ball to the middle)
local function partnerOf(slot)
	local options, total, person = {}, 0, nil
	for _, s in teams[slot.team].slots do
		if s ~= slot and s.root then
			if not s.isAI and not person then
				person = s
			end
			local role = roleOf(s)
			if isFrontRow(s) and SET_WEIGHT[role] then
				table.insert(options, s)
				total += SET_WEIGHT[role]
			end
		end
	end
	if person then
		return person
	end
	if #options > 0 then
		local pick = rng:NextNumber(0, total)
		for _, s in options do
			pick -= SET_WEIGHT[roleOf(s)]
			if pick <= 0 then
				return s
			end
		end
		return options[#options]
	end
	-- nobody in the front row: whoever is nearest the net
	local best, bestZ = nil, math.huge
	for _, s in teams[slot.team].slots do
		if s ~= slot and s.root and math.abs(s.root.Position.Z - C.Z) < bestZ then
			best, bestZ = s, math.abs(s.root.Position.Z - C.Z)
		end
	end
	return best or slot
end

-- Where a set to this attacker is played: his lane, or where a person is standing
local function attackSpot(team, attacker)
	local s = side(team)
	local lx = s * HALF_W * 0.6 * -1
	if attacker and attacker.root then
		if attacker.isAI and TEAM_SIZE == 6 then
			lx = s * HALF_W * 0.6 * (LANE[roleOf(attacker)] or -1)
		else
			lx = math.clamp(attacker.root.Position.X - C.X, -HALF_W + 3, HALF_W - 3)
		end
	end
	return floorPoint(team, lx, 3.5) + Vector3.new(0, ATTACK_H - R, 0)
end

-- How hard a spike is hit: AI from the team's level, people from timing; both lifted by attack rating
local function spikeSpeed(slot, q)
	local attack = attr01(slot, "ATK")
	if slot.isAI then
		return teamAI(slot.team).spike * (0.82 + 0.36 * attack)
	end
	return (62 + 26 * q) * (0.9 + 0.2 * attack)
end

-- Animation cue for every player's screen
local function act(slot, kind)
	if slot and slot.model then
		remote:FireAllClients("act", slot.model, kind)
	end
end

-- Keeps an aim point on the other half, at most `margin` studs past the lines
local function clampToOpp(team, aim, margin)
	local s = side(3 - team)
	local lx = math.clamp(aim.X - C.X, -HALF_W - margin, HALF_W + margin)
	local lz = (aim.Z - C.Z) * s
	if lz < 0 then
		lz = HALF_L * 0.55
	end
	lz = math.clamp(lz, 2, HALF_L + margin)
	return Vector3.new(C.X + lx, FLOOR, C.Z + s * lz)
end

local function randomOpp(team, margin)
	return floorPoint(3 - team, rng:NextNumber(-HALF_W + margin, HALF_W - margin), rng:NextNumber(margin + 2, HALF_L - margin))
end

-- Picks an open spot on the other half, away from the defenders
local function smartTarget(team, margin)
	local best, bestD = nil, -1
	for _ = 1, 6 do
		local pnt = randomOpp(team, margin)
		local d = 99
		for _, s in teams[3 - team].slots do
			if s.root then
				d = math.min(d, flatDist(s.root.Position, pnt))
			end
		end
		if d > bestD then
			best, bestD = pnt, d
		end
	end
	return best
end

---------------------------------------------------------------- rules

local function nextTouchNo(team)
	if ball.lastTeam == team then
		return ball.touches + 1
	end
	return 1
end

local function awardPoint(winner, reason)
	if not ball.live then
		return
	end
	ball.live = false
	local w, l = teams[winner], teams[3 - winner]
	w.score += 1
	if servingTeam ~= winner then
		servingTeam = winner
		w.serveIndex = w.serveIndex % TEAM_SIZE + 1
	end
	if w.score >= pointsToWin and w.score - l.score >= Config.WIN_BY then
		w.sets += 1
		if w.sets >= setsToWin then
			phase, phaseUntil = "matchover", now() + 9
			banner(teams[winner].def.name .. " WIN", "FULL TIME   ·   " .. w.score .. " - " .. l.score, winner)
		else
			phase, phaseUntil = "setover", now() + 5
			banner(teams[winner].def.name .. " TAKE THE SET", w.score .. " - " .. l.score, winner)
		end
	else
		phase, phaseUntil = "point", now() + 3.4
		banner(teams[winner].def.short .. " POINT", reason, winner)
	end
	sendState()
end

-- Can this player play the ball from here? Returns ok and a timing quality 0..1.
local function reachCheck(slot, kind, rootPos, bp, airborne, t)
	if (bp.Z - C.Z) * side(slot.team) < -1.5 then
		return false -- the ball is over the other side
	end
	local d = bp - rootPos
	local flat = Vector3.new(d.X, 0, d.Z).Magnitude
	local reach = REACH + ((slot.diveUntil or 0) > t and 3.5 or 0) + (slot.isAI and 0 or 1.5)
	if flat > reach then
		return false
	end
	local lo, hi, ideal
	if kind == "spike" or kind == "tip" then
		if not airborne then
			return false
		end
		lo, hi, ideal = -2.5, 8, 3
	elseif kind == "set" then
		lo, hi, ideal = -2, 7, 3
	else
		lo, hi, ideal = -3.5, 5, 0
	end
	if d.Y < lo or d.Y > hi then
		return false
	end
	local q = 1 - (flat / reach) * 0.45 - math.clamp(math.abs(d.Y - ideal) / 6, 0, 1) * 0.35
	if kind == "bump" then
		local speed = ballVel(t).Magnitude
		if speed > 45 then
			q -= math.min((speed - 45) / 90, 0.35) -- hard spikes are harder to pass
		end
	end
	return true, math.clamp(q, 0.05, 1)
end

-- A pass or set may drift, but it stays on the passer's side of the net
local function ownSide(team, p, minLz)
	local s = side(team)
	if (p.Z - C.Z) * s < minLz then
		return Vector3.new(p.X, p.Y, C.Z + s * minLz)
	end
	return p
end

-- Works out where a touch sends the ball
local function shotFor(slot, kind, p, aim, q, touchNo)
	local team = slot.team
	if (kind == "bump" or kind == "set") and touchNo >= 3 then
		-- third touch has to go over
		local target = clampToOpp(team, (aim and clampToOpp(team, aim, 0) or randomOpp(team, 4)) + jitter((1 - q) * 8), 1)
		return solveOver(p, target, 1.25, 2.2), "over"
	elseif kind == "bump" then
		return solve(p, ownSide(team, setSpot(team) + jitter((1 - q) * 9), 1.5), 1.25), "bump"
	elseif kind == "set" then
		local hitter = partnerOf(slot)
		local quick = hitter.isAI and roleOf(hitter) == "MB" and TEAM_SIZE == 6
		return solve(p, ownSide(team, attackSpot(team, hitter) + jitter((1 - q) * 6), 1.5), quick and 0.8 or 1.15), "set"
	elseif kind == "tip" then
		local target = aim and clampToOpp(team, aim, 0)
			or floorPoint(3 - team, rng:NextNumber(-HALF_W + 3, HALF_W - 3), rng:NextNumber(3, 9))
		return solveOver(p, target + jitter((1 - q) * 3), 0.8, 1.6), "tip"
	end
	local target = clampToOpp(team, aim or randomOpp(team, 3), 3) + jitter((1 - q) * 7)
	local speed = spikeSpeed(slot, q)
	local flat = Vector3.new(target.X - p.X, 0, target.Z - p.Z).Magnitude
	return solveOver(p, target, math.max(flat / speed, 0.28), 1.3), "spike"
end

local function touch(slot, kind, p, t, aim, q)
	local team = slot.team
	local n = nextTouchNo(team)
	if TEAM_SIZE > 1 and ball.lastSlot == slot then
		awardPoint(3 - team, "DOUBLE TOUCH")
		return false
	end
	if n > 3 then
		awardPoint(3 - team, "FOUR HITS")
		return false
	end
	local v, shot = shotFor(slot, kind, p, aim, q, n)
	if n == 1 and ball.lastKind == "spike" and slot.stats then
		slot.stats.digs += 1
	end
	ball.touches, ball.lastTeam, ball.lastSlot, ball.lastKind = n, team, slot, shot
	slot.lastTouch = now()
	launch(p, v, t)
	act(slot, kind)
	remote:FireAllClients("fx", "hit", p, { kind = shot, q = q, user = slot.player and slot.player.UserId or 0, team = team, index = slot.index })
	sendState()
	return true
end

-- Someone on `team` jumping at the net in front of the ball?
local function findBlocker(team, p)
	local s = side(team)
	for _, sl in teams[team].slots do
		local hrp = sl.root
		if hrp and sl.humanoid then
			local rp = hrp.Position
			local depth = (rp.Z - C.Z) * s
			local airborne = rp.Y > standHeight(sl) + 1
			if airborne and depth > -0.5 and depth < 5 and math.abs(rp.X - p.X) < 3.8 and p.Y < rp.Y + 5.5 and p.Y > rp.Y - 1 then
				local win = math.min(teamAI(team).blockWin * (0.7 + 0.6 * attr01(sl, "BLK")), 0.92)
				if not (sl.isAI and rng:NextNumber() > win) then
					return sl
				end
			end
		end
	end
	return nil
end

local function doBlock(blocker, p, v, t)
	if blocker.stats then
		blocker.stats.blocks += 1
	end
	local back = -side(blocker.team) -- towards the attackers
	local np, nv
	if rng:NextNumber() < 0.6 then
		-- stuff block: straight back down on the attackers
		np = Vector3.new(p.X, p.Y, C.Z + back * (R + 0.3))
		nv = Vector3.new(v.X * 0.2 + rng:NextNumber(-4, 4), -6, back * rng:NextNumber(10, 18))
	else
		-- soft block: pops up on the blockers' side, still playable
		np = Vector3.new(p.X, p.Y, C.Z - back * (R + 0.3))
		nv = Vector3.new(rng:NextNumber(-3, 3), 20, -back * rng:NextNumber(5, 10))
	end
	-- a block isn't one of the three touches, and the blocker may play the ball next
	ball.lastTeam, ball.lastSlot, ball.touches, ball.lastKind = blocker.team, nil, 0, "block"
	launch(np, nv, t, true)
	remote:FireAllClients("fx", "block", np, {})
	sendState()
end

local function onNet(t)
	local p, v = ballPos(t), ballVel(t)
	local into = v.Z < 0 and 2 or 1 -- the team whose half the ball is heading into
	local s = side(into)
	if math.abs(p.X - C.X) > HALF_W + 0.5 then
		ball.netDone = true
		if ball.live then
			awardPoint(3 - ball.lastTeam, "OUTSIDE THE ANTENNA")
		end
		return
	end
	local h = p.Y - GY
	if h < NET_H - R then
		-- into the net: it drops back on the side it came from
		local np = Vector3.new(p.X, p.Y, C.Z - s * (R + 0.15))
		local nv = Vector3.new(v.X * 0.25, math.min(v.Y, 0) * 0.2 - 2, -s * math.abs(v.Z) * 0.15)
		launch(np, nv, t, true, true)
		ball.netHit = true
		remote:FireAllClients("fx", "net", np, {})
		return
	end
	if ball.live and ball.lastKind == "spike" then
		local blocker = findBlocker(into, p)
		if blocker then
			doBlock(blocker, p, v, t)
			return
		end
	end
	if h < NET_H + R then
		-- clips the tape and dribbles over
		local np = Vector3.new(p.X, GY + NET_H + R, C.Z + s * 0.05)
		local nv = Vector3.new(v.X * 0.6, math.abs(v.Y) * 0.3 + 3, v.Z * 0.45)
		launch(np, nv, t, true, true)
		remote:FireAllClients("fx", "net", np, {})
		return
	end
	ball.netDone = true
end

local function onLand(t)
	local p, v = ballPos(t), ballVel(t)
	local landP = Vector3.new(p.X, FLOOR, p.Z)
	if ball.live then
		local lx, lz = p.X - C.X, p.Z - C.Z
		local inside = math.abs(lx) <= HALF_W + R * 0.5 and math.abs(lz) <= HALF_L + R * 0.5
		if inside then
			local winner = lz > 0 and 2 or 1
			local reason = "IN"
			if ball.lastTeam == winner then
				if ball.lastKind == "serve" then
					reason = "ACE"
					if ball.lastSlot and ball.lastSlot.stats then
						ball.lastSlot.stats.aces += 1
					end
				elseif ball.lastKind == "spike" then
					reason = "KILL"
					if ball.lastSlot and ball.lastSlot.stats then
						ball.lastSlot.stats.kills += 1
					end
				elseif ball.lastKind == "block" then
					reason = "BLOCK"
				elseif ball.lastKind == "tip" then
					reason = "TIP"
				end
			else
				-- it fell on the side of the team that touched it last
				reason = ball.netHit and "INTO THE NET" or "DROPPED"
			end
			awardPoint(winner, reason)
		else
			awardPoint(3 - ball.lastTeam, "OUT")
		end
		remote:FireAllClients("fx", "land", landP, { inside = inside })
	end
	if ball.bounces < 2 and math.abs(v.Y) > 6 then
		ball.bounces += 1
		launch(landP, Vector3.new(v.X * 0.45, math.abs(v.Y) * 0.4, v.Z * 0.45), t, ball.netDone, true)
	else
		ball.mode = "rest"
		ball.restPos = landP
		sendBall()
	end
end

-- Moves the ball's story forward to time t, handling the net and the floor in order
local function stepBall(t)
	for _ = 1, 6 do
		if ball.mode ~= "fly" then
			return
		end
		local tl, tn = landTime(), netTime()
		if tn < tl and tn <= t then
			onNet(tn)
		elseif tl <= t then
			onLand(tl)
		else
			return
		end
	end
end

local function doServe(slot, aim, power, airborne, rootPos)
	local team = slot.team
	local s = side(team)
	local p = rootPos + Vector3.new(0, airborne and 3.2 or 2.6, -s * 1.2)
	if (p.Z - C.Z) * s < HALF_L + 0.5 then
		p = Vector3.new(p.X, p.Y, C.Z + s * (HALF_L + 0.5)) -- serve from behind the end line
	end
	p = Vector3.new(math.clamp(p.X, C.X - HALF_W, C.X + HALF_W), p.Y, p.Z)
	if power ~= power then
		power = 0.5
	end
	power = math.clamp(power, 0, 1)
	local target = clampToOpp(team, aim, 2)
	if power > 0.9 then
		-- over-hit: it sails long
		local dir = Vector3.new(target.X - p.X, 0, target.Z - p.Z).Unit
		target += dir * (power - 0.9) * 110
	end
	-- the green zone (65-90%) is the most accurate
	if power < 0.65 then
		target += jitter(1.5 + (0.65 - power) * 5)
	else
		target += jitter(0.8 + math.max(power - 0.9, 0) * 10)
	end
	local tau = 1.7 + ((airborne and 0.8 or 0.95) - 1.7) * power
	local v
	if power < 0.15 then
		-- under-hit: straight into the net
		v = solve(p, Vector3.new(target.X, GY + NET_H - 2.5, C.Z), 1.1)
	else
		v = solveOver(p, target, tau, 2.2)
	end
	ball.live = true
	ball.lastTeam, ball.lastSlot, ball.lastKind, ball.touches = team, slot, "serve", 0
	ball.holder = nil
	phase = "rally"
	launch(p, v, now())
	act(slot, airborne and "jumpserve" or "serve")
	remote:FireAllClients("fx", "hit", p, { kind = "serve", q = 1, user = slot.player and slot.player.UserId or 0, team = team, index = slot.index })
	sendState()
end
