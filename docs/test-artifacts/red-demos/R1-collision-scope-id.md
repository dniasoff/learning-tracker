# Red-demo — R1 child-data integrity (TEA-002 scope-id collision)

**Gate:** `test/features/progress/domain/services/lifetime_tree_builder_collision_property_test.dart`
(property sweep over all 9 `CurriculumId`s × collision levels 2/3/4, via `test/fixtures/collision_fixtures.dart`).

**Seam under test:** `lib/core/content/content_grouping.dart` → `scopeUnitIdentifier`
(ancestor-qualified scope id; the mark's `unitIdentifier` is built through this same seam, so a revert collapses write+read together).

**Red-demo (run on integrated dev):** reverted `scopeUnitIdentifier` cases 2/3/4 to
the naive BARE level key → **18/20 tests failed** with the authentic over-count:

```
bavli L3: credits only the targeted parent
  Expected: {'bavli|A|2|leaf0', 'bavli|A|2|leaf1'}
  Actual:   {'bavli|A|2|leaf0','bavli|A|2|leaf1', 'bavli|B|2|leaf0','bavli|B|2|leaf1'}
```

Restored the fix → **20/20 green**. The guard is NOT inert: it catches the exact
class (a mark on one parent crediting a sibling parent's same-id child) across every
curriculum. Adversarial verifier independently reproduced both directions
(seam-revert → over-count; read-side revert → under-credit).
