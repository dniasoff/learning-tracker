import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { allocateGroupTask } from '../lib/group_task_allocator.js';
import { groupTaskCurriculumIds, listGroupTaskScopes, resolveGroupTaskUnits } from '../lib/group_task_catalog.js';

const member = (memberId, rankedRefs = [], capacityPerStudyDay = 10, studyDays = [1, 2, 3, 4, 5, 6, 7], paceUnit = 'mishna', workloadPerPaceUnit = 1) => ({
  memberId, rankedRefs, paceUnit, capacityPerStudyDay, workloadPerPaceUnit, studyDays,
});
const unit = (ref, weight, children = [], level = 'masechta') => ({ id: ref, ref, label: ref, level, weight, children });
const allocate = (units, members, deadline = '2026-11-20') => allocateGroupTask({
  taskId: 'task-stable', units, members, startDate: '2026-11-11', deadline,
});
const ownedRefs = (plan) => plan.members.flatMap((entry) => entry.units.map((item) => item.ref));

describe('deterministic whole-unit group allocation', () => {
  test('uses canonical Mishnayos weights and perakim from the content hierarchy', () => {
    const scopes = listGroupTaskScopes('mishnayos');
    const kelim = scopes.find((scope) => scope.ref === 'Mishnah Kelim');
    const tamid = scopes.find((scope) => scope.ref === 'Mishnah Tamid');
    assert.ok(kelim && tamid);
    assert.ok(kelim.weight > tamid.weight);
    const selected = resolveGroupTaskUnits('mishnayos', ['Mishnah Kelim']);
    assert.equal(selected.length, 1);
    assert.equal(selected[0].children.length, 30);
    assert.equal(selected[0].children.reduce((sum, perek) => sum + perek.weight, 0), kelim.weight);
  });

  test('offers only supported canonical curricula and excludes the weekly Shnayim Mikra cycle', () => {
    const curricula = groupTaskCurriculumIds();
    assert.ok(curricula.includes('tanach'));
    assert.ok(curricula.includes('chumash'));
    assert.ok(curricula.includes('nach'));
    assert.ok(!curricula.includes('shnayim_mikra'));
    assert.ok(!curricula.includes('arukh_hashulchan'));
  });

  test('maps Tanach to Chumash and Nach categories with sefarim as whole units and perakim below', () => {
    const scopes = listGroupTaskScopes('tanach');
    assert.deepEqual(scopes.slice(0, 2).map((scope) => scope.ref), ['Chumash', 'Nach']);
    const chumash = resolveGroupTaskUnits('tanach', ['Chumash']);
    const nach = resolveGroupTaskUnits('tanach', ['Nach']);
    const selectedSefer = resolveGroupTaskUnits('tanach', ['Genesis']);
    assert.equal(chumash.length, 5);
    assert.ok(chumash.every((sefer) => sefer.level === 'sefer' && sefer.children.length > 0));
    assert.ok(nach.length > 0 && nach.every((sefer) => sefer.level === 'sefer'));
    assert.equal(selectedSefer.length, 1);
    assert.equal(selectedSefer[0].ref, 'Genesis');
    assert.ok(selectedSefer[0].children.every((perek) => perek.level === 'chapter'));
  });

  test('represents terminal daf refs as atomic children so Yerushalmi masechtos can split at daf', () => {
    const daf = listGroupTaskScopes('yerushalmi').find((scope) => scope.ref === 'Jerusalem Talmud Berakhot');
    assert.ok(daf);
    const masechta = resolveGroupTaskUnits('yerushalmi', [daf.ref])[0];
    assert.ok(masechta.children.length > 0);
    assert.ok(masechta.children.every((item) => item.level === 'daf' && item.children.length === 0));
  });

  test('splits a heavy masechta into perakim only when needed to balance uneven units', () => {
    const kelim = unit('Mishnah Kelim', 10, [
      unit('Mishnah Kelim 1', 5), unit('Mishnah Kelim 2', 5),
    ]);
    const short = [unit('Mishnah Tamid', 3), unit('Mishnah Middot', 3)];
    const plan = allocate([kelim, ...short], [member('a'), member('b')]);
    assert.equal(plan.feasible, true);
    assert.deepEqual(ownedRefs(plan).sort(), ['Mishnah Kelim 1', 'Mishnah Kelim 2', 'Mishnah Middot', 'Mishnah Tamid']);
    assert.deepEqual(plan.members.map((entry) => entry.workload).sort((a, b) => a - b), [8, 8]);
    assert.equal(new Set(ownedRefs(plan)).size, 4);
  });

  test('never splits below a perek even when its leaf workload is still above the target', () => {
    const heavyPerek = unit('Kelim 1', 12, [unit('Kelim 1 mishna 1', 6, [], 'mishna'), unit('Kelim 1 mishna 2', 6, [], 'mishna')], 'perek');
    const plan = allocate([unit('Kelim', 13, [heavyPerek, unit('Kelim 2', 1, [], 'perek')])], [member('a'), member('b'), member('c')]);
    const assigned = plan.members.flatMap((entry) => entry.units);
    assert.ok(assigned.some((item) => item.ref === 'Kelim 1'));
    assert.ok(assigned.every((item) => item.level !== 'mishna'));
  });

  test('keeps balanced masechtos whole', () => {
    const plan = allocate([unit('Mishnah Berakhot', 4, [unit('Mishnah Berakhot 1', 2), unit('Mishnah Berakhot 2', 2)]),
      unit('Mishnah Peah', 4, [unit('Mishnah Peah 1', 2), unit('Mishnah Peah 2', 2)])], [member('a'), member('b')]);
    assert.deepEqual(ownedRefs(plan).sort(), ['Mishnah Berakhot', 'Mishnah Peah']);
  });

  test('handles more accepted members than available units without duplicate ownership', () => {
    const plan = allocate([unit('A', 1), unit('B', 1)], [member('a'), member('b'), member('c'), member('d')]);
    assert.equal(plan.feasible, true);
    assert.equal(ownedRefs(plan).length, 2);
    assert.equal(new Set(ownedRefs(plan)).size, 2);
    assert.equal(plan.members.filter((entry) => entry.units.length === 0).length, 2);
  });

  test('reports deadline capacity shortfall and leaves every unit unassigned when infeasible', () => {
    const plan = allocate([unit('A', 2), unit('B', 4)], [member('a', [], 2, [3])], '2026-11-11');
    assert.equal(plan.feasible, false);
    assert.equal(plan.shortfall, 4);
    assert.equal(plan.members[0].capacity, 2);
    assert.equal(plan.members[0].workload, 2);
    assert.equal(plan.unassignedRefs.length, 1);
  });

  test('uses preference rank, then stable member id for ties, and is repeatable', () => {
    const units = [unit('A', 2), unit('B', 2)];
    const members = [member('z', ['A', 'B']), member('a', ['A', 'B'])];
    const first = allocate(units, members);
    const second = allocate(units, members);
    assert.deepEqual(first, second);
    assert.deepEqual(first.members.find((entry) => entry.memberId === 'a').units.map((item) => item.ref), ['A']);
    assert.deepEqual(first.members.find((entry) => entry.memberId === 'z').units.map((item) => item.ref), ['B']);
  });

  test('builds deterministic daily tasks within selected study days', () => {
    const plan = allocate([unit('Mishnah Shabbat', 4, [unit('Mishnah Shabbat 1', 2), unit('Mishnah Shabbat 2', 2)])],
      [member('a', [], 2, [3, 5])], '2026-11-13');
    assert.equal(plan.feasible, true);
    assert.deepEqual(plan.members[0].dailyTasks.map((task) => task.date), ['2026-11-11', '2026-11-13']);
    assert.deepEqual(plan.members[0].dailyTasks.map((task) => task.refs), [['Mishnah Shabbat 1'], ['Mishnah Shabbat 2']]);
  });

  test('reports the daily amount in the selected coarse pace unit', () => {
    const plan = allocate([unit('Mishnah Shabbat', 4, [unit('Mishnah Shabbat 1', 2), unit('Mishnah Shabbat 2', 2)])],
      [member('a', [], 1, [3, 5], 'perek', 2)], '2026-11-13');
    assert.equal(plan.feasible, true);
    assert.deepEqual(plan.members[0].dailyTasks.map((task) => task.paceAmount), [1, 1]);
    assert.equal(plan.members[0].capacityInPaceUnits, 2);
  });

  test('rejects malformed or duplicate unit scopes', () => {
    assert.throws(() => allocate([unit('A', 1), unit('A', 1)], [member('a')]), /unique refs/);
    assert.throws(() => allocate([unit('A', 1)], [member('a', [], 0)]), /capacity is invalid/);
  });
});
