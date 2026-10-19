class WorkingDay {
  final bool enabled;
  final int fromMinutes;
  final int toMinutes;
  const WorkingDay({this.enabled = false, this.fromMinutes = 540, this.toMinutes = 1020});
  bool get valid => fromMinutes >= 0 && toMinutes <= 1440 && fromMinutes < toMinutes;
  factory WorkingDay.fromMap(Object? value) {
    final data = value is Map ? value : const {};
    return WorkingDay(enabled: data['enabled'] == true, fromMinutes: data['fromMinutes'] is num && (data['fromMinutes'] as num).isFinite ? (data['fromMinutes'] as num).toInt() : 540, toMinutes: data['toMinutes'] is num && (data['toMinutes'] as num).isFinite ? (data['toMinutes'] as num).toInt() : 1020);
  }
  Map<String, dynamic> toMap() => {'enabled': enabled, 'fromMinutes': fromMinutes, 'toMinutes': toMinutes};
  WorkingDay copyWith({bool? enabled, int? fromMinutes, int? toMinutes}) => WorkingDay(enabled: enabled ?? this.enabled, fromMinutes: fromMinutes ?? this.fromMinutes, toMinutes: toMinutes ?? this.toMinutes);
  static const keys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static Map<String, WorkingDay> decode(Object? value) { final map = value is Map ? value : const {}; return {for (final key in keys) key: WorkingDay.fromMap(map[key])}; }
}
