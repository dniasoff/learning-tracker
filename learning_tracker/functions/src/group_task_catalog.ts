import { GROUP_CURRICULUM_NODES, GroupCurriculumNodeData } from "./group_curriculum_manifest";
import { AllocationUnit } from "./group_task_allocator";

const nodesByCurriculum = new Map<string, GroupCurriculumNodeData[]>();
for (const node of GROUP_CURRICULUM_NODES) {
  const values = nodesByCurriculum.get(node.curriculumId) ?? [];
  values.push(node);
  nodesByCurriculum.set(node.curriculumId, values);
}

const PACE_UNITS: Readonly<Record<string, { coarse?: string; fine?: string }>> = {
  mishnayos: { coarse: "perek", fine: "mishna" },
  bavli: { coarse: "daf", fine: "amud" },
  yerushalmi: { fine: "daf" },
  chumash: { coarse: "perek", fine: "pasuk" },
  nach: { coarse: "perek", fine: "pasuk" },
  tanach: { coarse: "perek", fine: "pasuk" },
  mussar: { coarse: "perek", fine: "pasuk" },
  mishna_berurah: { coarse: "siman", fine: "seif" },
  mishneh_torah: { coarse: "perek", fine: "halacha" },
};

export function groupTaskPaceUnits(curriculumId: string): string[] {
  const options = PACE_UNITS[curriculumId];
  return options ? [options.coarse, options.fine].filter((value): value is string => value !== undefined) : [];
}

export function groupTaskWorkloadPerPaceUnit(curriculumId: string, paceUnit: string, units: readonly AllocationUnit[]): number {
  const options = PACE_UNITS[curriculumId];
  if (!options || !groupTaskPaceUnits(curriculumId).includes(paceUnit)) throw new Error("Pace unit is not available for this curriculum");
  if (paceUnit === options.fine) return 1;
  const splitUnits = units.flatMap((unit) => unit.children.length > 0 ? unit.children : [unit]);
  if (splitUnits.length === 0) return 1;
  return splitUnits.reduce((sum, unit) => sum + unit.weight, 0) / splitUnits.length;
}

function nodes(curriculumId: string): GroupCurriculumNodeData[] {
  return nodesByCurriculum.get(curriculumId) ?? [];
}

function unit(node: GroupCurriculumNodeData, all: readonly GroupCurriculumNodeData[]): AllocationUnit {
  const children = all.filter((child) => child.parentRef === node.ref && child.depth === node.depth + 1);
  return {
    id: node.ref,
    ref: node.ref,
    label: node.label,
    level: node.level,
    weight: node.weight,
    children: children.map((child) => ({
      id: child.ref,
      ref: child.ref,
      label: child.label,
      level: child.level,
      weight: child.weight,
      children: [],
    })),
  };
}

function majorDepth(all: readonly GroupCurriculumNodeData[]): number {
  return all.some((node) => node.depth === 2) ? 2 : 1;
}

export function listGroupTaskScopes(curriculumId: string): Array<{ ref: string; label: string; weight: number }> {
  const all = nodes(curriculumId);
  if (curriculumId === "tanach") {
    return all.filter((node) => node.depth === 1 || node.depth === 2)
      .sort((a, b) => a.depth - b.depth || a.sortOrder - b.sortOrder)
      .map((node) => ({ ref: node.ref, label: node.label, weight: node.weight }));
  }
  const depth = majorDepth(all);
  return all.filter((node) => node.depth === depth && (depth === 1 || node.parentRef !== null))
    .map((node) => ({ ref: node.ref, label: node.label, weight: node.weight }));
}

/** Resolve caller-selected canonical sections into server-weighted units. */
export function resolveGroupTaskUnits(curriculumId: string, scopeRefs: readonly string[]): AllocationUnit[] {
  const all = nodes(curriculumId);
  if (all.length === 0) throw new Error("Curriculum is not available for group tasks");
  const depth = majorDepth(all);
  const candidates = all.filter((node) => node.depth === depth && (depth === 1 || node.parentRef !== null));
  const byRef = new Map(all.map((node) => [node.ref, node]));
  if (scopeRefs.length === 0) return candidates.map((node) => unit(node, all));
  const chosen = new Map<string, GroupCurriculumNodeData>();
  const addDescendantsAtMajorDepth = (node: GroupCurriculumNodeData): void => {
    if (node.depth === depth) {
      chosen.set(node.ref, node);
      return;
    }
    if (node.depth > depth) throw new Error("Task scope must select a section, seder, or masechta");
    for (const child of all.filter((item) => item.parentRef === node.ref && item.depth === node.depth + 1)) {
      addDescendantsAtMajorDepth(child);
    }
  };
  for (const ref of scopeRefs) {
    const node = byRef.get(ref);
    if (!node) throw new Error("Task scope contains an unknown curriculum ref");
    addDescendantsAtMajorDepth(node);
  }
  return [...chosen.values()].sort((a, b) => a.sortOrder - b.sortOrder).map((node) => unit(node, all));
}

export function groupTaskCurriculumIds(): string[] {
  return [...nodesByCurriculum.keys()].filter((id) => id !== "shnayim_mikra" && PACE_UNITS[id] !== undefined).sort();
}
