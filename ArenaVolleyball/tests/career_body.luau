
---------------------------------------------------------------- two career seasons (appended after the career code)
matchActive = false
local plr = { DisplayName = "Tester", UserId = 1, Parent = true }
profiles[plr] = { custom = { number = 9, wearKit = true, kits = {} } }
Career.createCareer(plr, { club = 5, role = "OH", number = 9 })
local c = profiles[plr].career
for season = 1, 2 do
	local guard = 0
	local startSeason = c.season
	while c.season == startSeason and guard < 20 do
		guard += 1
		Career.startCareerMatch(plr)
		assert(lastSpec and lastSpec.away, "no opponent")
		local won = rng:NextNumber() < 0.65
		teams[1].score, teams[2].score = won and 25 or 20, won and 21 or 25
		teams[1].sets, teams[2].sets = won and 1 or 0, won and 0 or 1
		Career.finishCareerMatch(plr, { won = won, stats = { kills = rng:NextInteger(0, 9), aces = rng:NextInteger(0, 3), blocks = rng:NextInteger(0, 3), digs = rng:NextInteger(0, 6) } }, lastSpec)
	end
	print(string.format("season %d done after %d matches: level %d, ovr %d, status %s, money %d, trophies %d, inbox %d, phase now %s round %d", startSeason, guard, c.level, c.ovr, c.status, c.money, c.trophies, #c.inbox, c.phase, c.round))
	-- accept the first open offer, if any
	for _, item in c.inbox do
		if item.offer and not item.answered then
			Career.answerOffer(plr, { id = item.offer.id, accept = true })
			print("  moved to " .. Teams.list[c.club].name .. " as " .. c.status)
			break
		end
	end
end
Career.setFocus(plr, "SRV")
c.money = 5000
Career.trainingCamp(plr)
print("history seasons " .. #c.history .. ", awards " .. #c.awards .. ", SRV progress " .. c.progress.SRV)
for i = 1, 6 do print("  inbox: " .. c.inbox[i].title) end
