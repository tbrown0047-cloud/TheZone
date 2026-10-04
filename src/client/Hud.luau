-- In-game HUD in the menu's glass style (Battlefield-style layout):
--   top centre    compass strip with heading
--   top right     kill feed
--   centre        score popups ("ENEMY KILLED  100")
--   bottom left   rotating radar, coordinates and squad list with health
--   bottom right  ammo, health, hydration/energy and the 1 / 2 / 3 weapon strip
-- Keys 1/2/3 equip the SPEARHEAD Tool for the gun in each weapon slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared:WaitForChild("Inventory"))
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))
local UIConfig = require(Shared:WaitForChild("UIConfig"))

local ItemIcon = require(script.Parent.ItemIcon)
local Theme = require(script.Parent.Theme)

local C = Theme.Color
local KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }

-- Names the ammo readout looks for on the equipped Tool, as attributes or as
-- IntValue/NumberValue descendants. Add SPEARHEAD's names here if they differ.
local AMMO_KEYS = { "Ammo", "MagAmmo", "CurrentAmmo", "Mag", "Clip" }
local RESERVE_KEYS = { "StoredAmmo", "ReserveAmmo", "Reserve", "SpareAmmo", "AmmoPool" }
local FIREMODE_KEYS = { "FireMode", "Firemode", "Mode" }

local RADAR_SIZE = 240
local RADAR_RANGE = 150 -- studs from centre to edge
local KILL_POINTS = 100
local FEED_LIFETIME = 6
local MAX_FEED = 5

local Hud = {}

local function readValue(tool: Tool, keys: { string }): any
	for _, key in keys do
		local attr = tool:GetAttribute(key)
		if attr ~= nil then
			return attr
		end
		local child = tool:FindFirstChild(key, true)
		if child and child:IsA("ValueBase") then
			return (child :: any).Value
		end
	end
	return nil
end

function Hud.new(playerGui: PlayerGui)
	local self = {}
	local player = Players.LocalPlayer
	local state: any = nil
	local menuOpen = true
	local enabledSetting = true

	local gui = Theme.create("ScreenGui", {
		Parent = playerGui,
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})

	-- Each corner group scales with the screen but stays pinned to its corner
	local scales: { UIScale } = {}
	local function group(name: string, anchor: Vector2, position: UDim2, size: Vector2): Frame
		local frame = Theme.create("Frame", {
			Parent = gui,
			Name = name,
			BackgroundTransparency = 1,
			AnchorPoint = anchor,
			Position = position,
			Size = UDim2.fromOffset(size.X, size.Y),
		})
		table.insert(scales, Theme.create("UIScale", { Parent = frame }))
		return frame
	end
	local function fit()
		local size = gui.AbsoluteSize
		if size.X > 0 then
			local scale = math.clamp(math.min(size.X / 1920, size.Y / 1080), 0.55, 1.6)
			for _, s in scales do
				s.Scale = scale
			end
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local bottomLeft = group("BottomLeft", Vector2.new(0, 1), UDim2.new(0, 28, 1, -28), Vector2.new(520, 300))
	local bottomRight = group("BottomRight", Vector2.new(1, 1), UDim2.new(1, -28, 1, -28), Vector2.new(460, 200))
	local topRight = group("TopRight", Vector2.new(1, 0), UDim2.new(1, -28, 0, 24), Vector2.new(560, 200))
	local topCenter = group("TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 16), Vector2.new(520, 48))
	local center = group("Center", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.64), Vector2.new(520, 140))

	------------------------------------------------------------------------------
	-- Compass
	------------------------------------------------------------------------------

	local PX_PER_DEG = 4
	local compassClip = Theme.create("Frame", {
		Parent = topCenter,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.fromOffset(480, 24),
	})
	local strip = Theme.create("Frame", { Parent = compassClip, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 24) })
	local LETTERS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }
	for deg = -180, 540, 15 do
		local wrapped = deg % 360
		local x = deg * PX_PER_DEG
		local letter = LETTERS[wrapped]
		if letter then
			Theme.label({
				Parent = strip,
				Text = letter,
				FontFace = Theme.Font.Bold,
				TextSize = if #letter == 1 then 16 else 12,
				TextColor3 = if letter == "N" then C.Accent else C.Text,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(x, 0),
				Size = UDim2.fromOffset(30, 16),
			})
		else
			Theme.create("Frame", {
				Parent = strip,
				BackgroundColor3 = C.Text,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(x, 4),
				Size = UDim2.fromOffset(1, 8),
			})
		end
	end
	Theme.create("Frame", {
		Parent = topCenter,
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(260, 18),
		Size = UDim2.fromOffset(2, 8),
	})
	local headingLabel = Theme.label({
		Parent = topCenter,
		FontFace = Theme.Font.Mono,
		TextSize = 12,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(260, 28),
		Size = UDim2.fromOffset(60, 16),
	})

	------------------------------------------------------------------------------
	-- Radar + squad
	------------------------------------------------------------------------------

	Theme.label({
		Parent = bottomLeft,
		Text = UIConfig.GAME_NAME,
		FontFace = Theme.Font.Bold,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(120, 18),
	})
	local coordLabel = Theme.label({
		Parent = bottomLeft,
		FontFace = Theme.Font.Mono,
		TextSize = 11,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(RADAR_SIZE - 150, 33),
		Size = UDim2.fromOffset(150, 18),
	})

	local radar = Theme.glass({
		Parent = bottomLeft,
		BackgroundTransparency = 0.4,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 300 - RADAR_SIZE),
		Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE),
	})
	for _, info in { { UDim2.new(0.5, 0, 0, 0), UDim2.new(0, 1, 1, 0) }, { UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1) } } do
		Theme.create("Frame", { Parent = radar, BackgroundColor3 = C.Text, BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = info[1], Size = info[2] })
	end
	local ring = Theme.create("Frame", {
		Parent = radar,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
	})
	Theme.create("UICorner", { Parent = ring, CornerRadius = UDim.new(1, 0) })
	Theme.stroke(ring, 0.85)
	local dots = Theme.create("Frame", { Parent = radar, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local northMarker = Theme.label({
		Parent = radar,
		Text = "N",
		FontFace = Theme.Font.Bold,
		TextSize = 12,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
	})
	Theme.label({
		Parent = radar,
		Text = "▲",
		TextSize = 14,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 3,
	})

	Theme.header(bottomLeft, "Squad", UDim2.fromOffset(RADAR_SIZE + 24, 300 - RADAR_SIZE))
	local squadRows = {}
	for i = 1, 4 do
		local y = 300 - RADAR_SIZE + 26 + (i - 1) * 48
		local name = Theme.label({
			Parent = bottomLeft,
			FontFace = Theme.Font.Bold,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(RADAR_SIZE + 24, y),
			Size = UDim2.fromOffset(220, 20),
		})
		local track, set = Theme.bar(bottomLeft, UDim2.fromOffset(RADAR_SIZE + 24, y + 24), UDim2.fromOffset(160, 3), C.Text)
		squadRows[i] = { name = name, track = track, set = set, fill = track:FindFirstChildOfClass("Frame") }
	end

	local function teammates(): { Player }
		local list = { player }
		if player.Team and not player.Neutral then
			for _, other in Players:GetPlayers() do
				if other ~= player and other.Team == player.Team then
					table.insert(list, other)
				end
			end
		end
		return list
	end

	local function healthOf(p: Player): number
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return 0
		end
		return humanoid.Health / math.max(humanoid.MaxHealth, 1)
	end

	local function renderSquad()
		local list = teammates()
		for i, row in squadRows do
			local p = list[i]
			row.name.Visible = p ~= nil
			row.track.Visible = p ~= nil
			if p then
				local hp = healthOf(p)
				row.name.Text = p.DisplayName
				row.name.TextColor3 = if p == player then C.Accent elseif hp <= 0 then C.Faint else C.Text
				row.set(hp)
				row.fill.BackgroundColor3 = if hp < 0.35 then C.Danger else C.Text
			end
		end
	end

	local dotPool: { Frame } = {}
	local function renderRadar(heading: number)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, dot in dotPool do
			dot.Visible = false
		end
		local yaw = math.rad(heading)
		local half = RADAR_SIZE / 2

		local function project(offset: Vector3): Vector2
			-- Rotate so the camera's facing points up the radar
			local x = offset.X * math.cos(yaw) + offset.Z * math.sin(yaw)
			local y = -offset.X * math.sin(yaw) + offset.Z * math.cos(yaw)
			return Vector2.new(x, y) * (half / RADAR_RANGE)
		end

		local north = project(Vector3.new(0, 0, -RADAR_RANGE)).Unit * (half - 12)
		northMarker.Position = UDim2.fromOffset(half + north.X, half + north.Y)

		if not root then
			return
		end
		local index = 0
		for _, other in Players:GetPlayers() do
			local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				if Vector2.new(offset.X, offset.Z).Magnitude <= RADAR_RANGE then
					index += 1
					local dot = dotPool[index]
					if not dot then
						dot = Theme.create("Frame", {
							Parent = dots,
							BorderSizePixel = 0,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Size = UDim2.fromOffset(7, 7),
						})
						Theme.create("UICorner", { Parent = dot, CornerRadius = UDim.new(1, 0) })
						dotPool[index] = dot
					end
					local p = project(offset)
					local friendly = player.Team ~= nil and not player.Neutral and other.Team == player.Team
					dot.BackgroundColor3 = if friendly then C.Text else C.Danger
					dot.Position = UDim2.fromOffset(half + p.X, half + p.Y)
					dot.Visible = true
				end
			end
		end
		local pos = root.Position
		coordLabel.Text = string.format("%04d  %04d", math.floor(pos.X) % 10000, math.floor(pos.Z) % 10000)
	end

	------------------------------------------------------------------------------
	-- Weapon panel
	------------------------------------------------------------------------------

	local weaponLabel = Theme.label({
		Parent = bottomRight,
		FontFace = Theme.Font.Bold,
		TextSize = 12,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(460, 16),
	})
	local magLabel = Theme.label({
		Parent = bottomRight,
		FontFace = Theme.Font.Mono,
		TextSize = 60,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(100, 14),
		Size = UDim2.fromOffset(236, 64),
	})
	Theme.create("Frame", { Parent = bottomRight, BackgroundColor3 = C.Text, BackgroundTransparency = 0.8, BorderSizePixel = 0, Position = UDim2.fromOffset(350, 30), Size = UDim2.fromOffset(1, 40) })
	local reserveLabel = Theme.label({
		Parent = bottomRight,
		FontFace = Theme.Font.Mono,
		TextSize = 24,
		TextColor3 = C.Dim,
		Position = UDim2.fromOffset(364, 40),
		Size = UDim2.fromOffset(96, 30),
	})
	local vitalsLabel = Theme.label({
		Parent = bottomRight,
		FontFace = Theme.Font.Mono,
		TextSize = 11,
		TextColor3 = C.Dim,
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.fromOffset(300, 16),
	})
	local healthLabel = Theme.label({
		Parent = bottomRight,
		FontFace = Theme.Font.Mono,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(300, 86),
		Size = UDim2.fromOffset(160, 18),
	})
	local healthTrack, setHealth = Theme.bar(bottomRight, UDim2.fromOffset(0, 108), UDim2.fromOffset(460, 4), C.Text)
	local healthFill = healthTrack:FindFirstChildOfClass("Frame") :: Frame

	local slotViews = {}
	for i, slotName in Inventory.WEAPON_SLOTS do
		local frame = Theme.glass({
			Parent = bottomRight,
			BackgroundTransparency = 0.4,
			Position = UDim2.fromOffset((i - 1) * 156, 122),
			Size = UDim2.fromOffset(148, 74),
		})
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		local iconHolder = Theme.create("Frame", { Parent = frame, BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(132, 44) })
		local key = Theme.label({
			Parent = frame,
			Text = tostring(i),
			FontFace = Theme.Font.Mono,
			TextSize = 12,
			TextColor3 = C.Dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(110, 4),
			Size = UDim2.fromOffset(30, 14),
		})
		local name = Theme.label({
			Parent = frame,
			FontFace = Theme.Font.Bold,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(8, 52),
			Size = UDim2.fromOffset(132, 16),
		})
		slotViews[i] = { slot = slotName, frame = frame, stroke = stroke, icon = iconHolder, key = key, name = name, uid = "" }
	end

	local function equippedTool(): Tool?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Tool")
	end

	local function renderSlots()
		if not state then
			return
		end
		local tool = equippedTool()
		local currentUid = tool and tool:GetAttribute("ItemUid")
		for _, view in slotViews do
			local item = Inventory.slotItem(state, view.slot)
			local uid = if item then item.uid else ""
			if uid ~= view.uid then
				view.uid = uid
				view.icon:ClearAllChildren()
				if item then
					ItemIcon.render(view.icon, ItemDefs[item.id], 132 / 44, false)
				end
			end
			local active = item ~= nil and item.uid == currentUid
			view.name.Text = if item then ItemDefs[item.id].name else string.upper(view.slot)
			view.name.TextColor3 = if active then C.AccentText elseif item then C.Text else C.Faint
			view.key.TextColor3 = if active then C.AccentText else C.Dim
			view.frame.BackgroundColor3 = if active then C.Accent else C.Glass
			view.frame.BackgroundTransparency = if active then 0.1 else 0.4
			view.stroke.Transparency = if active then 1 else Theme.Alpha.Stroke
		end
	end

	local function renderWeapon()
		local tool = equippedTool()
		if not tool then
			weaponLabel.Text = ""
			magLabel.Text = "—"
			magLabel.TextColor3 = C.Faint
			reserveLabel.Text = ""
			return
		end
		local mode = readValue(tool, FIREMODE_KEYS)
		weaponLabel.Text = string.upper(tool.Name) .. (if mode ~= nil then "  ·  " .. string.upper(tostring(mode)) else "")
		local mag = readValue(tool, AMMO_KEYS)
		local reserve = readValue(tool, RESERVE_KEYS)
		if type(mag) == "number" then
			magLabel.Text = string.format("%03d", math.max(0, math.floor(mag)))
			magLabel.TextColor3 = if mag <= 5 then C.Danger else C.Text
		else
			magLabel.Text = "—"
			magLabel.TextColor3 = C.Faint
		end
		reserveLabel.Text = if type(reserve) == "number" then tostring(math.floor(reserve)) else ""
	end

	local function renderHealth()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local hp = if humanoid then humanoid.Health else 0
		local maxHp = if humanoid then humanoid.MaxHealth else 100
		local alpha = hp / math.max(maxHp, 1)
		setHealth(alpha)
		healthFill.BackgroundColor3 = if alpha < 0.35 then C.Danger else C.Text
		healthLabel.Text = string.format("+ %d", math.ceil(hp))
		healthLabel.TextColor3 = if alpha < 0.35 then C.Danger else C.Text
		if state then
			vitalsLabel.Text = string.format("HYD %03d   NRG %03d", math.floor(state.vitals.hydration), math.floor(state.vitals.energy))
			vitalsLabel.TextColor3 = if state.vitals.hydration < 20 or state.vitals.energy < 20 then C.Danger else C.Dim
		end
	end

	------------------------------------------------------------------------------
	-- Kill feed and score popups
	------------------------------------------------------------------------------

	local feed = Theme.create("Frame", { Parent = topRight, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	Theme.create("UIListLayout", {
		Parent = feed,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})
	local feedOrder = 0

	local function feedEntry(data: any)
		feedOrder += 1
		local row = Theme.glass({
			Parent = feed,
			BackgroundTransparency = 0.55,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = -feedOrder,
		})
		Theme.create("UIListLayout", {
			Parent = row,
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		Theme.create("UIPadding", { Parent = row, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
		local function part(text: string, color: Color3, font: Font, order: number)
			local l = Theme.label({ Parent = row, Text = text, TextColor3 = color, FontFace = font, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), LayoutOrder = order })
			return l
		end
		local me = player.UserId
		if data.killer then
			part(data.killer, if data.killerId == me then C.Accent else C.Text, Theme.Font.Bold, 1)
		end
		part(if data.weapon ~= "" then "[" .. string.upper(data.weapon) .. "]" else "[KIA]", C.Dim, Theme.Font.Mono, 2)
		part(data.victim, if data.victimId == me then C.Accent else C.Danger, Theme.Font.Bold, 3)

		local rows = {}
		for _, child in feed:GetChildren() do
			if child:IsA("Frame") then
				table.insert(rows, child)
			end
		end
		table.sort(rows, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = MAX_FEED + 1, #rows do
			rows[i]:Destroy()
		end
		task.delay(FEED_LIFETIME, function()
			if row.Parent then
				row:Destroy()
			end
		end)
	end

	local scoreTotal = Theme.label({
		Parent = center,
		FontFace = Theme.Font.Mono,
		TextSize = 30,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(520, 34),
		Visible = false,
	})
	local scoreLines = Theme.create("Frame", { Parent = center, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(520, 100) })
	Theme.create("UIListLayout", { Parent = scoreLines, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	local streak, streakToken, lineOrder = 0, 0, 0

	local function scorePopup(text: string, points: number)
		streak += points
		streakToken += 1
		local token = streakToken
		lineOrder += 1
		scoreTotal.Text = tostring(streak)
		scoreTotal.Visible = true
		local line = Theme.label({
			Parent = scoreLines,
			Text = text .. "   " .. points,
			FontFace = Theme.Font.Bold,
			TextSize = 20,
			TextColor3 = C.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(520, 26),
			LayoutOrder = -lineOrder,
		})
		Theme.tween(line, 0.25, { TextColor3 = C.Accent })
		task.delay(3, function()
			Theme.tween(line, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			line:Destroy()
			if token == streakToken then
				streak = 0
				scoreTotal.Visible = false
			end
		end)
	end

	local hudRemotes = ReplicatedStorage:WaitForChild("HudRemotes", 10)
	local killFeed = hudRemotes and hudRemotes:FindFirstChild("KillFeed") :: RemoteEvent?
	if killFeed then
		killFeed.OnClientEvent:Connect(function(data)
			feedEntry(data)
			if data.killerId == player.UserId and data.victimId ~= player.UserId then
				scorePopup("ENEMY KILLED", KILL_POINTS)
			end
		end)
	end

	------------------------------------------------------------------------------
	-- Input and updates
	------------------------------------------------------------------------------

	local function toggleSlot(index: number)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChildOfClass("Backpack")
		local item = state and Inventory.slotItem(state, slotViews[index].slot)
		if not humanoid or not backpack or not item then
			return
		end
		local tool = equippedTool()
		if tool and tool:GetAttribute("ItemUid") == item.uid then
			humanoid:UnequipTools()
			return
		end
		for _, t in backpack:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("ItemUid") == item.uid then
				humanoid:EquipTool(t)
				return
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or menuOpen then
			return
		end
		local index = KEYS[input.KeyCode]
		if index then
			toggleSlot(index)
		end
	end)

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(renderSlots)
		character.ChildRemoved:Connect(renderSlots)
		renderSlots()
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	local slowAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		local camera = workspace.CurrentCamera
		local look = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
		local heading = math.deg(math.atan2(look.X, -look.Z)) % 360
		strip.Position = UDim2.fromOffset(240 - heading * PX_PER_DEG, 0)
		headingLabel.Text = string.format("%03d", math.floor(heading))
		renderHealth()

		slowAcc += dt
		if slowAcc >= 0.1 then
			slowAcc = 0
			renderRadar(heading)
			renderWeapon()
			renderSquad()
		end
	end)

	local function updateVisibility()
		gui.Enabled = enabledSetting and not menuOpen and state ~= nil
		fit()
	end

	function self.refresh(newState: any)
		state = newState
		updateVisibility()
		renderSlots()
	end

	function self.setMenuOpen(open: boolean)
		menuOpen = open
		updateVisibility()
	end

	function self.setEnabled(enabled: boolean)
		enabledSetting = enabled
		updateVisibility()
	end

	return self
end

return Hud
