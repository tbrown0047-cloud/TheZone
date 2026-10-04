-- CHARACTER screen: equipment slots, carrier grids and the locker, with
-- drag and drop (R rotates while dragging), double-click quick move,
-- right-click item menu and an inspect panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared:WaitForChild("Inventory"))
local ItemDefs = require(Shared:WaitForChild("ItemDefs"))

local ItemIcon = require(script.Parent.ItemIcon)
local Net = require(script.Parent.Net)
local Theme = require(script.Parent.Theme)

local C = Theme.Color
local CELL = Theme.CELL
local DOUBLE_CLICK = 0.35

local CARRIER_ROWS = {
	{ container = "vest", slot = "Vest", label = "VEST" },
	{ container = "backpack", slot = "Backpack", label = "BACKPACK" },
	{ container = "belt", slot = "Belt", label = "BELT" },
	{ container = "pockets", label = "POCKETS" },
}

local EQUIPMENT_SLOTS = {
	{ slot = "Helmet", x = 20, y = 46, w = 175, h = 120 },
	{ slot = "Headset", x = 205, y = 46, w = 175, h = 120 },
	{ slot = "Primary", x = 20, y = 196, w = 360, h = 130 },
	{ slot = "Secondary", x = 20, y = 356, w = 360, h = 130 },
	{ slot = "Sidearm", x = 20, y = 516, w = 175, h = 110 },
}

local CharacterScreen = {}

function CharacterScreen.new(ctx: any, parent: Instance)
	local self = {}
	local state: any = nil
	local visible = false

	local frame = Theme.create("Frame", {
		Parent = parent,
		Name = "Character",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	self.frame = frame

	local gear = Theme.create("Frame", { Parent = frame, Name = "Gear", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local health = Theme.create("Frame", { Parent = frame, Name = "Health", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local apparel = Theme.create("Frame", { Parent = frame, Name = "Apparel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local pages = { GEAR = gear, HEALTH = health, APPAREL = apparel }

	local _, selectPage = Theme.tabs(frame, { "GEAR", "HEALTH", "APPAREL" }, UDim2.fromOffset(60, 66), 140, 30, function(name)
		for pageName, page in pages do
			page.Visible = pageName == name
		end
	end, 13)
	selectPage("GEAR")

	------------------------------------------------------------------------------
	-- Panels
	------------------------------------------------------------------------------

	local equipPanel = Theme.glass({ Parent = gear, Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(400, 930) })
	Theme.header(equipPanel, "Equipment", UDim2.fromOffset(20, 16))

	local carrierPanel = Theme.glass({ Parent = gear, Position = UDim2.fromOffset(480, 110), Size = UDim2.fromOffset(560, 930) })
	Theme.header(carrierPanel, "Carriers", UDim2.fromOffset(20, 16))
	local weightLabel = Theme.label({
		Parent = carrierPanel,
		FontFace = Theme.Font.Mono,
		TextSize = 12,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -220, 0, 14),
		Size = UDim2.fromOffset(200, 20),
	})
	local carrierScroll = Theme.create("ScrollingFrame", {
		Parent = carrierPanel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -30, 1, -60),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Dim,
		CanvasSize = UDim2.new(),
	})

	local lockerPanel = Theme.glass({ Parent = gear, Position = UDim2.fromOffset(1060, 110), Size = UDim2.fromOffset(800, 930) })
	Theme.header(lockerPanel, "Your locker", UDim2.fromOffset(20, 16))
	local moneyLabel = Theme.label({
		Parent = lockerPanel,
		FontFace = Theme.Font.Mono,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -240, 0, 12),
		Size = UDim2.fromOffset(220, 24),
	})
	local lockerScroll = Theme.create("ScrollingFrame", {
		Parent = lockerPanel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -30, 1, -60),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Dim,
		CanvasSize = UDim2.fromOffset(0, Inventory.LOCKER.h * CELL),
	})

	------------------------------------------------------------------------------
	-- Drop targets
	------------------------------------------------------------------------------

	type GridTarget = { container: string, holder: Frame, gw: number, gh: number, preview: Frame, clip: GuiObject }
	local gridTargets: { GridTarget } = {}
	local slotFrames: { [string]: Frame } = {}
	local slotStrokes: { [string]: UIStroke } = {}

	for _, info in EQUIPMENT_SLOTS do
		local slotFrame = Theme.create("Frame", {
			Parent = equipPanel,
			Name = info.slot,
			BackgroundColor3 = C.GlassHi,
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(info.x, info.y),
			Size = UDim2.fromOffset(info.w, info.h),
		})
		slotStrokes[info.slot] = Theme.stroke(slotFrame)
		Theme.label({
			Parent = slotFrame,
			Name = "Caption",
			Text = string.upper(info.slot),
			FontFace = Theme.Font.Bold,
			TextSize = 11,
			TextColor3 = C.Faint,
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.fromOffset(150, 16),
			ZIndex = 3,
		})
		slotFrames[info.slot] = slotFrame
	end

	-- Vitals at the bottom of the equipment column
	local vitalSetters: { [string]: (number) -> () } = {}
	local vitalValues: { [string]: TextLabel } = {}
	for i, info in { { "HEALTH", C.Danger }, { "HYDRATION", C.Water }, { "ENERGY", C.Good } } do
		local y = 760 + (i - 1) * 50
		Theme.label({
			Parent = equipPanel,
			Text = info[1],
			FontFace = Theme.Font.Bold,
			TextSize = 12,
			TextColor3 = C.Dim,
			Position = UDim2.fromOffset(20, y),
			Size = UDim2.fromOffset(200, 16),
		})
		vitalValues[info[1]] = Theme.label({
			Parent = equipPanel,
			FontFace = Theme.Font.Mono,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(180, y),
			Size = UDim2.fromOffset(200, 16),
		})
		local _, set = Theme.bar(equipPanel, UDim2.fromOffset(20, y + 22), UDim2.fromOffset(360, 4), info[2])
		vitalSetters[info[1]] = set
	end

	------------------------------------------------------------------------------
	-- Inspect panel
	------------------------------------------------------------------------------

	local inspect = Theme.glass({
		Parent = gear,
		Name = "Inspect",
		BackgroundTransparency = 0.12,
		Position = UDim2.fromOffset(480, 110),
		Size = UDim2.fromOffset(420, 760),
		Visible = false,
		ZIndex = 20,
	})
	local inspectToken = 0

	local function closeInspect()
		inspect.Visible = false
		inspectToken += 1
	end

	local function openInspect(item: any)
		inspectToken += 1
		local token = inspectToken
		inspect:ClearAllChildren()
		Theme.stroke(inspect)
		local def = ItemDefs[item.id]

		Theme.label({ Parent = inspect, Text = def.name, FontFace = Theme.Font.Bold, TextSize = 24, Position = UDim2.fromOffset(20, 16), Size = UDim2.fromOffset(330, 30), ZIndex = 21 })
		Theme.label({
			Parent = inspect,
			Text = string.upper(def.category) .. (if def.caliber then "  ·  " .. def.caliber else ""),
			TextSize = 12,
			TextColor3 = C.Dim,
			Position = UDim2.fromOffset(20, 46),
			Size = UDim2.fromOffset(330, 16),
			ZIndex = 21,
		})
		local close = Theme.button({ Parent = inspect, Text = "✕", TextSize = 16, Position = UDim2.new(1, -46, 0, 14), Size = UDim2.fromOffset(32, 32), ZIndex = 21 }, "ghost")
		close.Activated:Connect(closeInspect)

		local art = Theme.create("Frame", {
			Parent = inspect,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(20, 76),
			Size = UDim2.fromOffset(380, 190),
			ZIndex = 21,
		})
		local icon = ItemIcon.render(art, def, 380 / 190, false)
		if icon then
			icon.ZIndex = 22
		else
			Theme.label({ Parent = art, Text = def.short, FontFace = Theme.Font.Bold, TextSize = 28, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 22 })
		end

		local rows: { { string } } = {
			{ "Weight", string.format("%.2f kg", def.weight * item.count) },
			{ "Value", Theme.formatMoney(def.value * item.count) },
			{ "Size", def.w .. " x " .. def.h },
		}
		if def.stack then
			table.insert(rows, { "Stack", item.count .. " / " .. def.stack })
		end
		if def.heal then
			table.insert(rows, { "Restores health", "+" .. def.heal })
		end
		if def.hydration then
			table.insert(rows, { "Hydration", "+" .. def.hydration })
		end
		if def.energy then
			table.insert(rows, { "Energy", "+" .. def.energy })
		end
		if def.grid then
			table.insert(rows, { "Storage", def.grid.w .. " x " .. def.grid.h })
		end

		local list = Theme.create("ScrollingFrame", {
			Parent = inspect,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(20, 280),
			Size = UDim2.fromOffset(380, 330),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = C.Dim,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 21,
		})
		Theme.create("UIListLayout", { Parent = list, SortOrder = Enum.SortOrder.LayoutOrder })

		local order = 0
		local function addRow(key: string, value: string)
			order += 1
			local row = Theme.create("Frame", {
				Parent = list,
				BackgroundColor3 = C.GlassHi,
				BackgroundTransparency = if order % 2 == 0 then 0.75 else 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 0, 26),
				LayoutOrder = order,
				ZIndex = 21,
			})
			Theme.label({ Parent = row, Text = key, TextSize = 13, TextColor3 = C.Dim, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 22 })
			Theme.label({
				Parent = row,
				Text = value,
				FontFace = Theme.Font.Mono,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(0.4, 0, 0, 0),
				Size = UDim2.new(0.6, -8, 1, 0),
				ZIndex = 22,
			})
		end
		for _, row in rows do
			addRow(row[1], row[2])
		end

		Theme.label({
			Parent = inspect,
			Text = def.description,
			TextSize = 13,
			TextColor3 = C.Dim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(20, 626),
			Size = UDim2.fromOffset(380, 120),
			ZIndex = 21,
		})
		inspect.Visible = true

		-- SPEARHEAD WeaponStats, fetched from the server
		if def.tool then
			task.spawn(function()
				local ok, _, stats = Net.Action("inspect", item.uid)
				if ok and token == inspectToken and type(stats) == "table" then
					if #stats > 0 then
						order += 1
						local heading = Theme.label({
							Parent = list,
							Text = "WEAPON STATS",
							FontFace = Theme.Font.Bold,
							TextSize = 11,
							TextColor3 = C.Accent,
							Size = UDim2.new(1, 0, 0, 28),
							LayoutOrder = order,
							ZIndex = 22,
						})
						heading.TextYAlignment = Enum.TextYAlignment.Bottom
					end
					for _, row in stats do
						addRow(row[1], row[2])
					end
				end
			end)
		end
	end

	------------------------------------------------------------------------------
	-- Item tiles and dragging
	------------------------------------------------------------------------------

	local drag: any = nil
	local pendingRefresh = false
	local lastClick = { uid = "", time = 0 }
	local lastPointer = Vector2.zero
	local render: () -> ()

	local function pointerFrom(input: InputObject): Vector2
		if input.UserInputType == Enum.UserInputType.Touch then
			return Vector2.new(input.Position.X, input.Position.Y) + ctx.inset()
		end
		return UserInputService:GetMouseLocation()
	end

	local function within(gui: GuiObject, point: Vector2): boolean
		local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
		return point.X >= pos.X and point.Y >= pos.Y and point.X <= pos.X + size.X and point.Y <= pos.Y + size.Y
	end

	local function itemMenu(item: any, point: Vector2)
		local def = ItemDefs[item.id]
		local options = {}
		local function act(name: string, ...: any)
			local args = table.pack(...)
			task.spawn(function()
				local ok, message, extra = Net.Action(name, table.unpack(args, 1, args.n))
				if not ok then
					ctx.toast(message or "Couldn't do that", "error")
				elseif name == "sell" then
					ctx.toast("Sold for " .. Theme.formatMoney(extra or 0), "good")
				end
			end)
		end

		table.insert(options, { text = "INSPECT", callback = function()
			openInspect(item)
		end })
		if Inventory.isConsumable(def) then
			table.insert(options, { text = "USE", callback = function()
				act("use", item.uid)
			end })
		end
		if def.slots then
			local equipped = Inventory.slotOf(item.at) ~= nil
			table.insert(options, { text = if equipped then "UNEQUIP" else "EQUIP", callback = function()
				act("quick", item.uid)
			end })
		elseif item.at ~= "locker" then
			table.insert(options, { text = "MOVE TO LOCKER", callback = function()
				act("quick", item.uid)
			end })
		end
		table.insert(options, { text = "SELL  " .. Theme.formatMoney(math.floor(def.value * item.count * 0.5)), callback = function()
			act("sell", item.uid)
		end })
		table.insert(options, { text = "DISCARD", style = "danger", callback = function()
			ctx.confirm("DISCARD " .. string.upper(def.name) .. "?", "This item will be destroyed.", "DISCARD", function()
				act("discard", item.uid)
			end)
		end })
		ctx.contextMenu(point, options)
	end

	local function makeVisual(parent: Instance, item: any, def: any, size: UDim2, w: number, h: number, rot: boolean, zIndex: number): Frame
		local tile = Theme.create("Frame", {
			Parent = parent,
			Name = "Tile",
			BackgroundColor3 = C.GlassHi,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = size,
			ZIndex = zIndex,
		})
		Theme.stroke(tile, 0.75)
		Theme.create("Frame", {
			Parent = tile,
			BackgroundColor3 = Theme.Category[def.category] or C.Dim,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = zIndex + 1,
		})
		local iconHolder = Theme.create("Frame", {
			Parent = tile,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 14),
			Size = UDim2.new(1, -8, 1, -18),
			ZIndex = zIndex + 1,
		})
		local icon = ItemIcon.render(iconHolder, def, math.max(w, 0.5) / math.max(h, 0.5), rot)
		if icon then
			icon.ZIndex = zIndex + 1
		end
		Theme.label({
			Parent = tile,
			Text = def.short,
			FontFace = Theme.Font.Bold,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(4, 1),
			Size = UDim2.new(1, -6, 0, 13),
			ZIndex = zIndex + 2,
		})
		if (def.stack or 1) > 1 then
			Theme.label({
				Parent = tile,
				Text = tostring(item.count),
				FontFace = Theme.Font.Mono,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -3),
				Size = UDim2.fromOffset(40, 12),
				ZIndex = zIndex + 2,
			})
		end
		return tile
	end

	local function clearPreviews()
		for _, target in gridTargets do
			target.preview.Visible = false
		end
		for _, stroke in slotStrokes do
			stroke.Color = C.Stroke
			stroke.Transparency = Theme.Alpha.Stroke
		end
	end

	-- Where the dragged item would land: returns (kind, target, x, y, valid)
	local function dropTarget(): (string?, any, number, number, boolean)
		local item, def = drag.item, drag.def
		local w, h = Inventory.footprint(def, drag.rot)

		for slot, slotFrame in slotFrames do
			if within(slotFrame, lastPointer) then
				local occupant = Inventory.slotItem(state, slot)
				local valid = Inventory.canEquip(def, slot) and (occupant == nil or occupant.uid == item.uid)
				return "slot", slot, 0, 0, valid
			end
		end

		for _, target in gridTargets do
			if target.holder.Parent and within(target.clip, lastPointer) and within(target.holder, lastPointer) then
				local cellPx = target.holder.AbsoluteSize.X / target.gw
				local topLeft = lastPointer - drag.grab
				local x = math.floor((topLeft.X - target.holder.AbsolutePosition.X) / cellPx + 0.5)
				local y = math.floor((topLeft.Y - target.holder.AbsolutePosition.Y) / cellPx + 0.5)

				local fromSlot = Inventory.slotOf(item.at)
				if fromSlot and Inventory.containerForSlot(fromSlot) == target.container then
					return "grid", target, x, y, false
				end
				local under = Inventory.itemAt(state, target.container, math.floor((lastPointer.X - target.holder.AbsolutePosition.X) / cellPx), math.floor((lastPointer.Y - target.holder.AbsolutePosition.Y) / cellPx), item.uid)
				if under and under.id == item.id and (def.stack or 1) > 1 and under.count < def.stack then
					return "grid", target, under.x, under.y, true
				end
				return "grid", target, x, y, Inventory.fits(state, target.container, w, h, x, y, item.uid)
			end
		end
		return nil, nil, 0, 0, false
	end

	local function updateDrag()
		if not drag or not drag.ghost then
			return
		end
		drag.ghost.Position = UDim2.fromOffset(ctx.toCanvas(lastPointer - drag.grab).X, ctx.toCanvas(lastPointer - drag.grab).Y)
		clearPreviews()
		local kind, target, x, y, valid = dropTarget()
		local color = if valid then C.Good else C.Danger
		if kind == "slot" then
			slotStrokes[target].Color = color
			slotStrokes[target].Transparency = 0.2
		elseif kind == "grid" then
			local w, h = Inventory.footprint(drag.def, drag.rot)
			target.preview.Position = UDim2.fromOffset(x * CELL, y * CELL)
			target.preview.Size = UDim2.fromOffset(w * CELL, h * CELL)
			target.preview.BackgroundColor3 = color
			target.preview.Visible = true
		end
	end

	local function buildGhost()
		if drag.ghost then
			drag.ghost:Destroy()
		end
		local w, h = Inventory.footprint(drag.def, drag.rot)
		local ghost = makeVisual(ctx.overlay, drag.item, drag.def, UDim2.fromOffset(w * CELL - 2, h * CELL - 2), w, h, drag.rot, 60)
		ghost.BackgroundTransparency = 0.15
		drag.ghost = ghost
	end

	local function endDrag(commit: boolean)
		local current = drag
		if not current then
			return
		end
		if current.ghost then
			if commit then
				local kind, target, x, y, valid = dropTarget()
				if kind and valid then
					local to = if kind == "slot" then "slot:" .. target else target.container
					task.spawn(function()
						local ok, message = Net.Action("move", current.item.uid, to, x, y, current.rot)
						if not ok then
							ctx.toast(message or "Can't move that", "error")
						end
					end)
				elseif kind then
					ctx.toast("Can't place that there", "error")
				end
			end
			current.ghost:Destroy()
			current.tile.BackgroundTransparency = 0.35
		end
		drag = nil
		clearPreviews()
		if pendingRefresh then
			pendingRefresh = false
			render()
		end
	end

	local function onTileClick(item: any, input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			itemMenu(item, ctx.toCanvas(lastPointer))
			return
		end
		local now = os.clock()
		if lastClick.uid == item.uid and now - lastClick.time < DOUBLE_CLICK then
			lastClick.uid = ""
			task.spawn(function()
				local ok, message = Net.Action("quick", item.uid)
				if not ok then
					ctx.toast(message or "No room", "error")
				end
			end)
		else
			lastClick.uid = item.uid
			lastClick.time = now
		end
	end

	local function makeTile(parent: Instance, item: any, position: UDim2, size: UDim2, w: number, h: number, zIndex: number)
		local def = ItemDefs[item.id]
		local tile = makeVisual(parent, item, def, size, w, h, item.rot, zIndex)
		tile.Position = position
		local hit = Theme.create("TextButton", {
			Parent = tile,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 3,
		})
		hit.MouseEnter:Connect(function()
			if not drag then
				tile.BackgroundTransparency = 0.15
			end
		end)
		hit.MouseLeave:Connect(function()
			if not drag or drag.tile ~= tile then
				tile.BackgroundTransparency = 0.35
			end
		end)
		hit.MouseButton2Click:Connect(function()
			itemMenu(item, ctx.toCanvas(UserInputService:GetMouseLocation()))
		end)
		hit.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				lastPointer = pointerFrom(input)
				drag = {
					item = item,
					def = def,
					rot = item.rot,
					tile = tile,
					start = lastPointer,
					grab = lastPointer - tile.AbsolutePosition,
					input = input,
					ghost = nil,
				}
			end
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
			return
		end
		lastPointer = pointerFrom(input)
		if drag and not drag.ghost and (lastPointer - drag.start).Magnitude > 5 then
			-- Grab point is kept in screen pixels relative to the tile's corner
			buildGhost()
			drag.tile.BackgroundTransparency = 0.7
			closeInspect()
		end
		updateDrag()
	end)

	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if not drag or (t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch) then
			return
		end
		if drag.ghost then
			endDrag(true)
		else
			local item = drag.item
			drag = nil
			onTileClick(item, input)
		end
	end)

	UserInputService.InputBegan:Connect(function(input)
		if drag and drag.ghost and input.KeyCode == Enum.KeyCode.R then
			drag.rot = not drag.rot
			local cellPx = CELL * ctx.scale()
			drag.grab = Vector2.new(cellPx / 2, cellPx / 2)
			buildGhost()
			updateDrag()
		elseif drag and drag.ghost and input.KeyCode == Enum.KeyCode.Escape then
			endDrag(false)
		end
	end)

	------------------------------------------------------------------------------
	-- Rendering
	------------------------------------------------------------------------------

	local function renderGrid(parent: Instance, container: string, gw: number, gh: number, position: UDim2, clip: GuiObject): Frame
		local holder = Theme.create("Frame", {
			Parent = parent,
			Name = "Grid_" .. container,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			Position = position,
			Size = UDim2.fromOffset(gw * CELL, gh * CELL),
		})
		Theme.stroke(holder, 0.8)
		local cells = Theme.create("Frame", { Parent = holder, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		Theme.create("UIGridLayout", {
			Parent = cells,
			CellSize = UDim2.fromOffset(CELL, CELL),
			CellPadding = UDim2.new(),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		for _ = 1, gw * gh do
			local cell = Theme.create("Frame", {
				Parent = cells,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.97,
				BorderSizePixel = 0,
			})
			Theme.stroke(cell, 0.93)
		end

		local preview = Theme.create("Frame", {
			Parent = holder,
			Name = "Preview",
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 8,
		})
		table.insert(gridTargets, { container = container, holder = holder, gw = gw, gh = gh, preview = preview, clip = clip })

		for _, item in Inventory.itemsIn(state, container) do
			local def = ItemDefs[item.id]
			local w, h = Inventory.footprint(def, item.rot)
			makeTile(holder, item, UDim2.fromOffset(item.x * CELL + 1, item.y * CELL + 1), UDim2.fromOffset(w * CELL - 2, h * CELL - 2), w, h, 4)
		end
		return holder
	end

	local function renderSlot(slotFrame: Frame, slot: string)
		for _, child in slotFrame:GetChildren() do
			if child.Name == "Tile" then
				child:Destroy()
			end
		end
		local item = Inventory.slotItem(state, slot)
		if item then
			local def = ItemDefs[item.id]
			makeTile(slotFrame, item, UDim2.fromOffset(4, 20), UDim2.new(1, -8, 1, -24), def.w, def.h, 2)
		end
	end

	local function renderVitals()
		if not state then
			return
		end
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		local hp = if humanoid then humanoid.Health else 0
		local maxHp = if humanoid then humanoid.MaxHealth else 100
		vitalSetters.HEALTH(hp / math.max(maxHp, 1))
		vitalValues.HEALTH.Text = string.format("%d / %d", math.ceil(hp), maxHp)
		vitalSetters.HYDRATION(state.vitals.hydration / 100)
		vitalValues.HYDRATION.Text = string.format("%d / 100", math.floor(state.vitals.hydration))
		vitalSetters.ENERGY(state.vitals.energy / 100)
		vitalValues.ENERGY.Text = string.format("%d / 100", math.floor(state.vitals.energy))
	end

	render = function()
		if not state then
			return
		end
		table.clear(gridTargets)
		moneyLabel.Text = Theme.formatMoney(state.money)
		weightLabel.Text = string.format("%.1f KG", Inventory.totalWeight(state))

		for slot, slotFrame in slotFrames do
			renderSlot(slotFrame, slot)
		end

		-- Carriers: each equipped carrier gets a slot box and its grid
		carrierScroll:ClearAllChildren()
		local y = 0
		for _, row in CARRIER_ROWS do
			local carrier = row.slot and Inventory.slotItem(state, row.slot)
			local caption = row.label .. (if carrier then "  ·  " .. string.upper(ItemDefs[carrier.id].name) else "")
			Theme.label({
				Parent = carrierScroll,
				Text = caption,
				FontFace = Theme.Font.Bold,
				TextSize = 11,
				TextColor3 = C.Faint,
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.fromOffset(500, 16),
			})
			y += 20

			local gridX = 0
			local rowHeight = CELL
			if row.slot then
				local box = Theme.create("Frame", {
					Parent = carrierScroll,
					Name = row.slot,
					BackgroundColor3 = C.GlassHi,
					BackgroundTransparency = 0.7,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.fromOffset(100, 100),
				})
				slotStrokes[row.slot] = Theme.stroke(box)
				slotFrames[row.slot] = box
				if carrier then
					makeTile(box, carrier, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8), ItemDefs[carrier.id].w, ItemDefs[carrier.id].h, 2)
				else
					Theme.label({ Parent = box, Text = "EMPTY", TextSize = 11, TextColor3 = C.Faint, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
				end
				gridX = 116
				rowHeight = 100
			end

			local gw, gh = Inventory.containerSize(state, row.container)
			if gw and gh then
				renderGrid(carrierScroll, row.container, gw, gh, UDim2.fromOffset(gridX, y), carrierScroll)
				rowHeight = math.max(rowHeight, gh * CELL)
			end
			y += rowHeight + 22
		end
		carrierScroll.CanvasSize = UDim2.fromOffset(0, y)

		lockerScroll:ClearAllChildren()
		renderGrid(lockerScroll, "locker", Inventory.LOCKER.w, Inventory.LOCKER.h, UDim2.fromOffset(0, 0), lockerScroll)

		renderVitals()
	end

	------------------------------------------------------------------------------
	-- Health and apparel pages
	------------------------------------------------------------------------------

	local healthPanel = Theme.glass({ Parent = health, Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(700, 520) })
	Theme.header(healthPanel, "Condition", UDim2.fromOffset(24, 20))
	local bigSetters: { [string]: (number) -> () } = {}
	local bigValues: { [string]: TextLabel } = {}
	for i, info in { { "HEALTH", C.Danger }, { "HYDRATION", C.Water }, { "ENERGY", C.Good } } do
		local y = 70 + (i - 1) * 120
		Theme.label({ Parent = healthPanel, Text = info[1], FontFace = Theme.Font.Bold, TextSize = 16, Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(300, 24) })
		bigValues[info[1]] = Theme.label({
			Parent = healthPanel,
			FontFace = Theme.Font.Mono,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(376, y - 6),
			Size = UDim2.fromOffset(300, 36),
		})
		local _, set = Theme.bar(healthPanel, UDim2.fromOffset(24, y + 44), UDim2.fromOffset(652, 6), info[2])
		bigSetters[info[1]] = set
	end
	Theme.label({
		Parent = healthPanel,
		Text = "Hydration and energy drain over time. At zero you start losing health. Right-click food, drink and medical items in your inventory and choose USE.",
		TextSize = 13,
		TextColor3 = C.Dim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(24, 430),
		Size = UDim2.fromOffset(652, 70),
	})

	local apparelPanel = Theme.glass({ Parent = apparel, Position = UDim2.fromOffset(60, 110), Size = UDim2.fromOffset(700, 200) })
	Theme.header(apparelPanel, "Apparel", UDim2.fromOffset(24, 20))
	Theme.label({
		Parent = apparelPanel,
		Text = "Clothing and camo customisation will live here.",
		TextSize = 15,
		TextColor3 = C.Dim,
		Position = UDim2.fromOffset(24, 70),
		Size = UDim2.fromOffset(652, 24),
	})

	local function renderHealthPage()
		if not state then
			return
		end
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		local hp = if humanoid then humanoid.Health else 0
		local maxHp = if humanoid then humanoid.MaxHealth else 100
		bigSetters.HEALTH(hp / math.max(maxHp, 1))
		bigValues.HEALTH.Text = string.format("%d", math.ceil(hp))
		bigSetters.HYDRATION(state.vitals.hydration / 100)
		bigValues.HYDRATION.Text = string.format("%d", math.floor(state.vitals.hydration))
		bigSetters.ENERGY(state.vitals.energy / 100)
		bigValues.ENERGY.Text = string.format("%d", math.floor(state.vitals.energy))
	end

	-- Health changes outside of inventory updates, so poll it while visible
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not visible then
			return
		end
		acc += dt
		if acc >= 0.25 then
			acc = 0
			renderVitals()
			renderHealthPage()
		end
	end)

	------------------------------------------------------------------------------

	function self.refresh(newState: any)
		state = newState
		if not visible then
			return
		end
		if drag then
			pendingRefresh = true
			return
		end
		render()
		renderHealthPage()
	end

	function self.show()
		visible = true
		frame.Visible = true
		if state then
			render()
			renderHealthPage()
		end
	end

	function self.hide()
		visible = false
		frame.Visible = false
		endDrag(false)
		closeInspect()
	end

	return self
end

return CharacterScreen
