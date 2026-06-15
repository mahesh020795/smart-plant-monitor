import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/schedule.dart';
import '../../providers/app_provider.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schedules = context.watch<AppProvider>().schedules;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watering Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            onPressed: () => _openScheduleDialog(context, null),
          ),
        ],
      ),
      body: schedules.isEmpty
          ? _EmptyView(onAdd: () => _openScheduleDialog(context, null))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) =>
                  _ScheduleTile(schedule: schedules[i]),
            ),
      floatingActionButton: schedules.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openScheduleDialog(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Schedule'),
            )
          : null,
    );
  }

  void _openScheduleDialog(BuildContext ctx, WateringSchedule? existing) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScheduleForm(existing: existing),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final WateringSchedule schedule;
  const _ScheduleTile({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final color = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              schedule.enabled ? color.primaryContainer : Colors.grey.shade200,
          child: Icon(
            Icons.water_drop_rounded,
            color: schedule.enabled ? color.primary : Colors.grey,
          ),
        ),
        title: Text(
          schedule.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${schedule.timeString}  •  ${schedule.daysString}'),
            Text('Duration: ${schedule.durationSeconds}s'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: schedule.enabled,
              onChanged: (v) => provider.toggleSchedule(schedule.id, v),
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _ScheduleForm(existing: schedule),
                  );
                } else if (action == 'delete') {
                  _confirmDelete(context, provider, schedule.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext ctx, AppProvider provider, String id) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteSchedule(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleForm extends StatefulWidget {
  final WateringSchedule? existing;
  const _ScheduleForm({this.existing});

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final _nameCtrl = TextEditingController();
  late TimeOfDay _time;
  late int _duration;
  late List<bool> _days; // index 0=Mon … 6=Sun
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameCtrl.text = s?.name ?? '';
    _time = s != null ? TimeOfDay(hour: s.hour, minute: s.minute) : TimeOfDay.now();
    _duration = s?.durationSeconds ?? 30;
    _days = List.generate(7, (i) => s?.days.contains(i + 1) ?? true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a schedule name')),
      );
      return;
    }
    if (!_days.any((d) => d)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final days = [
      for (int i = 0; i < 7; i++)
        if (_days[i]) i + 1
    ];

    final schedule = WateringSchedule(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      durationSeconds: _duration,
      days: days,
      enabled: widget.existing?.enabled ?? true,
    );

    if (widget.existing != null) {
      await provider.updateSchedule(schedule);
    } else {
      await provider.addSchedule(schedule);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing != null ? 'Edit Schedule' : 'New Schedule',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Schedule Name',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Time',
                prefixIcon: Icon(Icons.access_time_rounded),
              ),
              child: Text(
                _time.format(context),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Duration: $_duration seconds',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: _duration.toDouble(),
            min: 5,
            max: 300,
            divisions: 59,
            label: '${_duration}s',
            onChanged: (v) => setState(() => _duration = v.toInt()),
          ),
          const SizedBox(height: 6),
          Text(
            'Days',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              return GestureDetector(
                onTap: () => setState(() => _days[i] = !_days[i]),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _days[i]
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200,
                  child: Text(
                    dayNames[i],
                    style: TextStyle(
                      color: _days[i] ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _saving
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: _save,
                  child: Text(widget.existing != null ? 'Update' : 'Save Schedule'),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No schedules yet'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Schedule'),
          ),
        ],
      ),
    );
  }
}
