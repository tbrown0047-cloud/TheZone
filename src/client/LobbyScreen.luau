-- Main menu / lobby: logo, mode tabs and DEPLOY card on the left, your
-- character in the middle, player card and news + menu buttons on the right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared:WaitForChild("UIConfig"))

local Theme = require(script.Parent.Theme)

local C = Theme.Color
local IDLE_R15 = "rbxassetid://507766388"
local IDLE_R6 = "rbxassetid://180435571"

local LobbyScreen = {}

function LobbyScreen.new(ctx: any, parent: Instance)
	local self = {}
	local player = Players.LocalPlayer
	local state: any = nil
	local modeIndex = 1
	local regionIndex = 1

	local frame = Theme.create("Frame", { Parent = parent, Name = "Lobby", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	self.frame = frame

	-- Logo
	if UIConfig.LOGO_IMAGE ~= "" then
		Theme.create("ImageLabel", {
			Parent = frame,
			BackgroundTransparency = 1,
			Image = UIConfig.LOGO_IMAGE,
			ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromOffset(90, 56),
			Size = UDim2.fromOffset(math.floor(120 * UIConfig.LOGO_ASPECT), 120),
		})
	else
		Theme.label({
			Parent = frame,
			Text = UIConfig.GAME_NAME,
			FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
			TextSize = 72,
			Position = UDim2.fromOffset(86, 70),
			Size = UDim2.fromOffset(600, 90),
		})
	end

	-- Mode tabs + deploy card
	local card = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(90, 290), Size = UDim2.fromOffset(400, 520) })
	local art = Theme.create("Frame", {
		Parent = card,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(400, 250),
	})
	if UIConfig.DEPLOY_IMAGE ~= "" then
		Theme.create("ImageLabel", { Parent = art, BackgroundTransparency = 1, Image = UIConfig.DEPLOY_IMAGE, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1) })
	end
	local artWord = Theme.label({
		Parent = art,
		FontFace = Theme.Font.Bold,
		TextSize = 64,
		TextColor3 = C.Text,
		TextTransparency = if UIConfig.DEPLOY_IMAGE ~= "" then 1 else 0.88,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	Theme.create("Frame", {
		Parent = art,
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
	})
	local modeTitle = Theme.label({ Parent = card, FontFace = Theme.Font.Bold, TextSize = 28, Position = UDim2.fromOffset(24, 268), Size = UDim2.fromOffset(352, 34) })
	local modeDesc = Theme.label({
		Parent = card,
		TextSize = 14,
		TextColor3 = C.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(24, 310),
		Size = UDim2.fromOffset(352, 100),
	})
	local deployButton = Theme.button({ Parent = card, Text = "DEPLOY", TextSize = 20, Position = UDim2.fromOffset(20, 448), Size = UDim2.fromOffset(360, 52) }, "primary")
	deployButton.Activated:Connect(function()
		ctx.deploy()
	end)

	local modeNames = {}
	for _, mode in UIConfig.MODES do
		table.insert(modeNames, mode.name)
	end
	local function showMode()
		local mode = UIConfig.MODES[modeIndex]
		modeTitle.Text = mode.title
		modeDesc.Text = mode.description
		artWord.Text = mode.name
	end
	local _, selectMode = Theme.tabs(frame, modeNames, UDim2.fromOffset(90, 252), 200, 32, function(name)
		for i, mode in UIConfig.MODES do
			if mode.name == name then
				modeIndex = i
			end
		end
		showMode()
	end, 13)
	selectMode(modeNames[1])

	-- Region selector
	local region = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(90, 822), Size = UDim2.fromOffset(400, 40), BackgroundTransparency = 0.45 })
	local regionLabel = Theme.label({ Parent = region, FontFace = Theme.Font.Bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	local function showRegion()
		regionLabel.Text = UIConfig.REGIONS[regionIndex]
	end
	for i, arrow in { "◂", "▸" } do
		local button = Theme.button({ Parent = region, Text = arrow, TextSize = 16, Position = UDim2.fromOffset(if i == 1 then 4 else 360, 4), Size = UDim2.fromOffset(36, 32) }, "ghost")
		button.Activated:Connect(function()
			regionIndex = (regionIndex - 1 + (if i == 1 then -1 else 1)) % #UIConfig.REGIONS + 1
			showRegion()
		end)
	end
	showRegion()

	-- Character
	local viewport = Theme.create("ViewportFrame", {
		Parent = frame,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(700, 90),
		Size = UDim2.fromOffset(520, 980),
		Ambient = Color3.fromRGB(150, 155, 165),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
	})

	local function buildCharacterView()
		viewport:ClearAllChildren()
		local character = player.Character
		if not character then
			return
		end
		character.Archivable = true
		local clone = character:Clone()
		if not clone then
			return
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("Sound") or d:IsA("ForceField") then
				d:Destroy()
			end
		end

		local world = Instance.new("WorldModel")
		world.Parent = viewport
		clone:PivotTo(CFrame.Angles(0, math.rad(-18), 0))
		clone.Parent = world

		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.2, -13), Vector3.new(0, -0.4, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
			local animation = Instance.new("Animation")
			animation.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15 then IDLE_R15 else IDLE_R6
			pcall(function()
				local track = animator:LoadAnimation(animation)
				track.Looped = true
				track:Play()
			end)
		end
	end
	player.CharacterAppearanceLoaded:Connect(function()
		if frame.Visible then
			buildCharacterView()
		end
	end)

	-- Top right: squad, player card, settings
	local squad = Theme.button({ Parent = frame, Text = "+  CREATE SQUAD", TextSize = 13, Position = UDim2.fromOffset(1236, 24), Size = UDim2.fromOffset(180, 36) }, "ghost")
	squad.Activated:Connect(function()
		ctx.toast("Squads are coming soon", "info")
	end)

	local playerCard = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(1430, 24), Size = UDim2.fromOffset(300, 48), BackgroundTransparency = 0.45 })
	Theme.label({ Parent = playerCard, Text = "1", FontFace = Theme.Font.Mono, TextSize = 14, TextColor3 = C.Accent, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(20, 40) })
	Theme.label({ Parent = playerCard, Text = player.DisplayName, FontFace = Theme.Font.Bold, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(38, 0), Size = UDim2.fromOffset(150, 40) })
	local moneyLabel = Theme.label({
		Parent = playerCard,
		FontFace = Theme.Font.Mono,
		TextSize = 13,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(150, 0),
		Size = UDim2.fromOffset(136, 40),
	})
	local _, setXp = Theme.bar(playerCard, UDim2.new(0, 0, 1, -3), UDim2.new(1, 0, 0, 3), C.Accent)
	setXp(0.35)

	local settingsButton = Theme.button({ Parent = frame, Text = "SETTINGS", TextSize = 13, Position = UDim2.fromOffset(1744, 24), Size = UDim2.fromOffset(116, 48) }, "glass")
	settingsButton.Activated:Connect(function()
		ctx.open("settings")
	end)

	-- Right: news + menu
	local news = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(1460, 590), Size = UDim2.fromOffset(400, 236) })
	Theme.header(news, UIConfig.NEWS.title, UDim2.fromOffset(20, 18))
	Theme.label({
		Parent = news,
		Text = UIConfig.NEWS.summary,
		TextSize = 14,
		TextColor3 = C.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.fromOffset(360, 110),
	})
	local readMore = Theme.button({ Parent = news, Text = "READ FULL ARTICLE", TextSize = 13, Position = UDim2.fromOffset(20, 180), Size = UDim2.fromOffset(360, 38) }, "glass")
	readMore.Activated:Connect(function()
		ctx.modal(UIConfig.NEWS.title, UIConfig.NEWS.body)
	end)

	local menuButtons = {
		{ text = "CHARACTER", callback = function()
			ctx.open("character")
		end },
		{ text = "VENDORS", callback = function()
			ctx.open("vendors")
		end },
		{ text = "CREDITS", callback = function()
			ctx.modal("CREDITS", UIConfig.CREDITS)
		end },
		{ text = "WIPE CHARACTER", style = "danger", callback = function()
			ctx.confirm("WIPE CHARACTER?", "Your inventory, money and progress reset to the starter kit. Settings are kept. This can't be undone.", "WIPE", function()
				ctx.wipe()
			end)
		end },
	}
	for i, info in menuButtons do
		local button = Theme.button({
			Parent = frame,
			Text = info.text,
			TextSize = 13,
			Position = UDim2.fromOffset(1460, 840 + (i - 1) * 44),
			Size = UDim2.fromOffset(400, 38),
		}, info.style or "glass")
		button.Activated:Connect(info.callback)
	end

	Theme.label({
		Parent = frame,
		Text = UIConfig.BUILD,
		FontFace = Theme.Font.Mono,
		TextSize = 11,
		TextColor3 = C.Faint,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(1460, 1030),
		Size = UDim2.fromOffset(400, 20),
	})

	function self.refresh(newState: any)
		state = newState
		moneyLabel.Text = if state then Theme.formatMoney(state.money) else ""
	end

	function self.show()
		frame.Visible = true
		buildCharacterView()
		self.refresh(state)
	end

	function self.hide()
		frame.Visible = false
	end

	return self
end

return LobbyScreen
