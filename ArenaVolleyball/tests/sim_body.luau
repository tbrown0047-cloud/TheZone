
---------------------------------------------------------------- headless AI vs AI match

-- fake bodies: walk toward MoveTo goals at WalkSpeed, jump with JumpPower 50
for t = 1, 2 do
	for _, sl in teams[t].slots do
		local root = { Position = homeSpot(sl) + Vector3.new(0, 3, 0), Size = Vector3.new(2, 2, 1), vy = 0, AssemblyLinearVelocity = Vector3.zero }
		root.CFrame = { Lerp = function(self) return self end }
		local hum = { HipHeight = 2, WalkSpeed = 16, FloorMaterial = "Plastic", Jump = false }
		function hum:MoveTo(p)
			self.goal = p
		end
		sl.root, sl.humanoid = root, hum
		sl.model = {
			PivotTo = function(_, cf)
				root.Position = cf.Position
				root.vy = 0
			end,
		}
	end
end

local function stepBodies(dt)
	for t = 1, 2 do
		for _, sl in teams[t].slots do
			local r, h = sl.root, sl.humanoid
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
			local pos = Vector3.new(r.Position.X, y, r.Position.Z)
			if h.goal then
				local d = Vector3.new(h.goal.X - pos.X, 0, h.goal.Z - pos.Z)
				local m = d.Magnitude
				local stepLen = h.WalkSpeed * dt
				if m <= stepLen then
					pos = Vector3.new(h.goal.X, y, h.goal.Z)
					h.goal = nil
				else
					pos = pos + d * (stepLen / m)
				end
			end
			r.Position = pos
		end
	end
end

startMatch()
local dt = 1 / 60
local minutes = 20
for _ = 1, 60 * 60 * minutes do
	CLOCK += dt
	stepBodies(dt)
	stepBall(CLOCK)
	updateMatch(CLOCK)
	aiTeam(1, CLOCK)
	aiTeam(2, CLOCK)
end

-- tally what happened
local reasons, hits, wins, points = {}, {}, {}, 0
local rallyTouches, current = {}, 0
for _, e in EVENTS do
	if e.kind == "fx" and e.a == "hit" then
		hits[e.c.kind] = (hits[e.c.kind] or 0) + 1
		if e.c.kind ~= "serve" then
			current += 1
		end
	elseif e.kind == "fx" and e.a == "block" then
		hits.block = (hits.block or 0) + 1
	elseif e.kind == "banner" then
		if string.find(e.a, "POINT") or string.find(e.a, "WIN") or string.find(e.a, "SET") and not string.find(e.a, "FIRST") then
			if string.find(e.a, " WIN") then
				table.insert(wins, e.a .. " " .. e.b)
			end
			points += 1
			local r = string.find(e.a, "POINT") and e.b or "set/match point"
			reasons[r] = (reasons[r] or 0) + 1
			table.insert(rallyTouches, current)
			current = 0
		end
	end
end
print(string.format("%d simulated minutes: %d points, %d matches finished", minutes, points, #wins))
for _, w in wins do
	print("  " .. w)
end
print("how points ended:")
for r, n in reasons do
	print(string.format("  %-22s %d", r, n))
end
print("touches by type:")
for k, n in hits do
	print(string.format("  %-8s %d", k, n))
end
local total, longest = 0, 0
for _, n in rallyTouches do
	total += n
	longest = math.max(longest, n)
end
print(string.format("average touches per rally %.1f, longest %d", total / math.max(#rallyTouches, 1), longest))
print("final phase: " .. phase .. "  score " .. teams[1].score .. "-" .. teams[2].score)
