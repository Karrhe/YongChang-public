# QA batch 1 · 《永昌堡·守潮》

Build `v0.2.0-playtest` at `c1f98ccf24d405c3c9070ee5c768b7cd5dcf0a82`. Tested on macOS with Godot `4.7.2.stable.official.ed1daf0bf`. Scope follows TEAM-001 QA. ISSUE-001 IDs below identify previously tracked items.

## Existing headless suite

Run from the project root after importing assets with `--headless --editor --import`. Each scene ran in a separate Godot process. The table records the exact verdict and exit diagnostics from the first run.

| Scene under `tests/` | Exit | Exact test verdict | Checks | Exit diagnostics |
|---|---:|---|---:|---|
| `smoke_test.tscn` | 0 | `SMOKE TEST: PASS` | 25 | None |
| `flow/flow_test.tscn` | 0 | `FLOW TEST: PASS` | 99 | 6 ObjectDB instances, 1 resource |
| `story/story_test.tscn` | 0 | `STORY TEST: PASS` | 61 | None |
| `flow/flow3_test.tscn` | 0 | `FLOW3 TEST: PASS` | 55 | None |
| `ending/ending_test.tscn` | 0 | `ENDING TEST: PASS` | 33 | 4 ObjectDB instances, 1 resource |
| `battle/battle_test.tscn` | 0 | `BATTLE TEST: PASS` | 74 | 11 ObjectDB instances, 3 resources |
| `work/work_test.tscn` | 0 | `WORK TEST: PASS` | 37 | None |
| `flow/playthrough_test.tscn` | 0 | `PLAYTHROUGH TEST: PASS` | 5 | 6 ObjectDB instances, 2 resources |

The first clean import printed missing cached resources for the UI button texture and font while loading the theme. The import generated both assets, the eight scenes ran successfully, and the next import emitted no errors. All eight suites and the independent probe passed in the final recheck. The raw first-run logs, including the initial import and its rerun, are in [evidence](evidence/).

## Independent checks

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --editor --import
"$GODOT" --headless --path . res://tests/qa/batch1_probe.tscn
```

The probe uses a process-specific test save and deletes it on completion. Its exact verdict is `QA BATCH 1 PROBE: PASS`. Observations used for the issue list are printed alongside the assertions. See [probe output](evidence/probe.log).

- **重打.** Played B1 twice in the real battle scene using its autoplay controls. Both attempts displayed Accept and Retry and returned the same result, `costly`, with 3 villagers saved and 0 villagers or defenders lost. Injected fatal results through the real B7 and B8 scenes' completion signals to exercise forced Retry deterministically. In all three battles, Retry reopened a fresh turn-one scene with identical input. The pending result left the autosave byte-for-byte unchanged and added no result or lanterns. Reload resumed at the battle start.
- **Conditional dialogue.** Checked all 38 conditional rows in the production CSV in three survival states, for 114 evaluations. The states were hero alive, hero dead with companion alive, and both dead. All five condition labels selected the expected rows. The existing story suite separately covers death-stage fixtures. The production CSV contains no `DEATH_Bn` condition rows.
- **G2-6.** Opened all four variants through the real Flow and Story scenes with each first-generation survival state. All 12 cases selected the expected key and loaded dialogue without missing-text placeholders. The probe log records the exact line IDs. The four-way routing works. The dialogue content findings are below.
- **STO-15.** E3 created visible-label nodes containing the first villager and defender names for each generation, the custom third-generation hero name, and the first generated overflow name `王老大`. None of the 17 labels showed `无名`. This verifies newly generated names in the tagged build. Legacy save migration and total fallback-name exhaustion were outside this pass.

## Issue list

Severity totals are **0 blocker, 2 high, 2 medium, 1 low**. High covers narrative continuity contradictions and medium covers presentation consistency or balance follow-up.

| ID | Severity | Reproduction | Expected | Actual and evidence |
|---|---|---|---|---|
| QA-001 (STO-01) | High | Accept a second-generation hero death at B4, then accept 周砚's death while he is the substitute at B5 or B6. Reach G2-6. The probe applies B4/B5 results through `FlowLogic.apply_battle` and opens the actual dialogue scene. | A surviving speaker or narration covers the scene. | Both second-generation survival flags are false. `G2-6_B_unmet/02` still has 周砚 speak, and `G2-6_B_met/01–02` also depicts him repairing the wall and speaking. |
| QA-002 (STO-03) | High | Accept B5 with the second-generation hero alive and read the first line of G2-4. | The dialogue identifies B5's south gate. | `G2-4_A/01` says `西门守住了，换粮的路却断了。` B5 uses map B in `data/rules/battle.json`, and `WORK_MAP_B` in `data/text/work.csv` labels it `村道 / 南门`. |
| QA-003 | Medium | Give the second-generation hero a custom name at T1. Keep 王成 alive, accept the second-generation hero's death, and reach either G2-6 B variant. | 王成's memorial line uses the chosen name. | With `测试石娘` in the probe, line `05` in both B variants says `也给阿囡写一盏。` Both CSV rows hardcode the default name. The alternate 阿棠 lines use `{名2}`. |
| QA-004 (BAT-08) | Medium | Run the tagged playthrough scene using its default stationary attacks and end-turn policy, farming assignments, and B choices. | Playtest follow-up should establish which scenarios require movement or tactical changes to hold. | B2–B9 all returned `held` with this policy. B1 returned `costly` and B9 cost the third-generation protagonist. This is a balance signal from one scripted route. See the numeric note below. |
| QA-005 | Low | Run the exiting headless scenes in the suite table. | Godot exits without leaked-object or resource-in-use diagnostics. | The first run printed `WARNING: … ObjectDB instances were leaked at exit (run with --verbose for details).` and `ERROR: … resources still in use at exit (run with --verbose for details).` after PASS in Flow, Ending, Battle, and Playthrough. Exact counts and lines are in the logs. Player-facing impact was unverified. |

## Numeric playtest

The scripted run completed in 467 steps and 3.7 seconds. It reached the ending with all nine battles accepted and all five choices made. Eight of nine battles held. B1 was costly. End state was **population 4, grain 72, materials 7, and 8 lanterns** (4 villagers, 3 defenders, 1 protagonist or companion). All companions survived. The first two protagonists survived and the third fell in B9, the only third-generation battle where the flow allows an accepted protagonist death.

Population finished at the configured floor of 4 while the all-farming route still banked 72 grain, matching the latest WORK-10 baseline. This run provides no comparison with mixed labor assignments and does not establish the value of switching off farming. The combination is worth comparing across labor strategies and on manually played battles.

## Coverage limits

The pass used headless scenes and deterministic save/result fixtures for rare branches. Manual mouse play, audio quality, visual layout, and the exported Windows executable were outside this pass.
