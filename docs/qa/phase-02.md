# Phase 02 — Prove painting before adding content

```text
Phase ID / title: 02 — Prove painting before adding content
Status: PASS_CODE (desktop Studio). Mobile renderer budget: BLOCKED (no physical device). Live EditableImage path:
        not used (API disabled for the experience; native renderer qualified per GDD 10.4, D-004).
Project / place / branch: C:\Color-Clash / Color Clash (130101797221207) / main
Implementation completed:
  - PaintGrid (pure): surface manifests, masks, 1-stud cells, owner transitions, incremental counts, sphere/rect stamps
    with injected occlusion, 16x16 chunks, versioned full-chunk payloads, snapshots, hash
  - MapLoader: collision-derived masks (overlap probe), stacked-scoring rejection, budgets
  - PaintService: real raycast occlusion (map geometry + enemy screens), 10 Hz deltas, chunked snapshots,
    late join, bounded resync (1/s server + 2 s client guard), sync ack gating, freeze, clear, hash acks
  - Client PaintClient mirror: match/map filtering, version-ordered apply, gap detection -> resync, freeze lock
  - NativeRenderer (IPaintRenderer): greedy per-chunk rectangles, pooled parts, frame-budgeted sliced building
    with atomic chunk swap, palette recolour, prediction overlay with deny/expiry
Tests executed (actual invocations, Studio Play solo, dev desktop):
  engine:PaintEngine (fixture geometry) ............ 10/10  PAINT-01..07 at engine level
  client:PaintRender (after PaintEngine) ........... 5/5    NET-01 hash convergence; PAINT-08 fixture: rendered owner ==
                                                           authoritative owner at ALL 6,412 legal cells; PAINT-09;
                                                           PAINT-12 denied prediction removed < 0.5 s; expiry
  engine:PaintSync (real client in loop) ........... 5/5    NET-01 late join; NET-02 gap -> exactly one bounded resync ->
                                                           exact state; PAINT-10 forged newer delta after freeze ignored
                                                           (client frozen hash == server); PAINT-11/NET-03 reset during
                                                           pending snapshot discards old match, new match converges
  perf:PaintStress + client:PerfPaintStress ........ 2/2 + 3/3  (see measurements)
  perf:PaintRealistic + client:PerfPaintStress ..... 1/1 + 3/3
  Full suites same session: engine 30/30, unit (Studio VM) 53/53, client UIInput 8/8; Lune unit 53/53
Measurements (Studio 0.740.19, dev desktop, server + client + editor in ONE process; not a reference device):
  Frame-time p95 baseline, no paint parts ............ 17.86-17.99 ms (environment baseline)
  Worst case: stress_lab 65,960 cells (49,960 scoring + 16,000 wall), full alternating checkerboard
    server: map load+validation 307 ms; pattern write 16 ms; flush 4.2 ms; one delta 23,694 bytes (< 40 KiB)
    client: 65,960 parts; fully rendered in 4.3 s over 259 frames; frame p95 while rendering 18.28 ms, worst 21.05 ms;
            steady p95 17.98 ms (= baseline); renderer work worst frame 6.67 ms (before slicing fix);
            memory +119 MB; 9,422 sampled cells 0 mismatches
  Realistic heavy: 2,400 overlapping splats r 1.5-6 from both teams in ~1 s to 90% coverage
    client: 5,924 parts; renderer work p95 3.41 ms / max 3.59 ms with a 3.0 ms budget (budget then lowered to
            2.5 ms); steady p95 17.96 ms (= baseline); memory +4 MB; largest delta 5,838 bytes
Defects found and fixes:
  - renderer meshed a whole chunk per step (6.67 ms spikes) -> sliced part preparation + atomic swap
  - renderer p95 slightly over 3 ms under burst -> per-frame budget 2.5 ms
  - stress spec measured after render finished -> client spec starts first; baseline captured
  - weak NET-02 rate assertion -> exact "one resync" assertion
Unrun tests or external blockers:
  - Two-client paint/repaint/late-join/reset: BLOCKED for real multi-client (MCP starts solo Play only). The single
    real client was exercised as a late joiner, through gap resync, freeze and reset. Re-run with 2 clients when a
    multi-client route exists.
  - Renderer p95 on reference mobile (GDD target <= 3 ms): BLOCKED (no device). Desktop numbers above only.
  - Published live-context renderer check: native parts need no live-only API; publishing not authorised.
Next automatic step: Phase 03
```

## Renderer qualification summary (GDD 10.4)

- Accuracy: 100% of legal fixture cells and 9,422 sampled budget cells render the authoritative owner. Opposing colours
  are never merged and cells are never dropped (every legal owned cell is covered by exactly one rectangle).
- Bounds: parts ≤ owned cells ≤ 66,000 at map budget; realistic heavy play ≈ 6k parts; pool reuse; per-frame work
  budgeted (2.5 ms) with no visual tearing (atomic chunk swap).
- Dependency: no live-only API; works in Studio and published contexts alike.
- Risk carried forward: the adversarial full-map checkerboard costs ~120 MB and 66k parts. It stays correct and does
  not hitch on desktop, but mobile headroom is unmeasured. If device testing fails, the fallback is the preferred
  EditableImage atlas behind the same IPaintRenderer, which needs the owner to enable the API in Experience Settings.
