# Red-demo — R8 Part A (Learn/aggregate all-curricula OOM)

**Gate:** `test/features/progress/presentation/providers/r8_oom_materialized_curricula_test.dart`
(counts DISTINCT curricula whose full content is materialized during ONE items-learned/lifetime-view aggregate computation, for a profile with completions in exactly 1 curriculum).
**Equivalence gate:** `test/features/content_browsing/data/repositories/content_repository_count_leaves_test.dart`
(`countLeavesForCurriculum(c) == getContentForCurriculum(c).where(isLeaf).length` for every `CurriculumId`, cold+warm).

**Seam:** `content_repository_impl.dart` `_contentCache` (permanent in-memory cache) + `items_learned_providers.dart` compute*Summary reorder.

**Red-demo (run on integrated dev):** with Part A, one aggregate for a 1-curriculum
(mussar) profile materializes **{mussar} (size 1)**. Reverting Part A → **all 9
curricula materialized** (the OOM path). Both directions captured from real code.

**Totals invariant proved:** the equivalence test pins every per-curriculum leaf
count; Part A only removes wasted "materialize-then-return-null" for curricula with
no completions (they returned null anyway). **No displayed total changed.**

**Scope:** Part A (fixes the common 1-track Learn crash). **Part B** — the header
`70,033 = |union(all leaf refs)|` denominator still materializes all 9; a
union-aware count path is the deferred follow-up (a naive per-curriculum count-sum
= 93,395 would change the total — explicitly NOT done).
