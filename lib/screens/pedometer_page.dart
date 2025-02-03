import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_package;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:health/health.dart';

// Create a global Health instance
final health = Health();

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
  bool _authorized = false;
  List<RecordingMethod> recordingMethodsToFilter = [];

  List<int> _weeklySteps = List.filled(7, 0);
  List<int> _monthlySteps = List.filled(30, 0);

  late Stream<StepCount> _stepCountStream;
  Database? _database;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Configure health plugin before use
    health.configure();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveData);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      await _resetStepsAtMidnight(); // Add this line
      await _loadInitialSteps();
      _initForegroundTask();
      await _startForegroundTask();
      await _syncWithHealthApp();
    });
  }

  Future<void> _authorize() async {
    // Request activity recognition permission for step counting
    await Permission.activityRecognition.request();
    await Permission.location.request();

    // Check if we have health permissions
    bool? hasPermissions = await health.hasPermissions([HealthDataType.STEPS]);

    // Request authorization if needed
    if (hasPermissions != null && !hasPermissions) {
      try {
        _authorized = await health.requestAuthorization([HealthDataType.STEPS]);
      } catch (error) {
        print("Exception in authorize: $error");
        _authorized = false;
      }
    } else {
      _authorized = true;
    }
  }

  Future<void> _syncWithHealthApp() async {
    await _authorize();

    if (_authorized) {
      try {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);

        int? healthSteps = await health.getTotalStepsInInterval(
            midnight,
            now,
            includeManualEntry: !recordingMethodsToFilter.contains(RecordingMethod.manual)
        );

        if (healthSteps != null && healthSteps > 0) {
          // Use Health app data as the source of truth
          setState(() {
            _dailySteps = healthSteps;
            _updateDerivedMetrics();
          });
          await _saveStepData();

          // Update the background service with the new value
          FlutterForegroundTask.updateService(
            notificationTitle: 'Pedometer running',
            notificationText: '$_dailySteps steps',
          );
        }
      } catch (error) {
        print("Exception in syncWithHealthApp: $error");
      }
    }
  }

  void _updateDerivedMetrics() {
    _distanceKm = _dailySteps * 0.0007;
    _caloriesBurned = (_dailySteps * 0.04).toInt();
    _activityTime = Duration(minutes: (_dailySteps * 0.01).toInt());
    _updateWeeklyAndMonthlyData();
  }

  void _onReceiveData(Object? data) {
    print('Data received from background service: $data');
    if (data is int && mounted) {
      setState(() {
        // Update _dailySteps only if the new value is greater
        if (data > _dailySteps) {
          _dailySteps = data;
          _updateDerivedMetrics();
        }
      });
      _saveStepData();
      // Sync with Health app to get the most accurate value
      _syncWithHealthApp();
    }
  }

  void _updateWeeklyAndMonthlyData() {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final dayOfMonth = now.day - 1;

    _weeklySteps[todayIndex] = _dailySteps;
    _monthlySteps[dayOfMonth] = _dailySteps;
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.activityRecognition,
      Permission.location,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      await _initializeApp();
    } else {
      await _showPermissionDialog();
    }
  }

  Future<void> _showPermissionDialog() async {
    await showDialog<void>(
      context: context as BuildContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions required'),
          content: Text('This app requires permissions to access activity and location to function properly.'),
          actions: <Widget>[
            TextButton(
              child: Text('Quit'),
              onPressed: () => exit(0),
            ),
            TextButton(
              child: Text('Grant'),
              onPressed: () async {
                Navigator.of(context).pop();
                bool granted = await _checkPermissions();
                if (!granted) {
                  await _showOpenSettingsDialog();
                } else {
                  await _initializeApp();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOpenSettingsDialog() async {
    await showDialog<void>(
      context: context as BuildContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions required'),
          content: Text('You need to grant permissions to use this feature. Do you want to open the app settings?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                exit(0);
              },
            ),
            TextButton(
              child: Text('Open settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await AppSettings.openAppSettings();
                bool granted = await _checkPermissions();
                if (granted) {
                  await _initializeApp();
                } else {
                  exit(0);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.activityRecognition,
      Permission.location,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _initializeApp() async {
    try {
      await _initDatabase();
      await _loadSavedData();
      await _syncWithHealthApp();
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
        eventAction: ForegroundTaskEventAction.nothing(),
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
        notificationTitle: "Pedometer running",
        notificationText: "Counting steps in the background",
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
      _updateDerivedMetrics();
    });
    _saveStepData();
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = path_package.join(databasesPath, 'pedometer_database.db');

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
    final List<int> monthlySteps = List.filled(now.daysInMonth, 0);

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      weeklySteps[i] = await _getStepsForDate(date);
    }

    for (int i = 0; i < now.daysInMonth; i++) {
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

  Future<void> _loadInitialSteps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int savedSteps = prefs.getInt('dailySteps') ?? 0;
    DateTime lastResetTime = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('lastResetTime') ?? DateTime.now().millisecondsSinceEpoch);

    if (DateTime.now().day != lastResetTime.day) {
      // If it's a new day, reset the steps
      savedSteps = 0;
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('lastResetTime', DateTime.now().millisecondsSinceEpoch);
    }

    setState(() {
      _dailySteps = savedSteps;
      _updateDerivedMetrics();
    });
  }

  Future<void> _resetStepsAtMidnight() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lastResetTime = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('lastResetTime') ?? now.millisecondsSinceEpoch
    );

    if (now.day != lastResetTime.day) {
      // Reset steps at midnight
      setState(() {
        _dailySteps = 0;
        _updateDerivedMetrics();
      });
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('lastResetTime', now.millisecondsSinceEpoch);

      // Sync with Health app after reset
      await _syncWithHealthApp();
    }
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
        title: Text('Pedometer'),
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
              'Today',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(Icons.directions_walk, '$_dailySteps', 'Steps'),
                _buildInfoItem(Icons.straighten, '${_distanceKm.toStringAsFixed(2)} km', 'Distance'),
                _buildInfoItem(Icons.local_fire_department, '$_caloriesBurned', 'Calories'),
              ],
            ),
            SizedBox(height: 10),
            Text('Activity time: ${_activityTime.inHours}h ${_activityTime.inMinutes % 60}min'),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: _dailySteps / _dailyGoal,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 5),
            Text('Goal: $_dailyGoal steps'),
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
              'This week',
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
                          const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final now = DateTime.now();
    final daysInMonth = now.daysInMonth;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This month',
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
                          if (value % 5 == 0 && value < daysInMonth) {
                            return Text(
                              (value + 1).toInt().toString(),
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
                  maxX: daysInMonth - 1,
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
              'History',
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
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No data available');
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
          Text(DateFormat('MM/dd/yyyy').format(date)),
          Text('$steps steps'),
          Text('${distance.toStringAsFixed(1)} km'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveData);
    FlutterForegroundTask.stopService();
    _database?.close();
    super.dispose();
  }
}

extension DateTimeExtension on DateTime {
  int get daysInMonth {
    return DateTime(this.year, this.month + 1, 0).day;
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PedometerTaskHandler());
}

class PedometerTaskHandler extends TaskHandler {
  int _steps = 0;
  int _lastReportedSteps = 0;
  DateTime _lastResetTime = DateTime.now();
  StreamSubscription<StepCount>? _stepCountSubscription;
  SharedPreferences? _prefs;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await [Permission.activityRecognition, Permission.location].request();
    _prefs = await SharedPreferences.getInstance();

    // Load saved state
    _steps = _prefs?.getInt('dailySteps') ?? 0;
    _lastResetTime = DateTime.fromMillisecondsSinceEpoch(
      _prefs?.getInt('lastResetTime') ?? DateTime.now().millisecondsSinceEpoch,
    );

    _stepCountSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      final now = DateTime.now();

      // Reset at midnight
      if (now.day != _lastResetTime.day) {
        _steps = 0;
        _lastReportedSteps = 0;
        _lastResetTime = now;
        _prefs?.setInt('lastResetTime', now.millisecondsSinceEpoch);
        _prefs?.setInt('dailySteps', 0);
      }

      // Calculate step difference and update if reasonable
      int stepsDifference = event.steps - _lastReportedSteps;
      if (stepsDifference > 0 && stepsDifference < 100) { // Filter unreasonable jumps
        _steps += stepsDifference;
        _lastReportedSteps = event.steps;
        _prefs?.setInt('dailySteps', _steps);

        // Update notification and main UI
        FlutterForegroundTask.updateService(
          notificationTitle: 'Pedometer running',
          notificationText: '$_steps steps',
        );
        FlutterForegroundTask.sendDataToMain(_steps);
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Implementation of required method
    // Not used as we're using stream-based updates
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('Button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    print('Notification pressed');
  }
}