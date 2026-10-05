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
	NET_HEIGHT = 8.7, -- 2.43 m (men's net). Use 7.9 for the women's 2.24 m net.

	GRAVITY = 35, -- 9.81 m/s²
	BALL_RADIUS = 0.42, -- a real ball is 0.38; a touch bigger so it's easy to follow
	REACH = 6.5, -- how far from your body you can play the ball
	SERVE_TIME = 8, -- seconds to serve (8 s, like the real rule) before one is made for you

	-- Your dive can play a marketplace emote you own instead of the built-in dive.
	-- Paste the emote's ID (the number in its catalog link); 0 uses the built-in dive.
	DIVE_EMOTE_ID = 87869019490136,
}
