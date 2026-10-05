
---------------------------------------------------------------- state from the server

local state = {
	phase = "waiting",
	score = { 0, 0 },
	sets = { 0, 0 },
	serving = 1,
	server = 0,
	touches = 0,
	touchTeam = 0,
	roster = { {}, {} },
	deadline = 0,
}
local ballState = {
	id = 0,
	mode = "rest",
	p0 = C + Vector3.new(0, R, 0),
	v0 = Vector3.zero,
	t0 = 0,
	rest = C + Vector3.new(0, R, 0),
}

local function myTeam()
	for t = 1, 2 do
		for _, e in state.roster[t] or {} do
			if e.id == player.UserId then
				return t
			end
		end
	end
	return 0
end

local function myServe()
	return state.phase == "serve" and state.server == player.UserId
end

local function character()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hum, hrp
end

local function airborne(hum)
	return hum ~= nil and hum.FloorMaterial == Enum.Material.Air
end

local function ballAt(t)
	if ballState.mode == "fly" then
		local dt = math.max(t - ballState.t0, 0)
		local p = ballState.p0 + ballState.v0 * dt + Vector3.new(0, -0.5 * G * dt * dt, 0)
		if p.Y < FLOOR then
			p = Vector3.new(p.X, FLOOR, p.Z)
		end
		return p
	elseif ballState.mode == "hold" then
		local holder = ballState.holder
		local hrp = holder and holder.Parent and holder:FindFirstChild("HumanoidRootPart")
		if hrp then
			return (hrp.CFrame * CFrame.new(0.5, 0.4, -1.4)).Position
		end
	end
	return ballState.rest
end

local function landingPoint()
	local p0, v0 = ballState.p0, ballState.v0
	local disc = v0.Y * v0.Y + 2 * G * (p0.Y - FLOOR)
	if disc < 0 then
		return nil
	end
	local s = (v0.Y + math.sqrt(disc)) / G
	return p0 + v0 * s + Vector3.new(0, -0.5 * G * s * s, 0)
end

---------------------------------------------------------------- HUD updates

local lastInput = touchMode and "touch" or "kbm"
UserInputService.LastInputTypeChanged:Connect(function(inputType)
	if inputType == Enum.UserInputType.Touch then
		lastInput = "touch"
	elseif string.find(inputType.Name, "Gamepad") then
		lastInput = "pad"
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		lastInput = "kbm"
	end
end)

local POSITION_NAMES = { "RIGHT BACK · SERVER", "RIGHT FRONT", "MIDDLE FRONT", "LEFT FRONT", "LEFT BACK", "MIDDLE BACK" }

local function myEntry()
	for t = 1, 2 do
		for _, e in state.roster[t] or {} do
			if e.id == player.UserId then
				return e, t
			end
		end
	end
	return nil, 0
end

local lastScore = ""
local function refreshBoard()
	local score = state.score[1] .. " - " .. state.score[2]
	scoreLabel.Text = score
	if score ~= lastScore and lastScore ~= "" then
		scorePop.Scale = 1.18
		TweenService:Create(scorePop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	lastScore = score
	homeServe.Visible = state.serving == 1
	awayServe.Visible = state.serving == 2
	setLabel.Text = "SET " .. (state.sets[1] + state.sets[2] + 1)
	targetLabel.Text = (Config.SETS_TO_WIN > 1 and ("SETS " .. state.sets[1] .. "-" .. state.sets[2] .. " · ") or "") .. "TO " .. (state.points or Config.POINTS_TO_WIN)

	local showDots = state.phase == "rally" and state.touchTeam ~= 0 and state.touches > 0
	strip.Visible = showDots
	for i = 1, 3 do
		local used = showDots and i <= state.touches
		dots[i].BackgroundColor3 = used and (COLORS[state.touchTeam] or TEXT) or TEXT
		dots[i].BackgroundTransparency = used and 0 or 0.8
	end

	-- player card
	local me, team = myEntry()
	if me then
		local color = COLORS[team] or TEXT
		cardStripe.BackgroundColor3 = color
		setRingColor(color)
		tagArrow.TextColor3 = color
		if (state.teamSize or 6) == 6 and state.serveIndex then
			local pos = (me.index - state.serveIndex[team]) % 6 + 1
			cardPos.Text = NAMES[team] .. "  ·  POS " .. pos .. "  " .. POSITION_NAMES[pos]
		else
			cardPos.Text = NAMES[team]
		end
		cardStats.Text = "KILLS <font color=\"#ffd450\">" .. me.k .. "</font>   ACES <font color=\"#ffd450\">" .. me.a
			.. "</font>   BLOCKS <font color=\"#ffd450\">" .. me.b .. "</font>   DIGS <font color=\"#ffd450\">" .. me.d .. "</font>"
		local rating = math.clamp(6 + 0.3 * me.k + 0.4 * me.a + 0.4 * me.b + 0.15 * me.d, 3, 10)
		ratingLabel.Text = string.format("%.1f", rating)
		ratingLabel.TextColor3 = rating >= 8 and Color3.fromRGB(120, 255, 170) or rating >= 7 and GOLD or TEXT
	end
end

local function updatePrompts()
	if myTeam() == 0 then
		setPrompts({})
		return
	end
	local pad = lastInput == "pad"
	if myServe() then
		local left = math.max(0, math.ceil(state.deadline - serverNow()))
		setPrompts({
			{ pad and "HOLD R2" or "HOLD CLICK", "Serve  (" .. left .. "s)" },
			{ pad and "A" or "SPACE", "Jump first: jump serve" },
			{ pad and "R-STICK" or "MOUSE", "Aim" },
		})
	elseif state.phase == "rally" then
		setPrompts({
			{ pad and "R2" or "CLICK", "Pass · Spike in the air" },
			{ pad and "X" or "E", "Set · Tip in the air" },
			{ pad and "A" or "SPACE", "Jump · Block at the net" },
			{ pad and "B" or "Q", "Dive" },
		})
	else
		setPrompts({})
	end
end

-- Swings the camera round behind you, facing the net
local function lookAtNet()
	local _, hrp = character()
	local cam = workspace.CurrentCamera
	if not hrp or not cam then
		return
	end
	local to = Vector3.new(C.X - hrp.Position.X, 0, C.Z - hrp.Position.Z)
	if to.Magnitude < 1 then
		return
	end
	to = to.Unit
	cam.CFrame = CFrame.lookAt(hrp.Position - to * 12 + Vector3.new(0, 5, 0), hrp.Position + to * 10)
end

player.CharacterAdded:Connect(function()
	task.delay(0.6, function()
		if myTeam() ~= 0 then
			lookAtNet()
		end
	end)
end)

---------------------------------------------------------------- controls

local charging, chargeStart = false, 0
local lastSend, lastDive, diveUntil = 0, 0, 0
local cueUntil = 0

local function chargePower()
	return math.clamp((os.clock() - chargeStart) / 1.2, 0, 1)
end

-- Where you're aiming on the floor: the mouse, or the middle of the screen on touch / gamepad
local function aimPoint()
	local cam = workspace.CurrentCamera
	local ray
	if lastInput == "kbm" then
		local m = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(m.X, m.Y)
	else
		ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y * 0.45)
	end
	local o, d = ray.Origin, ray.Direction
	if d.Y < -0.02 then
		return o + d * ((GY - o.Y) / d.Y)
	end
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return Vector3.new(o.X, GY, o.Z) + flat.Unit * 40
end

-- Same windows the server uses: can you play this touch right now?
local WINDOWS = { bump = { -3.5, 5 }, set = { -2, 7 }, spike = { -2.5, 8 }, tip = { -2.5, 8 } }
local function canPlay(kind, hum, hrp)
	if not hrp or state.phase ~= "rally" or ballState.mode ~= "fly" then
		return false
	end
	local team = myTeam()
	local pos = ballAt(serverNow())
	if team == 0 or (pos.Z - C.Z) * (team == 1 and 1 or -1) < -1.5 then
		return false
	end
	local off = pos - hrp.Position
	local win = WINDOWS[kind]
	return Vector3.new(off.X, 0, off.Z).Magnitude <= REACH + 1.2 and off.Y > win[1] and off.Y < win[2]
end

local pending = nil -- a press made slightly early, played as soon as the ball arrives

local function sendHit(kind)
	local hum, hrp = character()
	local air = airborne(hum) and os.clock() > diveUntil
	if not air and (kind == "spike" or kind == "tip") then
		kind = (kind == "spike") and "bump" or "set"
	end
	if os.clock() - lastSend < 0.3 then
		return
	end
	if not canPlay(kind, hum, hrp) then
		pending = { kind = kind, expires = os.clock() + 0.3 }
		return
	end
	pending = nil
	lastSend = os.clock()
	local t = serverNow()
	remote:FireServer("hit", { kind = kind, aim = aimPoint(), root = hrp.Position, air = air, id = ballState.id, t = t })
end

local function press()
	if myServe() then
		if ballState.mode == "hold" and not charging then
			charging = true
			chargeStart = os.clock()
		end
		return
	end
	sendHit("spike") -- in the air this spikes; on the ground it becomes a pass
end

local function release()
	if not charging then
		return
	end
	charging = false
	local hum, hrp = character()
	if not hrp or not myServe() then
		return
	end
	remote:FireServer("serve", { aim = aimPoint(), power = chargePower(), root = hrp.Position, air = airborne(hum) })
end

local function setBall()
	if not myServe() then
		sendHit("tip") -- in the air this tips over the block; on the ground it sets
	end
end

local function dive()
	local hum, hrp = character()
	if not hum or not hrp or state.phase ~= "rally" then
		return
	end
	if os.clock() - lastDive < 1.4 or airborne(hum) then
		return
	end
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = hrp.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	lastDive = os.clock()
	diveUntil = os.clock() + 0.7
	remote:FireServer("dive", {})
	hrp.AssemblyLinearVelocity = dir.Unit * 42 + Vector3.new(0, 14, 0)
	local speed = hum.WalkSpeed
	task.delay(0.35, function()
		if hum.Parent then
			hum.WalkSpeed = 4
		end
	end)
	task.delay(0.9, function()
		if hum.Parent then
			hum.WalkSpeed = speed
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or inMenu then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.M then
		openMenu()
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
		press()
	elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonX then
		setBall()
	elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.C or key == Enum.KeyCode.ButtonB then
		dive()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		release()
	end
end)

menuButton.Activated:Connect(function()
	openMenu()
end)
hitButton.MouseButton1Down:Connect(press)
hitButton.MouseButton1Up:Connect(release)
setButton.MouseButton1Down:Connect(setBall)
diveButton.MouseButton1Down:Connect(dive)

---------------------------------------------------------------- messages from the server

remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "ball" then
		ballState = a
		if a.mode ~= "hold" then
			charging = false
		end
	elseif kind == "state" then
		local wasServing, hadTeam = myServe(), myTeam() ~= 0
		state = a
		if not myServe() then
			charging = false
		elseif not wasServing then
			task.delay(0.35, lookAtNet)
		end
		if not hadTeam and myTeam() ~= 0 then
			task.delay(0.8, lookAtNet)
		end
		refreshBoard()
	elseif kind == "banner" then
		showBanner(a, b, c)
	elseif kind == "fx" then
		if a == "hit" then
			burst(b, Color3.new(1, 1, 1), 4)
			if c and c.user == player.UserId and c.kind ~= "serve" then
				showQuality(c.q or 0.5)
			end
		elseif a == "block" then
			burst(b, Color3.fromRGB(255, 230, 120), 6)
		elseif a == "net" then
			burst(b, Color3.fromRGB(200, 220, 255), 3)
		elseif a == "land" then
			ripple(b, (c and c.inside) and Color3.new(1, 1, 1) or Color3.fromRGB(255, 110, 90))
		end
	elseif kind == "miss" then
		flash("MISSED", DIM)
	elseif kind == "cue" then
		local keys = {
			kbm = { bump = "CLICK", set = "E", spike = "SPACE + CLICK  (E to tip)", over = "CLICK" },
			pad = { bump = "R2", set = "X", spike = "A + R2  (X to tip)", over = "R2" },
			touch = { bump = "HIT", set = "SET", spike = "JUMP + HIT  (SET to tip)", over = "HIT" },
		}
		local words = { bump = "PASS", set = "SET", spike = "SPIKE", over = "SEND IT OVER" }
		local key = (keys[lastInput] or keys.kbm)[a] or ""
		cue.Text = "YOUR BALL  ·  " .. (words[a] or "PLAY IT") .. "  <font color=\"#9aa0aa\">" .. key .. "</font>"
		cueUntil = (b or serverNow()) + 0.4
	end
end)

---------------------------------------------------------------- every frame

local spin = 0
RunService.RenderStepped:Connect(function(dt)
	local t = serverNow()
	local pos = ballAt(t)
	if ballState.mode == "fly" then
		spin += dt * math.min(ballState.v0.Magnitude, 60) * 0.3
	end
	local cf = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.4, 0)
	ballPart.CFrame = cf
	for i, band in stripes do
		band.CFrame = cf * STRIPE_OFFSET[i]
	end

	local height = math.max(pos.Y - GY, 0)
	local d = math.clamp(2.2 - height * 0.06, 0.7, 2.2)
	shadow.Size = Vector3.new(0.04, d, d)
	shadow.CFrame = CFrame.new(pos.X, GY + 0.05, pos.Z) * FLAT
	shadow.Transparency = math.clamp(0.5 + height * 0.025, 0.5, 0.88)

	local live = state.phase == "rally" and ballState.mode == "fly"
	local land = live and landingPoint()
	if land then
		marker.CFrame = CFrame.new(land.X, GY + 0.04, land.Z) * FLAT
		marker.Transparency = 0.8
	else
		marker.Transparency = 1
	end

	-- white outline on the ball when it's in your reach
	local glow = false
	local team = myTeam()
	if live and team ~= 0 then
		local hum, hrp = character()
		if hrp then
			local off = pos - hrp.Position
			local flat = Vector3.new(off.X, 0, off.Z).Magnitude
			local mySide = (pos.Z - C.Z) * (team == 1 and 1 or -1) > -1.5
			-- same windows the server uses: spike in the air, pass on the ground
			local lo, hi = -3.5, 5
			if airborne(hum) then
				lo, hi = -2.5, 8
			end
			glow = mySide and flat <= REACH + 1.2 and off.Y > lo and off.Y < hi
		end
	end
	reachGlow.Enabled = glow

	-- play a slightly early press the moment the ball arrives
	if pending then
		local hum, hrp = character()
		if os.clock() > pending.expires or not live then
			pending = nil
		elseif canPlay(pending.kind, hum, hrp) then
			local kind = pending.kind
			pending = nil
			lastSend = 0
			sendHit(kind)
		end
	end

	-- where your serve or spike will go
	local aiming = (charging and myServe()) or (live and team ~= 0 and airborne((character())))
	if aiming then
		local aim = aimPoint()
		aimMarker.CFrame = CFrame.new(aim.X, GY + 0.05, aim.Z) * FLAT
		aimMarker.Color = COLORS[team] or Color3.new(1, 1, 1)
		aimMarker.Transparency = 0.45
	else
		aimMarker.Transparency = 1
	end

	cueBox.Visible = live and t < cueUntil

	if charging then
		powerBar.Visible = true
		powerFill.Size = UDim2.fromScale(chargePower(), 1)
		if os.clock() - chargeStart > 2.2 then
			release() -- held far too long
		end
	else
		powerBar.Visible = false
	end
	updatePrompts()

	-- the ring on the floor and the name tag follow you
	local hum, hrp = character()
	local onCourt = not inMenu and team ~= 0 and hrp ~= nil
	if onCourt then
		local look = hrp.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local airLift = math.clamp(hrp.Position.Y - GY - 3, 0, 20)
		ringModel:PivotTo(CFrame.new(hrp.Position.X, GY + 0.06, hrp.Position.Z) * CFrame.Angles(0, yaw, 0))
		local fade = 0.15 + math.clamp(airLift / 10, 0, 0.5) -- fainter while you're high in the air
		for _, seg in ringParts do
			seg.Transparency = fade
		end
		tag.Adornee = hum and hum.Parent and hum.Parent:FindFirstChild("Head") or hrp
		tag.Enabled = true
	else
		for _, seg in ringParts do
			seg.Transparency = 1
		end
		tag.Enabled = false
	end
end)

refreshBoard()
remote:FireServer("sync")
