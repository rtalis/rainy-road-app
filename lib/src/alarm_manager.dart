import 'package:shared_preferences/shared_preferences.dart';

class MyAlarmManager {
  Future<DateTime> alarmDateTime() async {
    final now = DateTime.now();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final selectedHour = prefs.getInt('selectedHour') ?? now.hour;
    final selectedMinute = prefs.getInt('selectedMinute') ?? now.minute;

    DateTime selectedTime =
        DateTime(now.year, now.month, now.day, selectedHour, selectedMinute);
    if (selectedTime.isBefore(now)) {
      selectedTime = DateTime(
          now.year, now.month, now.day + 1, selectedHour, selectedMinute);
    }
    return selectedTime;
  }

  Future<bool> shouldRunToday() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final frequency = prefs.getString('frequency') ?? "";
    switch (frequency) {
      case "everyDay":
        return true;
      case "workDays":
        if (now.weekday >= 1 && now.weekday <= 5) {
          return true;
        }
      case "weekEnds":
        if (now.weekday >= 6 && now.weekday <= 7) {
          return true;
        } // Add more cases if needed
      default:
        return false;
    }
    return false;
  }
}
