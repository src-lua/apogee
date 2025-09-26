import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import '../services/task_service.dart';
import '../models/task_template.dart';
import '../models/task_streak_data.dart';

class StreakWidget extends StatefulWidget {
  const StreakWidget({super.key});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  TaskStreakData? _globalStreak;
  List<TaskTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadStreakData();
  }

  Future<void> _loadStreakData() async {
    try {
      final globalStreak = StreakService.instance.getGlobalStreakData();
      final templates = TaskService.instance.getTaskTemplates();

      setState(() {
        _globalStreak = globalStreak;
        _templates = templates;
      });
    } catch (e) {
      debugPrint('Error loading streak data: $e');
    }
  }

  void _showStreakDetails() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Sequências',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Global logging streak
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Sequência de Registros',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Atual: ${_globalStreak?.currentStreak ?? 0} dias'),
                    Text('Melhor: ${_globalStreak?.bestStreak ?? 0} dias'),
                    Text('Total registrado: ${_globalStreak?.totalCompletions ?? 0} dias'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Individual task streaks
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sequências por Tarefa:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final template in _templates) Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Atual: ${template.streakData.currentStreak}'),
                                Text('Melhor: ${template.streakData.bestStreak}'),
                              ],
                            ),
                            Text('Total: ${template.streakData.totalCompletions}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final maxCurrentStreak = _templates.isNotEmpty
        ? _templates.map((t) => t.streakData.currentStreak).reduce((a, b) => a > b ? a : b)
        : 0;

    final globalCurrentStreak = _globalStreak?.currentStreak ?? 0;

    return Tooltip(
      message: 'Sequências:\n'
          'Registros: $globalCurrentStreak dias\n'
          'Melhor tarefa: $maxCurrentStreak dias\n'
          'Clique para ver detalhes',
      child: InkWell(
        onTap: _showStreakDetails,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '$globalCurrentStreak',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}