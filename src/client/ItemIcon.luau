-- Item artwork. Uses the item's uploaded icon if it has one; for guns,
-- renders the gun's model in a ViewportFrame so icons match the guns in game.
-- Models come from the folders in WeaponConfig.MODEL_FOLDERS (ACS's
-- GunModels), or from the gun's Tool if the player is carrying it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponConfig"))

local ItemIcon = {}

local STRIP = { "LuaSourceContainer", "Sound", "ParticleEmitter", "Beam", "Trail", "Light", "Attachment" }

local function findModel(name: string): Instance?
	for _, path in WeaponConfig.MODEL_FOLDERS do
		local node: Instance? = ReplicatedStorage
		for _, part in path do
			node = node and node:FindFirstChild(part)
		end
		local model = node and node:FindFirstChild(name)
		if model then
			return model
		end
	end
	-- Fall back to the Tool itself, if the player is carrying it
	local player = Players.LocalPlayer
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		local tool = container and container:FindFirstChild(name)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

-- Tools aren't Models, so copy their parts into one to measure and display.
local function asModel(source: Instance): Instance
	local clone = source:Clone()
	if clone:IsA("Tool") then
		local model = Instance.new("Model")
		for _, child in clone:GetChildren() do
			child.Parent = model
		end
		clone:Destroy()
		return model
	end
	return clone
end

local function bounds(model: Instance): (CFrame?, Vector3?)
	if model:IsA("Model") then
		return model:GetBoundingBox()
	elseif model:IsA("BasePart") then
		return model.CFrame, model.Size
	end
	return nil, nil
end

-- aspect: width / height of the frame the icon fills. rot: draw it turned 90°.
function ItemIcon.render(parent: GuiObject, def: any, aspect: number, rot: boolean?): GuiObject?
	if def.icon and def.icon ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Image = def.icon
		image.ScaleType = Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		if rot then
			-- Turned 90°, so its unrotated box has the swapped aspect
			image.Size = UDim2.fromScale(1 / aspect, aspect)
			image.Rotation = 90
		else
			image.Size = UDim2.fromScale(1, 1)
		end
		image.Parent = parent
		return image
	end

	local source = def.tool and findModel(def.tool)
	if not source then
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(170, 175, 185)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)

	local model = asModel(source)
	for _, d in model:GetDescendants() do
		for _, className in STRIP do
			if d:IsA(className) then
				d:Destroy()
				break
			end
		end
	end
	model.Parent = viewport

	local cf, size = bounds(model)
	if not cf or not size then
		viewport:Destroy()
		return nil
	end

	-- Look at the gun side-on: the camera sits perpendicular to its long axis.
	local camera = Instance.new("Camera")
	camera.FieldOfView = 20
	local sideAxis = if size.X >= size.Z then cf.LookVector else cf.RightVector
	local length = math.max(size.X, size.Z)
	local height = size.Y

	local frameAspect = if rot then 1 / aspect else aspect
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local distance = math.max(length * 1.12 / (2 * tanHalf * frameAspect), height * 1.3 / (2 * tanHalf))

	local up = cf.UpVector
	local camCf = CFrame.lookAt(cf.Position + sideAxis * distance, cf.Position, up)
	if rot then
		camCf *= CFrame.Angles(0, 0, math.rad(90))
	end
	camera.CFrame = camCf
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	viewport.Parent = parent
	return viewport
end

return ItemIcon
