import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class GroupTasksSection extends ConsumerStatefulWidget {
  const GroupTasksSection({
    super.key,
    required this.group,
    required this.profileId,
    required this.parentSessionId,
    required this.repository,
    required this.onError,
    this.initialTaskId,
  });

  final LearningGroupDetails group;
  final String profileId;
  final String? parentSessionId;
  final LearningGroupRepository repository;
  final VoidCallback onError;
  final String? initialTaskId;

  @override
  ConsumerState<GroupTasksSection> createState() => _GroupTasksSectionState();
}

class _GroupTasksSectionState extends ConsumerState<GroupTasksSection> {
  late Future<List<LearningGroupTaskCard>> _tasks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _tasks = widget.repository.listTasks(
      groupId: widget.group.groupId,
      profileId: widget.profileId,
    );
  }

  Widget _curriculumLabel(String id) {
    final curriculum = CurriculumId.fromStorageKey(id);
    return curriculum == null
        ? Text(id)
        : CurriculumLabel.curriculum(curriculum);
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<LearningGroupTaskScope> _flatten(List<LearningGroupTaskScope> items) => [
    for (final item in items) item,
    for (final item in items) ..._flatten(item.children),
  ];

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: ref.read(localDayClockProvider).today(),
    lastDate: ref
        .read(localDayClockProvider)
        .today()
        .add(const Duration(days: 730)),
  );

  Future<void> _postTask(AppLocalizations l10n) async {
    try {
      final curricula = await widget.repository.taskCurricula();
      if (!mounted || curricula.isEmpty) return;
      var curriculum = curricula.first;
      var scopes = <LearningGroupTaskScope>[];
      var selected = <String>{};
      final today = ref.read(localDayClockProvider).today();
      var replyBy = today.add(const Duration(days: 3));
      var deadline = today.add(const Duration(days: 14));
      var loadingScopes = true;
      scopes = (await widget.repository.taskSetup(curriculum)).scopes;
      loadingScopes = false;
      if (!mounted) return;
      final result = await showDialog<(String, List<String>, String, String)?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.groupTaskCreate),
            content: SizedBox(
              width: 440,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(l10n.groupTaskSupportedCurricula),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: curriculum,
                    decoration: InputDecoration(
                      labelText: l10n.groupTaskCurriculum,
                    ),
                    items: [
                      for (final id in curricula)
                        DropdownMenuItem(
                          value: id,
                          child: _curriculumLabel(id),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setDialogState(() {
                        curriculum = value;
                        loadingScopes = true;
                        selected = {};
                      });
                      try {
                        final setup = await widget.repository.taskSetup(value);
                        setDialogState(() {
                          scopes = setup.scopes;
                          loadingScopes = false;
                        });
                      } catch (_) {
                        setDialogState(() => loadingScopes = false);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.groupTaskScope),
                  if (loadingScopes)
                    const LinearProgressIndicator()
                  else
                    SizedBox(
                      height: 220,
                      child: ListView(
                        children: [
                          for (final scope in scopes)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(scope.label),
                              value: selected.contains(scope.ref),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  selected.add(scope.ref);
                                } else {
                                  selected.remove(scope.ref);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.groupTaskReplyBy),
                    subtitle: Text(_date(replyBy)),
                    onTap: () async {
                      final choice = await _pickDate(replyBy);
                      if (choice != null)
                        setDialogState(() => replyBy = choice);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.groupTaskDeadline),
                    subtitle: Text(_date(deadline)),
                    onTap: () async {
                      final choice = await _pickDate(deadline);
                      if (choice != null)
                        setDialogState(() => deadline = choice);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: loadingScopes || !deadline.isAfter(replyBy)
                    ? null
                    : () => Navigator.pop(context, (
                        curriculum,
                        selected.toList(),
                        _date(replyBy),
                        _date(deadline),
                      )),
                child: Text(l10n.groupTaskCreate),
              ),
            ],
          ),
        ),
      );
      if (result == null) return;
      await widget.repository.createTask(
        groupId: widget.group.groupId,
        profileId: widget.profileId,
        curriculumId: result.$1,
        scopeRefs: result.$2,
        replyBy: result.$3,
        deadline: result.$4,
      );
      if (mounted) setState(_load);
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  Future<void> _setResponse(LearningGroupTaskCard task, bool accept) async {
    try {
      await widget.repository.respondToTask(
        groupId: widget.group.groupId,
        taskId: task.taskId,
        profileId: widget.profileId,
        accept: accept,
        parentSessionId: widget.parentSessionId,
      );
      if (mounted) setState(_load);
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  Future<void> _preferences(LearningGroupTaskCard task) async {
    try {
      final setup = await widget.repository.taskSetup(task.curriculumId);
      if (!mounted) return;
      final all = _flatten(task.scopeUnits);
      final order = all.map((scope) => scope.ref).toList();
      var paceUnit = setup.paceUnits.first;
      var capacity = 1;
      final days = <int>{1, 2, 3, 4, 5, 7};
      final capacityController = TextEditingController(text: '1');
      final result = await showDialog<(List<String>, String, int, List<int>)?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.groupTaskPreferences),
            content: SizedBox(
              width: 440,
              child: ListView(
                shrinkWrap: true,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: paceUnit,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      )!.groupTaskPaceUnit,
                    ),
                    items: [
                      for (final unit in setup.paceUnits)
                        DropdownMenuItem(value: unit, child: Text(unit)),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => paceUnit = value);
                    },
                  ),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      )!.groupTaskCapacity,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.groupTaskStudyDays),
                  Wrap(
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(
                            MaterialLocalizations.of(
                              context,
                            ).narrowWeekdays[day % 7],
                          ),
                          selected: days.contains(day),
                          onSelected: (value) => setDialogState(() {
                            value ? days.add(day) : days.remove(day);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.length,
                    onReorderItem: (oldIndex, newIndex) => setDialogState(() {
                      final item = order.removeAt(oldIndex);
                      order.insert(newIndex, item);
                    }),
                    itemBuilder: (context, index) {
                      final scope = all.firstWhere(
                        (item) => item.ref == order[index],
                      );
                      return ListTile(
                        key: ValueKey(scope.ref),
                        dense: true,
                        title: Text(scope.label),
                        leading: const Icon(Icons.drag_handle),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed:
                    days.isEmpty ||
                        int.tryParse(capacityController.text) == null
                    ? null
                    : () => Navigator.pop(context, (
                        order,
                        paceUnit,
                        int.parse(capacityController.text),
                        days.toList()..sort(),
                      )),
                child: Text(MaterialLocalizations.of(context).saveButtonLabel),
              ),
            ],
          ),
        ),
      );
      capacityController.dispose();
      if (result == null) return;
      capacity = result.$3;
      await widget.repository.saveTaskPreferences(
        groupId: widget.group.groupId,
        taskId: task.taskId,
        profileId: widget.profileId,
        rankedRefs: result.$1,
        paceUnit: result.$2,
        capacityPerStudyDay: capacity,
        studyDays: result.$4,
      );
      if (mounted) setState(_load);
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  Future<void> _allocate(LearningGroupTaskCard task) async {
    try {
      final result = await widget.repository.allocateTask(
        groupId: widget.group.groupId,
        taskId: task.taskId,
      );
      if (mounted) {
        if (result['feasible'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.groupTaskInfeasible(
                  result['shortfall'] is int ? result['shortfall'] as int : 0,
                ),
              ),
            ),
          );
        }
        setState(_load);
      }
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  Future<void> _requestJoin(LearningGroupTaskCard task) async {
    try {
      await widget.repository.requestLateTaskJoin(
        groupId: widget.group.groupId,
        taskId: task.taskId,
        profileId: widget.profileId,
      );
      if (mounted) setState(_load);
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  Future<void> _reviewJoin(
    LearningGroupTaskCard task,
    String memberId,
    bool approved,
  ) async {
    try {
      await widget.repository.reviewLateTaskJoin(
        groupId: widget.group.groupId,
        taskId: task.taskId,
        memberId: memberId,
        approved: approved,
      );
      if (mounted) setState(_load);
    } catch (_) {
      if (mounted) widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<LearningGroupTaskCard>>(
      future: _tasks,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text(l10n.errorWithMessage);
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final tasks = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.groupTaskTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.group.role == 'admin')
                  IconButton(
                    onPressed: () => _postTask(l10n),
                    icon: const Icon(Icons.add_task),
                    tooltip: l10n.groupTaskCreate,
                  ),
              ],
            ),
            if (tasks.isEmpty) Text(l10n.groupTaskNoTasks),
            for (final task in tasks)
              Card(
                color: task.taskId == widget.initialTaskId
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.taskName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          _curriculumLabel(task.curriculumId),
                          Text(
                            l10n.groupTaskStatusLine(
                              task.status,
                              task.deadline ?? l10n.groupTaskNoDeadline,
                            ),
                          ),
                        ],
                      ),
                      for (final request in task.joinRequests)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l10n.groupTaskJoinRequest(
                              request['displayName'] as String? ??
                                  l10n.groupMembers,
                            ),
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: l10n.groupTaskDeclineJoin,
                                onPressed: () => _reviewJoin(
                                  task,
                                  request['memberId'] as String,
                                  false,
                                ),
                                icon: const Icon(Icons.close),
                              ),
                              IconButton(
                                tooltip: l10n.groupTaskApproveJoin,
                                onPressed: () => _reviewJoin(
                                  task,
                                  request['memberId'] as String,
                                  true,
                                ),
                                icon: const Icon(Icons.check),
                              ),
                            ],
                          ),
                        ),
                      if (task.status == 'published') ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.groupTaskAssignments,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final member in task.allocationMembers)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              member['displayName'] as String? ??
                                  l10n.groupMembers,
                            ),
                            children: [
                              for (final unit
                                  in (member['units'] as List? ?? const []))
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    (unit as Map)['label']?.toString() ?? '',
                                  ),
                                ),
                              for (final daily
                                  in (member['dailyTasks'] as List? ??
                                      const []))
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.today),
                                  title: Text(_dailyLabel(daily)),
                                ),
                            ],
                          ),
                      ] else if (task.memberState == 'awaiting_response')
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _setResponse(task, false),
                              child: Text(l10n.groupTaskDecline),
                            ),
                            FilledButton(
                              onPressed: () => _setResponse(task, true),
                              child: Text(l10n.groupTaskAccept),
                            ),
                          ],
                        )
                      else if (task.memberState == 'accepted')
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _preferences(task),
                              child: Text(l10n.groupTaskPreferences),
                            ),
                            if (widget.group.role == 'admin')
                              FilledButton(
                                onPressed: () => _allocate(task),
                                child: Text(l10n.groupTaskAllocate),
                              ),
                          ],
                        )
                      else if (task.memberState == 'not_invited' &&
                          widget.group.role != 'admin')
                        TextButton(
                          onPressed: () => _requestJoin(task),
                          child: Text(l10n.groupTaskRequestJoin),
                        )
                      else if (widget.group.role == 'admin' &&
                          task.status != 'published')
                        FilledButton(
                          onPressed: () => _allocate(task),
                          child: Text(l10n.groupTaskAllocate),
                        ),
                      if (task.memberState == 'join_requested')
                        Text(l10n.groupTaskWaiting),
                      if (task.feasible == false)
                        Text(l10n.groupTaskInfeasible(task.shortfall ?? 0)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _dailyLabel(Object? value) {
    if (value is! Map) return '';
    return '${value['date']} · ${value['paceAmount']} ${value['paceUnit']}';
  }
}
