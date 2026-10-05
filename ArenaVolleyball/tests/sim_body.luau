
---------------------------------------------------------------- headless AI vs AI matches

-- fake bodies: walk where Humanoid:Move points at WalkSpeed, jump with JumpPower 50
local function giveBodies()
	for t = 1, 2 do
		for _, sl in teams[t].slots do
			local root = { Position = homeSpot(sl) + Vector3.new(0, 3, 0), Size = Vector3.new(2, 2, 1), vy = 0, AssemblyLinearVelocity = Vector3.zero }
			local hum = { HipHeight = 2, WalkSpeed = 16, FloorMaterial = "Plastic", Jump = false, moveDir = Vector3.zero }
			function hum:Move(dir)
				self.moveDir = dir
			end
			sl.root, sl.humanoid = root, hum
			sl.model = {
				PivotTo = function(_, cf)
					root.Position = cf.Position
					root.vy = 0
				end,
				Destroy = function() end,
				FindFirstChildOfClass = function() return nil end,
				FindFirstChild = function() return nil end,
				GetDescendants = function() return {} end,
			}
			sl.ai = { vel = Vector3.zero, pace = 1, drift = 0 }
		end
	end
end

local travelled = 0
local function stepBodies(dt)
	for t = 1, 2 do
		for _, sl in teams[t].slots do
			local r, h = sl.root, sl.humanoid
			if r and h then
				local stand = GY + 3
				if h.Jump and r.Position.Y <= stand + 0.01 then
					r.vy = 50
				end
				h.Jump = false
				local y = r.Position.Y + r.vy * dt
				r.vy -= 196.2 * dt
				if y <= stand then
					y, r.vy = stand, 0
				end
				h.FloorMaterial = (y > stand + 0.01) and Enum.Material.Air or "Plastic"
				local step = h.moveDir * (h.WalkSpeed * dt)
				travelled += step.Magnitude
				r.Position = Vector3.new(r.Position.X + step.X, y, r.Position.Z + step.Z)
				r.AssemblyLinearVelocity = h.moveDir * h.WalkSpeed
			end
		end
	end
end

-- HOME 5 stars against AWAY 1.5 stars, then two evenly matched clubs
local fixtures = { { 1, 12 }, { 5, 6 } }
local results = {}
local dt = 1 / 60
for _, fixture in fixtures do
	configureTeams(fixture[1], fixture[2])
	local wins = { 0, 0 }
	local points = { 0, 0 }
	for _ = 1, 3 do
		giveBodies()
		matchActive = true
		startMatch()
		local limit = CLOCK + 60 * 30
		while matchActive and CLOCK < limit do
			CLOCK += dt
			stepBodies(dt)
			stepBall(CLOCK)
			updateMatch(CLOCK)
			if matchActive then
				local first = (math.floor(CLOCK * 60) % 2) + 1
				aiTeam(first, CLOCK, dt)
				aiTeam(3 - first, CLOCK, dt)
				flushTouches()
			end
		end
		if teams[1].sets > teams[2].sets then
			wins[1] += 1
		else
			wins[2] += 1
		end
		points[1] += teams[1].score
		points[2] += teams[2].score
	end
	table.insert(results, { fixture = fixture, wins = wins, points = points })
end

-- tally what happened
local reasons, hits, banners = {}, {}, 0
local rallyTouches, current = {}, 0
for _, e in EVENTS do
	if e.kind == "fx" and e.a == "hit" then
		hits[e.c.kind] = (hits[e.c.kind] or 0) + 1
		if e.c.kind ~= "serve" then
			current += 1
		end
	elseif e.kind == "fx" and e.a == "block" then
		hits.block = (hits.block or 0) + 1
	elseif e.kind == "act" then
		hits["anim:" .. e.b] = (hits["anim:" .. e.b] or 0) + 1
	elseif e.kind == "banner" and (string.find(e.a, "POINT") or string.find(e.a, " WIN")) then
		banners += 1
		local r = string.find(e.a, "POINT") and e.b or "set/match point"
		reasons[r] = (reasons[r] or 0) + 1
		table.insert(rallyTouches, current)
		current = 0
	end
end
for _, r in results do
	local a, b = Teams.list[r.fixture[1]], Teams.list[r.fixture[2]]
	print(string.format("%s (%.1f stars) v %s (%.1f stars): matches %d-%d, final-set points %d-%d", a.name, Teams.stars(Teams.ratings(r.fixture[1]).OVR), b.name, Teams.stars(Teams.ratings(r.fixture[2]).OVR), r.wins[1], r.wins[2], r.points[1], r.points[2]))
end
print("how points ended:")
for r, n in reasons do
	print(string.format("  %-22s %d", r, n))
end
print("touches and animation cues:")
local keys = {}
for k in hits do
	table.insert(keys, k)
end
table.sort(keys)
for _, k in keys do
	print(string.format("  %-16s %d", k, hits[k]))
end
local total = 0
for _, n in rallyTouches do
	total += n
end
print(string.format("average touches per rally %.1f; AI players moved %.0f studs per point on average", total / math.max(#rallyTouches, 1), travelled / math.max(banners, 1) / 12))
print("final phase: " .. phase .. "  active " .. tostring(matchActive))

-- someone in switch mode on HOME (who never plays the ball): auto switching must follow the play
do
	local fake = { UserId = 1, DisplayName = "Tester" }
	configureTeams(3, 4)
	giveBodies()
	controllers[fake] = { team = 1, mode = "switch", home = 2, auto = true }
	pilotSlot(fake, teams[1].slots[2])
	local switches, last, bad = 0, slotOfPlayer[fake], 0
	matchActive = true
	startMatch()
	local limit = CLOCK + 60 * 4
	while matchActive and CLOCK < limit do
		CLOCK += dt
		stepBodies(dt)
		stepBall(CLOCK)
		updateMatch(CLOCK)
		if matchActive then
			aiTeam(1, CLOCK, dt)
			aiTeam(2, CLOCK, dt)
			flushTouches()
		end
		if slotOfPlayer[fake] ~= last then
			switches += 1
			last = slotOfPlayer[fake]
		end
		if matchActive then
			local piloted = 0
			for _, s in teams[1].slots do
				if s.player == fake then
					piloted += 1
				end
			end
			if piloted ~= 1 then
				bad += 1
			end
		end
	end
	print(string.format("switch mode: %d switches, %d frames not controlling exactly one body (should be 0), score %d-%d (he never plays the ball)", switches, bad, teams[1].score, teams[2].score))
	controllers[fake] = nil
end
