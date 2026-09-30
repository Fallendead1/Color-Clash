# Phase 07 — Complete the player-facing loop

```text
Phase ID / title: 07 — Complete the player-facing loop
Status: PASS_CODE (wireframe, solo + real client, contract fixtures). Blocked/not run: real DataStore save path
  (Studio API access disabled), FLOW-13 reconnect mid-state and UI-09 reconnect variant (multi-client), physical
  touch/mobile devices.
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  maps: shared Config/MapManifest (switchyard, canopy_courts slots: footprint, base centres, order, tolerances);
    MapLoader: OutOfBounds scoring cells / spawns / climb tops rejected, manifest attributes (ExpectedScoringCells,
    ExpectedWallCells, ExpectedPatches) must match (required for production maps), validateSlot (slot id, footprint,
    centring, base centres, mirrored scoring parity); MapService: production rotation = one model per slot in
    manifest order, others skipped with a diagnostic; dev contract fixtures for both slots (DevGate ContractFixtures)
  persistence: shared Settings/Prefs (schema v1, whitelist, validation, repair, read-only newer schema, dirty-only
    merge); SettingsService rewritten: DataStore (studio/live scopes) or dev memory backend with failure injection,
    bounded retries, debounced writes, leave/shutdown flush, SettingsState status to the client, notices
  loadout: stored kit adopted when the profile arrives unless the player already chose one this session
  client: SettingsController (rows from Prefs, local application: sensitivity, invert, glide hold/toggle/auto,
    shoulder, palette on paint+effects, reduced effects, music/SFX SoundGroups; coalesced patches; save status),
    ScoreboardController (team grouping, contribution-first order, long-name truncation, live stats every 2 s),
    UIController.adopt/activate/onAdopted (production UI swap by keys), Cancel/B closes the top panel, deferred
    gamepad selection, touch rebinding on UI swap, connection-delay notice, onboarding follows the stored profile
Tests executed:
  engine 98/98 (11 specs, fresh session) incl. new MapContract 5/5 and Prefs 5/5
  perf:RoundSoak (FLOW-14): 20/20 rounds on alternating contract fixtures, 7 kits reselected, 0 problems,
    memory -0.5 MB, 0 hash mismatches, 0 handler errors
  client all 14/14 incl. UIPanels (UI-04, UI-05 at 6 viewports, UI-06, UI-08, UI-10, settings)
  client ManualModalDeath (UI-09, real client, live match): PASS
  unit 66/66 (Lune + Studio) incl. Prefs 5/5; verify.ps1 PASSED
Defects found and fixed:
  - Gamepad B (Cancel) was bound but closed nothing -> panels were not escapable without a mouse
  - Gamepad selection was assigned in the same frame a panel became visible -> rejected ("invalid GuiObject")
  - Touch Jump overlapped Fire at every viewport -> right-thumb cluster re-laid out
  - Touch bindings and settings rows would have stayed on the old UI after a production swap -> rebind on adopt
Unrun / blocked:
  - DATA-01 on the published DataStore path: BLOCKED (enable Game Settings > Security > Studio Access to API
    Services, or test in a published server)
  - FLOW-13, UI-09 reconnect: need a client joining mid-state (multi-client)
  - UI-02 / UI-05 on physical touch devices: BLOCKED (no device)
  - Optional practice context: not built (GDD marks it optional)
```

Decisions: D-012 (persistence policy; UI swap).
