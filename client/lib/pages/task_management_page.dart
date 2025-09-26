import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../models/enums/recurrency_type.dart';
import '../models/enums/task_status.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';

class TaskManagementPage extends StatefulWidget {
  final VoidCallback onTasksChanged;

  const TaskManagementPage({super.key, required this.onTasksChanged});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage> {
  final TaskService _taskService = TaskService.instance;
  List<TaskTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    setState(() {
      _templates = _taskService.getTaskTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Tarefas'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showTaskDialog(),
          ),
        ],
      ),
      body: _templates.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma tarefa encontrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toque no botão + para adicionar sua primeira tarefa',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return Card(
                  child: ListTile(
                    leading: Switch(
                      value: template.isActive,
                      onChanged: (value) => _toggleTemplateActive(template, value),
                    ),
                    title: Text(
                      template.name,
                      style: TextStyle(
                        decoration: template.isActive ? null : TextDecoration.lineThrough,
                        color: template.isActive ? null : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💰${template.coins}'),
                        Text(
                          template.recurrencyType.displayName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (template.customDays != null && template.customDays!.isNotEmpty)
                          Text(
                            _getCustomDaysDisplay(template),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showTaskDialog(template: template);
                            break;
                          case 'delete':
                            _deleteTemplate(template);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Editar'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Excluir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _getCustomDaysDisplay(TaskTemplate template) {
    if (template.customDays == null || template.customDays!.isEmpty) return '';

    switch (template.recurrencyType) {
      case RecurrencyType.weekly:
        final weekdays = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
        return template.customDays!
            .map((day) => weekdays[day])
            .join(', ');
      case RecurrencyType.monthly:
        return 'Dias: ${template.customDays!.join(', ')}';
      default:
        return '';
    }
  }

  Future<void> _toggleTemplateActive(TaskTemplate template, bool isActive) async {
    // When deactivating, ask about deleting future tasks
    if (!isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Desativar Tarefa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deseja desativar a tarefa "${template.name}"?'),
              const SizedBox(height: 12),
              const Text(
                '• Tarefas concluídas/finalizadas em dias anteriores serão mantidas\n• Tarefas pendentes em dias anteriores serão removidas\n• Tarefas de dias futuros serão removidas\n• A tarefa não aparecerá mais no calendário',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Desativar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      final updatedTemplate = template.copyWith(isActive: isActive);

      if (isActive) {
        // When turning ON, use regular update to regenerate future tasks
        await _taskService.updateTaskTemplate(updatedTemplate);
      } else {
        // When turning OFF, use safe method that doesn't regenerate days
        await _taskService.updateTaskTemplateWithoutRegeneration(updatedTemplate);
        // Remove tasks from future days only
        await _removeFutureTasksOnly(template.id);
      }

      _loadTemplates();
      widget.onTasksChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar tarefa')),
        );
      }
    }
  }

  Future<void> _removeFutureTasksOnly(String templateId) async {
    try {
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      // Get all stored days
      final allKeys = Hive.box('apogee_data').keys
          .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
          .cast<String>()
          .toList();

      for (final key in allKeys) {
        final day = DateTime.parse(key);
        final tasksForDay = List<Task>.from(Hive.box('apogee_data').get(key) ?? []);

        bool tasksRemoved = false;

        if (day.isAfter(todayNormalized)) {
          // Future days: Remove all tasks from this template
          final originalLength = tasksForDay.length;
          tasksForDay.removeWhere((task) => task.id.startsWith('${templateId}_'));
          tasksRemoved = tasksForDay.length != originalLength;
        } else {
          // Previous days and today: Only remove tasks that are still "pending"
          final originalLength = tasksForDay.length;
          tasksForDay.removeWhere((task) =>
            task.id.startsWith('${templateId}_') &&
            task.status == TaskStatus.pending
          );
          tasksRemoved = tasksForDay.length != originalLength;
        }

        // Save if something was removed
        if (tasksRemoved) {
          if (tasksForDay.isEmpty) {
            await Hive.box('apogee_data').delete(key);
          } else {
            await Hive.box('apogee_data').put(key, tasksForDay);
          }
        }
      }
    } catch (e) {
      print('Error removing tasks: $e');
    }
  }

  Future<int> _calculateCoinImpactFromPreviousDays(TaskTemplate template) async {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    int totalCoins = 0;

    // Check all stored days before today
    final allKeys = Hive.box('apogee_data').keys
        .where((key) => key is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(key))
        .cast<String>()
        .toList();

    for (final key in allKeys) {
      final day = DateTime.parse(key);
      if (day.isBefore(todayNormalized)) {
        final tasks = _taskService.getTasksForDay(day);
        final templateTask = tasks.where((task) => task.id.startsWith('${template.id}_')).firstOrNull;

        if (templateTask != null && templateTask.status == TaskStatus.completed) {
          totalCoins += templateTask.coins;
        }
      }
    }

    return totalCoins;
  }

  Future<void> _deleteTemplate(TaskTemplate template) async {
    // Calculate coin impact from previous days
    final coinImpact = await _calculateCoinImpactFromPreviousDays(template);
    print('Calculated coin impact: $coinImpact for template ${template.name}');

    if (coinImpact > 0) {
      // Show coin impact dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deseja excluir a tarefa "${template.name}"?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Impacto em dias anteriores:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('💰 $coinImpact moedas ganhas em dias anteriores'),
                    const SizedBox(height: 8),
                    const Text(
                      'Tarefas de dias futuros serão excluídas automaticamente.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('keep_coins'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('Excluir e Manter Moedas'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('lose_coins'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir e Perder Moedas'),
            ),
          ],
        ),
      );

      if (result == 'keep_coins' || result == 'lose_coins') {
        try {
          // Delete template and tasks from future days (always)
          await _taskService.deleteTaskTemplate(template.id);

          // If user chose to lose coins, remove them from previous completed tasks
          if (result == 'lose_coins') {
            print('Removing $coinImpact coins from user balance');
            // Remove coins earned from this template in previous days
            final userService = UserService.instance;
            final currentCoins = userService.getUserCoins();
            print('Current coins before removal: $currentCoins');
            await userService.removeCoins(coinImpact);
            final newCoins = userService.getUserCoins();
            print('Coins after removal: $newCoins');
          }

          _loadTemplates();
          widget.onTasksChanged();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erro ao excluir tarefa')),
            );
          }
        }
      }
    } else {
      // No coin impact, simple deletion
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Deseja excluir a tarefa "${template.name}"?\n\nTarefas de dias futuros serão excluídas automaticamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await _taskService.deleteTaskTemplate(template.id);
          _loadTemplates();
          widget.onTasksChanged();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erro ao excluir tarefa')),
            );
          }
        }
      }
    }
  }

  void _showTaskDialog({TaskTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: TaskEditDialog(
            template: template,
            onSaved: () {
              _loadTemplates();
              widget.onTasksChanged();
            },
          ),
        ),
      ),
    );
  }
}

class TaskEditDialog extends StatefulWidget {
  final TaskTemplate? template;
  final VoidCallback onSaved;

  const TaskEditDialog({super.key, this.template, required this.onSaved});

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _coinsController = TextEditingController();
  final TaskService _taskService = TaskService.instance;

  RecurrencyType _selectedRecurrency = RecurrencyType.daily;
  List<int> _selectedWeekdays = [];
  List<int> _selectedMonthDays = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.template != null;

    if (_isEditing) {
      final template = widget.template!;
      _nameController.text = template.name;
      _coinsController.text = template.coins.toString();
      _selectedRecurrency = template.recurrencyType;
      _startDate = template.startDate;
      _endDate = template.endDate;

      if (template.customDays != null) {
        if (_selectedRecurrency == RecurrencyType.weekly) {
          _selectedWeekdays = List.from(template.customDays!);
        } else if (_selectedRecurrency == RecurrencyType.monthly) {
          _selectedMonthDays = List.from(template.customDays!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? 'Editar Tarefa' : 'Nova Tarefa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da Tarefa',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Digite o nome da tarefa';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _coinsController,
              decoration: const InputDecoration(
                labelText: 'Moedas',
                border: OutlineInputBorder(),
                suffixText: '💰',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Digite as moedas da tarefa';
                }
                final coins = int.tryParse(value);
                if (coins == null || coins <= 0) {
                  return 'Digite um número válido maior que 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurrencyType>(
              initialValue: _selectedRecurrency,
              decoration: const InputDecoration(
                labelText: 'Recorrência',
                border: OutlineInputBorder(),
              ),
              items: RecurrencyType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRecurrency = value!;
                  _selectedWeekdays.clear();
                  _selectedMonthDays.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedRecurrency == RecurrencyType.weekly) _buildWeekdaySelector(),
            if (_selectedRecurrency == RecurrencyType.monthly) _buildMonthDaySelector(),
            const SizedBox(height: 16),
            _buildDateRangeSelector(),
          ],
        ),
      ),
    ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isEditing ? 'Salvar' : 'Criar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector() {
    const weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dias da Semana:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(7, (index) {
            final dayNumber = index + 1; // Monday = 1, Sunday = 7
            final isSelected = _selectedWeekdays.contains(dayNumber);

            return FilterChip(
              label: Text(weekdays[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWeekdays.add(dayNumber);
                  } else {
                    _selectedWeekdays.remove(dayNumber);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMonthDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dias do Mês:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(31, (index) {
            final day = index + 1;
            final isSelected = _selectedMonthDays.contains(day);

            return FilterChip(
              label: Text(day.toString()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedMonthDays.add(day);
                  } else {
                    _selectedMonthDays.remove(day);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Período (Opcional):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Início',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _startDate != null
                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                        : 'Selecionar',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: _startDate ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Fim',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _endDate != null
                        ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                        : 'Selecionar',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_startDate != null)
              TextButton(
                onPressed: () => setState(() => _startDate = null),
                child: const Text('Limpar início'),
              ),
            if (_endDate != null)
              TextButton(
                onPressed: () => setState(() => _endDate = null),
                child: const Text('Limpar fim'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate custom days for weekly/monthly recurrency
    if (_selectedRecurrency == RecurrencyType.weekly && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia da semana')),
      );
      return;
    }

    if (_selectedRecurrency == RecurrencyType.monthly && _selectedMonthDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia do mês')),
      );
      return;
    }

    try {
      List<int>? customDays;
      if (_selectedRecurrency == RecurrencyType.weekly) {
        customDays = _selectedWeekdays;
      } else if (_selectedRecurrency == RecurrencyType.monthly) {
        customDays = _selectedMonthDays;
      }

      if (_isEditing) {
        final updatedTemplate = widget.template!.copyWith(
          name: _nameController.text.trim(),
          coins: int.parse(_coinsController.text),
          recurrencyType: _selectedRecurrency,
          customDays: customDays,
          startDate: _startDate,
          endDate: _endDate,
          updateModified: true,
        );
        await _taskService.updateTaskTemplate(updatedTemplate);
      } else {
        final newTemplate = TaskTemplate(
          name: _nameController.text.trim(),
          coins: int.parse(_coinsController.text),
          recurrencyType: _selectedRecurrency,
          customDays: customDays,
          startDate: _startDate,
          endDate: _endDate,
        );
        await _taskService.addTaskTemplate(newTemplate);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar tarefa')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _coinsController.dispose();
    super.dispose();
  }
}