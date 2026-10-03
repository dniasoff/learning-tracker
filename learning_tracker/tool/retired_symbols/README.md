# Retired-symbols inventory (AD-49)

This directory holds the data for `tool/check_retired_symbols.dart`, the AD-49 cutover gate. DNI-521 created the checker, and no other story changes it. Retirement stories edit only the JSON files here.

- `R1.json` … `R16.json`: one file per Retirement Inventory group in `docs/planning/architecture/architecture-sub-tracks-2026-09-30/ARCHITECTURE-SPINE.md`. Each entry has its own line: `{symbol, kind, state, owner, paths?, match?, note?}`.
- `allowlist.json`: the exact AD-49 cutover remnants as `{symbol, path, count, reason}`. DNI-490 filled it with the five deny-all `firestore.rules` matches and the `streak_events` and `learning_order` indexes, and DNI-491 empties it again.

## Contract for retirement stories

1. Delete the code.
2. Set your own entries (`owner` = your story) in your group's file to `"state": "retired"`. A retired symbol that is still referenced outside the allowlist fails `make audit` (check 105) and CI.
3. If you find a retired symbol that is not listed, add it with your story as `owner`. Never edit another story's entry.
4. When a shared symbol needs a different owner in a different part of the tree, add a second entry with a different `paths` scope. For an example, see `completions`: R1 covers `lib/`, R12 covers `functions/src/`, and R14 covers the rules, indexes and `deletes.ts` remnants.

`pending` entries are reported and never fail the gate in the default mode. `--enforce` treats every entry as retired and requires the allowlist to match exactly. Since the cutover release (DNI-490), CI, `make ci` and `make audit` run with `--enforce`, so a `pending` entry fails as soon as it has a hit outside the allowlist. The R14 entries stay `pending` only so that `tool/check_retired_test_references.dart` keeps accepting test names for the retired collections; their remnants are the allowlist.

Run `dart run tool/check_retired_symbols.dart --report` to list every current hit for each entry.
