import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

void main() {
  runApp(const SettingsScreen());
}

enum Calendar { everyday, workweek, weekend }

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool everyday = false;
  bool workweek = false;
  bool weekend = false;
  bool enableRepSettings = false;
  Calendar calendarView = Calendar.everyday;
  TimeOfDay selectedTime = TimeOfDay.now();
  final TextEditingController _controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadSettings();
    setState(() {
      _controller.text = '${selectedTime.hour}:${selectedTime.minute}';
    });
  }

  final MaterialStateProperty<Icon?> thumbIcon =
      MaterialStateProperty.resolveWith<Icon?>(
    (Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Icon(Icons.check);
      }
      return const Icon(Icons.close);
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("Configurações de servidor")),
            TextFormField(
                controller: _serverController,
                decoration: const InputDecoration(label: Text("Endereço"))),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Habilitar repetições"),
                Switch(
                  thumbIcon: thumbIcon,
                  value: enableRepSettings,
                  onChanged: (bool value) {
                    setState(() {
                      enableRepSettings = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (enableRepSettings) ...[
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Configurações de repetição")),
              const SizedBox(height: 16),
              SegmentedButton<Calendar>(
                segments: const <ButtonSegment<Calendar>>[
                  ButtonSegment<Calendar>(
                      value: Calendar.everyday,
                      label: Text('Diário'),
                      icon: Icon(Icons.calendar_view_day)),
                  ButtonSegment<Calendar>(
                      value: Calendar.workweek,
                      label: Text('Seg-Sex'),
                      icon: Icon(Icons.calendar_view_week)),
                  ButtonSegment<Calendar>(
                      value: Calendar.weekend,
                      label: Text('Sab-Dom'),
                      icon: Icon(Icons.calendar_view_month)),
                ],
                selected: <Calendar>{calendarView},
                onSelectionChanged: (Set<Calendar> newSelection) {
                  setState(() {
                    // By default there is only a single segment that can be
                    // selected at one time, so its value is always the first
                    // item in the selected set.
                    calendarView = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                readOnly: true,
                decoration:
                    const InputDecoration(label: Text("Selecionar hora")),
                controller: _controller,
                onTap: () => _selectTime(context),
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              child: const Text("Salvar"),
              onPressed: () {
                _saveSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.lightGreen,
                    content: Text('Configurações salvas'),
                  ),
                );
                Future.delayed(const Duration(seconds: 3)).then(
                  (_) => Navigator.pop(context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverController.text = prefs.getString('server') ?? "http://";
      enableRepSettings = prefs.getBool('enableRepSettings') ?? false;
      everyday = prefs.getBool('everyday') ?? false;
      weekend = prefs.getBool('weekend') ?? false;
      workweek = prefs.getBool('workweek') ?? false;
      final savedHour = prefs.getInt('selectedHour') ?? TimeOfDay.now().hour;
      final savedMinute =
          prefs.getInt('selectedMinute') ?? TimeOfDay.now().minute;
      selectedTime = TimeOfDay(hour: savedHour, minute: savedMinute);
    });
  }

  Future<void> _saveSettings() async {
    if (calendarView == Calendar.everyday) {
      everyday = true;
    } else if (calendarView == Calendar.workweek) {
      workweek = true;
    } else if (calendarView == Calendar.weekend) {
      weekend = true;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      prefs.setBool('enableRepSettings', enableRepSettings);
      prefs.setString('server', _serverController.text);
      prefs.setBool('everyday', everyday);
      prefs.setBool('weekend', weekend);
      prefs.setBool('workweek', workweek);
      prefs.setInt('selectedHour', selectedTime.hour);
      prefs.setInt('selectedMinute', selectedTime.minute);
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay picked = (await showTimePicker(
      context: context,
      initialTime: selectedTime,
    ))!;
    if (picked != selectedTime) {
      setState(() {
        selectedTime = picked;
        _controller.text = '${selectedTime.hour}:${selectedTime.minute}';
        _saveSettings();
      });
    }
  }
}
