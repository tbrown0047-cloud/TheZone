-- VENDORS screen (vendor list, TRADE grid, per-vendor TASKS) and the TASKS
-- screen, which shows every vendor's tasks on one board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))
local VendorDefs = require(Shared:WaitForChild("VendorDefs"))

local ItemIcon = require(script.Parent.ItemIcon)
local Net = require(script.Parent.Net)
local Theme = require(script.Parent.Theme)

local C = Theme.Color

local VendorScreen = {}

-- Task list on the left, details on the right. getEntries returns
-- { { task = Task, vendor = Vendor } }. Returns a refresh(state) function.
local function buildTaskBoard(ctx: any, parent: Instance, position: UDim2, size: Vector2, getEntries: () -> { any })
	local holder = Theme.create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
	})
	local list = Theme.create("ScrollingFrame", {
		Parent = holder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(360, size.Y),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Dim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	Theme.create("UIListLayout", { Parent = list, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	local detail = Theme.glass({
		Parent = holder,
		BackgroundTransparency = 0.45,
		Position = UDim2.fromOffset(380, 0),
		Size = UDim2.fromOffset(size.X - 380, size.Y),
	})

	local state: any = nil
	local selectedId: string? = nil

	local function renderDetail()
		for _, child in detail:GetChildren() do
			if not child:IsA("UIStroke") and not child:IsA("UIGradient") then
				child:Destroy()
			end
		end
		local entry
		for _, e in getEntries() do
			if e.task.id == selectedId then
				entry = e
			end
		end
		if not entry then
			Theme.label({ Parent = detail, Text = "Select a task", TextColor3 = C.Dim, TextSize = 15, Position = UDim2.fromOffset(28, 24), Size = UDim2.fromOffset(400, 24) })
			return
		end

		local task_ = entry.task
		local active = state and state.tasks and state.tasks[task_.id] == "ACTIVE"
		local width = size.X - 380 - 56

		Theme.label({ Parent = detail, Text = entry.vendor.name, FontFace = Theme.Font.Bold, TextSize = 12, TextColor3 = C.Accent, Position = UDim2.fromOffset(28, 24), Size = UDim2.fromOffset(width, 16) })
		Theme.label({ Parent = detail, Text = task_.title, FontFace = Theme.Font.Bold, TextSize = 30, Position = UDim2.fromOffset(28, 42), Size = UDim2.fromOffset(width, 38) })
		local chip = Theme.label({
			Parent = detail,
			Text = if active then "ACTIVE" else "AVAILABLE",
			FontFace = Theme.Font.Bold,
			TextSize = 11,
			TextColor3 = if active then C.AccentText else C.Text,
			BackgroundColor3 = if active then C.Accent else C.GlassHi,
			BackgroundTransparency = if active then 0 else 0.4,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(28, 86),
			Size = UDim2.fromOffset(90, 20),
		})
		Theme.stroke(chip, 0.8)

		Theme.label({
			Parent = detail,
			Text = task_.text,
			TextSize = 15,
			TextColor3 = C.Dim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(28, 124),
			Size = UDim2.fromOffset(width, 120),
		})

		Theme.header(detail, "Objectives", UDim2.fromOffset(28, 262))
		local y = 290
		for _, objective in task_.objectives do
			local box = Theme.create("Frame", {
				Parent = detail,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(28, y + 3),
				Size = UDim2.fromOffset(12, 12),
			})
			Theme.stroke(box, 0.5)
			Theme.label({ Parent = detail, Text = objective, TextSize = 14, TextWrapped = true, Position = UDim2.fromOffset(50, y), Size = UDim2.fromOffset(width - 30, 18) })
			y += 30
		end

		Theme.header(detail, "Rewards", UDim2.fromOffset(28, y + 14))
		Theme.label({ Parent = detail, Text = task_.reward, FontFace = Theme.Font.Mono, TextSize = 14, Position = UDim2.fromOffset(28, y + 40), Size = UDim2.fromOffset(width, 20) })

		local button = Theme.button({
			Parent = detail,
			Text = if active then "ABANDON TASK" else "ACCEPT TASK",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -28, 1, -24),
			Size = UDim2.fromOffset(220, 44),
		}, if active then "glass" else "primary")
		button.Activated:Connect(function()
			local ok, message = Net.Action("acceptTask", task_.id)
			if not ok then
				ctx.toast(message or "Couldn't update task", "error")
			end
		end)
	end

	local function renderList()
		list:ClearAllChildren()
		Theme.create("UIListLayout", { Parent = list, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		for i, entry in getEntries() do
			local task_ = entry.task
			local active = state and state.tasks and state.tasks[task_.id] == "ACTIVE"
			local selected = task_.id == selectedId
			local card = Theme.button({
				Parent = list,
				Text = "",
				LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 64),
				BackgroundTransparency = if selected then 0.25 else 0.55,
			}, "glass")
			Theme.create("Frame", {
				Parent = card,
				BackgroundColor3 = C.Accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 2, 1, 0),
				Visible = selected,
			})
			Theme.label({ Parent = card, Text = task_.title, FontFace = Theme.Font.Bold, TextSize = 15, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -24, 0, 20) })
			Theme.label({
				Parent = card,
				Text = entry.vendor.name .. "  ·  " .. (if active then "ACTIVE" else "AVAILABLE"),
				TextSize = 12,
				TextColor3 = if active then C.Accent else C.Dim,
				Position = UDim2.fromOffset(16, 34),
				Size = UDim2.new(1, -24, 0, 16),
			})
			card.Activated:Connect(function()
				selectedId = task_.id
				renderList()
				renderDetail()
			end)
		end
	end

	return function(newState: any)
		state = newState
		local entries = getEntries()
		if not selectedId and entries[1] then
			selectedId = entries[1].task.id
		end
		renderList()
		renderDetail()
	end
end

function VendorScreen.new(ctx: any, parent: Instance)
	local self = {}
	local state: any = nil
	local vendor = VendorDefs[1]

	local frame = Theme.create("Frame", { Parent = parent, Name = "Vendors", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	self.frame = frame

	-- Vendor list
	local listPanel = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(320, 930) })
	Theme.header(listPanel, "Vendors", UDim2.fromOffset(20, 16))
	local vendorCards: { [string]: TextButton } = {}

	-- Main panel
	local main = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(400, 110), Size = UDim2.fromOffset(1460, 930) })
	local nameLabel = Theme.label({ Parent = main, FontFace = Theme.Font.Bold, TextSize = 44, Position = UDim2.fromOffset(32, 22), Size = UDim2.fromOffset(900, 50) })
	local roleLabel = Theme.label({ Parent = main, FontFace = Theme.Font.Bold, TextSize = 13, TextColor3 = C.Accent, Position = UDim2.fromOffset(34, 74), Size = UDim2.fromOffset(600, 18) })
	local descLabel = Theme.label({
		Parent = main,
		TextSize = 14,
		TextColor3 = C.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(34, 100),
		Size = UDim2.fromOffset(820, 44),
	})
	local moneyLabel = Theme.label({
		Parent = main,
		FontFace = Theme.Font.Mono,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -332, 0, 28),
		Size = UDim2.fromOffset(300, 28),
	})

	local tradePage = Theme.create("ScrollingFrame", {
		Parent = main,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(32, 210),
		Size = UDim2.fromOffset(1400, 700),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Dim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	local tasksPage = Theme.create("Frame", { Parent = main, BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 210), Size = UDim2.fromOffset(1400, 700), Visible = false })

	local refreshTasks = buildTaskBoard(ctx, tasksPage, UDim2.new(), Vector2.new(1400, 700), function()
		local entries = {}
		for _, t in vendor.tasks do
			table.insert(entries, { task = t, vendor = vendor })
		end
		return entries
	end)

	local _, selectTab = Theme.tabs(main, { "TRADE", "TASKS" }, UDim2.fromOffset(32, 160), 130, 32, function(name)
		tradePage.Visible = name == "TRADE"
		tasksPage.Visible = name == "TASKS"
	end, 13)
	selectTab("TRADE")

	local function renderTrade()
		tradePage:ClearAllChildren()
		Theme.create("UIGridLayout", {
			Parent = tradePage,
			CellSize = UDim2.fromOffset(214, 250),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		for i, entry in vendor.stock do
			local def = ItemDefs[entry.item]
			if def then
				local card = Theme.glass({ Parent = tradePage, BackgroundTransparency = 0.5, LayoutOrder = i })
				local art = Theme.create("Frame", {
					Parent = card,
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.65,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(10, 10),
					Size = UDim2.fromOffset(194, 110),
				})
				if not ItemIcon.render(art, def, 194 / 110, false) then
					Theme.label({ Parent = art, Text = def.short, FontFace = Theme.Font.Bold, TextSize = 22, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
				end
				Theme.create("Frame", {
					Parent = art,
					BackgroundColor3 = Theme.Category[def.category] or C.Dim,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 2),
				})
				local title = def.name .. (if entry.count and entry.count > 1 then "  x" .. entry.count else "")
				Theme.label({ Parent = card, Text = title, FontFace = Theme.Font.Bold, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(12, 128), Size = UDim2.fromOffset(190, 20) })
				Theme.label({ Parent = card, Text = string.upper(def.category) .. "  ·  " .. def.w .. "x" .. def.h, TextSize = 12, TextColor3 = C.Dim, Position = UDim2.fromOffset(12, 150), Size = UDim2.fromOffset(190, 16) })
				local affordable = state and state.money >= entry.price
				Theme.label({
					Parent = card,
					Text = Theme.formatMoney(entry.price),
					FontFace = Theme.Font.Mono,
					TextSize = 16,
					TextColor3 = if affordable then C.Text else C.Danger,
					Position = UDim2.fromOffset(12, 176),
					Size = UDim2.fromOffset(190, 20),
				})
				local buy = Theme.button({ Parent = card, Text = "BUY", Position = UDim2.fromOffset(10, 204), Size = UDim2.fromOffset(194, 34) }, if affordable then "primary" else "glass")
				buy.Activated:Connect(function()
					local ok, message = Net.Action("buy", vendor.id, entry.item)
					if ok then
						ctx.toast(def.name .. " sent to your locker", "good")
					else
						ctx.toast(message or "Couldn't buy that", "error")
					end
				end)
			end
		end
	end

	local function renderHeader()
		nameLabel.Text = vendor.name
		roleLabel.Text = vendor.role
		descLabel.Text = vendor.description
		moneyLabel.Text = if state then Theme.formatMoney(state.money) else ""
		for id, card in vendorCards do
			local selected = id == vendor.id
			card:SetAttribute("BaseAlpha", if selected then 0.25 else 0.55)
			card.BackgroundTransparency = if selected then 0.25 else 0.55
			local marker = card:FindFirstChild("Marker") :: Frame
			marker.Visible = selected
		end
	end

	local function selectVendor(v: any)
		vendor = v
		renderHeader()
		renderTrade()
		refreshTasks(state)
	end

	for i, v in VendorDefs do
		local card = Theme.button({
			Parent = listPanel,
			Text = "",
			Position = UDim2.fromOffset(20, 46 + (i - 1) * 92),
			Size = UDim2.fromOffset(280, 82),
		}, "glass")
		Theme.create("Frame", { Parent = card, Name = "Marker", BackgroundColor3 = C.Accent, BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, 0), Visible = false })
		Theme.label({ Parent = card, Text = v.name, FontFace = Theme.Font.Bold, TextSize = 20, Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(250, 26) })
		Theme.label({ Parent = card, Text = v.role, TextSize = 12, TextColor3 = C.Dim, Position = UDim2.fromOffset(18, 44), Size = UDim2.fromOffset(250, 16) })
		card.Activated:Connect(function()
			selectVendor(v)
		end)
		vendorCards[v.id] = card
	end

	function self.refresh(newState: any)
		state = newState
		if frame.Visible then
			renderHeader()
			renderTrade()
			refreshTasks(state)
		end
	end

	function self.show()
		frame.Visible = true
		selectVendor(vendor)
	end

	function self.hide()
		frame.Visible = false
	end

	return self
end

function VendorScreen.newTaskBoard(ctx: any, parent: Instance)
	local self = {}
	local frame = Theme.create("Frame", { Parent = parent, Name = "Tasks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	self.frame = frame
	local state: any = nil

	local panel = Theme.glass({ Parent = frame, Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(1800, 930) })
	Theme.header(panel, "All tasks", UDim2.fromOffset(28, 20))
	local refresh = buildTaskBoard(ctx, panel, UDim2.fromOffset(28, 56), Vector2.new(1744, 850), function()
		local entries = {}
		for _, v in VendorDefs do
			for _, t in v.tasks do
				table.insert(entries, { task = t, vendor = v })
			end
		end
		return entries
	end)

	function self.refresh(newState: any)
		state = newState
		if frame.Visible then
			refresh(state)
		end
	end

	function self.show()
		frame.Visible = true
		refresh(state)
	end

	function self.hide()
		frame.Visible = false
	end

	return self
end

return VendorScreen
