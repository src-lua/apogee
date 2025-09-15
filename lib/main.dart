import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/task.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  
  await Hive.initFlutter();
  
  Hive.registerAdapter(TaskAdapter());

  await Hive.openBox('apogee_data');
  
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
  final Box _dataBox = Hive.box('apogee_data');

  CalendarFormat _calendarFormat = CalendarFormat.month;

  int _userPoints = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final List<Task> _dailyTaskTemplate = [
    Task(name: 'Lavar a louça do dia', points: 15),
    Task(name: 'Estudar Programação Competitiva (1h)', points: 40),
    Task(name: 'Limpar e organizar a casa (15 min)', points: 20),
    Task(name: 'Praticar piano (30 min)', points: 30),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _userPoints = _dataBox.get('userPoints', defaultValue: 0);
  }

  List<Task> _getTasksForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final key = normalizedDay.toIso8601String();
    
    final taskData = _dataBox.get(key);

    if (taskData == null) {
      final newTasks = _dailyTaskTemplate
          .map((task) => Task(name: task.name, points: task.points))
          .toList();
      _dataBox.put(key, newTasks);
      return newTasks;
    } else {
      return List<Task>.from(taskData);
    }
  }

  void _toggleTask(Task task, DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final key = normalizedDay.toIso8601String();

    List<Task> tasksForDay = _getTasksForDay(normalizedDay);
    
    final taskIndex = tasksForDay.indexWhere((t) => t.name == task.name);

    if (taskIndex != -1) {
      final isFinished = !tasksForDay[taskIndex].finished;
      tasksForDay[taskIndex].finished = isFinished;
      
      setState(() {
        if (isFinished) {
          _userPoints += task.points;
        } else {
          _userPoints -= task.points;
        }
      });

      _dataBox.put(key, tasksForDay);
      _dataBox.put('userPoints', _userPoints);
    }
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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                '$_userPoints XP',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                final completedCount = tasks.where((task) => task.finished).length;
                if (completedCount == 0 && !isSameDay(day, DateTime.now())) return null;

                final percentage = completedCount / tasks.length;
                Color dayColor;

                if (completedCount == 0) {
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


          Expanded( child: ListView.builder(
            itemCount: selectedTasks.length,
            itemBuilder: (context, index) {
              final task = selectedTasks[index];
              
              return ListTile(
                onTap: () => _toggleTask(task, selectedDay),
                
                leading: Checkbox(
                  value: task.finished,
                  onChanged: (_) => _toggleTask(task, selectedDay),
                ),
                
                title: Text(
                  task.name,
                  style: TextStyle(
                    decoration: task.finished
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: task.finished ? Colors.grey : null,
                  ),
                ),
                
                trailing: Text(
                  '+${task.points} XP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: task.finished ? Colors.grey : null,
                  ),
                ),
              
              );
            },

          )),
        ],
      ),
    );
  }
}