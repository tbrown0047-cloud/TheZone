-- stand-ins for the server pieces the career code uses
Config.SEASON_ROUNDS = 11
local profiles = {}
local saving = true
local function sendProfile() end
local function saveProfile() end
local ensureCareerLater
local slotOfPlayer = {}
local teams = { { score = 0, sets = 0 }, { score = 0, sets = 0 } }
local lastSpec
local function beginMatch(spec) lastSpec = spec end
local remoteLog = {}
remote.FireClient = function(_, plr, kind, a) table.insert(remoteLog, kind) end
