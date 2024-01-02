import 'package:shared_preferences/shared_preferences.dart';

class MyAlarmManager {
  Future<DateTime> alarmDateTime(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final now = DateTime.now();
    String workHour = "";
    String workMinute = "";
    if (id == 1) {
      workHour = "selectedHour";
      workMinute = "selectedMinute";
    } else {
      workHour = "selectedHourTwo";
      workMinute = "selectedMinuteTwo";
    }

    final selectedHour = prefs.getInt(workHour) ?? now.hour;
    final selectedMinute = prefs.getInt(workMinute) ?? now.minute;
    DateTime selectedTime =
        DateTime(now.year, now.month, now.day, selectedHour, selectedMinute);
    if (selectedTime.isBefore(now)) {
      selectedTime = DateTime(
          now.year, now.month, now.day + 1, selectedHour, selectedMinute);
    }
    return selectedTime;
  }

  Future<bool> shouldRunToday(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    String work = "";
    if (id == 1) {
      work = "frequency";
    } else {
      work = "frequencyTwo";
    }
    final now = DateTime.now();
    final frequency = prefs.getString(work) ?? "";
    final activated = prefs.getBool('repEnabled') ?? false;
    if (activated) {
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
    }
    return false;
  }
}
