-- Item artwork. Uses the item's uploaded icon if it has one; for guns,
-- renders the SPEARHEAD weapon model (ReplicatedStorage.SPH_Assets.WeaponModels)
-- in a ViewportFrame so icons match the guns in game automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemIcon = {}

local STRIP = { "LuaSourceContainer", "Sound", "ParticleEmitter", "Beam", "Trail", "Light", "Attachment" }

local function findModel(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("SPH_Assets")
	local models = assets and assets:FindFirstChild("WeaponModels")
	return models and models:FindFirstChild(name)
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

	local model = source:Clone()
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
