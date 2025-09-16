import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/task.dart';
import 'models/task_template.dart';
import 'models/enums/recurrency_type.dart';
import 'models/enums/task_status.dart';
import 'services/task_service.dart';
import 'services/user_service.dart';
import 'pages/task_management_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  
  await Hive.initFlutter();

  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TaskTemplateAdapter());
  Hive.registerAdapter(RecurrencyTypeAdapter());
  Hive.registerAdapter(TaskStatusAdapter());

  await Hive.openBox('apogee_data');

  // Initialize services
  await TaskService.instance.initialize();
  await UserService.instance.initialize();
  
  runApp(const Apogee());
}

class Apogee extends StatelessWidget {
  const Apogee({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // Remove a faixa de "Debug"
      title: 'Apogee',
      home: ApogeeHomePage(),
    );
  }
}

class ApogeeHomePage extends StatefulWidget {
  const ApogeeHomePage({super.key});

  @override
  State<ApogeeHomePage> createState() => _ApogeeHomePageState();
}

class _ApogeeHomePageState extends State<ApogeeHomePage> {
  final TaskService _taskService = TaskService.instance;
  final UserService _userService = UserService.instance;

  CalendarFormat _calendarFormat = CalendarFormat.month;

  int _userPoints = 0;
  int _userCoins = 0;
  int _userDiamonds = 0;
  int _userLevel = 1;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserData();
  }

  void _loadUserData() {
    setState(() {
      _userPoints = _userService.getUserPoints();
      _userCoins = _userService.getUserCoins();
      _userDiamonds = _userService.getUserDiamonds();
      _userLevel = _userService.getUserLevel();
    });
  }

  List<Task> _getTasksForDay(DateTime day) {
    return _taskService.getTasksForDay(day);
  }

  Future<void> _updateTaskStatus(Task task, TaskStatus newStatus, DateTime day) async {
    try {
      await _taskService.updateTaskStatus(task, newStatus, day);

      // Get updated task to check if it's late
      final updatedTasks = _taskService.getTasksForDay(day);
      final updatedTask = updatedTasks.firstWhere((t) => t.id == task.id);

      // Handle rewards based on status change
      if (task.status != newStatus) {
        // Handle coin rewards/losses
        if (newStatus == TaskStatus.completed) {
          await _userService.addCoins(task.coins);
        } else if (task.status == TaskStatus.completed && newStatus != TaskStatus.completed) {
          // If changing from completed to something else, remove coins
          await _userService.removeCoins(task.coins);
        }

        // Handle XP rewards/losses
        if (newStatus != TaskStatus.pending) {
          // Calculate XP based on status and timing (only for on-time tasks)
          int xpAmount = 0;
          if (!updatedTask.isLate) {
            // Only give XP if task is not late
            if (newStatus == TaskStatus.completed) {
              xpAmount = task.coins; // Full XP for on-time completion
            } else if (newStatus == TaskStatus.notNecessary) {
              xpAmount = task.coins ~/ 2; // Half XP for "not necessary"
            } else if (newStatus == TaskStatus.notDid) {
              xpAmount = task.coins ~/ 4; // Quarter XP for "not did"
            }
          }
          // Late completion gives 0 XP (xpAmount stays 0)

          if (xpAmount > 0) {
            await _userService.addPoints(xpAmount);
          }
        } else if (task.status != TaskStatus.pending && newStatus == TaskStatus.pending) {
          // Reverting to pending - lose XP and coins
          int xpLoss = 0;
          if (task.status == TaskStatus.completed && !task.isLate) {
            xpLoss = task.coins;
          } else if (task.status == TaskStatus.notNecessary) {
            xpLoss = task.coins ~/ 2;
          } else if (task.status == TaskStatus.notDid) {
            xpLoss = task.coins ~/ 4;
          }

          if (xpLoss > 0) {
            await _userService.removePoints(xpLoss);
          }
        }

        // Update streak for the day after task status change
        final updatedTasksForDay = _taskService.getTasksForDay(day);
        await _userService.updateStreakForDay(updatedTasksForDay);
      }

      _loadUserData();
      setState(() {}); // Refresh UI
    } catch (e) {
      if (kDebugMode) print('Error updating task ${task.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar tarefa. Tente novamente.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _taskService.dispose();
    _userService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay ?? _focusedDay;
    final selectedTasks = _getTasksForDay(selectedDay);

    return Scaffold(

      appBar: AppBar(
        title: const Text('Apogee'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _regenerateAllTasks(),
            tooltip: 'Atualizar todas as tarefas',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nv.$_userLevel',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_userPoints XP',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '💰$_userCoins',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '💎$_userDiamonds',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [

          TableCalendar(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mês',
              CalendarFormat.week: 'Semana',
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              // ADICIONE ESTA LINHA:
              formatButtonShowsNext: false, // Diz ao botão para mostrar o texto do formato ATUAL
              
              // Seus outros estilos podem continuar aqui
              formatButtonTextStyle: const TextStyle(color: Colors.white),
              formatButtonDecoration: BoxDecoration(
                color: Colors.deepPurple.shade300,
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            onFormatChanged: (format) {
              // Verificamos se o formato realmente mudou para evitar reconstruções desnecessárias
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              // Builder para dias fora do mês atual
              defaultBuilder: (context, day, focusedDay) {
                if (day.month != focusedDay.month) {
                  return Center(
                    child: Text('${day.day}', style: const TextStyle(color: Colors.grey)),
                  );
                }
                return null;
              },

              // Builder para o dia de hoje
              todayBuilder: (context, day, focusedDay) {
                return Center(
                  child: Container(
                    width: 42.0,
                    height: 42.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.deepPurple.shade300, width: 2),
                    ),
                    child: Center(
                      child: Text('${day.day}', style: const TextStyle(color: Colors.black)),
                    ),
                  ),
                );
              },

              // Builder para o dia selecionado
              selectedBuilder: (context, day, focusedDay) {
                return Center(
                  child: Container(
                    width: 42.0,
                    height: 42.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.shade300,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },

              // Builder para os marcadores de ponto
              markerBuilder: (context, day, events) {
                final tasks = _getTasksForDay(day);
                if (tasks.isEmpty) return null;

                final completedCount = tasks.where((task) => task.status == TaskStatus.completed).length;
                final notNecessaryCount = tasks.where((task) => task.status == TaskStatus.notNecessary).length;
                final finishedCount = completedCount + notNecessaryCount;

                if (finishedCount == 0 && !isSameDay(day, DateTime.now())) return null;

                final percentage = finishedCount / tasks.length;
                Color dayColor;

                if (finishedCount == 0) {
                  dayColor = Colors.red.shade700;
                } else if (percentage < 1.0) {
                  dayColor = Color.lerp(Colors.red.shade700, Colors.green.shade700, percentage)!;
                } else {
                  dayColor = Colors.green.shade700;
                }

                return Container(
                  width: 8.0,
                  height: 24.0,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: dayColor,
                    shape: BoxShape.circle,
                  ),
                );
              },

            ),
          ),


          const Divider(),


          Expanded(
            child: ListView.builder(
              itemCount: selectedTasks.length,
              itemBuilder: (context, index) {
                final task = selectedTasks[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(
                      task.name,
                      style: TextStyle(
                        decoration: task.status == TaskStatus.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: task.status == TaskStatus.completed ? Colors.grey : null,
                      ),
                    ),
                    subtitle: task.status != TaskStatus.pending
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.status.description, style: const TextStyle(fontSize: 12)),
                              if (task.isLate && task.status != TaskStatus.pending)
                                const Text(
                                  '🕐 Atrasada',
                                  style: TextStyle(fontSize: 11, color: Colors.orange),
                                ),
                            ],
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '💰${task.coins}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: task.status == TaskStatus.completed ? Colors.grey : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<TaskStatus>(
                          onSelected: (status) => _updateTaskStatus(task, status, selectedDay),
                          icon: Icon(
                            task.status == TaskStatus.pending ? Icons.radio_button_unchecked :
                            task.status == TaskStatus.completed ? Icons.check_circle :
                            task.status == TaskStatus.notNecessary ? Icons.not_interested :
                            Icons.cancel,
                            color: task.status == TaskStatus.completed ? Colors.green :
                                   task.status == TaskStatus.notNecessary ? Colors.blue :
                                   task.status == TaskStatus.notDid ? Colors.orange :
                                   Colors.grey,
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: TaskStatus.completed,
                              child: ListTile(
                                leading: Icon(Icons.check_circle, color: Colors.green),
                                title: Text('Concluída'),
                                subtitle: Text('Ganhar moedas'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: TaskStatus.notNecessary,
                              child: ListTile(
                                leading: Icon(Icons.not_interested, color: Colors.blue),
                                title: Text('Não necessária'),
                                subtitle: Text('Sem penalidade'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: TaskStatus.notDid,
                              child: ListTile(
                                leading: Icon(Icons.cancel, color: Colors.orange),
                                title: Text('Não fez'),
                                subtitle: Text('Ganhar XP mais tarde'),
                              ),
                            ),
                            const PopupMenuItem(
                              value: TaskStatus.pending,
                              child: ListTile(
                                leading: Icon(Icons.radio_button_unchecked, color: Colors.grey),
                                title: Text('Pendente'),
                                subtitle: Text('Resetar status'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskManagement(),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.settings),
      ),
    );
  }

  Future<void> _regenerateAllTasks() async {
    try {
      await _taskService.regenerateAllDays();
      setState(() {}); // Refresh UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas as tarefas foram atualizadas!')),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error regenerating all tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar tarefas')),
        );
      }
    }
  }

  void _showTaskManagement() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: TaskManagementPage(
            onTasksChanged: () {
              _loadUserData(); // Refresh user data (coins, XP, etc.)
              setState(() {}); // Refresh the calendar view
            },
          ),
        ),
      ),
    );
  }
}