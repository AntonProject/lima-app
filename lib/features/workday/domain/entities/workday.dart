enum WorkdayPhase { notStarted, active, completed }

class DayType {
  final int id;
  final String name;
  final String description;

  const DayType({
    required this.id,
    required this.name,
    required this.description,
  });

  factory DayType.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0;
    return DayType(
      id: id,
      name: '${map['name'] ?? map['title'] ?? ''}'.trim(),
      description: '${map['desc'] ?? map['description'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
}

class WorkdayStatus {
  final bool isStarted;
  final bool isCompleted;
  final String? startTime;
  final String? endTime;
  final int? dayTypeId;
  final String? dayTypeName;
  final bool isLate;
  final String? duration;

  const WorkdayStatus({
    this.isStarted = false,
    this.isCompleted = false,
    this.startTime,
    this.endTime,
    this.dayTypeId,
    this.dayTypeName,
    this.isLate = false,
    this.duration,
  });

  WorkdayPhase get phase {
    if (isStarted && !isCompleted) return WorkdayPhase.active;
    return WorkdayPhase.notStarted;
  }

  factory WorkdayStatus.fromMap(Map<String, dynamic> map) {
    bool toBool(Object? value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = '$value'.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    int? toInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    String? toText(Object? value) {
      final text = '$value'.trim();
      return text.isEmpty || text == 'null' ? null : text;
    }

    return WorkdayStatus(
      isStarted: toBool(map['is_started']),
      isCompleted: toBool(map['is_completed']),
      startTime: toText(map['start_time']),
      endTime: toText(map['end_time']),
      dayTypeId: toInt(map['day_type_id']),
      dayTypeName: toText(map['day_type_name']),
      isLate: toBool(map['is_late']),
      duration: toText(map['duration']),
    );
  }

  WorkdayStatus copyWith({
    bool? isStarted,
    bool? isCompleted,
    String? startTime,
    String? endTime,
    int? dayTypeId,
    String? dayTypeName,
    bool? isLate,
    String? duration,
  }) => WorkdayStatus(
    isStarted: isStarted ?? this.isStarted,
    isCompleted: isCompleted ?? this.isCompleted,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    dayTypeId: dayTypeId ?? this.dayTypeId,
    dayTypeName: dayTypeName ?? this.dayTypeName,
    isLate: isLate ?? this.isLate,
    duration: duration ?? this.duration,
  );

  Map<String, dynamic> toJson() => {
    'is_started': isStarted,
    'is_completed': isCompleted,
    'start_time': startTime,
    'end_time': endTime,
    'day_type_id': dayTypeId,
    'day_type_name': dayTypeName,
    'is_late': isLate,
    'duration': duration,
  };
}

class WorkdayCachedState {
  final bool? featureEnabled;
  final WorkdayStatus? status;
  final List<DayType> dayTypes;

  const WorkdayCachedState({
    this.featureEnabled,
    this.status,
    this.dayTypes = const [],
  });
}

class WorkdayActionResult {
  final bool queued;

  const WorkdayActionResult({required this.queued});
}
