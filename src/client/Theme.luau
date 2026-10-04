-- Visual language for the menus: dark frosted-glass panels (the 3D world is
-- blurred behind them), hairline strokes, uppercase labels and a single warm
-- accent for primary actions and selection.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.REF_SIZE = Vector2.new(1920, 1080)
Theme.CELL = 46

Theme.Color = {
	Glass = Color3.fromRGB(14, 17, 21),
	GlassHi = Color3.fromRGB(38, 43, 51),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 242, 245),
	Dim = Color3.fromRGB(150, 157, 166),
	Faint = Color3.fromRGB(95, 101, 110),
	Accent = Color3.fromRGB(245, 166, 35),
	AccentText = Color3.fromRGB(22, 17, 10),
	Danger = Color3.fromRGB(226, 84, 72),
	Good = Color3.fromRGB(110, 205, 125),
	Water = Color3.fromRGB(90, 170, 230),
}

Theme.Category = {
	Weapon = Color3.fromRGB(245, 166, 35),
	Ammo = Color3.fromRGB(220, 200, 90),
	Medical = Color3.fromRGB(226, 84, 72),
	Food = Color3.fromRGB(110, 205, 125),
	Gear = Color3.fromRGB(90, 170, 230),
	Misc = Color3.fromRGB(170, 170, 180),
}

Theme.Alpha = {
	Panel = 0.3,
	Raised = 0.45,
	Cell = 0.93,
	Stroke = 0.87,
	StrokeHi = 0.55,
}

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
Theme.Font = {
	Regular = Font.new(BUILDER, Enum.FontWeight.Regular),
	Medium = Font.new(BUILDER, Enum.FontWeight.Medium),
	Bold = Font.new(BUILDER, Enum.FontWeight.Bold),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json"),
}

function Theme.create(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Theme.tween(inst: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

function Theme.stroke(parent: Instance, transparency: number?, color: Color3?): UIStroke
	return Theme.create("UIStroke", {
		Parent = parent,
		Color = color or Theme.Color.Stroke,
		Transparency = transparency or Theme.Alpha.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function withDefaults(props: { [string]: any }, defaults: { [string]: any }): { [string]: any }
	for key, value in defaults do
		if props[key] == nil then
			props[key] = value
		end
	end
	return props
end

-- Frosted panel: translucent, lit slightly from the top, hairline border.
function Theme.glass(props: { [string]: any }): Frame
	local frame = Theme.create(
		"Frame",
		withDefaults(props, {
			BackgroundColor3 = Theme.Color.Glass,
			BackgroundTransparency = Theme.Alpha.Panel,
			BorderSizePixel = 0,
		})
	)
	Theme.stroke(frame)
	Theme.create("UIGradient", {
		Parent = frame,
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 180, 190)),
	})
	return frame
end

function Theme.label(props: { [string]: any }): TextLabel
	return Theme.create(
		"TextLabel",
		withDefaults(props, {
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Medium,
			TextColor3 = Theme.Color.Text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromOffset(200, 20),
		})
	)
end

-- Small uppercase section label with an accent tick, e.g. "EQUIPMENT".
function Theme.header(parent: Instance, text: string, position: UDim2): Frame
	local holder = Theme.create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.fromOffset(300, 16),
	})
	Theme.create("Frame", {
		Parent = holder,
		BackgroundColor3 = Theme.Color.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(2, 10),
	})
	Theme.label({
		Parent = holder,
		Text = string.upper(text),
		FontFace = Theme.Font.Bold,
		TextSize = 12,
		TextColor3 = Theme.Color.Dim,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -10, 1, 0),
	})
	return holder
end

-- style: "primary" | "glass" | "ghost" | "danger"
function Theme.button(props: { [string]: any }, style: string?): TextButton
	local kind = style or "glass"
	local bg, bgAlpha, textColor = Theme.Color.GlassHi, Theme.Alpha.Raised, Theme.Color.Text
	if kind == "primary" then
		bg, bgAlpha, textColor = Theme.Color.Accent, 0, Theme.Color.AccentText
	elseif kind == "ghost" then
		bg, bgAlpha, textColor = Theme.Color.GlassHi, 1, Theme.Color.Dim
	elseif kind == "danger" then
		bg, bgAlpha, textColor = Theme.Color.Danger, 0.75, Theme.Color.Text
	end
	if props.BackgroundTransparency ~= nil then
		bgAlpha = props.BackgroundTransparency
	end

	local button = Theme.create(
		"TextButton",
		withDefaults(props, {
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = bg,
			BackgroundTransparency = bgAlpha,
			FontFace = Theme.Font.Bold,
			TextSize = 14,
			TextColor3 = textColor,
			Size = UDim2.fromOffset(160, 36),
		})
	)
	local stroke = if kind ~= "primary" then Theme.stroke(button, if kind == "ghost" then 1 else Theme.Alpha.Stroke) else nil

	-- Set a "BaseAlpha" attribute to change the resting transparency later
	-- (e.g. for a selected card) without hover resetting it.
	local function restingAlpha(): number
		local attr = button:GetAttribute("BaseAlpha")
		return if type(attr) == "number" then attr else bgAlpha
	end

	local hoverBg = if kind == "primary" then bg:Lerp(Color3.new(1, 1, 1), 0.2) else bg
	button.MouseEnter:Connect(function()
		local hoverAlpha = if kind == "primary" then 0 elseif kind == "ghost" then 0.8 else math.max(0, restingAlpha() - 0.2)
		Theme.tween(button, 0.12, { BackgroundColor3 = hoverBg, BackgroundTransparency = hoverAlpha })
		if kind == "ghost" then
			Theme.tween(button, 0.12, { TextColor3 = Theme.Color.Text })
		end
		if stroke then
			Theme.tween(stroke, 0.12, { Transparency = Theme.Alpha.StrokeHi })
		end
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(button, 0.15, { BackgroundColor3 = bg, BackgroundTransparency = restingAlpha() })
		if kind == "ghost" then
			Theme.tween(button, 0.15, { TextColor3 = textColor })
		end
		if stroke then
			Theme.tween(stroke, 0.15, { Transparency = if kind == "ghost" then 1 else Theme.Alpha.Stroke })
		end
	end)
	return button
end

-- Row of text tabs with an accent underline on the active one.
-- Returns the holder and a select(name) function.
function Theme.tabs(
	parent: Instance,
	names: { string },
	position: UDim2,
	tabWidth: number,
	height: number,
	onSelect: (string) -> (),
	textSize: number?
): (Frame, (string) -> ())
	local holder = Theme.create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.fromOffset(#names * tabWidth, height),
	})
	local buttons: { [string]: TextButton } = {}
	local underlines: { [string]: Frame } = {}
	local current: string? = nil

	local function render()
		for name, button in buttons do
			local active = name == current
			button.TextColor3 = if active then Theme.Color.Text else Theme.Color.Dim
			button.BackgroundTransparency = if active then 0.6 else 1
			underlines[name].Visible = active
		end
	end

	local function select(name: string)
		current = name
		render()
		onSelect(name)
	end

	for i, name in names do
		local button = Theme.create("TextButton", {
			Parent = holder,
			Name = name,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Color.GlassHi,
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Bold,
			TextSize = textSize or 14,
			TextColor3 = Theme.Color.Dim,
			Text = name,
			Position = UDim2.fromOffset((i - 1) * tabWidth, 0),
			Size = UDim2.fromOffset(tabWidth - 4, height),
		})
		underlines[name] = Theme.create("Frame", {
			Parent = button,
			BackgroundColor3 = Theme.Color.Accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			Visible = false,
		})
		button.MouseEnter:Connect(function()
			if current ~= name then
				button.TextColor3 = Theme.Color.Text
			end
		end)
		button.MouseLeave:Connect(function()
			if current ~= name then
				button.TextColor3 = Theme.Color.Dim
			end
		end)
		button.Activated:Connect(function()
			select(name)
		end)
		buttons[name] = button
	end

	return holder, select
end

-- Thin progress bar. Returns the track and a setter taking 0..1.
function Theme.bar(parent: Instance, position: UDim2, size: UDim2, color: Color3): (Frame, (number) -> ())
	local track = Theme.create("Frame", {
		Parent = parent,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
	})
	local fill = Theme.create("Frame", {
		Parent = track,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})
	return track, function(alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
end

function Theme.formatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return "$ " .. formatted
end

return Theme
