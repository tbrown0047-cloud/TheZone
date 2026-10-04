-- SETTINGS: GAME / GRAPHICS / CONTROLS tabs with arrow selectors and
-- sliders, a description footer, RESET TO DEFAULT and APPLY. Values are
-- applied locally through ctx.applySettings and saved on the server.

local UserInputService = game:GetService("UserInputService")

local Net = require(script.Parent.Net)
local Theme = require(script.Parent.Theme)

local C = Theme.Color

local SettingsScreen = {}

SettingsScreen.DEFAULTS = {
	fov = 70,
	showHotbar = true,
	musicVolume = 50,
	uiSounds = true,
	menuBlur = true,
	blurStrength = 14,
	uiScale = 100,
	saturation = 0,
	contrast = 0,
	brightness = 0,
}

type Row = {
	kind: string, -- "section" | "slider" | "toggle" | "info"
	key: string?,
	label: string,
	min: number?,
	max: number?,
	suffix: string?,
	value: string?,
	desc: string?,
}

local PAGES: { [string]: { Row } } = {
	GAME = {
		{ kind = "section", label = "GAMEPLAY" },
		{ kind = "slider", key = "fov", label = "Field of View", min = 60, max = 100, desc = "Camera field of view outside of aiming." },
		{ kind = "toggle", key = "showHotbar", label = "Show HUD", desc = "Show the in-game HUD: compass, radar, squad, kill feed, ammo and the 1 / 2 / 3 weapon slots." },
		{ kind = "section", label = "AUDIO" },
		{ kind = "slider", key = "musicVolume", label = "Menu Music", min = 0, max = 100, suffix = "%", desc = "Volume of the menu music." },
		{ kind = "toggle", key = "uiSounds", label = "Interface Sounds", desc = "Click sounds on menu buttons." },
	},
	GRAPHICS = {
		{ kind = "section", label = "DISPLAY" },
		{ kind = "toggle", key = "menuBlur", label = "Menu Background Blur", desc = "Blur the world behind menus for the frosted glass look." },
		{ kind = "slider", key = "blurStrength", label = "Blur Strength", min = 4, max = 24, desc = "How strongly the world is blurred behind menus." },
		{ kind = "slider", key = "uiScale", label = "Menu Scale", min = 80, max = 120, suffix = "%", desc = "Size of the menus relative to your screen." },
		{ kind = "section", label = "COLOR" },
		{ kind = "slider", key = "brightness", label = "Brightness", min = -30, max = 30, desc = "Adjusts overall brightness." },
		{ kind = "slider", key = "contrast", label = "Contrast", min = -50, max = 50, desc = "Adjusts the difference between light and dark." },
		{ kind = "slider", key = "saturation", label = "Saturation", min = -50, max = 50, desc = "Adjusts the intensity of colors, making them more vibrant or muted." },
	},
	CONTROLS = {
		{ kind = "section", label = "MENUS" },
		{ kind = "info", label = "Open Character / Inventory", value = "TAB  ·  I" },
		{ kind = "info", label = "Rotate Dragged Item", value = "R" },
		{ kind = "info", label = "Quick Move / Equip", value = "DOUBLE-CLICK" },
		{ kind = "info", label = "Item Menu", value = "RIGHT-CLICK" },
		{ kind = "section", label = "WEAPONS" },
		{ kind = "info", label = "Primary", value = "1" },
		{ kind = "info", label = "Secondary", value = "2" },
		{ kind = "info", label = "Sidearm", value = "3" },
		{ kind = "info", label = "Fire, reload, aim and attachments", value = "SET BY ACS" },
	},
}

function SettingsScreen.new(ctx: any, parent: Instance)
	local self = {}
	local values: { [string]: any } = table.clone(SettingsScreen.DEFAULTS)
	local currentPage = "GAME"

	local frame = Theme.create("Frame", { Parent = parent, Name = "Settings", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	self.frame = frame

	local closeButton = Theme.button({ Parent = frame, Text = "✕", TextSize = 20, Position = UDim2.fromOffset(60, 22), Size = UDim2.fromOffset(40, 40) }, "ghost")
	closeButton.Activated:Connect(function()
		ctx.back()
	end)

	local panel = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(60, 90), Size = UDim2.fromOffset(820, 900) })
	local rowsFrame = Theme.create("ScrollingFrame", {
		Parent = panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(24, 20),
		Size = UDim2.fromOffset(780, 700),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Dim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})

	local footerTitle = Theme.label({ Parent = panel, FontFace = Theme.Font.Bold, TextSize = 14, Position = UDim2.fromOffset(24, 742), Size = UDim2.fromOffset(770, 20) })
	local footerText = Theme.label({
		Parent = panel,
		TextSize = 13,
		TextColor3 = C.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(24, 766),
		Size = UDim2.fromOffset(770, 50),
	})
	Theme.create("Frame", { Parent = panel, BackgroundColor3 = C.Stroke, BackgroundTransparency = 0.88, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 730), Size = UDim2.fromOffset(772, 1) })

	local resetButton = Theme.button({ Parent = frame, Text = "RESET TO DEFAULT", Position = UDim2.fromOffset(1420, 1004), Size = UDim2.fromOffset(200, 44) }, "ghost")
	local applyButton = Theme.button({ Parent = frame, Text = "APPLY", Position = UDim2.fromOffset(1640, 1004), Size = UDim2.fromOffset(220, 44) }, "primary")

	local activeSlider: any = nil
	local renderPage: () -> ()

	local function makeSlider(rowFrame: Frame, row: Row)
		local key = row.key :: string
		local min, max = row.min :: number, row.max :: number
		local track = Theme.create("TextButton", {
			Parent = rowFrame,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(440, 21),
			Size = UDim2.fromOffset(240, 2),
		})
		local fill = Theme.create("Frame", { Parent = track, BackgroundColor3 = C.Text, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })
		local knob = Theme.create("Frame", {
			Parent = track,
			BackgroundColor3 = C.Accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(4, 16),
		})
		local valueLabel = Theme.label({
			Parent = rowFrame,
			FontFace = Theme.Font.Mono,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(690, 12),
			Size = UDim2.fromOffset(70, 20),
		})

		local function show()
			local alpha = (values[key] - min) / (max - min)
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
			valueLabel.Text = tostring(values[key]) .. (row.suffix or "")
		end

		local function setFromPointer(x: number)
			local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			values[key] = math.floor(min + (max - min) * alpha + 0.5)
			show()
		end

		track.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				activeSlider = setFromPointer
				setFromPointer(UserInputService:GetMouseLocation().X)
			end
		end)
		show()
	end

	local function makeToggle(rowFrame: Frame, row: Row)
		local key = row.key :: string
		local valueLabel = Theme.label({
			Parent = rowFrame,
			FontFace = Theme.Font.Bold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(480, 12),
			Size = UDim2.fromOffset(240, 20),
		})
		local function show()
			valueLabel.Text = if values[key] then "ON" else "OFF"
		end
		for i, arrow in { "◂", "▸" } do
			local button = Theme.button({
				Parent = rowFrame,
				Text = arrow,
				TextSize = 16,
				Position = UDim2.fromOffset(if i == 1 then 440 else 724, 6),
				Size = UDim2.fromOffset(32, 32),
			}, "ghost")
			button.Activated:Connect(function()
				values[key] = not values[key]
				show()
			end)
		end
		show()
	end

	renderPage = function()
		rowsFrame:ClearAllChildren()
		Theme.create("UIListLayout", { Parent = rowsFrame, SortOrder = Enum.SortOrder.LayoutOrder })
		for i, row in PAGES[currentPage] do
			if row.kind == "section" then
				local holder = Theme.create("Frame", { Parent = rowsFrame, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = i })
				Theme.header(holder, row.label, UDim2.fromOffset(0, 20))
			else
				local rowFrame = Theme.create("Frame", {
					Parent = rowsFrame,
					BackgroundColor3 = C.GlassHi,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -8, 0, 44),
					LayoutOrder = i,
				})
				Theme.label({ Parent = rowFrame, Text = row.label, TextSize = 15, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(400, 44) })
				rowFrame.MouseEnter:Connect(function()
					rowFrame.BackgroundTransparency = 0.7
					footerTitle.Text = string.upper(row.label)
					footerText.Text = row.desc or ""
				end)
				rowFrame.MouseLeave:Connect(function()
					rowFrame.BackgroundTransparency = 1
				end)
				if row.kind == "slider" then
					makeSlider(rowFrame, row)
				elseif row.kind == "toggle" then
					makeToggle(rowFrame, row)
				elseif row.kind == "info" then
					Theme.label({
						Parent = rowFrame,
						Text = row.value or "",
						FontFace = Theme.Font.Mono,
						TextSize = 14,
						TextColor3 = C.Dim,
						TextXAlignment = Enum.TextXAlignment.Right,
						Position = UDim2.fromOffset(440, 0),
						Size = UDim2.fromOffset(320, 44),
					})
				end
			end
		end
	end

	local _, selectTab = Theme.tabs(frame, { "GAME", "GRAPHICS", "CONTROLS" }, UDim2.fromOffset(120, 26), 150, 32, function(name)
		currentPage = name
		footerTitle.Text = ""
		footerText.Text = ""
		renderPage()
	end, 14)

	UserInputService.InputChanged:Connect(function(input)
		if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			activeSlider(UserInputService:GetMouseLocation().X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeSlider = nil
		end
	end)

	resetButton.Activated:Connect(function()
		values = table.clone(SettingsScreen.DEFAULTS)
		renderPage()
	end)

	applyButton.Activated:Connect(function()
		ctx.applySettings(values)
		task.spawn(function()
			local ok = Net.Action("saveSettings", values)
			ctx.toast(if ok then "Settings saved" else "Applied, but couldn't save", if ok then "good" else "error")
		end)
	end)

	-- Called with the saved settings from the server
	function self.load(saved: { [string]: any }?)
		values = table.clone(SettingsScreen.DEFAULTS)
		for key, value in saved or {} do
			if values[key] ~= nil and type(values[key]) == type(value) then
				values[key] = value
			end
		end
		return values
	end

	function self.show()
		frame.Visible = true
		selectTab(currentPage)
	end

	function self.hide()
		frame.Visible = false
	end

	function self.refresh() end

	return self
end

return SettingsScreen
