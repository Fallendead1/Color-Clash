-- String table (GDD 12.3: text lives in a string table, not scattered through controllers).
-- Codex may restyle text but should keep meaning; controllers format with string.format.

return table.freeze({
	Title = "COLOR CLASH",
	OnboardingLines = {
		"Paint the floor.",
		"Glide in your color to move and refill.",
		"Own more floor when time ends.",
	},
	Play = "Play",
	Ready = "Ready",
	Unready = "Unready",
	Armory = "Armory",
	Controls = "Controls",
	Settings = "Settings",
	Close = "Close",
	Equip = "Equip",
	Equipped = "Equipped",
	Retry = "Retry",
	Back = "Back",
	Dismiss = "Got it",

	StatusWaiting = "Waiting for players: %d/%d ready",
	StatusCountdown = "Match starts in %d — %d ready",
	StatusLoading = "Loading the next match…",
	StatusLive = "Match in progress (%s left) — ready up to join",
	StatusLiveClosed = "Match in progress — you will join the next round",
	StatusResults = "Results",
	StatusIntermission = "Next round soon — change your kit now",
	StatusPaused = "Waiting for players to return…",
	StatusSoloFixture = "Solo practice on the engineering fixture",

	LoadingStages = {
		Remotes = "Connecting",
		Map = "Receiving map",
		Paint = "Syncing paint",
		Ready = "Ready",
	},
	LoadingFailed = "Couldn't load the match. %s",

	KitLocked = "Kits are locked during your match",
	KitUnknown = "That kit is not available",
	KitSelected = "Equipped %s",
	KitPending = "Equipping…",

	Eliminated = "Eliminated",
	EliminatedBy = "Eliminated by %s (%s)",
	EliminatedEnv = "Eliminated",
	Respawn = "Back in %d",
	BaseShieldHint = "Protected base: you can't shoot out of it. Leave to attack.",

	OutcomeWin = "%s wins",
	OutcomeDraw = "Draw",
	OutcomeNoContest = "Round ended — not enough players",
	CoverageLine = "%s  ·  %s  ·  neutral %s",
	ScoreboardHeader = "Paint Contribution (floor you converted — not final area, not the winner) · E · A · D",
	ScoreboardRow = "%s   %d   ·   %d / %d / %d",
	ContributionTooltip = "Paint Contribution counts floor you converted during the match. It can exceed the final area because floor gets reclaimed. It does not decide the winner.",

	LowPaint = "Low paint",
	DryFire = "Out of paint",
	BlockedShot = "Blocked",
	ShieldHit = "Shielded",
	UltimateReady = "Ultimate ready",
	FinalCue = "30 seconds left",

	NoticeIdleUnready = "You were set to Unready after 60 s idle",
	NoticeBackfillClosed = "Less than a minute left — you'll join the next round",
	NoticeMatchFull = "The match is full — you'll join the next round",
	NoticeVacancy = "A team is empty — play paused (15 s)",
	NoticeLoadingFailed = "Match loading failed — returning to staging",
	NoticeSaveFailed = "Settings couldn't be saved; they'll apply this session",
	NoticePrefsUnavailable = "Saved settings couldn't be loaded — using defaults this session",
	NoticeConnection = "Connection delayed",

	TeamNames = { [1] = "Team A", [2] = "Team B" },
})
