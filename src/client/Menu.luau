-- Menu controller: builds the menu ScreenGui, switches between screens,
-- blurs the world behind the glass panels, owns toasts / context menus /
-- dialogs, applies settings, and hands over from the title screen.
--
-- Flow: title screen -> LOBBY -> DEPLOY -> in game (TAB / I opens CHARACTER).

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared:WaitForChild("UIConfig"))

local CharacterScreen = require(script.Parent.CharacterScreen)
local Hud = require(script.Parent.Hud)
local LobbyScreen = require(script.Parent.LobbyScreen)
local Net = require(script.Parent.Net)
local SettingsScreen = require(script.Parent.SettingsScreen)
local Theme = require(script.Parent.Theme)
local VendorScreen = require(script.Parent.VendorScreen)

local C = Theme.Color
local NAV_SCREENS = { map = "MAP", character = "CHARACTER", vendors = "VENDORS", tasks = "TASKS" }
local NAV_NAMES = { "BACK", "MAP", "CHARACTER", "VENDORS", "TASKS" }

local Menu = {}

local function setCoreGui(coreType: Enum.CoreGuiType, enabled: boolean)
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(coreType, enabled)
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function setControlsEnabled(enabled: boolean)
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, controls = pcall(function(): any
			local playerScripts = player:WaitForChild("PlayerScripts", 10)
			local module = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
			return module and (require(module :: ModuleScript) :: any):GetControls()
		end)
		if ok and controls then
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

function Menu.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	------------------------------------------------------------------------------
	-- Root GUI
	------------------------------------------------------------------------------

	local screenGui = Theme.create("ScreenGui", {
		Parent = playerGui,
		Name = "Menu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local root = Theme.create("Frame", { Parent = screenGui, Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

	-- Darken the blurred world a touch, more at the edges
	local backdrop = Theme.create("Frame", {
		Parent = root,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})
	Theme.create("UIGradient", {
		Parent = backdrop,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.35, 0.55),
			NumberSequenceKeypoint.new(0.65, 0.55),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
	})

	-- Unlocks the mouse while a menu is open, even in first person
	Theme.create("TextButton", {
		Parent = root,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1, 1),
		Modal = true,
	})

	local canvas = Theme.create("Frame", {
		Parent = root,
		Name = "Canvas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Theme.REF_SIZE.X, Theme.REF_SIZE.Y),
	})
	local canvasScale = Theme.create("UIScale", { Parent = canvas })
	local uiScaleSetting = 1

	local function fit()
		local size = root.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			canvasScale.Scale = math.min(size.X / Theme.REF_SIZE.X, size.Y / Theme.REF_SIZE.Y) * uiScaleSetting
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local screensLayer = Theme.create("Frame", { Parent = canvas, Name = "Screens", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local navLayer = Theme.create("Frame", { Parent = canvas, Name = "Nav", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local overlay = Theme.create("Frame", { Parent = canvas, Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

	local blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "PlayerColorSettings"
	color.Parent = Lighting

	local music: Sound? = nil
	if UIConfig.MENU_MUSIC_ID ~= "" then
		music = Theme.create("Sound", { Parent = SoundService, SoundId = UIConfig.MENU_MUSIC_ID, Looped = true, Volume = 0.5 })
	end
	local clickSound: Sound? = nil
	if UIConfig.CLICK_SOUND_ID ~= "" then
		clickSound = Theme.create("Sound", { Parent = SoundService, SoundId = UIConfig.CLICK_SOUND_ID, Volume = 0.4 })
	end

	------------------------------------------------------------------------------
	-- Shared context for screens
	------------------------------------------------------------------------------

	local ctx: any = {}
	local settings: { [string]: any } = table.clone(SettingsScreen.DEFAULTS)
	local screens: { [string]: any } = {}
	local current: string? = nil
	local previous: string? = nil
	local isOpen = false
	local deployed = false
	local hud = Hud.new(playerGui)

	ctx.overlay = overlay

	function ctx.scale(): number
		return canvasScale.Scale
	end

	function ctx.inset(): Vector2
		local inset = GuiService:GetGuiInset()
		return inset
	end

	function ctx.toCanvas(point: Vector2): Vector2
		return (point - canvas.AbsolutePosition) / canvasScale.Scale
	end

	-- Toasts
	-- Toasts get their own layer so they also show while the menu is closed
	local toastGui = Theme.create("ScreenGui", {
		Parent = playerGui,
		Name = "Toasts",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
	})
	local toastFrame = Theme.glass({
		Parent = toastGui,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(460, 44),
		Visible = false,
	})
	local toastScale = Theme.create("UIScale", { Parent = toastFrame })
	canvasScale:GetPropertyChangedSignal("Scale"):Connect(function()
		toastScale.Scale = canvasScale.Scale
	end)
	local toastBar = Theme.create("Frame", { Parent = toastFrame, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) })
	local toastText = Theme.label({ Parent = toastFrame, TextSize = 15, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -30, 1, 0) })
	local toastToken = 0

	-- kind: "info" | "good" | "error"
	function ctx.toast(text: string, kind: string?)
		toastToken += 1
		local token = toastToken
		toastText.Text = text
		toastBar.BackgroundColor3 = if kind == "error" then C.Danger elseif kind == "good" then C.Good else C.Accent
		toastFrame.Visible = true
		task.delay(2.6, function()
			if token == toastToken then
				toastFrame.Visible = false
			end
		end)
	end

	-- Context menu: options = { { text, style?, callback } }
	function ctx.contextMenu(point: Vector2, options: { any })
		local blocker = Theme.create("TextButton", { Parent = overlay, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 70 })
		local height = #options * 34 + 8
		local menu = Theme.glass({
			Parent = blocker,
			BackgroundTransparency = 0.1,
			Position = UDim2.fromOffset(math.min(point.X, Theme.REF_SIZE.X - 230), math.min(point.Y, Theme.REF_SIZE.Y - height - 10)),
			Size = UDim2.fromOffset(220, height),
			ZIndex = 71,
		})
		blocker.Activated:Connect(function()
			blocker:Destroy()
		end)
		blocker.MouseButton2Click:Connect(function()
			blocker:Destroy()
		end)
		for i, option in options do
			local button = Theme.button({
				Parent = menu,
				Text = option.text,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if option.style == "danger" then C.Danger else C.Text,
				Position = UDim2.fromOffset(4, 4 + (i - 1) * 34),
				Size = UDim2.fromOffset(212, 32),
				ZIndex = 72,
			}, "ghost")
			Theme.create("UIPadding", { Parent = button, PaddingLeft = UDim.new(0, 12) })
			button.Activated:Connect(function()
				blocker:Destroy()
				option.callback()
			end)
		end
	end

	-- Dialog with a title, body and buttons = { { text, style?, callback? } }
	local function dialog(title: string, body: string, buttons: { any })
		local blocker = Theme.create("TextButton", {
			Parent = overlay,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 80,
		})
		local lines = #string.split(body, "\n")
		local height = math.clamp(150 + lines * 20 + math.floor(#body / 70) * 20, 220, 700)
		local box = Theme.glass({
			Parent = blocker,
			BackgroundTransparency = 0.08,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(620, height),
			ZIndex = 81,
		})
		Theme.label({ Parent = box, Text = title, FontFace = Theme.Font.Bold, TextSize = 24, Position = UDim2.fromOffset(32, 26), Size = UDim2.fromOffset(556, 30), ZIndex = 82 })
		Theme.label({
			Parent = box,
			Text = body,
			TextSize = 15,
			TextColor3 = C.Dim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(32, 70),
			Size = UDim2.new(1, -64, 1, -150),
			ZIndex = 82,
		})
		for i, info in buttons do
			local button = Theme.button({
				Parent = box,
				Text = info.text,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -32 - (#buttons - i) * 196, 1, -26),
				Size = UDim2.fromOffset(184, 42),
				ZIndex = 82,
			}, info.style or "glass")
			button.Activated:Connect(function()
				blocker:Destroy()
				if info.callback then
					info.callback()
				end
			end)
		end
	end

	function ctx.modal(title: string, body: string)
		dialog(title, body, { { text = "CLOSE", style = "glass" } })
	end

	function ctx.confirm(title: string, body: string, confirmText: string, callback: () -> ())
		dialog(title, body, {
			{ text = "CANCEL", style = "ghost" },
			{ text = confirmText, style = "danger", callback = callback },
		})
	end

	------------------------------------------------------------------------------
	-- Open / close
	------------------------------------------------------------------------------

	local function updateMusic()
		if not music then
			return
		end
		music.Volume = 0.5 * (settings.musicVolume / 100)
		local shouldPlay = isOpen and not deployed
		if shouldPlay and not music.IsPlaying then
			music:Play()
		elseif not shouldPlay and music.IsPlaying then
			music:Stop()
		end
	end

	local function setOpen(open: boolean)
		if open == isOpen then
			return
		end
		isOpen = open
		root.Visible = open
		Theme.tween(blur, 0.35, { Size = if open and settings.menuBlur then settings.blurStrength else 0 })
		setControlsEnabled(not open)
		hud.setMenuOpen(open)
		if open then
			UserInputService.MouseIconEnabled = true
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
		updateMusic()
	end

	local selectNav: (string) -> ()
	local suppressNav = false

	local function open(name: string)
		if not screens[name] then
			return
		end
		if name == "settings" and current ~= "settings" then
			previous = current
		end
		if current and current ~= name and screens[current] then
			screens[current].hide()
		end
		current = name
		setOpen(true)
		screens[name].show()

		local navName = NAV_SCREENS[name]
		navLayer.Visible = navName ~= nil
		if navName then
			suppressNav = true
			selectNav(navName)
			suppressNav = false
		end
	end

	local function close()
		if current and screens[current] then
			screens[current].hide()
		end
		current = nil
		setOpen(false)
	end

	local function back()
		if current == "settings" then
			if previous and previous ~= "settings" then
				open(previous)
			elseif deployed then
				close()
			else
				open("lobby")
			end
		elseif deployed then
			close()
		else
			open("lobby")
		end
	end

	ctx.open = open
	ctx.back = back

	function ctx.deploy()
		task.spawn(Net.Action, "deploy")
		deployed = true
		close()
		ctx.toast("Deployed. Press TAB for your inventory.", "info")
	end

	function ctx.wipe()
		local ok, message = Net.Action("wipe")
		ctx.toast(if ok then "Character wiped" else message or "Couldn't wipe", if ok then "good" else "error")
	end

	function ctx.applySettings(values: { [string]: any })
		settings = table.clone(values)
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = settings.fov
		end
		color.Brightness = settings.brightness / 100
		color.Contrast = settings.contrast / 100
		color.Saturation = settings.saturation / 100
		uiScaleSetting = settings.uiScale / 100
		fit()
		hud.setEnabled(settings.showHotbar)
		if isOpen then
			Theme.tween(blur, 0.2, { Size = if settings.menuBlur then settings.blurStrength else 0 })
		end
		updateMusic()
	end

	------------------------------------------------------------------------------
	-- Top navigation (in-game screens)
	------------------------------------------------------------------------------

	local _, navSelect = Theme.tabs(navLayer, NAV_NAMES, UDim2.fromOffset(60, 18), 150, 38, function(name)
		if suppressNav then
			return
		end
		if name == "BACK" then
			back()
		else
			open(string.lower(name))
		end
	end, 15)
	selectNav = navSelect

	local navMoney = Theme.label({
		Parent = navLayer,
		FontFace = Theme.Font.Mono,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(1300, 18),
		Size = UDim2.fromOffset(200, 38),
	})
	Theme.label({
		Parent = navLayer,
		Text = player.DisplayName,
		FontFace = Theme.Font.Bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(1510, 18),
		Size = UDim2.fromOffset(200, 38),
	})
	local navSettings = Theme.button({ Parent = navLayer, Text = "SETTINGS", TextSize = 13, Position = UDim2.fromOffset(1744, 18), Size = UDim2.fromOffset(116, 38) }, "glass")
	navSettings.Activated:Connect(function()
		open("settings")
	end)
	Theme.create("Frame", {
		Parent = navLayer,
		BackgroundColor3 = C.Stroke,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(60, 58),
		Size = UDim2.fromOffset(1800, 1),
	})

	------------------------------------------------------------------------------
	-- Map
	------------------------------------------------------------------------------

	local mapScreen = {}
	do
		local frame = Theme.create("Frame", { Parent = screensLayer, Name = "Map", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
		local panel = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(1800, 930), ClipsDescendants = true })
		if UIConfig.MAP_IMAGE ~= "" then
			Theme.create("ImageLabel", { Parent = panel, BackgroundTransparency = 1, Image = UIConfig.MAP_IMAGE, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1) })
		else
			local grid = Theme.create("Frame", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
			Theme.create("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(100, 100), CellPadding = UDim2.new() })
			for _ = 1, 18 * 10 do
				local cell = Theme.create("Frame", { Parent = grid, BackgroundTransparency = 1 })
				Theme.stroke(cell, 0.94)
			end
			Theme.label({ Parent = panel, Text = "NO MAP DATA", FontFace = Theme.Font.Bold, TextSize = 28, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.5, -30), Size = UDim2.new(1, 0, 0, 34) })
			Theme.label({ Parent = panel, Text = "Set MAP_IMAGE in UIConfig to show your map here.", TextSize = 14, TextColor3 = C.Faint, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.5, 8), Size = UDim2.new(1, 0, 0, 20) })
		end
		local position = Theme.label({ Parent = panel, FontFace = Theme.Font.Mono, TextSize = 13, TextColor3 = C.Dim, Position = UDim2.new(0, 24, 1, -40), Size = UDim2.fromOffset(500, 20) })
		RunService.Heartbeat:Connect(function()
			if frame.Visible then
				local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					local p = rootPart.Position
					position.Text = string.format("POS  X %d   Z %d   ALT %d", p.X, p.Z, p.Y)
				end
			end
		end)
		mapScreen.frame = frame
		function mapScreen.show()
			frame.Visible = true
		end
		function mapScreen.hide()
			frame.Visible = false
		end
		function mapScreen.refresh() end
	end

	------------------------------------------------------------------------------
	-- Screens
	------------------------------------------------------------------------------

	screens.lobby = LobbyScreen.new(ctx, screensLayer)
	screens.character = CharacterScreen.new(ctx, screensLayer)
	screens.vendors = VendorScreen.new(ctx, screensLayer)
	screens.tasks = VendorScreen.newTaskBoard(ctx, screensLayer)
	screens.map = mapScreen
	screens.settings = SettingsScreen.new(ctx, screensLayer)

	-- Interface click sounds
	if clickSound then
		local function hook(inst: Instance)
			if inst:IsA("GuiButton") then
				inst.Activated:Connect(function()
					if settings.uiSounds then
						clickSound:Play()
					end
				end)
			end
		end
		for _, d in screenGui:GetDescendants() do
			hook(d)
		end
		screenGui.DescendantAdded:Connect(hook)
	end

	local settingsLoaded = false
	Net.Changed:Connect(function(state)
		if not settingsLoaded and state then
			settingsLoaded = true
			ctx.applySettings(screens.settings.load(state.settings))
		end
		navMoney.Text = Theme.formatMoney(state.money)
		for _, screen in screens do
			screen.refresh(state)
		end
		hud.refresh(state)
	end)
	Net.Start()
	fit()

	------------------------------------------------------------------------------
	-- Keys
	------------------------------------------------------------------------------

	UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		if key ~= Enum.KeyCode.Tab and key ~= Enum.KeyCode.I then
			return
		end
		if processed and key ~= Enum.KeyCode.Tab then
			return
		end
		if UserInputService:GetFocusedTextBox() or not deployed then
			return
		end
		if isOpen and current ~= "settings" then
			close()
		elseif not isOpen then
			open("character")
		end
	end)

	------------------------------------------------------------------------------
	-- Hand-over from the title screen
	------------------------------------------------------------------------------

	local function titleActive(): boolean
		return playerGui:FindFirstChild("TitleScreen") ~= nil or playerGui:FindFirstChild("LoadingScreen") ~= nil
	end

	if not player:GetAttribute("TitleScreenDone") and titleActive() then
		player:GetAttributeChangedSignal("TitleScreenDone"):Wait()
	end
	-- The menu sits under the fading title screen, so open it right away
	open("lobby")

	-- The title screen restores controls when it finishes; take them back.
	task.spawn(function()
		while titleActive() do
			playerGui.ChildRemoved:Wait()
		end
		setCoreGui(Enum.CoreGuiType.Backpack, false)
		setCoreGui(Enum.CoreGuiType.Health, false)
		if isOpen then
			setControlsEnabled(false)
		end
	end)
end

return Menu
