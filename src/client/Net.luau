-- Client side of the inventory remotes: holds the latest state snapshot from
-- the server and fires Changed whenever it updates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.state = nil :: any
local changed = Instance.new("BindableEvent")
Net.Changed = changed.Event

local remotes: Folder

function Net.Start()
	remotes = ReplicatedStorage:WaitForChild("InventoryRemotes") :: Folder
	local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
	stateEvent.OnClientEvent:Connect(function(state)
		Net.state = state
		changed:Fire(state)
	end)

	local getState = remotes:WaitForChild("GetState") :: RemoteFunction
	local ok, state = pcall(function()
		return getState:InvokeServer()
	end)
	if ok and state then
		Net.state = state
		changed:Fire(state)
	end
end

-- Returns (ok, message?, extra?) from the server's handler.
function Net.Action(name: string, ...: any): (boolean, string?, any)
	local action = remotes and remotes:FindFirstChild("Action") :: RemoteFunction?
	if not action then
		return false, "Not connected"
	end
	local args = table.pack(...)
	local ok, success, message, extra = pcall(function()
		return action:InvokeServer(name, table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "Connection error"
	end
	return success == true, message, extra
end

return Net
