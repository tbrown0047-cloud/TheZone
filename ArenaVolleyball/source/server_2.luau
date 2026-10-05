
---------------------------------------------------------------- teams, lineups and players

-- Each team has TEAM_SIZE slots, one per player in the lineup. A slot is played by a
-- person or by an AI body wearing that player's name and number.
local teams = {}
for t = 1, 2 do
	teams[t] = { id = t, slots = {}, score = 0, sets = 0, serveIndex = (t == 1) and 1 or 0, subs = 0 }
	for i = 1, TEAM_SIZE do
		teams[t].slots[i] = { team = t, index = i, isAI = true, ai = {} }
	end
end
-- People never play with their own Roblox character: each one controls an AI body on
-- his team. In "switch" mode he jumps to whoever plays the ball next (or presses the
-- switch key); in "lock" mode he keeps one player all match.
local slotOfPlayer = {} -- the body each person is controlling right now
local controllers = {} -- person -> { team, mode = "switch" | "lock", home = slot index, auto = bool }
local charConnections = {}

local function tactic(team, key)
	local plan = teams[team].plan
	return plan and plan.tactics[key] or "BALANCED"
end

-- A team's AI strength from its lineup's rating, then its captain and tactics
local function applyPlan(t)
	local team = teams[t]
	team.lineup = team.plan.lineup
	team.rating = Teams.ratings(team.defId, team.lineup).OVR
	local ai = aiForSkill(Teams.skill(team.rating))
	if table.find(team.lineup, team.plan.captain) then
		ai.quality = math.min(ai.quality + 0.02, 0.95)
		ai.react = math.max(ai.react - 0.01, 0.1)
	end
	local block = team.plan.tactics.block
	if block == "READ" then
		ai.blockTry *= 0.7
		ai.blockWin = math.min(ai.blockWin * 1.15, 0.9)
	elseif block == "COMMIT" then
		ai.blockTry = math.min(ai.blockTry * 1.4, 0.97)
		ai.blockWin *= 0.9
	end
	team.ai = ai
end

-- Picks the clubs and their game plans (lineup, tactics and roles)
local function configureTeams(homeId, awayId, homePlan, awayPlan)
	for t, id in { homeId, awayId } do
		local team = teams[t]
		team.defId = id
		team.def = Teams.list[id]
		team.plan = Teams.cleanPlan(id, t == 1 and homePlan or awayPlan)
		team.subs = 0
		applyPlan(t)
	end
end
configureTeams(1, 2)

-- The libero the team has picked, if he's on the bench
local function liberoIndex(team)
	local index = team.plan and team.plan.libero
	local squad = Teams.squad(team.defId)
	if index and squad[index] and squad[index].role == "L" and not table.find(team.lineup, index) then
		return index
	end
	return nil
end

-- The squad player a slot stands for: a career player in your own slot, and the libero
-- in place of a middle blocker while he's in the back row (but not when he serves)
local function playerOf(slot)
	if slot.override then
		return slot.override
	end
	local team = teams[slot.team]
	local squad = Teams.squad(team.defId)
	local p = squad[team.lineup[slot.index] or slot.index]
	if TEAM_SIZE == 6 and p and p.role == "MB" then
		local pos = (slot.index - team.serveIndex) % 6 + 1
		local libero = (pos == 5 or pos == 6) and liberoIndex(team)
		if libero then
			return squad[libero]
		end
	end
	return p
end

local function roleOf(slot)
	local p = playerOf(slot)
	return p and p.role or "OH"
end

-- A player's attribute as 0..1 (50 or lower = 0, 100 = 1)
local function attr01(slot, attr)
	local p = playerOf(slot)
	return math.clamp(((p and p.attrs[attr] or 70) - 50) / 50, 0, 1)
end

local function teamAI(team)
	return teams[team].ai
end

-- Rotation position 1-6 (1 = back right, the server; 2 front right ... 6 back middle).
-- Players move round one place each time their team wins the serve back.
local function rotationPos(slot)
	return (slot.index - teams[slot.team].serveIndex) % 6 + 1
end

local function isFrontRow(slot)
	if TEAM_SIZE ~= 6 then
		return true
	end
	local pos = rotationPos(slot)
	return pos >= 2 and pos <= 4
end

-- Six-a-side spots: {across, as a share of half the width (+ = the team's right), distance from the net}
local SIX = {
	receive = { { 0.6, 0.72 }, { 0.65, 0.3 }, { 0, 0.2 }, { -0.65, 0.3 }, { -0.6, 0.72 }, { 0, 0.82 } },
	defend = { { 0.6, 0.7 }, { 0.55, 0.08 }, { 0, 0.08 }, { -0.55, 0.08 }, { -0.6, 0.7 }, { 0, 0.8 } },
}

-- Where a player stands while waiting
local function homeSpot(slot, mode)
	local s = side(slot.team)
	if TEAM_SIZE == 6 then
		local spot = SIX[mode == "receive" and "receive" or "defend"][rotationPos(slot)]
		local depth = spot[2]
		if mode ~= "receive" and depth > 0.5 then
			-- the back row's line comes from the team's defensive tactic
			local line = tactic(slot.team, "defense")
			depth += line == "DEEP" and 0.1 or line == "UP" and -0.14 or 0
		end
		-- facing the net, a team's right is +X for HOME and -X for AWAY
		return Vector3.new(C.X + s * spot[1] * HALF_W, GY, C.Z + s * math.max(depth * HALF_L, 2.5))
	end
	local x = 0
	if TEAM_SIZE > 1 then
		x = (-1 + 2 * (slot.index - 1) / (TEAM_SIZE - 1)) * HALF_W * 0.5
	end
	local depth = (mode == "serving") and HALF_L * 0.45 or HALF_L * 0.6
	return Vector3.new(C.X + x, GY, C.Z + s * depth)
end

local function serveSpot(slot)
	return Vector3.new(C.X + side(slot.team) * HALF_W * 0.45, GY, C.Z + side(slot.team) * (HALF_L + 3))
end

local function standHeight(slot)
	local hum, hrp = slot.humanoid, slot.root
	if hum and hrp then
		return GY + hum.HipHeight + hrp.Size.Y / 2
	end
	return GY + 3
end

-- Turns an AI body smoothly (it has its own turning instead of the humanoid's)
local function faceTowards(slot, dir)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if slot.align and flat.Magnitude > 0.05 then
		slot.align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end

local function placeSlot(slot, pos)
	local model = slot.model
	if not model or not slot.root then
		return
	end
	local p = Vector3.new(pos.X, standHeight(slot) + 0.2, pos.Z)
	local look = Vector3.new(C.X, p.Y, C.Z)
	model:PivotTo(CFrame.lookAt(p, look))
	faceTowards(slot, look - p)
	slot.ai.vel = Vector3.zero
	if slot.isAI and slot.humanoid then
		slot.humanoid:Move(Vector3.zero)
	end
end

local SKIN = {
	Color3.fromRGB(255, 220, 177),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(94, 58, 26),
}
-- Walk, run, idle, jump and fall for every body. Starts as Roblox's own; the server
-- swaps in Config.ANIMATION_PACK once it has loaded (see the start of the match code).
local PACK = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
}

-- Shirt numbers on the front and back
local function addNumber(model, number, color)
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if not torso then
		return
	end
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "ShirtNumber"
		gui.Face = face
		gui.CanvasSize = Vector2.new(100, 100)
		gui.LightInfluence = 1
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = face == Enum.NormalId.Back and UDim2.fromScale(1, 1) or UDim2.new(0.4, 0, 0.4, 0)
		text.Position = face == Enum.NormalId.Back and UDim2.new() or UDim2.fromScale(0.55, 0.12)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = color
		text.Text = tostring(number)
		text.Parent = gui
		gui.Parent = torso
	end
end

-- Puts an AI body in the right shirt: the libero wears a contrasting one
local function dressBot(slot)
	local model = slot.model
	if not model then
		return
	end
	local def = teams[slot.team].def
	local p = playerOf(slot)
	local libero = p and p.role == "L"
	local shirtColor = libero and def.secondary or def.primary
	local colors = model:FindFirstChildOfClass("BodyColors")
	if colors then
		colors.TorsoColor3 = shirtColor
	end
	for _, name in { "UpperTorso", "LowerTorso", "Torso" } do
		local partInstance = model:FindFirstChild(name)
		if partInstance then
			partInstance.Color = shirtColor
		end
	end
	local light = (shirtColor.R + shirtColor.G + shirtColor.B) > 1.8
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Name == "ShirtNumber" then
			local label = d:FindFirstChildOfClass("TextLabel")
			if label and p then
				label.Text = tostring(p.number)
				label.TextColor3 = light and Color3.fromRGB(20, 20, 30) or Color3.new(1, 1, 1)
			end
		end
	end
	if p then
		model.Name = p.last
	end
end

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
	torso.Color = teams[slot.team].def.primary
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

local function makeBot(slot)
	local def = teams[slot.team].def
	local p = playerOf(slot)
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = def.primary
	desc.LeftLegColor = def.secondary
	desc.RightLegColor = def.secondary
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn("[Arena Volleyball] Using a simple AI body: " .. tostring(model))
		model = simpleBody(slot)
	end
	-- a person may have taken this spot, or the match ended, while the body was made
	if not slot.isAI or slot.model or not matchActive then
		model:Destroy()
		return
	end
	model.Name = p and p.last or "PLAYER"
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
	hum.WalkSpeed = teamAI(slot.team).speed
	hum.UseJumpPower = true
	hum.JumpPower = 50
	hum.AutoRotate = false -- turning is done by the AlignOrientation below
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	model:SetAttribute("VolleyballAI", true)
	if p then
		local light = (def.primary.R + def.primary.G + def.primary.B) > 1.8
		addNumber(model, p.number, light and Color3.fromRGB(20, 20, 30) or Color3.new(1, 1, 1))
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "FaceAttachment"
	attachment.Parent = hrp
	local align = Instance.new("AlignOrientation")
	align.Name = "Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.MaxTorque = 1e6
	align.Responsiveness = 14
	align.Parent = hrp

	slot.model, slot.humanoid, slot.root, slot.align = model, hum, hrp, align
	dressBot(slot)
	-- everyone moves a little differently
	slot.ai = { vel = Vector3.zero, pace = rng:NextNumber(0.88, 1.12), drift = rng:NextNumber(0, 10) }
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
	for name, id in PACK do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local loaded, track = pcall(animator.LoadAnimation, animator, anim)
		if loaded and track then
			slot.tracks[name] = track
		end
	end
	slot.anim = nil
end

-- Plays idle / walk / run / jump on an AI body
local function animateBot(slot)
	local tracks, hum, hrp = slot.tracks, slot.humanoid, slot.root
	if not tracks or not hum or not hrp then
		return
	end
	local vel = hrp.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local want = "idle"
	-- a body someone else controls is simulated on his screen, so check its height too
	if hum.FloorMaterial == Enum.Material.Air or hrp.Position.Y > standHeight(slot) + 0.8 then
		want = (vel.Y > 1 or not tracks.fall) and "jump" or "fall"
	elseif speed > 10 then
		want = "run"
	elseif speed > 1.2 then
		want = "walk"
	end
	if want ~= slot.anim then
		if slot.anim and tracks[slot.anim] then
			tracks[slot.anim]:Stop(0.2)
		end
		if tracks[want] then
			tracks[want]:Play(0.2)
		end
		slot.anim = want
	end
	if want == "run" and tracks.run then
		tracks.run:AdjustSpeed(math.clamp(speed / 18, 0.7, 1.5))
	elseif want == "walk" and tracks.walk then
		tracks.walk:AdjustSpeed(math.clamp(speed / 8, 0.5, 1.4))
	end
end

local function clearBody(slot)
	if slot.model then
		slot.model:Destroy()
	end
	slot.model, slot.humanoid, slot.root, slot.tracks, slot.anim, slot.align = nil, nil, nil, nil, nil, nil
	slot.ai = {}
end

---------------------------------------------------------------- people controlling bodies

-- What a person's body can do: a little quicker than the AI so it feels responsive
local function pilotSpeed(slot)
	return 17 + 4 * attr01(slot, "PHY")
end

-- Hands a body back to the AI
local function releasePilot(slot)
	if not slot or not slot.player then
		return
	end
	slot.player = nil
	slot.isAI = true
	slot.ai = { vel = Vector3.zero, pace = slot.ai and slot.ai.pace or 1, drift = slot.ai and slot.ai.drift or 0 }
	if slot.root then
		pcall(function()
			slot.root:SetNetworkOwner(nil)
		end)
	end
	if slot.humanoid then
		slot.humanoid.AutoRotate = false
		slot.humanoid:Move(Vector3.zero)
	end
	if slot.align then
		slot.align.Enabled = true
	end
end

-- Gives a person control of a body: its physics runs on his screen so it moves at once
local function pilotSlot(plr, slot)
	if not slot or not slot.model or (slot.player and slot.player ~= plr) then
		return nil
	end
	if slot.player == plr then
		return slot
	end
	local old = slotOfPlayer[plr]
	if old then
		releasePilot(old)
	end
	slot.player = plr
	slot.isAI = false
	slotOfPlayer[plr] = slot
	if slot.humanoid then
		slot.humanoid.AutoRotate = true
		slot.humanoid.WalkSpeed = pilotSpeed(slot)
		slot.humanoid:Move(Vector3.zero)
	end
	if slot.align then
		slot.align.Enabled = false
	end
	if slot.root then
		pcall(function()
			slot.root:SetNetworkOwner(plr)
		end)
	end
	sendState()
	return slot
end

-- In switch mode, a person follows the play: he takes over whoever plays the ball next
local function autoSwitch(team, slot)
	if not slot or slot.player or not slot.model then
		return
	end
	for plr, ctrl in controllers do
		if ctrl.team == team and ctrl.mode == "switch" and ctrl.auto ~= false and slotOfPlayer[plr] ~= slot then
			pilotSlot(plr, slot)
			return
		end
	end
end

-- The free teammate nearest a point (for the switch key)
local function nearestFree(team, point, exclude, plr)
	local best, bestD = nil, math.huge
	for _, s in teams[team].slots do
		if s ~= exclude and not s.player and s.root and (s.reserved == nil or s.reserved == plr) then
			local d = flatDist(s.root.Position, point)
			if d < bestD then
				best, bestD = s, d
			end
		end
	end
	return best
end

-- Your own character waits on the bench like a coach while you play
local function parkCharacter(plr)
	local ctrl = controllers[plr]
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not ctrl or not hrp then
		return
	end
	local spot = Vector3.new(C.X + HALF_W + 8, GY + 3, C.Z + side(ctrl.team) * (10 + (ctrl.benchNo or 0) * 3))
	hrp.Anchored = true
	char:PivotTo(CFrame.lookAt(spot, Vector3.new(C.X, spot.Y, spot.Z)))
end

local function unparkCharacter(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
	end
end

local function anyPeople()
	return next(controllers) ~= nil
end

-- A free spot on a team: the one asked for, else the first nobody has
local function freeSlot(team, want)
	local tm = teams[team]
	local preferred = want and tm.slots[want]
	if preferred and not preferred.player and not preferred.reserved then
		return preferred
	end
	for _, s in tm.slots do
		if not s.player and not s.reserved then
			return s
		end
	end
	return nil
end

-- Puts a person in the match on a team. Only one person per team can switch between
-- players; anyone else on that team is locked to one player. Returns his home slot.
local function addPlayer(plr, wantTeam, wantIndex, mode)
	if controllers[plr] then
		return teams[controllers[plr].team].slots[controllers[plr].home]
	end
	local order = (wantTeam == 2) and { 2, 1 } or { 1, 2 }
	for _, t in order do
		local slot = freeSlot(t, t == order[1] and tonumber(wantIndex) or nil)
		if slot then
			local switching, count = false, 0
			for _, c in controllers do
				if c.team == t then
					count += 1
					switching = switching or c.mode == "switch"
				end
			end
			controllers[plr] = {
				team = t,
				mode = (mode == "lock" or switching) and "lock" or "switch",
				home = slot.index,
				auto = true,
				benchNo = count,
			}
			slot.reserved = plr
			slot.stats = slot.stats or { kills = 0, aces = 0, blocks = 0, digs = 0 }
			if charConnections[plr] then
				charConnections[plr]:Disconnect()
			end
			charConnections[plr] = plr.CharacterAdded:Connect(function(char)
				char:WaitForChild("HumanoidRootPart", 10)
				task.wait(0.2)
				if controllers[plr] then
					parkCharacter(plr)
				end
			end)
			if slot.model then
				-- joining a match that's already on
				pilotSlot(plr, slot)
				parkCharacter(plr)
				if phase == "serve" and currentServer() == slot then
					serveDeadline = now() + Config.SERVE_TIME
				end
			end
			sendState()
			return slot
		end
	end
	return nil
end

local function removePlayer(plr)
	if charConnections[plr] then
		charConnections[plr]:Disconnect()
		charConnections[plr] = nil
	end
	local ctrl = controllers[plr]
	if not ctrl then
		return
	end
	controllers[plr] = nil
	local slot = slotOfPlayer[plr]
	slotOfPlayer[plr] = nil
	if slot then
		releasePilot(slot)
	end
	for t = 1, 2 do
		for _, s in teams[t].slots do
			if s.reserved == plr then
				s.reserved = nil
				s.override = nil
				task.defer(dressBot, s)
			end
		end
	end
	unparkCharacter(plr)
	if matchActive and not anyPeople() then
		stopMatch() -- nobody left playing: back to the menu
		return
	end
	if phase == "serve" and slot and currentServer() == slot then
		serveAt = now() + 2.5
	end
	sendState()
end
