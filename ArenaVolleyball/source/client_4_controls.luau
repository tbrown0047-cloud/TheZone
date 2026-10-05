
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
	local custom = Anim.tryDiveEmote()
	if not custom then
		Anim.play(hum.Parent, "dive")
	end
	remote:FireServer("dive", { custom = custom })
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

---------------------------------------------------------------- broadcast camera: behind your team, following the play

local Cam = { focus = nil, zoom = 1 }

UserInputService.InputChanged:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseWheel and settings.camera == "broadcast" and not inMenu then
		Cam.zoom = math.clamp(Cam.zoom - input.Position.Z * 0.06, 0.6, 1.25)
	end
end)

function Cam.update(dt, ballPos)
	if inMenu then
		return
	end
	local cam = workspace.CurrentCamera
	local team = myTeam()
	local hum, hrp = character()
	if settings.camera ~= "broadcast" or team == 0 or not hrp then
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
	local target = Vector3.new(C.X + (ballPos.X - C.X) * 0.35 + (hrp.Position.X - C.X) * 0.3, GY, C.Z)
	Cam.focus = Cam.focus and Cam.focus:Lerp(target, math.min(1, dt * 2.5)) or target
	local eye = Vector3.new(C.X + (Cam.focus.X - C.X) * 0.8, GY + 28 * Cam.zoom, C.Z + s * (HALF_L + 34) * Cam.zoom)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 52
	cam.CFrame = CFrame.lookAt(eye, Vector3.new(Cam.focus.X, GY + 2, C.Z - s * 4))
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
		HUD.setPrompts({
			{ pad and "R2" or "CLICK", "Pass · spike in the air" },
			{ pad and "X" or "E", "Set · tip in the air" },
			{ pad and "A" or "SPACE", "Jump · block at the net" },
			{ pad and "B" or "Q", "Dive" },
			{ pad and "START" or "M", "Pause" },
		})
	else
		HUD.setPrompts({ { pad and "START" or "M", "Pause" }, { "V", "Camera" } })
	end
end
