--!strict
-- Match, movement, tank, health, camera and network tunables. Values are the GDD's starting specification
-- (Sections 03-06, 10.5). Change them here with a DECISIONS.md entry, never inside scripts.

local GameConfig = {
	ModeId = "color_control",
	ConfigVersion = 1,

	Match = {
		ServerCapacity = 8,
		TeamCap = 4,
		PublicMinimumReady = 4,
		CountdownSeconds = 20,
		FullLobbyCountdownSeconds = 5, -- remaining countdown shortened to this when 8 are ready
		LiveSeconds = 240,
		IntroSeconds = 3,
		ResultsSeconds = 10,
		IntermissionSeconds = 15,
		LoadingTimeoutSeconds = 30,
		BackfillMinimumRemainingSeconds = 60, -- join live only with MORE than this remaining
		VacancyGraceSeconds = 15,
		IdleUnreadySeconds = 60,
		FinalCueSeconds = 30,
		RespawnSeconds = 4,
	},

	Movement = {
		WalkSpeed = 16,
		FiringLightSpeed = 14,
		GlideSpeed = 26,
		GlideAccelerationSeconds = 0.15,
		NeutralCrouchSpeed = 10,
		EnemyPaintSpeed = 9,
		ClimbSpeed = 14,
		ChargingSpeed = 10,
		RollingSpeed = 12,
		BrushPushSpeed = 22,
		BoundaryHysteresisSeconds = 0.08,
		GlideExitToFireSeconds = 0.12,
		MaxClimbHeight = 12,
		JumpPower = 50,
		GlideJumpMomentumCap = 30,
		SurfaceProbeDepth = 4, -- studs below the root to look for the supporting cell
	},

	Tank = {
		Capacity = 100,
		LowWarning = 20,
		-- rate units/second, delay seconds after last paint-consuming action
		Refill = {
			OwnGlide = { Rate = 30, Delay = 0.35 },
			OwnStanding = { Rate = 12, Delay = 0.65 },
			OwnClimb = { Rate = 20, Delay = 0.35 },
			NeutralStanding = { Rate = 6, Delay = 1.25 },
			ProtectedBase = { Rate = 50, Delay = 0 },
		},
		DryCueMinInterval = 0.6,
	},

	Health = {
		Max = 100,
		RegenDelay = 3,
		RegenRate = 20,
	},

	Combat = {
		CapsuleHeight = 5.5,
		CapsuleRadius = 1.4,
		MaxRewindSeconds = 0.15,
		AssistMinimumDamage = 20,
		AssistWindowSeconds = 5,
		EnvironmentalCreditWindowSeconds = 5,
		SpawnShieldSeconds = 2,
		UltimateRetainOnDeath = 0.5,
		MaxActiveProjectiles = 128,
		MaxActiveThrowables = 32,
		MaxActiveStorms = 8,
		MaxActiveScreens = 8,
		DripMaxDepth = 6,
		HeldAimTimeoutSeconds = 0.5,
		MaxAimAge = 1.0, -- seconds; older client timestamps are rejected
		MaxFutureSkew = 0.25,
		MuzzleTolerance = 6, -- max studs between claimed origin and server muzzle estimate
	},

	Ultimate = {
		Max = 100,
		CellsPerPoint = 16,
		MaxGainPerSecond = 6,
		SameCellCreditCooldown = 5,
	},

	-- Preference persistence (GDD 11.6): bounded retries, debounced writes, bounded shutdown flush.
	Persistence = {
		ReadAttempts = 3,
		WriteAttempts = 3,
		RetryBackoffSeconds = 0.5, -- x attempt number
		SaveDebounceSeconds = 4,
		ShutdownFlushSeconds = 20,
	},

	Launch = {
		ChannelSeconds = 1.0,
		ChannelMaxMove = 1,
		RecentDamageBlockSeconds = 1.5,
		TransitSeconds = 1.0,
		LandingProtectionSeconds = 0.25,
		CooldownSeconds = 8,
		LandingSearchRadius = 6,
	},

	Camera = {
		Distance = 9,
		VerticalOffset = 2.5,
		RightOffset = 1.75,
		FieldOfView = 75,
		ChargerFocusFieldOfView = 55,
		MinDistance = 1.5,
		ReturnSpeed = 10,
	},

	Paint = {
		CellSize = 1,
		ChunkSize = 16,
		DeltaRateHz = 10,
		MaxScoringCells = 50000,
		MaxWallCells = 16000,
		MaxPatches = 96,
		SnapshotBudgetBytes = 160 * 1024,
		SnapshotChunksPerMessage = 64,
		SnapshotReplayBufferMax = 4096, -- buffered delta messages before a snapshot restarts
		ResyncMinInterval = 1.0,
		PredictionTimeout = 0.5,
		MinimapRefreshHz = 5,
		SurfaceOffset = 0.03, -- render offset above the surface, studs
		PlaneTolerance = 0.6, -- max |distance| from a patch plane for an impact to belong to it
		TrailSampleSpacingFactor = 0.5, -- sample spacing = footprint radius * factor
		MaxTrailStepPerSecond = 40, -- studs/s; larger steps are treated as teleports and not painted
	},

	Net = {
		ActionRequestsPerSecond = 40,
		ReadyRequestsPerSecond = 4,
		LoadoutRequestsPerSecond = 4,
		SettingsRequestsPerSecond = 4,
		ResyncRequestsPerSecond = 2,
		LaunchRequestsPerSecond = 4,
		HeldAimUpdatesPerSecond = 30,
		MaxPayloadKeys = 16,
		MaxStringLength = 64,
	},

	Teams = {
		A = { Id = 1, Key = "A", DisplayName = "Team A" },
		B = { Id = 2, Key = "B", DisplayName = "Team B" },
	},

	Owner = {
		Neutral = 0,
		A = 1,
		B = 2,
	},
}

return table.freeze(GameConfig)
