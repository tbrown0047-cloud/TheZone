
---------------------------------------------------------------- tests (appended after server_3)

local function runUntilRest(limit)
	local t = CLOCK
	while ball.mode == "fly" and t < limit do
		t += 1 / 60
		stepBall(t)
	end
	CLOCK = t
end

local function lastBanner()
	for i = #EVENTS, 1, -1 do
		if EVENTS[i].kind == "banner" then
			return EVENTS[i].a .. " / " .. EVENTS[i].b
		end
	end
	return "no point"
end

local function netClearance()
	local p0, v0 = ball.p0, ball.v0
	local s = (C.Z - p0.Z) / v0.Z
	if s <= 0 then
		return 0 / 0
	end
	return p0.Y + v0.Y * s - 0.5 * G * s * s - GY
end

local function reset(lastTeam, touches, lastKind)
	EVENTS = {}
	teams[1].score, teams[2].score = 0, 0
	ball.live = true
	ball.lastTeam, ball.touches, ball.lastSlot, ball.lastKind = lastTeam, touches, nil, lastKind
end

print("== serves from HOME's end line (net is " .. NET_H .. " high)")
for _, case in { { 0.05, false }, { 0.2, false }, { 0.45, false }, { 0.65, false }, { 0.8, false }, { 0.9, false }, { 0.96, false }, { 1, false }, { 0.8, true }, { 1, true } } do
	reset(0, 0, nil)
	ball.mode = "hold"
	ball.live = false
	local srv = teams[1].slots[1]
	doServe(srv, floorPoint(2, 0, 15), case[1], case[2], Vector3.new(C.X, GY + 3, C.Z + HALF_L + 3))
	local clear = netClearance()
	local tau = landTime() - ball.t0
	runUntilRest(CLOCK + 10)
	print(string.format("  power %.2f %s  flight %.2fs  height over net %.1f  -> %s", case[1], case[2] and "jump " or "stand", tau, clear, lastBanner()))
end

print("== AWAY passes a serve at different spots (should reach the set spot near the net)")
for _, lx in { -8, 0, 8 } do
	reset(1, 0, "serve")
	local slot = teams[2].slots[1]
	local bp = Vector3.new(C.X + lx, GY + 3, C.Z - 18)
	touch(slot, "bump", bp, CLOCK, nil, 0.95)
	local spot = setSpot(2)
	local th = heightTime(spot.Y)
	local at = ballPos(th)
	print(string.format("  from x=%d: apex %.1f above floor, arrives %.1f studs from the set spot after %.2fs", lx, ball.p0.Y + ball.v0.Y ^ 2 / (2 * G) - GY, flatDist(at, spot), th - ball.t0))
	runUntilRest(CLOCK + 10)
end

print("== AWAY sets to an attacker on the right")
reset(2, 1, "bump")
teams[2].slots[2].root = { Position = Vector3.new(C.X + 7, GY + 3, C.Z - 10) }
local setter = teams[2].slots[1]
touch(setter, "set", setSpot(2), CLOCK, nil, 0.95)
local spot = attackSpot(2, teams[2].slots[2])
local th = heightTime(spot.Y)
print(string.format("  set peaks %.1f above floor, comes down through the attack spot %.1f studs off, %.2fs after the set", ball.p0.Y + ball.v0.Y ^ 2 / (2 * G) - GY, flatDist(ballPos(th), spot), th - ball.t0))
runUntilRest(CLOCK + 10)

print("== AWAY spikes (attack spot is 3.5 studs from the net, contact 9.5 high)")
for _, case in { { 3.5, 20, 0 }, { 3.5, 6, 8 }, { 3.5, 26, -12 }, { 10, 20, 0 }, { 14, 22, 5 } } do
	reset(2, 2, "set")
	local attacker = teams[2].slots[2]
	attacker.isAI = false
	local bp = Vector3.new(C.X + 6, GY + 9.5, C.Z - case[1])
	touch(attacker, "spike", bp, CLOCK, floorPoint(1, case[3], case[2]), 1)
	local clear = netClearance()
	local speed = ball.v0.Magnitude
	runUntilRest(CLOCK + 10)
	print(string.format("  from %.1f off the net, aim %d deep: speed %.0f, height over net %.1f -> %s", case[1], case[2], speed, clear, lastBanner()))
end

print("== HOME blocker in the air at the net vs an AWAY spike")
reset(2, 2, "set")
local blocker = teams[1].slots[1]
blocker.isAI = false
blocker.humanoid = {}
blocker.root = { Position = Vector3.new(C.X + 6, GY + 7.5, C.Z + 1.6) }
touch(teams[2].slots[2], "spike", Vector3.new(C.X + 6, GY + 10.5, C.Z - 3), CLOCK, floorPoint(1, 6, 18), 1)
runUntilRest(CLOCK + 10)
local blocked = false
for _, e in EVENTS do
	if e.kind == "fx" and e.a == "block" then
		blocked = true
	end
end
print("  blocked: " .. tostring(blocked) .. "  -> " .. lastBanner())

print("== rules")
reset(1, 0, "serve")
local p1 = teams[2].slots[1]
touch(p1, "bump", Vector3.new(C.X, GY + 3, C.Z - 15), CLOCK, nil, 0.9)
touch(p1, "bump", Vector3.new(C.X, GY + 3, C.Z - 14), CLOCK, nil, 0.9)
print("  same player twice: " .. lastBanner())
reset(2, 3, "set")
touch(teams[2].slots[1], "bump", Vector3.new(C.X, GY + 3, C.Z - 6), CLOCK, nil, 0.9)
print("  fourth touch: " .. lastBanner())
reset(2, 0, "bump")
ball.live = true
launch(Vector3.new(C.X + 20, GY + 9, C.Z - 3), Vector3.new(0, 4, 20), CLOCK)
runUntilRest(CLOCK + 10)
print("  over the net outside the antenna: " .. lastBanner())
reset(2, 1, "bump")
launch(Vector3.new(C.X, GY + 4, C.Z - 6), Vector3.new(0, 2, 30), CLOCK)
runUntilRest(CLOCK + 10)
print("  into the net, drops on AWAY's side: " .. lastBanner())

print("== deep serves (aim 24 of 27 deep)")
for _, pw in { 0.7, 0.85, 0.95, 1 } do
	reset(0, 0, nil)
	ball.mode = "hold"
	ball.live = false
	doServe(teams[1].slots[1], floorPoint(2, 4, 24), pw, false, Vector3.new(C.X, GY + 3, C.Z + HALF_L + 3))
	runUntilRest(CLOCK + 10)
	print(string.format("  power %.2f -> %s", pw, lastBanner()))
end
