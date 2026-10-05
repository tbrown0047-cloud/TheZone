
---------------------------------------------------------------- animations
-- Hand-made poses for passes, sets, spikes, tips, serves, blocks and dives. Each
-- player's screen layers them on every character (people and AI) over the normal
-- walk and run, so everyone sees the same thing. Angles are degrees; the fourth
-- number lowers or raises the body.

local Anim = {
	active = setmetatable({}, { __mode = "k" }),
	weights = setmetatable({}, { __mode = "k" }),
	motors = setmetatable({}, { __mode = "k" }),
}

local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
}

local function J(rx, ry, rz, ty)
	return { rx or 0, ry or 0, rz or 0, ty or 0 }
end
local ZERO = J()

-- held positions, blended in and out automatically
local READY = {
	Root = J(0, 0, 0, -0.35), Waist = J(-12), Neck = J(10),
	RightHip = J(28), LeftHip = J(28), RightKnee = J(-48), LeftKnee = J(-48),
	RightShoulder = J(28, 0, 8), LeftShoulder = J(28, 0, -8), RightElbow = J(45), LeftElbow = J(45),
}
local COCK = {
	RightShoulder = J(160, 0, 25), RightElbow = J(115), LeftShoulder = J(135, 0, -12), LeftElbow = J(18),
	Waist = J(20, -15, 0), Neck = J(15),
	RightHip = J(-8), LeftHip = J(12), RightKnee = J(-55), LeftKnee = J(-40),
}
local BLOCK = {
	RightShoulder = J(168, 0, 10), LeftShoulder = J(168, 0, -10), RightElbow = J(4), LeftElbow = J(4),
	RightWrist = J(15), LeftWrist = J(15), Neck = J(8),
	RightHip = J(8), LeftHip = J(8), RightKnee = J(-25), LeftKnee = J(-25),
}
local TOSS = {
	LeftShoulder = J(150, 0, -6), LeftElbow = J(10), RightShoulder = J(150, 0, 30), RightElbow = J(110),
	Waist = J(14, -18, 0), Neck = J(25), RightHip = J(-6), LeftHip = J(14), LeftKnee = J(-18), RightKnee = J(-10),
}
local STRIKE = {
	RightShoulder = J(55, 0, 8), RightElbow = J(8), LeftShoulder = J(30, 0, -5), LeftElbow = J(40),
	Waist = J(-24, 12, 0), Neck = J(-5), RightHip = J(30), LeftHip = J(20), RightKnee = J(-35), LeftKnee = J(-30),
}
local DIVE = {
	Root = J(-70, 0, 0, -1.05), RightShoulder = J(165, 0, 12), LeftShoulder = J(165, 0, -12),
	RightHip = J(-12), LeftHip = J(-12), RightKnee = J(-30), LeftKnee = J(-30), Neck = J(45),
}

-- one-off moves: { seconds, pose } keyframes; `hold` keeps the last one until replaced
local POSES = {
	bump = { keys = {
		{ 0, {} },
		{ 0.1, {
			Root = J(0, 0, 0, -0.6), Waist = J(-18), RightHip = J(38), LeftHip = J(38), RightKnee = J(-70), LeftKnee = J(-70),
			RightShoulder = J(70, 0, -14), LeftShoulder = J(70, 0, 14), RightWrist = J(-10), LeftWrist = J(-10),
		} },
		{ 0.24, {
			Root = J(0, 0, 0, -0.25), Waist = J(-6), RightHip = J(18), LeftHip = J(18), RightKnee = J(-30), LeftKnee = J(-30),
			RightShoulder = J(92, 0, -14), LeftShoulder = J(92, 0, 14),
		} },
		{ 0.55, {} },
	} },
	set = { keys = {
		{ 0, {} },
		{ 0.12, {
			Root = J(0, 0, 0, -0.3), RightHip = J(16), LeftHip = J(16), RightKnee = J(-32), LeftKnee = J(-32),
			RightShoulder = J(150, 0, 22), LeftShoulder = J(150, 0, -22), RightElbow = J(85), LeftElbow = J(85),
			RightWrist = J(-30), LeftWrist = J(-30), Neck = J(22),
		} },
		{ 0.24, {
			Root = J(0, 0, 0, 0.05), RightKnee = J(-6), LeftKnee = J(-6),
			RightShoulder = J(172, 0, 10), LeftShoulder = J(172, 0, -10), RightElbow = J(12), LeftElbow = J(12), Neck = J(18),
		} },
		{ 0.55, {} },
	} },
	spike = { keys = { { 0, COCK }, { 0.07, STRIKE }, { 0.45, {} } } },
	jumpserve = { keys = { { 0, COCK }, { 0.07, STRIKE }, { 0.5, {} } } },
	tip = { keys = {
		{ 0, { RightShoulder = J(150, 0, 20), RightElbow = J(70), LeftShoulder = J(120, 0, -10), Waist = J(10) } },
		{ 0.14, { RightShoulder = J(172, 0, 6), RightElbow = J(5), RightWrist = J(35), LeftShoulder = J(80, 0, -10) } },
		{ 0.45, {} },
	} },
	serveprep = { hold = 3.5, keys = { { 0, {} }, { 0.35, TOSS } } },
	serve = { keys = {
		{ 0, TOSS },
		{ 0.09, { RightShoulder = J(150, 0, 5), RightElbow = J(5), LeftShoulder = J(60, 0, -10), LeftElbow = J(30), Waist = J(-8, 10, 0), Neck = J(10) } },
		{ 0.25, { RightShoulder = J(40, 0, -10), RightElbow = J(20), LeftShoulder = J(30, 0, -10), Waist = J(-16, 12, 0), RightHip = J(20) } },
		{ 0.6, {} },
	} },
	dive = { keys = { { 0, {} }, { 0.14, DIVE }, { 0.6, DIVE }, { 1, {} } } },
}

local function motorsOf(model)
	local cached = Anim.motors[model]
	if cached then
		return cached
	end
	cached = {}
	for joint, partName in JOINTS do
		local part = model:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(joint)
		if motor and motor:IsA("Motor6D") then
			cached[joint] = motor
		end
	end
	Anim.motors[model] = cached
	return cached
end

local function addTo(out, joint, a, b, x, weight)
	local acc = out[joint]
	if not acc then
		acc = { 0, 0, 0, 0 }
		out[joint] = acc
	end
	for i = 1, 4 do
		acc[i] += (a[i] + (b[i] - a[i]) * x) * weight
	end
end

local function addPose(out, pose, weight)
	if weight <= 0.001 then
		return
	end
	for joint, v in pose do
		addTo(out, joint, v, v, 0, weight)
	end
end

-- adds a one-off move at `tau` seconds; returns false once it has finished
local function addMove(out, move, tau)
	local keys = move.keys
	local last = keys[#keys]
	if tau >= last[1] then
		if move.hold and tau < last[1] + move.hold then
			addPose(out, last[2], 1)
			return true
		end
		return false
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if tau >= a[1] and tau <= b[1] then
			local x = (tau - a[1]) / math.max(b[1] - a[1], 1e-3)
			x = x * x * (3 - 2 * x)
			for joint, va in a[2] do
				addTo(out, joint, va, b[2][joint] or ZERO, x, 1)
			end
			for joint, vb in b[2] do
				if not a[2][joint] then
					addTo(out, joint, ZERO, vb, x, 1)
				end
			end
			break
		end
	end
	return true
end

function Anim.play(model, kind)
	local move = POSES[kind]
	if model and move then
		Anim.active[model] = { move = move, t0 = os.clock() }
	end
end

-- Your dive can use a marketplace emote instead (Config.DIVE_EMOTE_ID); falls back to the hand-made one
local emoteBroken = false
function Anim.tryDiveEmote()
	local id = tonumber(Config.DIVE_EMOTE_ID)
	local hum = character()
	if emoteBroken or not id or id <= 0 or not hum then
		return false
	end
	local ok, played = pcall(function()
		local success = hum:PlayEmoteAndGetAnimTrackById(id)
		return success
	end)
	if ok and played then
		return true
	end
	emoteBroken = true
	warn("[Arena Volleyball] Couldn't play dive emote " .. id .. "; using the built-in dive instead.")
	return false
end

-- which held position a character should be in right now
local function autoTargets(team, hum, hrp, ballPos)
	if state.phase ~= "rally" or ballState.mode ~= "fly" then
		return 0, 0, 0
	end
	local s = team == 1 and 1 or -1
	local stand = GY + hum.HipHeight + hrp.Size.Y / 2
	local depth = (hrp.Position.Z - C.Z) * s
	local ballSide = (ballPos.Z - C.Z) * s
	if hrp.Position.Y > stand + 1 then
		if depth < 4.5 and ballSide < 2 then
			return 0, 0, 1 -- jumping at the net while they attack: block
		end
		return 0, (ballSide > -1) and 1 or 0, 0 -- in the air on our side: wind up
	end
	local v = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	return math.clamp(1 - (speed - 5) / 6, 0, 1), 0, 0 -- standing or shuffling: ready crouch
end

function Anim.step(dt, ballPos)
	local now = os.clock()
	local blend = math.min(1, dt * 10)
	for team = 1, 2 do
		for _, e in state.roster[team] or {} do
			local model = e.model
			local hum = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
			local hrp = hum and model:FindFirstChild("HumanoidRootPart")
			if hrp then
				local motors = motorsOf(model)
				local out = {}
				local w = Anim.weights[model]
				if not w then
					w = { ready = 0, cock = 0, block = 0, seed = math.random() * 10 }
					Anim.weights[model] = w
				end
				local ready, cock, block = autoTargets(team, hum, hrp, ballPos)
				local active = Anim.active[model]
				if active and not addMove(out, active.move, now - active.t0) then
					Anim.active[model] = nil
					active = nil
				end
				if active then
					ready, cock, block = 0, 0, 0
					w.cock, w.block, w.ready = 0, 0, 0 -- the move takes over at once
				end
				w.ready += (ready - w.ready) * blend
				w.cock += (cock - w.cock) * blend
				w.block += (block - w.block) * blend
				addPose(out, READY, w.ready * (0.85 + 0.15 * math.sin(now * 2.1 + w.seed)))
				addPose(out, COCK, w.cock)
				addPose(out, BLOCK, w.block)
				for joint, v in out do
					local motor = motors[joint]
					if motor then
						motor.Transform = motor.Transform * CFrame.new(0, v[4], 0) * CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
					end
				end
			end
		end
	end
end
