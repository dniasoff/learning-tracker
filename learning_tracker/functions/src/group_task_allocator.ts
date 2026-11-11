/** Pure, deterministic allocator for one complete group task. */

export interface AllocationUnit {
  id: string;
  ref: string;
  label: string;
  level: string;
  weight: number;
  children: AllocationUnit[];
}

export interface AllocationMember {
  memberId: string;
  rankedRefs: string[];
  paceUnit: string;
  capacityPerStudyDay: number;
  workloadPerPaceUnit: number;
  studyDays: number[]; // ISO weekday: Monday=1 ... Sunday=7.
}

export interface DailyTask {
  date: string;
  refs: string[];
  workload: number;
  paceUnit: string;
  paceAmount: number;
}

export interface MemberAllocation {
  memberId: string;
  units: AllocationUnit[];
  workload: number;
  capacity: number;
  capacityInPaceUnits: number;
  dailyTasks: DailyTask[];
}

export interface GroupAllocation {
  feasible: boolean;
  shortfall: number;
  totalWorkload: number;
  algorithmVersion: 1;
  members: MemberAllocation[];
  unassignedRefs: string[];
}

export interface RebalanceParticipant {
  memberId: string;
  canReceive?: boolean;
  capacityPerDay: number;
  workloadPerPaceUnit: number;
  paceUnit: string;
  workloadByRef: Readonly<Record<string, number>>;
  futureDays: string[];
  dailyTasks: DailyTask[];
}

export interface RebalancedSchedule {
  schedules: Record<string, DailyTask[]>;
  keptByOwner: string[];
  transferred: Array<{ ref: string; fromMemberId: string; toMemberId: string }>;
  unassigned: string[];
}

/** Places missed work into the original owner's remaining capacity first. */
export function rebalanceMissedWork(args: {
  ownerMemberId: string;
  missedRefs: string[];
  participants: RebalanceParticipant[];
}): RebalancedSchedule {
  const byId = new Map(args.participants.map((member) => [member.memberId, member]));
  const owner = byId.get(args.ownerMemberId);
  if (!owner || new Set(args.participants.map((member) => member.memberId)).size !== args.participants.length) {
    throw new Error("Rebalance participants are invalid");
  }
  const schedules = new Map(args.participants.map((member) => [member.memberId,
    member.dailyTasks.map((task) => ({ ...task, refs: [...task.refs] }))]));
  const append = (member: RebalanceParticipant, ref: string): boolean => {
    if (member.canReceive === false) return false;
    const workload = member.workloadByRef[ref];
    if (!Number.isFinite(workload) || workload < 1) return false;
    const daily = schedules.get(member.memberId)!;
    for (const date of member.futureDays) {
      let task = daily.find((item) => item.date === date);
      const current = task?.workload ?? 0;
      const hasCapacity = member.workloadPerPaceUnit > 1
        ? (task?.refs.length ?? 0) < member.capacityPerDay
        : current + workload <= member.capacityPerDay * member.workloadPerPaceUnit;
      const oversizedUnitAlone = member.workloadPerPaceUnit <= 1 &&
        workload > member.capacityPerDay * member.workloadPerPaceUnit && (task?.refs.length ?? 0) === 0;
      if (!hasCapacity && !oversizedUnitAlone) continue;
      if (!task) {
        task = { date, refs: [], workload: 0, paceUnit: member.paceUnit, paceAmount: 0 };
        daily.push(task);
      }
      task.refs.push(ref);
      task.workload += workload;
      task.paceAmount += member.workloadPerPaceUnit > 1 ? 1 : workload;
      return true;
    }
    return false;
  };
  const keptByOwner: string[] = [];
  const transferred: RebalancedSchedule["transferred"] = [];
  const unassigned: string[] = [];
  for (const ref of [...new Set(args.missedRefs)].sort()) {
    if (append(owner, ref)) {
      keptByOwner.push(ref);
      continue;
    }
    let assigned = false;
    for (const candidate of args.participants.filter((member) => member.memberId !== owner.memberId)
      .sort((a, b) => a.memberId.localeCompare(b.memberId))) {
      if (!append(candidate, ref)) continue;
      transferred.push({ ref, fromMemberId: owner.memberId, toMemberId: candidate.memberId });
      assigned = true;
      break;
    }
    if (!assigned && owner.canReceive !== false && owner.futureDays.length > 0) {
      const lastDate = owner.futureDays[owner.futureDays.length - 1];
      let lastTask = schedules.get(owner.memberId)!.find((item) => item.date === lastDate);
      if (!lastTask) {
        lastTask = { date: lastDate, refs: [], workload: 0, paceUnit: owner.paceUnit, paceAmount: 0 };
        schedules.get(owner.memberId)!.push(lastTask);
      }
      const workload = owner.workloadByRef[ref];
      if (Number.isFinite(workload) && workload >= 1) {
        lastTask.refs.push(ref);
        lastTask.workload += workload;
        lastTask.paceAmount += owner.workloadPerPaceUnit > 1 ? 1 : workload;
        keptByOwner.push(ref);
        assigned = true;
      }
    }
    if (!assigned) unassigned.push(ref);
  }
  for (const daily of schedules.values()) daily.sort((a, b) => a.date.localeCompare(b.date));
  return {
    schedules: Object.fromEntries([...schedules.entries()].map(([id, daily]) => [id, daily])),
    keptByOwner,
    transferred,
    unassigned,
  };
}

const DAY_MS = 24 * 60 * 60 * 1000;

function assertInputs(units: readonly AllocationUnit[], members: readonly AllocationMember[], startDate: string, deadline: string): void {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !/^\d{4}-\d{2}-\d{2}$/.test(deadline) || startDate > deadline) {
    throw new Error("Allocation dates are invalid");
  }
  if (units.length === 0 || members.length === 0 || members.length > 12) throw new Error("Allocation scope or roster is invalid");
  const refs = new Set<string>();
  const visit = (unit: AllocationUnit): void => {
    if (!unit.id || !unit.ref || !unit.level || !Number.isSafeInteger(unit.weight) || unit.weight < 1 || refs.has(unit.ref)) {
      throw new Error("Allocation units must have unique refs and positive integer weights");
    }
    refs.add(unit.ref);
    for (const child of unit.children) visit(child);
    if (unit.children.length > 0 && unit.children.reduce((sum, child) => sum + child.weight, 0) !== unit.weight) {
      throw new Error("Allocation child weights must sum to their parent weight");
    }
  };
  units.forEach(visit);
  const memberIds = new Set<string>();
  for (const member of members) {
    if (!member.memberId || memberIds.has(member.memberId) || !member.paceUnit ||
        !Number.isSafeInteger(member.capacityPerStudyDay) || member.capacityPerStudyDay < 1 ||
        !Number.isFinite(member.workloadPerPaceUnit) || member.workloadPerPaceUnit < 1 || member.studyDays.length === 0 ||
        member.studyDays.some((day) => !Number.isInteger(day) || day < 1 || day > 7)) {
      throw new Error("Allocation member capacity is invalid");
    }
    memberIds.add(member.memberId);
  }
}

function isoWeekday(date: Date): number {
  const day = date.getUTCDay();
  return day === 0 ? 7 : day;
}

function studyDates(startDate: string, deadline: string, studyDays: readonly number[]): string[] {
  const allowed = new Set(studyDays);
  const from = Date.parse(`${startDate}T00:00:00.000Z`);
  const until = Date.parse(`${deadline}T00:00:00.000Z`);
  const result: string[] = [];
  for (let day = from; day <= until; day += DAY_MS) {
    const date = new Date(day);
    if (allowed.has(isoWeekday(date))) result.push(date.toISOString().slice(0, 10));
  }
  return result;
}

function preferenceRank(member: AllocationMember, unit: AllocationUnit): number {
  const direct = member.rankedRefs.indexOf(unit.ref);
  if (direct >= 0) return direct;
  // A preference for a whole masechta/seder also applies to its split perakim.
  for (const ancestorRef of member.rankedRefs) {
    if (unit.ref.startsWith(`${ancestorRef} `)) return member.rankedRefs.indexOf(ancestorRef);
  }
  return member.rankedRefs.length + 1;
}

function splitForBalance(unit: AllocationUnit, targetWorkload: number): AllocationUnit[] {
  if (unit.children.length === 0 || unit.weight <= targetWorkload) return [unit];
  // A canonical unit may split once into its immediate children (masechta
  // into perakim, sefer into perakim, etc.). Never recurse below that level:
  // a perek or daf is the smallest allocation unit.
  return unit.children;
}

function schedule(units: readonly AllocationUnit[], member: AllocationMember, dates: readonly string[]): DailyTask[] {
  const smallestUnits = new Set(["perek", "chapter", "daf", "amud", "siman", "seif", "halacha", "pasuk", "mishna"]);
  const schedulable = units.flatMap((unit) => unit.children.length > 0 && !smallestUnits.has(unit.level) ? unit.children : [unit])
    .sort((a, b) => a.ref.localeCompare(b.ref));
  const tasks: DailyTask[] = [];
  let index = 0;
  for (const date of dates) {
    const refs: string[] = [];
    let workload = 0;
    while (index < schedulable.length && (member.workloadPerPaceUnit > 1
      ? refs.length < member.capacityPerStudyDay
      : workload + schedulable[index].weight <= member.capacityPerStudyDay * member.workloadPerPaceUnit)) {
      refs.push(schedulable[index].ref);
      workload += schedulable[index].weight;
      index++;
    }
    if (refs.length > 0) tasks.push({
      date,
      refs,
      workload,
      paceUnit: member.paceUnit,
      paceAmount: member.workloadPerPaceUnit > 1 ? refs.length : workload,
    });
  }
  // The allocator reports global capacity feasibility. A remaining item that
  // is larger than the daily cap is kept as an explicit one-day task.
  while (index < schedulable.length && dates.length > 0) {
    const day = dates[Math.min(tasks.length, dates.length - 1)];
    const unit = schedulable[index++];
    const last = tasks[tasks.length - 1];
    if (last?.date === day) {
      last.refs.push(unit.ref);
      last.workload += unit.weight;
      last.paceAmount += member.workloadPerPaceUnit > 1 ? 1 : unit.weight;
    } else {
      tasks.push({ date: day, refs: [unit.ref], workload: unit.weight, paceUnit: member.paceUnit,
        paceAmount: member.workloadPerPaceUnit > 1 ? 1 : unit.weight });
    }
  }
  return tasks;
}

/**
 * Assigns every unit to at most one member. The largest masechtos are
 * considered first; a unit larger than its fair share is split down its
 * canonical child tree, while balanced units stay whole. Preference rank is
 * considered before current normalized load; stable lexical ids break ties.
 */
export function allocateGroupTask(args: {
  taskId: string;
  units: AllocationUnit[];
  members: AllocationMember[];
  startDate: string;
  deadline: string;
}): GroupAllocation {
  const { taskId, units, members, startDate, deadline } = args;
  if (!taskId) throw new Error("Allocation task id is required");
  assertInputs(units, members, startDate, deadline);
  const datesByMember = new Map(members.map((member) => [member.memberId,
    studyDates(startDate, deadline, member.studyDays)]));
  const capacities = new Map(members.map((member) => [member.memberId,
    member.capacityPerStudyDay * member.workloadPerPaceUnit * (datesByMember.get(member.memberId)?.length ?? 0)]));
  const capacitiesInPaceUnits = new Map(members.map((member) => [member.memberId,
    member.capacityPerStudyDay * (datesByMember.get(member.memberId)?.length ?? 0)]));
  const totalWorkload = units.reduce((sum, unit) => sum + unit.weight, 0);
  const totalCapacity = [...capacities.values()].reduce((sum, capacity) => sum + capacity, 0);
  const averageCapacityShare = members.reduce((sum, member) => sum + (capacities.get(member.memberId) ?? 0), 0) > 0
    ? totalWorkload * Math.min(...members.map((member) => capacities.get(member.memberId) ?? 0)) /
      Math.max(1, totalCapacity)
    : 0;
  const averageLoad = totalWorkload / members.length;
  const targetWorkload = Math.max(1, Math.min(averageLoad, averageCapacityShare || averageLoad));
  const work = units.flatMap((unit) => splitForBalance(unit, targetWorkload))
    .sort((a, b) => b.weight - a.weight || a.ref.localeCompare(b.ref));
  const assigned = new Map(members.map((member) => [member.memberId, [] as AllocationUnit[]]));
  const loads = new Map(members.map((member) => [member.memberId, 0]));
  const unassignedRefs: string[] = [];

  for (const unit of work) {
    const candidates = members.filter((member) => (loads.get(member.memberId) ?? 0) + unit.weight <= (capacities.get(member.memberId) ?? 0))
      .sort((a, b) => {
        const rank = preferenceRank(a, unit) - preferenceRank(b, unit);
        if (rank !== 0) return rank;
        const loadA = (loads.get(a.memberId) ?? 0) / Math.max(1, capacities.get(a.memberId) ?? 0);
        const loadB = (loads.get(b.memberId) ?? 0) / Math.max(1, capacities.get(b.memberId) ?? 0);
        if (loadA !== loadB) return loadA - loadB;
        return a.memberId.localeCompare(b.memberId);
      });
    const chosen = candidates[0];
    if (!chosen) {
      unassignedRefs.push(unit.ref);
      continue;
    }
    assigned.get(chosen.memberId)!.push(unit);
    loads.set(chosen.memberId, (loads.get(chosen.memberId) ?? 0) + unit.weight);
  }

  const results = members.map((member): MemberAllocation => {
    const memberUnits = assigned.get(member.memberId)!;
    const workload = loads.get(member.memberId) ?? 0;
    const dates = datesByMember.get(member.memberId) ?? [];
    return {
      memberId: member.memberId,
      units: memberUnits,
      workload,
      capacity: capacities.get(member.memberId) ?? 0,
      capacityInPaceUnits: capacitiesInPaceUnits.get(member.memberId) ?? 0,
      dailyTasks: schedule(memberUnits, member, dates),
    };
  });
  const shortfall = Math.max(0, totalWorkload - totalCapacity);
  return {
    feasible: unassignedRefs.length === 0 && shortfall === 0,
    shortfall,
    totalWorkload,
    algorithmVersion: 1,
    members: results,
    unassignedRefs,
  };
}
