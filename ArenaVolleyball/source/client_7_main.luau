
---------------------------------------------------------------- messages from the server

local recordedMatch = false

remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "ball" then
		ballState = a
		if a.mode ~= "hold" then
			Controls.charging = false
		end
	elseif kind == "state" then
		local wasServing = myServe()
		state = a
		local me, team = myEntry()
		if not myServe() then
			Controls.charging = false
		elseif not wasServing then
			Cam.focus = nil
		end
		-- a finished match goes into this session's results (form and head-to-head)
		if me and a.phase == "matchover" and not recordedMatch then
			recordedMatch = true
			local winner = (a.sets[1] > a.sets[2]) and 1 or 2
			table.insert(history, {
				home = a.teamIds[1],
				away = a.teamIds[2],
				winner = winner,
				score = a.score[1] .. " - " .. a.score[2],
				mine = team,
			})
		elseif a.phase ~= "matchover" then
			recordedMatch = false
		end
		if inMenu and Menu.waiting and me then
			closeMenu()
		elseif not inMenu and not me then
			-- full time, or you were taken out of the match
			openMenu("home")
			local last = history[#history]
			if last and not a.active then
				Menu.toast(string.format("FULL TIME   %s %s %s", Teams.list[last.home].short, last.score, Teams.list[last.away].short))
			end
		end
		if inMenu and (Menu.current == "teams" or Menu.current == "preview") then
			-- someone else may have started a match: show it
			local hook = Menu.onShow[Menu.current]
			if hook and (a.active ~= Menu.lastActive) then
				hook()
			end
		end
		Menu.lastActive = a.active
		if not inMenu then
			HUD.refresh()
		end
	elseif kind == "banner" then
		if not inMenu then
			HUD.showBanner(a, b, c)
		end
	elseif kind == "act" then
		-- animation cue: your own dive and serve toss already played the moment you pressed
		local mine = a == player.Character
		if not (mine and (b == "dive" or b == "serveprep")) then
			Anim.play(a, b)
		end
	elseif kind == "fx" then
		if a == "hit" then
			burst(b, Color3.new(1, 1, 1), 4)
			if c then
				lastTouch.team, lastTouch.index = c.team or 0, c.index or 0
				if c.user == player.UserId and c.kind ~= "serve" then
					HUD.quality(c.q or 0.5)
				end
				if not inMenu then
					HUD.refresh()
				end
			end
		elseif a == "block" then
			burst(b, Color3.fromRGB(255, 230, 120), 6)
		elseif a == "net" then
			burst(b, Color3.fromRGB(200, 220, 255), 3)
		elseif a == "land" then
			ripple(b, (c and c.inside) and Color3.new(1, 1, 1) or Color3.fromRGB(255, 110, 90))
		end
	elseif kind == "miss" then
		HUD.flash("MISSED", COL.dim)
	elseif kind == "cue" then
		local keys = {
			kbm = { bump = "CLICK", set = "E", spike = "SPACE + CLICK  (E to tip)", over = "CLICK" },
			pad = { bump = "R2", set = "X", spike = "A + R2  (X to tip)", over = "R2" },
			touch = { bump = "HIT", set = "SET", spike = "JUMP + HIT  (SET to tip)", over = "HIT" },
		}
		local words = { bump = "PASS", set = "SET", spike = "SPIKE", over = "SEND IT OVER" }
		local key = (keys[lastInput] or keys.kbm)[a] or ""
		HUD.cueText.Text = "YOUR BALL  ·  " .. (words[a] or "PLAY IT") .. "  <font color=\"#5ef2e0\">" .. key .. "</font>"
		HUD.cueUntil = (b or serverNow()) + 0.4
	end
end)

-- the plain body for kits arrives from the server shortly after joining
shared.ChildAdded:Connect(function(child)
	if child.Name == "MenuModel" and inMenu then
		local hook = Menu.onShow[Menu.current]
		if hook then
			hook()
		end
	end
end)

---------------------------------------------------------------- every frame

-- poses go on after the normal animations each frame
RunService.Stepped:Connect(function(_, dt)
	Anim.step(dt, ballAt(serverNow()))
end)

local spin = 0
RunService.RenderStepped:Connect(function(dt)
	local t = serverNow()
	local pos = ballAt(t)
	local hidden = ballState.mode == "hidden"
	if ballState.mode == "fly" then
		spin += dt * math.min(ballState.v0.Magnitude, 60) * 0.3
	end
	local cf = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.4, 0)
	Ball.part.CFrame = cf
	Ball.part.Transparency = hidden and 1 or 0
	for i, band in Ball.bands do
		band.CFrame = cf * Ball.BAND_OFFSET[i]
		band.Transparency = hidden and 1 or 0
	end
	local height = math.max(pos.Y - GY, 0)
	local d = math.clamp(2 - height * 0.06, 0.6, 2)
	Ball.shadow.Size = Vector3.new(0.04, d, d)
	Ball.shadow.CFrame = CFrame.new(pos.X, GY + 0.05, pos.Z) * FLAT
	Ball.shadow.Transparency = hidden and 1 or math.clamp(0.5 + height * 0.025, 0.5, 0.88)

	local live = state.phase == "rally" and ballState.mode == "fly"
	local land = live and landingPoint()
	if land then
		Ball.marker.CFrame = CFrame.new(land.X, GY + 0.04, land.Z) * FLAT
		Ball.marker.Transparency = 0.8
	else
		Ball.marker.Transparency = 1
	end

	local _, team = myEntry()
	local hum, hrp = character()
	-- white outline on the ball when it's in your reach
	local glow = false
	if live and team ~= 0 and hrp then
		local off = pos - hrp.Position
		local flat = Vector3.new(off.X, 0, off.Z).Magnitude
		local mySide = (pos.Z - C.Z) * (team == 1 and 1 or -1) > -1.5
		local lo, hi = -3.5, 5
		if airborne(hum) then
			lo, hi = -2.5, 8
		end
		glow = mySide and flat <= REACH + 1.2 and off.Y > lo and off.Y < hi
	end
	Ball.glow.Enabled = glow and not inMenu

	-- play a slightly early press the moment the ball arrives
	local pending = Controls.pending
	if pending then
		if os.clock() > pending.expires or not live then
			Controls.pending = nil
		elseif canPlay(pending.kind, hrp) then
			Controls.pending = nil
			Controls.lastSend = 0
			sendHit(pending.kind)
		end
	end

	-- where your serve or spike will land
	local aiming = settings.aimMarker and not inMenu and ((Controls.charging and myServe()) or (live and team ~= 0 and airborne(hum)))
	if aiming then
		local aim = aimPoint()
		Ball.aim.CFrame = CFrame.new(aim.X, GY + 0.05, aim.Z) * FLAT
		Ball.aim.Color = teamDef(team).primary
		Ball.aim.Transparency = 0.4
	else
		Ball.aim.Transparency = 1
	end

	if Controls.charging then
		HUD.power = chargePower()
		if os.clock() - Controls.chargeStart > 2.2 then
			release() -- held far too long
		end
	else
		HUD.power = nil
	end
	Stamina.update(dt)
	if not inMenu then
		updatePrompts()
		HUD.update(t, pos)
		Cam.update(dt, pos)
	end
end)

---------------------------------------------------------------- start in the main menu

openMenu("home")
remote:FireServer("sync")
