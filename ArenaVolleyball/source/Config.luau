-- ARENA VOLLEYBALL settings. Change a value, then press Play.
return {
	TEAM_SIZE = 2, -- players per side (1 to 4). Empty spots are played by AI.
	POINTS_TO_WIN = 15, -- points needed to win a set
	WIN_BY = 2,
	SETS_TO_WIN = 1, -- 1 = one set, 2 = best of three
	AI_LEVEL = 2, -- 1 rookie, 2 pro, 3 legend

	TEAM_NAMES = { "HOME", "AWAY" },
	TEAM_COLORS = { Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 96, 76) },

	-- The court is built here, on the ground below this point.
	COURT_CENTER = Vector3.new(0, 0, 90),

	-- Sizes in studs (roughly 3 studs to a metre)
	COURT_LENGTH = 54,
	COURT_WIDTH = 27,
	NET_HEIGHT = 7.5,

	GRAVITY = 48, -- ball gravity: lower is floatier
	BALL_RADIUS = 0.8,
	REACH = 6.5, -- how far from your body you can play the ball
	SERVE_TIME = 12, -- seconds before a serve is made for you
}
