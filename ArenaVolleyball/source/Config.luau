-- ARENA VOLLEYBALL settings. Change a value, then press Play.
-- Sizes use Roblox's scale of 1 stud = 0.28 m, so the court matches a real one.
return {
	TEAM_SIZE = 6, -- players per side (1 to 6). Empty spots are played by AI. 6 uses real rotations.
	POINTS_TO_WIN = 25, -- points needed to win a set
	WIN_BY = 2,
	SETS_TO_WIN = 1, -- 1 = one set, 2 = best of three, 3 = best of five

	-- The court is built here, on the ground below this point.
	COURT_CENTER = Vector3.new(0, 0, 110),

	-- Real dimensions in studs
	COURT_LENGTH = 64, -- 18 m
	COURT_WIDTH = 32, -- 9 m
	NET_HEIGHT = 10, -- taller than a real net (8.7) so it looks right next to Roblox players

	GRAVITY = 35, -- 9.81 m/s²
	BALL_RADIUS = 0.42, -- a real ball is 0.38; a touch bigger so it's easy to follow
	REACH = 6.5, -- how far from your body you can play the ball
	SERVE_TIME = 8, -- seconds to serve (8 s, like the real rule) before one is made for you

	-- Your own animations: paste an animation ID for any move (0 uses the built-in pose).
	-- Upload them to the same account or group that owns the game, or Roblox won't play them.
	ANIMATIONS = {
		serve = 0,
		jumpserve = 0,
		bump = 0,
		set = 0,
		spike = 0,
		tip = 0,
		block = 0,
		dive = 0,
	},

	-- Sound IDs (0 = silent): ball contact, spikes, the whistle after a point, crowd cheer
	SOUNDS = { hit = 0, spike = 0, whistle = 0, crowd = 0 },

	-- Every player (AI and people) walks, runs and idles with this animation bundle (0 = Roblox's own)
	ANIMATION_PACK = 10739370185157, -- Garry's Animation Pack

	SUBS_PER_SET = 6, -- substitutions each team may make in a set (the libero doesn't count)
	ABILITY_CHARGE = 1, -- how fast ability meters fill (2 = twice as fast)
	SEASON_ROUNDS = 11, -- career league: every club plays each other once
}
