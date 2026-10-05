
---------------------------------------------------------------- controls

local Controls = { charging = false, chargeStart = 0, lastSend = 0, lastDive = 0, diveUntil = 0, pending = nil }
local showPause -- the pause screen, defined with the menus

local function chargePower()
	return math.clamp((os.clock() - Controls.chargeStart) / 1.2, 0, 1)
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
local function canPlay(kind, hrp)
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

-- a press made slightly early is played the moment the ball arrives
local function sendHit(kind)
	local hum, hrp = character()
	local air = airborne(hum) and os.clock() > Controls.diveUntil
	if not air and (kind == "spike" or kind == "tip") then
		kind = (kind == "spike") and "bump" or "set"
	end
	if os.clock() - Controls.lastSend < 0.3 then
		return
	end
	if not canPlay(kind, hrp) then
		Controls.pending = { kind = kind, expires = os.clock() + 0.3 }
		return
	end
	Controls.pending = nil
	Controls.lastSend = os.clock()
	remote:FireServer("hit", { kind = kind, aim = aimPoint(), root = hrp.Position, air = air, id = ballState.id, t = serverNow() })
end

local function press()
	if inMenu then
		return
	end
	if myServe() then
		if ballState.mode == "hold" and not Controls.charging then
			Controls.charging = true
			Controls.chargeStart = os.clock()
			local hum = character()
			if hum and hum.Parent then
				Anim.play(hum.Parent, "serveprep")
			end
			remote:FireServer("prep", {})
		end
		return
	end
	sendHit("spike") -- in the air this spikes; on the ground it becomes a pass
end

local function release()
	if not Controls.charging then
		return
	end
	Controls.charging = false
	local hum, hrp = character()
	if not hrp or not myServe() then
		return
	end
	remote:FireServer("serve", { aim = aimPoint(), power = chargePower(), root = hrp.Position, air = airborne(hum) })
end

local function setBall()
	if not inMenu and not myServe() then
		sendHit("tip") -- in the air this tips over the block; on the ground it sets
	end
end

---------------------------------------------------------------- stamina: jumps and dives tire you; it comes back on the ground

local Stamina = { value = 100 }

local function hookCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	Stamina.hum = hum
	Stamina.baseJump = hum.JumpPower
	Stamina.baseHeight = hum.JumpHeight
	Stamina.value = 100
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping and not inMenu then
			Stamina.value = math.max(0, Stamina.value - 12)
		end
	end)
end
if player.Character then
	task.spawn(hookCharacter, player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

function Stamina.update(dt)
	local hum = Stamina.hum
	if not hum or not hum.Parent then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air then
		Stamina.value = math.min(100, Stamina.value + 9 * dt)
	end
	-- tired legs don't jump as high
	local scale = (Stamina.value < 25 and not inMenu) and 0.75 or 1
	if Stamina.baseJump then
		hum.JumpPower = Stamina.baseJump * scale
	end
	if Stamina.baseHeight then
		hum.JumpHeight = Stamina.baseHeight * scale
	end
	HUD.stamina = Stamina.value / 100
end

local function dive()
	local hum, hrp = character()
	if inMenu or not hum or not hrp or state.phase ~= "rally" then
		return
	end
	if os.clock() - Controls.lastDive < 1.4 or airborne(hum) or Stamina.value < 20 then
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
	Stamina.value -= 20
	Controls.lastDive = os.clock()
	Controls.diveUntil = os.clock() + 0.7
	Anim.play(hum.Parent, "dive")
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
	if key == Enum.KeyCode.M or key == Enum.KeyCode.ButtonStart then
		if showPause then
			showPause()
		end
	elseif state.paused then
		return -- nothing to do while the match is paused
	elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonY then
		remote:FireServer("ability", {})
	elseif key == Enum.KeyCode.F or key == Enum.KeyCode.DPadUp then
		remote:FireServer("call", {})
	elseif key == Enum.KeyCode.V then
		settings.camera = settings.camera == "broadcast" and "player" or "broadcast"
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
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

HUD.hitButton.MouseButton1Down:Connect(press)
HUD.hitButton.MouseButton1Up:Connect(release)
HUD.setButton.MouseButton1Down:Connect(setBall)
HUD.diveButton.MouseButton1Down:Connect(dive)

---------------------------------------------------------------- cameras
-- BROADCAST: a low chase camera behind your team that follows you and the ball.
-- SHOULDER (V): over your right shoulder, third-person-shooter style; the mouse turns it.

local Cam = { focus = nil, zoom = 1, yaw = 0, pitch = -0.22, ready = false, stick = Vector2.zero, shakeUntil = 0, shakePower = 0 }

function Cam.shake(power, seconds)
	Cam.shakePower = math.max(Cam.shakePower, power)
	Cam.shakeUntil = math.max(Cam.shakeUntil, os.clock() + seconds)
end

local function shoulderActive()
	return settings.camera == "player" and not inMenu and myTeam() ~= 0 and not state.paused
end

UserInputService.InputChanged:Connect(function(input, processed)
	if inMenu then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		Cam.zoom = math.clamp(Cam.zoom - input.Position.Z * 0.06, 0.6, 1.4)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement and shoulderActive() then
		Cam.yaw -= input.Delta.X * 0.0045
		Cam.pitch = math.clamp(Cam.pitch - input.Delta.Y * 0.0035, -1.1, 0.45)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		Cam.stick = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

function Cam.update(dt, ballPos)
	if inMenu then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	local cam = workspace.CurrentCamera
	local team = myTeam()
	local hum, hrp = character()
	if team == 0 or not hrp then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if cam.CameraType ~= Enum.CameraType.Custom then
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = 70
			if hum then
				cam.CameraSubject = hum
			end
		end
		return
	end
	local s = team == 1 and 1 or -1
	local shake = Vector3.zero
	if os.clock() < Cam.shakeUntil then
		local p = Cam.shakePower * (Cam.shakeUntil - os.clock()) / 0.3
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * p
	else
		Cam.shakePower = 0
	end
	cam.CameraType = Enum.CameraType.Scriptable

	if settings.camera == "player" then
		if not Cam.ready then
			Cam.yaw = team == 1 and 0 or math.pi -- start facing the net
			Cam.pitch = -0.22
			Cam.ready = true
		end
		UserInputService.MouseBehavior = shoulderActive() and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
		if Cam.stick.Magnitude > 0.15 then
			Cam.yaw -= Cam.stick.X * dt * 3
			Cam.pitch = math.clamp(Cam.pitch + Cam.stick.Y * dt * 2, -1.1, 0.45)
		end
		local rot = CFrame.Angles(0, Cam.yaw, 0) * CFrame.Angles(Cam.pitch, 0, 0)
		local pivot = hrp.Position + Vector3.new(0, 2.4, 0)
		local eye = pivot + rot:VectorToWorldSpace(Vector3.new(2.6, 0.8, 9 * Cam.zoom))
		eye = Vector3.new(eye.X, math.max(eye.Y, GY + 1.2), eye.Z)
		cam.FieldOfView = 70
		cam.CFrame = CFrame.new(eye + shake) * rot
		return
	end

	Cam.ready = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	-- follow a point between you and the ball, kept on the court
	local ballOnOurSide = (ballPos.Z - C.Z) * s > 0
	local blend = ballOnOurSide and 0.45 or 0.3
	local target = hrp.Position:Lerp(ballPos, blend)
	local depth = math.clamp((target.Z - C.Z) * s, -4, HALF_L + 2)
	target = Vector3.new(math.clamp(target.X, C.X - HALF_W - 4, C.X + HALF_W + 4), GY, C.Z + s * depth)
	Cam.focus = Cam.focus and Cam.focus:Lerp(target, math.min(1, dt * 3)) or target
	local focusDepth = (Cam.focus.Z - C.Z) * s
	local eye = Vector3.new(C.X + (Cam.focus.X - C.X) * 0.75, GY + 15 * Cam.zoom, C.Z + s * (focusDepth + 26 * Cam.zoom))
	local look = Vector3.new(Cam.focus.X, GY + 3, C.Z + s * (focusDepth - 14))
	cam.FieldOfView = 62
	cam.CFrame = CFrame.lookAt(eye + shake, look)
end

local function updatePrompts()
	if myTeam() == 0 then
		HUD.setPrompts({})
		return
	end
	local pad = lastInput == "pad"
	if myServe() then
		local left = math.max(0, math.ceil(state.deadline - serverNow()))
		HUD.setPrompts({
			{ pad and "HOLD R2" or "HOLD CLICK", "Serve  (" .. left .. "s)" },
			{ pad and "A" or "SPACE", "Jump first: jump serve" },
			{ pad and "R-STICK" or "MOUSE", "Aim" },
		})
	elseif state.phase == "rally" then
		local me = myEntry()
		local ready = me and (me.meter or 0) >= 100
		HUD.setPrompts({
			{ pad and "R2" or "CLICK", "Pass · spike in the air" },
			{ pad and "X" or "E", "Set · tip in the air" },
			{ pad and "A" or "SPACE", "Jump · block at the net" },
			{ pad and "B" or "Q", "Dive" },
			ready and { pad and "Y" or "R", (me.ability or "Ability") .. " ready!" } or { pad and "UP" or "F", "Call for a quick set" },
		})
	else
		HUD.setPrompts({ { pad and "START" or "M", "Pause" }, { "V", "Camera" } })
	end
end
