import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class PedometerPage extends StatefulWidget {
  const PedometerPage({Key? key}) : super(key: key);

  @override
  _PedometerPageState createState() => _PedometerPageState();
}

class _PedometerPageState extends State<PedometerPage> {
  int _dailySteps = 0;
  double _distanceKm = 0;
  int _caloriesBurned = 0;
  Duration _activityTime = Duration.zero;
  int _dailyGoal = 10000;

  List<int> _weeklySteps = List.filled(7, 0);
  List<int> _monthlySteps = List.filled(30, 0);

  late Stream<StepCount> _stepCountStream;
  Database? _database;
  bool _isLoading = true;

  void _onReceiveData(Object data) {
    if (data is int && mounted) {
      setState(() {
        _dailySteps = data;
        _distanceKm = _dailySteps * 0.0007;
        _caloriesBurned = (_dailySteps * 0.04).round();
        _activityTime = Duration(minutes: (_dailySteps * 0.01).round());
      });
      _saveStepData();
    }
  }

  Future<void> _requestPermissions() async {
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _initDatabase();
      await _loadSavedData();
      _initPedometer();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pedometer_notification_channel',
        channelName: 'Pedometer Notification',
        channelDescription: 'This notification appears when the pedometer is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),  // Utilisation du constructeur factory nothing()
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }





  Future<void> _startForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: "Podomètre en cours d'exécution",
        notificationText: "Comptage des pas en arrière-plan",
        callback: startCallback,
      );
    }
  }

  void _initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(_onStepCount);
  }

  void _onStepCount(StepCount event) {
    setState(() {
      _dailySteps = event.steps;
      _distanceKm = _dailySteps * 0.0007;
      _caloriesBurned = (_dailySteps * 0.04).round();
      _activityTime = Duration(minutes: (_dailySteps * 0.01).round());
    });
    _saveStepData();
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'pedometer_database.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE steps(date TEXT PRIMARY KEY, count INTEGER)',
        );
      },
    );
  }

  Future<void> _loadSavedData() async {
    if (_database == null) return;

    final prefs = await SharedPreferences.getInstance();
    final dailyGoal = prefs.getInt('dailyGoal') ?? 10000;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final List<int> weeklySteps = List.filled(7, 0);
    final List<int> monthlySteps = List.filled(30, 0);

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      weeklySteps[i] = await _getStepsForDate(date);
    }

    for (int i = 0; i < 30; i++) {
      final date = monthStart.add(Duration(days: i));
      monthlySteps[i] = await _getStepsForDate(date);
    }

    if (mounted) {
      setState(() {
        _dailyGoal = dailyGoal;
        _weeklySteps = weeklySteps;
        _monthlySteps = monthlySteps;
      });
    }
  }

  Future<int> _getStepsForDate(DateTime date) async {
    if (_database == null) return 0;

    final String dateStr = DateFormat('yyyy-MM-dd').format(date);
    final List<Map<String, dynamic>> maps = await _database!.query(
      'steps',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (maps.isNotEmpty) {
      return maps.first['count'] as int;
    }

    return 0;
  }

  Future<void> _saveStepData() async {
    if (_database == null) return;

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _database!.insert(
      'steps',
      {'date': today, 'count': _dailySteps},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Podomètre'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDailyOverview(),
              SizedBox(height: 20),
              _buildWeeklyChart(),
              SizedBox(height: 20),
              _buildMonthlyChart(),
              SizedBox(height: 20),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyOverview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aujourd\'hui',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(Icons.directions_walk, '$_dailySteps', 'Pas'),
                _buildInfoItem(Icons.straighten, '${_distanceKm.toStringAsFixed(2)} km', 'Distance'),
                _buildInfoItem(Icons.local_fire_department, '$_caloriesBurned', 'Calories'),
              ],
            ),
            SizedBox(height: 10),
            Text('Temps d\'activité: ${_activityTime.inHours}h ${_activityTime.inMinutes % 60}min'),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: _dailySteps / _dailyGoal,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 5),
            Text('Objectif: $_dailyGoal pas'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blue),
        SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette semaine',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _weeklySteps.reduce((a, b) => a > b ? a : b).toDouble(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                          return Text(
                            weekDays[value.toInt()],
                            style: const TextStyle(
                              color: Color(0xff7589a2),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _weeklySteps.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ce mois',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value % 5 == 0) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Color(0xff68737d),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  minX: 0,
                  maxX: 29,
                  minY: 0,
                  maxY: _monthlySteps.reduce((a, b) => a > b ? a : b).toDouble() + 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _monthlySteps.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_database == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historique',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _database!.query('steps', orderBy: 'date DESC', limit: 7),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Erreur: ${snapshot.error}');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('Aucune donnée disponible');
                }
                return Column(
                  children: snapshot.data!.map((data) {
                    DateTime date = DateFormat('yyyy-MM-dd').parse(data['date']);
                    int steps = data['count'];
                    double distance = steps * 0.0007;
                    return _buildHistoryItem(date, steps, distance);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(DateTime date, int steps, double distance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(DateFormat('dd/MM/yyyy').format(date)),
          Text('$steps pas'),
          Text('${distance.toStringAsFixed(1)} km'),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveData);
    _initializeApp();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      _initForegroundTask();
      await _startForegroundTask();
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveData);
    FlutterForegroundTask.stopService();
    _database?.close();
    super.dispose();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PedometerTaskHandler());
}

class PedometerTaskHandler extends TaskHandler {
  int _steps = 0;
  StreamSubscription<StepCount>? _stepCountSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _stepCountSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      _steps = event.steps;
      FlutterForegroundTask.updateService(
        notificationTitle: 'Podomètre en cours d\'exécution',
        notificationText: '$_steps pas',
      );
      // Send step count to main isolate
      FlutterForegroundTask.sendDataToMain(_steps);
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Not used as we're using stream
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('Bouton pressé: $id');
  }

  @override
  void onNotificationPressed() {
    print('Notification pressée');
  }
}

