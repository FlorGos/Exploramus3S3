class Schedule {
  DateTime openAt;
  DateTime closeAt;

  Schedule({required this.openAt, required this.closeAt});

  Map<String, dynamic> toJson() {
    return {
      'openAt': openAt.toIso8601String(),
      'closeAt': closeAt.toIso8601String(),
    };
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      openAt: DateTime.parse(json['openAt']),
      closeAt: DateTime.parse(json['closeAt']),
    );
  }
}

class DailySchedule {
  List<Schedule> schedules;

  DailySchedule({required this.schedules});

  Map<String, dynamic> toJson() {
    return {
      'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
    };
  }

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    return DailySchedule(
      schedules: (json['schedules'] as List)
          .map((schedule) => Schedule.fromJson(schedule))
          .toList(),
    );
  }
}

class WeeklySchedule {
  List<DailySchedule> dailySchedules;

  WeeklySchedule({required this.dailySchedules});

  Map<String, dynamic> toJson() {
    return {
      'dailySchedules': dailySchedules.map((dailySchedule) => dailySchedule.toJson()).toList(),
    };
  }

  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    return WeeklySchedule(
      dailySchedules: (json['dailySchedules'] as List)
          .map((dailySchedule) => DailySchedule.fromJson(dailySchedule))
          .toList(),
    );
  }
}

