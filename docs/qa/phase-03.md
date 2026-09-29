# Phase 03 — Movement, camera, paint tank and survivability

```text
Phase ID / title: 03 — Movement, camera, paint tank and survivability
Status: PASS_CODE (desktop Studio, keyboard/mouse). UI-02 real multi-touch: BLOCKED (no touch injection / device).
        MOVE-06 and MOVE-08 depend on weapons: moved to Phase 05.
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  client: CameraController (shoulder cam 9/2.5/1.75/75°, spherecast collision with smooth return, shoulder swap,
          sensitivity/invert-Y, continuous control in every state, muzzle-vs-aim ray with blocked indicator, touch
          look that ignores touches starting on buttons); MovementController (explicit states, mirror ground with
          0.08 s hysteresis, glide 0.15 s ramp, crouch on neutral, enemy 9, fire exits glide, Paint Climb with
          two-sample own-paint contact, lost-paint detach + 0.5 s re-grab cooldown, clearance-tested mantle limited to
          wall-top height, jump detach, move-state reports); HudController (paint/health/ultimate/gadget/kit/shield,
          low-paint callout, elimination countdown); TouchController (held touch buttons -> semantic actions)
  server: validated move-state attribute for presentation; orientation-independent climb validation (geometric,
          two samples, own colour); no-flying correction; refill using validated state; regen; spawn shield;
          out-of-bounds elimination
  dev: MatchHarness (solo live match, placement, paint helpers), harness specs (MatchSetup/Teardown/Place),
       RoundService.devEndLiveNow (dev-gated)
Tests executed (Studio Play solo, fixture, "solo practice (dev override)"):
  engine:Movement (server) .................. 11/11
    shield blocks then offensive action removes it; MOVE-05 own 12/s after .65 s, own glide 30/s after .35 s,
    neutral 6/s after 1.25 s, enemy 0 (even gliding), base 50/s immediate capped 100; MOVE-09 regen waits 3 s then
    20/s, new damage restarts delay; climb legal only on own-colour climbable wall; OOB elimination + respawn
  client:ManualMoveStrips (REAL keyboard: Shift+W) ... PASS
    Own glide WalkSpeed 26 (44/44 stable samples), measured 26.0 studs/s; Neutral crouch 10 (measured 10.0);
    Enemy 9 (measured 9.0); camera pitch change mid-glide
  client:ManualMoveClimb hostile (REAL keyboard) ..... PASS — detach reason lostPaint while keys held; max root
    y 104.6 (own rows end at 104); no stuck climb; CAM-02 yaw change mid-climb
  client:ManualMoveClimb mantle (REAL keyboard) ...... PASS — detach reason mantled; stood on platform top
  client:ManualMoveClimb blocked (REAL keyboard) ..... PASS — held at edge (mantle refused by clearance), max x -7.4,
    never on platform, safe drop on Glide release
  client:ManualMoveFireGlide (REAL keyboard) ......... PASS — glide exit after noted fire: 0.000003 s (<0.12 s)
  client:ManualCamChecks ............................. 3/3 — CAM-03 near-wall pull-in with camera outside geometry;
    CAM-03 shoulder swap flips side; CAM-01 blocked muzzle detected while the camera sees past, clears after
  client:ManualHeldOnDeath ........................... PASS — MOVE-07 held Primary/Glide released on elimination and
    absent in the new life
  Regression (fresh session): engine 41/41, unit 53/53 (Studio VM), client all 8/8; Lune 53/53; verify.ps1 PASSED
Defects found and fixed (all found by these tests):
  1. Server climb validation used root facing (client rotates root to camera) -> geometric validation
  2. Climb input fell back to world-space MoveDirection -> inverted up/down -> camera-relative conversion
  3. Hold at hostile paint boundary instead of detaching -> contact status own/notown/none, detach on notown
  4. Re-grab loop after lost-paint detach -> 0.5 s re-entry cooldown
  5. Mantle vaulted onto the top of an overhang (3 studs above the wall) -> landing restricted to wall-top window
  6. Camera MinDistance clamp pushed the camera into walls -> collision always wins
Test-harness limitation found:
  Studio MCP key injection is delivered only for the first injected sequence per Play session (observed 6 times).
  Samplers detect undelivered input and report "INPUT NOT DELIVERED" (inconclusive, never PASS). Each input-driven
  scenario runs in its own Play session.
Unrun tests or external blockers:
  UI-02 real multi-touch move+aim+fire+glide: BLOCKED (no touch injection, no device). Code path: touch buttons ->
    InputController.press; touch-look ignores processed touches.
  MOVE-06 (charge/roll/push vs refill) and MOVE-08 (dash/roll at low FPS): Phase 05 with the weapons.
  Gamepad stick look/move: NOT RUN (no gamepad injection verified).
Next automatic step: Phase 04 — Sprayline vertical slice
```
