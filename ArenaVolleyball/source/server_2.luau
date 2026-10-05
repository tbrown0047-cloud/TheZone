
---------------------------------------------------------------- teams and players

-- Each team has TEAM_SIZE slots. A slot is played by a person or by an AI body.
local teams = {}
for t = 1, 2 do
	teams[t] = { id = t, slots = {}, score = 0, sets = 0, serveIndex = (t == 1) and 1 or 0 }
	for i = 1, TEAM_SIZE do
		teams[t].slots[i] = { team = t, index = i, isAI = true, ai = {} }
	end
end
local slotOfPlayer = {}

-- Rotation position 1-6 (1 = back right, the server; 2 front right ... 6 back middle).
-- Players move round one place each time their team wins the serve back.
local function rotationPos(slot)
	return (slot.index - teams[slot.team].serveIndex) % 6 + 1
end

-- Six-a-side spots: {across, as a share of half the width (+ = the team's right), distance from the net}
local SIX = {
	receive = { { 0.6, 0.72 }, { 0.65, 0.3 }, { 0, 0.2 }, { -0.65, 0.3 }, { -0.6, 0.72 }, { 0, 0.82 } },
	defend = { { 0.6, 0.7 }, { 0.55, 0.08 }, { 0, 0.08 }, { -0.55, 0.08 }, { -0.6, 0.7 }, { 0, 0.8 } },
}

-- Where a player stands while waiting. lz is the distance from the net.
local function homeSpot(slot, mode)
	local s = side(slot.team)
	if TEAM_SIZE == 6 then
		local spot = SIX[mode == "receive" and "receive" or "defend"][rotationPos(slot)]
		-- facing the net, a team's right is +X for HOME and -X for AWAY
		return Vector3.new(C.X + s * spot[1] * HALF_W, GY, C.Z + s * math.max(spot[2] * HALF_L, 2.5))
	end
	local x = 0
	if TEAM_SIZE > 1 then
		x = (-1 + 2 * (slot.index - 1) / (TEAM_SIZE - 1)) * HALF_W * 0.5
	end
	local depth = (mode == "serving") and HALF_L * 0.45 or HALF_L * 0.6
	return Vector3.new(C.X + x, GY, C.Z + s * depth)
end

local function serveSpot(slot)
	return Vector3.new(C.X, GY, C.Z + side(slot.team) * (HALF_L + 3))
end

local function standHeight(slot)
	local hum, hrp = slot.humanoid, slot.root
	if hum and hrp then
		return GY + hum.HipHeight + hrp.Size.Y / 2
	end
	return GY + 3
end

local function placeSlot(slot, pos)
	local model = slot.model
	if not model or not slot.root then
		return
	end
	local p = Vector3.new(pos.X, standHeight(slot) + 0.2, pos.Z)
	model:PivotTo(CFrame.lookAt(p, Vector3.new(C.X, p.Y, C.Z)))
	slot.ai.goal = nil
	if slot.isAI and slot.humanoid then
		slot.humanoid:MoveTo(p)
	end
end

local SKIN = {
	Color3.fromRGB(255, 220, 177),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(94, 58, 26),
}
local BOT_NAMES = { "Silva", "Kato", "Novak", "Reyes", "Okafor", "Lindqvist", "Moreau", "Park", "Rossi", "Haddad", "Ivanov", "Costa" }
local ANIM_IDS = { idle = 507766666, run = 507767714, jump = 507765000 }

-- Used only if Roblox can't build a normal body
local function simpleBody(slot)
	local model = Instance.new("Model")
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CFrame = CFrame.new(0, 3, 0)
	hrp.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2.6, 1)
	torso.Color = Config.TEAM_COLORS[slot.team]
	torso.CanCollide = false
	torso.Massless = true
	torso.CFrame = hrp.CFrame
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.3, 1.3, 1.3)
	head.Color = SKIN[1]
	head.CanCollide = false
	head.Massless = true
	head.CFrame = hrp.CFrame * CFrame.new(0, 2, 0)
	head.Parent = model
	for _, p in { torso, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = p
		weld.Parent = hrp
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2
	hum.Parent = model
	model.PrimaryPart = hrp
	return model
end

local botCount = 0
local function makeBot(slot)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Config.TEAM_COLORS[slot.team]
	desc.LeftLegColor = Color3.fromRGB(35, 38, 48)
	desc.RightLegColor = Color3.fromRGB(35, 38, 48)
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn("[Arena Volleyball] Using a simple AI body: " .. tostring(model))
		model = simpleBody(slot)
	end
	-- a person may have taken this spot while the body was being made
	if not slot.isAI or slot.model then
		model:Destroy()
		return
	end
	botCount += 1
	model.Name = BOT_NAMES[(botCount - 1) % #BOT_NAMES + 1]
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		model:Destroy()
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = AI.speed
	hum.UseJumpPower = true
	hum.JumpPower = 50
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	model:SetAttribute("VolleyballAI", true)

	slot.model, slot.humanoid, slot.root = model, hum, hrp
	slot.ai = {}
	model.Parent = courtFolder
	if phase == "serve" and currentServer() == slot then
		placeSlot(slot, serveSpot(slot))
	else
		placeSlot(slot, homeSpot(slot))
	end
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)

	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	slot.tracks = {}
	for name, id in ANIM_IDS do
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. id
		local loaded, track = pcall(animator.LoadAnimation, animator, anim)
		if loaded and track then
			slot.tracks[name] = track
		end
	end
	slot.anim = nil
end

-- Plays idle / run / jump on an AI body
local function animateBot(slot)
	local tracks, hum, hrp = slot.tracks, slot.humanoid, slot.root
	if not tracks or not hum or not hrp then
		return
	end
	local vel = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local want = "idle"
	if hum.FloorMaterial == Enum.Material.Air then
		want = "jump"
	elseif speed > 1.5 then
		want = "run"
	end
	if want ~= slot.anim then
		if slot.anim and tracks[slot.anim] then
			tracks[slot.anim]:Stop(0.15)
		end
		if tracks[want] then
			tracks[want]:Play(0.15)
		end
		slot.anim = want
	end
	if want == "run" and tracks.run then
		tracks.run:AdjustSpeed(math.clamp(speed / 16, 0.6, 1.6))
	end
end

local function clearBody(slot)
	if slot.isAI and slot.model then
		slot.model:Destroy()
	end
	slot.model, slot.humanoid, slot.root, slot.tracks, slot.anim = nil, nil, nil, nil, nil
	slot.ai = {}
end

local function bindCharacter(slot, plr, char)
	local hum = char:WaitForChild("Humanoid", 10)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if slot.player ~= plr or not hum or not hrp then
		return
	end
	slot.model, slot.humanoid, slot.root = char, hum, hrp
	task.wait(0.15)
	if slot.player ~= plr or slot.model ~= char then
		return
	end
	if phase == "serve" and currentServer() == slot then
		placeSlot(slot, serveSpot(slot))
	else
		placeSlot(slot, homeSpot(slot))
	end
end

local function addPlayer(plr)
	if slotOfPlayer[plr] then
		return
	end
	-- people fill HOME first, so you play with or against AI
	local slot
	for t = 1, 2 do
		for _, s in teams[t].slots do
			if s.isAI and not slot then
				slot = s
			end
		end
	end
	if not slot then
		return -- teams are full: this person watches
	end
	clearBody(slot)
	slot.isAI = false
	slot.player = plr
	slotOfPlayer[plr] = slot
	plr.CharacterAdded:Connect(function(char)
		bindCharacter(slot, plr, char)
	end)
	if plr.Character then
		task.spawn(bindCharacter, slot, plr, plr.Character)
	end
	if phase == "serve" and currentServer() == slot then
		serveDeadline = now() + Config.SERVE_TIME
	end
	sendState()
end

local function removePlayer(plr)
	local slot = slotOfPlayer[plr]
	if not slot then
		return
	end
	slotOfPlayer[plr] = nil
	slot.player = nil
	slot.model, slot.humanoid, slot.root = nil, nil, nil
	slot.isAI = true
	slot.ai = {}
	if phase == "serve" and currentServer() == slot then
		serveAt = now() + 2.5
	end
	task.spawn(makeBot, slot)
	sendState()
end
