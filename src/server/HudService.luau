--!strict
-- Broadcasts kills for the HUD kill feed. The killer comes from the standard
-- "creator" ObjectValue tag that weapons (including SPEARHEAD, see its
-- rblxDamageTags setting) leave in the victim's Humanoid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudService = {}

function HudService.Start()
	local remotes = Instance.new("Folder")
	remotes.Name = "HudRemotes"
	local killFeed = Instance.new("RemoteEvent")
	killFeed.Name = "KillFeed"
	killFeed.Parent = remotes
	remotes.Parent = ReplicatedStorage

	local function onCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			local tag = humanoid:FindFirstChild("creator")
			local killer = if tag and tag:IsA("ObjectValue") then tag.Value else nil
			local killerPlayer = if killer and killer:IsA("Player") then killer else nil
			local weapon = ""
			local tool = killerPlayer and killerPlayer.Character and killerPlayer.Character:FindFirstChildOfClass("Tool")
			if tool then
				weapon = tool.Name
			end
			killFeed:FireAllClients({
				killer = if killerPlayer and killerPlayer ~= player then killerPlayer.DisplayName else nil,
				killerId = if killerPlayer then killerPlayer.UserId else nil,
				victim = player.DisplayName,
				victimId = player.UserId,
				weapon = weapon,
			})
		end)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return HudService
