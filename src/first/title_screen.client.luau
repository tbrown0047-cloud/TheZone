--!strict
-- Title screen: blurred space backdrop that loops forever (slow zoom and
-- crossfade between images), THE ZONE logo with a light sweep, and a
-- "press any key" prompt. It sits underneath the HUD loading screen, so it is
-- revealed as that fades out. Pressing any key, button, click or tap starts
-- the game.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--------------------------------------------------------------------------------
-- Settings: paste your uploaded asset IDs here, e.g. "rbxassetid://1234567890".
-- Anything left as "" is skipped, with a plain fallback where it matters.
--------------------------------------------------------------------------------

-- Pre-blurred backgrounds from assets/title/ (bg_horizon_blur.png, bg_sunrise_blur.png)
local BACKGROUND_IMAGES = {
	"",
	"",
}
-- assets/title/logo.png. Without it, the logo is drawn as text.
local LOGO_IMAGE = ""
local LOGO_ASPECT = 1024 / 335

-- Audio (add later)
local MUSIC_ID = "" -- loops while the title screen is up
local MUSIC_VOLUME = 0.5
local START_SOUND_ID = "" -- plays once when the player presses a key
local START_SOUND_VOLUME = 0.8

local SLIDE_TIME = 9 -- seconds each background stays up
local CROSSFADE_TIME = 2.5
local SHIMMER_PERIOD = 4.5 -- seconds between light sweeps across the logo
local FADE_OUT_TIME = 1.2
local FOOTER_TEXT = "THE ZONE  //  BUILD 0.1"

--------------------------------------------------------------------------------

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local LOGO_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local LOGO_COLOR = Color3.fromRGB(242, 242, 242)

local function setCoreGui(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

-- Stops the character walking around behind the title screen.
local function setControlsEnabled(enabled: boolean)
	task.spawn(function()
		local ok, controls = pcall(function(): any
			local playerScripts = player:WaitForChild("PlayerScripts", 10)
			local module = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
			if not module then
				return nil
			end
			return (require(module :: ModuleScript) :: any):GetControls()
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

local function makeSound(id: string, volume: number, looped: boolean): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TitleScreen"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999 -- just below the HUD loading screen
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.new(0, 0, 0)
root.BorderSizePixel = 0
root.ClipsDescendants = true
root.Parent = screenGui

-- Background slides
local slides: { ImageLabel } = {}
for _, id in BACKGROUND_IMAGES do
	if id ~= "" then
		local slide = Instance.new("ImageLabel")
		slide.Name = "Slide"
		slide.Image = id
		slide.ScaleType = Enum.ScaleType.Crop
		slide.BackgroundTransparency = 1
		slide.ImageTransparency = 1
		slide.AnchorPoint = Vector2.new(0.5, 0.5)
		slide.Position = UDim2.fromScale(0.5, 0.5)
		slide.Size = UDim2.fromScale(1.08, 1.08)
		slide.ZIndex = 1
		slide.Parent = root
		table.insert(slides, slide)
	end
end

if #slides == 0 then
	-- Stand-in until the images are uploaded: a soft blue horizon glow.
	local glow = Instance.new("Frame")
	glow.Name = "FallbackGlow"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = Color3.fromRGB(70, 110, 170)
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	glow.Parent = root
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 0.85),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	gradient.Parent = glow
end

-- Darken and vignette so the logo reads on any frame of the backdrop.
local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.45
shade.BorderSizePixel = 0
shade.ZIndex = 3
shade.Parent = root

for _, rotation in { 90, 0 } do
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.new(0, 0, 0)
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 3
	vignette.Parent = root
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	gradient.Parent = vignette
end

-- Logo
local logoHolder = Instance.new("Frame")
logoHolder.Name = "LogoHolder"
logoHolder.BackgroundTransparency = 1
logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
logoHolder.Position = UDim2.fromScale(0.5, 0.43)
logoHolder.Size = UDim2.fromScale(0.46, 0.3)
logoHolder.ZIndex = 4
logoHolder.Parent = root

local logoAspect = Instance.new("UIAspectRatioConstraint")
logoAspect.AspectRatio = LOGO_ASPECT
logoAspect.Parent = logoHolder

local logoSizeLimit = Instance.new("UISizeConstraint")
logoSizeLimit.MaxSize = Vector2.new(920, 920 / LOGO_ASPECT)
logoSizeLimit.Parent = logoHolder

local logo: GuiObject
local logoFadeProp: string
if LOGO_IMAGE ~= "" then
	local image = Instance.new("ImageLabel")
	image.Image = LOGO_IMAGE
	image.ScaleType = Enum.ScaleType.Fit
	image.ImageTransparency = 1
	logo = image
	logoFadeProp = "ImageTransparency"
else
	local text = Instance.new("TextLabel")
	text.Text = "THE ZONE →"
	text.FontFace = LOGO_FONT
	text.TextColor3 = LOGO_COLOR
	text.TextScaled = true
	text.TextTransparency = 1
	logo = text
	logoFadeProp = "TextTransparency"
end
logo.Name = "Logo"
logo.BackgroundTransparency = 1
logo.Size = UDim2.fromScale(1, 1)
logo.ZIndex = 4
logo.Parent = logoHolder

local logoScale = Instance.new("UIScale")
logoScale.Scale = 1.06
logoScale.Parent = logoHolder

-- A bright band that sweeps across the logo every SHIMMER_PERIOD seconds.
local shimmer = Instance.new("UIGradient")
shimmer.Rotation = 20
shimmer.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.44, 0.2),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.56, 0.2),
	NumberSequenceKeypoint.new(1, 0.2),
})
shimmer.Offset = Vector2.new(-1, 0)
shimmer.Parent = logo

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.AnchorPoint = Vector2.new(0.5, 0.5)
divider.Position = UDim2.fromScale(0.5, 0.63)
divider.Size = UDim2.new(0, 0, 0, 1)
divider.BackgroundColor3 = LOGO_COLOR
divider.BackgroundTransparency = 0.6
divider.BorderSizePixel = 0
divider.ZIndex = 4
divider.Parent = root

local promptText = "PRESS ANY KEY TO START"
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	promptText = "TAP ANYWHERE TO START"
elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
	promptText = "PRESS ANY BUTTON TO START"
end

local prompt = Instance.new("TextLabel")
prompt.Name = "Prompt"
prompt.AnchorPoint = Vector2.new(0.5, 0.5)
prompt.Position = UDim2.fromScale(0.5, 0.69)
prompt.Size = UDim2.new(1, 0, 0, 24)
prompt.BackgroundTransparency = 1
prompt.FontFace = MONO
prompt.Text = promptText
prompt.TextColor3 = LOGO_COLOR
prompt.TextSize = 18
prompt.TextTransparency = 1
prompt.ZIndex = 4
prompt.Parent = root

local footer = Instance.new("TextLabel")
footer.Name = "Footer"
footer.AnchorPoint = Vector2.new(1, 1)
footer.Position = UDim2.new(1, -24, 1, -18)
footer.Size = UDim2.fromOffset(400, 16)
footer.BackgroundTransparency = 1
footer.FontFace = MONO
footer.Text = FOOTER_TEXT
footer.TextColor3 = LOGO_COLOR
footer.TextSize = 11
footer.TextTransparency = 1
footer.TextXAlignment = Enum.TextXAlignment.Right
footer.ZIndex = 4
footer.Parent = root

screenGui.Parent = playerGui
setCoreGui(false)
setControlsEnabled(false)

task.spawn(function()
	local toLoad: { Instance } = { logo }
	for _, slide in slides do
		table.insert(toLoad, slide)
	end
	pcall(function()
		ContentProvider:PreloadAsync(toLoad)
	end)
end)

--------------------------------------------------------------------------------
-- Looping background
--------------------------------------------------------------------------------

local function play(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

local backgroundLoop = task.spawn(function()
	if #slides == 0 then
		return
	end

	if #slides == 1 then
		local slide = slides[1]
		play(slide, TweenInfo.new(CROSSFADE_TIME), { ImageTransparency = 0 })
		play(slide, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = UDim2.fromScale(1.18, 1.18),
		})
		return
	end

	local index = 1
	while true do
		local slide = slides[index]
		for _, other in slides do
			other.ZIndex = if other == slide then 2 else 1
		end

		-- Slow zoom and drift that outlasts the slide, so motion never stops.
		slide.Size = UDim2.fromScale(1.08, 1.08)
		slide.Position = UDim2.fromScale(0.5, 0.5)
		play(slide, TweenInfo.new(SLIDE_TIME + CROSSFADE_TIME * 2, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1.2, 1.2),
			Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.05, 0.5 + (math.random() - 0.5) * 0.04),
		})
		play(slide, TweenInfo.new(CROSSFADE_TIME, Enum.EasingStyle.Sine), { ImageTransparency = 0 })
		task.wait(CROSSFADE_TIME)

		for _, other in slides do
			if other ~= slide then
				other.ImageTransparency = 1
			end
		end
		task.wait(SLIDE_TIME)
		index = index % #slides + 1
	end
end)

--------------------------------------------------------------------------------
-- Logo shimmer, breathing and prompt pulse
--------------------------------------------------------------------------------

local ready = false
local animStart = os.clock()
local animConnection = RunService.Heartbeat:Connect(function()
	local t = os.clock() - animStart

	local sweep = (t % SHIMMER_PERIOD) / 1.2
	shimmer.Offset = Vector2.new(if sweep < 1 then -1 + sweep * 2 else 1, 0)

	if ready then
		logoScale.Scale = 1 + math.sin(t * 1.2) * 0.012
		prompt.TextTransparency = 0.15 + 0.55 * (0.5 + 0.5 * math.sin(t * 3))
	end
end)

--------------------------------------------------------------------------------
-- Intro: wait for the HUD loading screen to finish, then reveal
--------------------------------------------------------------------------------

if not game:IsLoaded() then
	game.Loaded:Wait()
end
while playerGui:FindFirstChild("LoadingScreen") do
	playerGui.ChildRemoved:Wait()
end

local music = makeSound(MUSIC_ID, MUSIC_VOLUME, true)
if music then
	music.Volume = 0
	music:Play()
	play(music, TweenInfo.new(2), { Volume = MUSIC_VOLUME })
end

local introInfo = TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
play(logo, introInfo, { [logoFadeProp] = 0 })
play(logoScale, introInfo, { Scale = 1 })
task.wait(0.6)
play(divider, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { Size = UDim2.new(0.28, 0, 0, 1) })
play(footer, TweenInfo.new(1), { TextTransparency = 0.6 })
task.wait(0.5)
play(prompt, TweenInfo.new(0.6), { TextTransparency = 0.15 })
task.wait(0.6)
animStart = os.clock()
ready = true

--------------------------------------------------------------------------------
-- Press any key
--------------------------------------------------------------------------------

local started = Instance.new("BindableEvent")

local function isStartInput(input: InputObject): boolean
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.Keyboard then
		return input.KeyCode ~= Enum.KeyCode.Unknown
	elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
		return true
	elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return input.KeyCode ~= Enum.KeyCode.Thumbstick1 and input.KeyCode ~= Enum.KeyCode.Thumbstick2
	end
	return false
end

local inputConnection = UserInputService.InputBegan:Connect(function(input)
	if ready and isStartInput(input) then
		ready = false
		started:Fire()
	end
end)

started.Event:Wait()
inputConnection:Disconnect()
player:SetAttribute("TitleScreenDone", true)

local startSound = makeSound(START_SOUND_ID, START_SOUND_VOLUME, false)
if startSound then
	startSound:Play()
	startSound.Ended:Once(function()
		startSound:Destroy()
	end)
end

-- Quick confirm blink on the prompt
prompt.Text = "STARTING"
for _ = 1, 3 do
	prompt.TextTransparency = 1
	task.wait(0.06)
	prompt.TextTransparency = 0
	task.wait(0.08)
end

--------------------------------------------------------------------------------
-- Fade out into the game
--------------------------------------------------------------------------------

task.cancel(backgroundLoop)
animConnection:Disconnect()

local fadeInfo = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
for _, inst in screenGui:GetDescendants() do
	if inst:IsA("ImageLabel") then
		play(inst, fadeInfo, { ImageTransparency = 1 })
	elseif inst:IsA("TextLabel") then
		play(inst, fadeInfo, { TextTransparency = 1 })
	elseif inst:IsA("Frame") and inst.BackgroundTransparency < 1 then
		play(inst, fadeInfo, { BackgroundTransparency = 1 })
	end
end
if music then
	play(music, fadeInfo, { Volume = 0 })
end
task.wait(FADE_OUT_TIME)

if music then
	music:Destroy()
end
setCoreGui(true)
setControlsEnabled(true)
screenGui:Destroy()
