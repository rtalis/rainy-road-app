import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

void main() {
  runApp(const SettingsScreen());
}

enum Calendar { everyDay, workDays, weekEnds }

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  String frequency = '';
  String frequencyTwo = '';
  bool alarmTwoEnabled = false;
  bool repEnabled = false;
  Calendar calendarView = Calendar.everyDay;
  Calendar calendarViewTwo = Calendar.everyDay;

  TimeOfDay selectedTime = TimeOfDay.now();
  TimeOfDay selectedTimeTwo = TimeOfDay.now();
  final TextEditingController _controllerTwo = TextEditingController();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings().then((value) => setState(() {
          _controller.text =
              '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}';
          _controllerTwo.text =
              '${selectedTimeTwo.hour}:${selectedTimeTwo.minute.toString().padLeft(2, '0')}';
        }));
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
            ListTile(
              contentPadding: const EdgeInsets.all(0),
              title: const Text('Habilitar notificações'),
              subtitle: const Text(
                'Defina um horário para notificações automáticas',
              ),
              trailing: Switch(
                thumbIcon: thumbIcon,
                value: repEnabled,
                onChanged: (bool value) {
                  setState(() {
                    Permission.notification.request().then((status) {
                      if (status != PermissionStatus.denied) {
                        if (value == true) {
                          showDisableEnergySavingMessage();
                        }
                        repEnabled = value;
                        setState(() {});
                      }
                    });
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            if (repEnabled) ...[
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Configurações de repetição")),
              const SizedBox(height: 16),
              SegmentedButton<Calendar>(
                segments: const <ButtonSegment<Calendar>>[
                  ButtonSegment<Calendar>(
                      value: Calendar.everyDay,
                      label: Text('Diário'),
                      icon: Icon(Icons.calendar_view_day)),
                  ButtonSegment<Calendar>(
                      value: Calendar.workDays,
                      label: Text('Seg-Sex'),
                      icon: Icon(Icons.calendar_view_week)),
                  ButtonSegment<Calendar>(
                      value: Calendar.weekEnds,
                      label: Text('Sab-Dom'),
                      icon: Icon(Icons.calendar_view_month)),
                ],
                selected: <Calendar>{calendarView},
                onSelectionChanged: (Set<Calendar> newSelection) {
                  setState(() {
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
              if (alarmTwoEnabled) ...[
                const SizedBox(height: 30),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Configurações de segunda repetição")),
                const SizedBox(height: 16),
                SegmentedButton<Calendar>(
                  // Segmented button for the second frequency
                  segments: const <ButtonSegment<Calendar>>[
                    ButtonSegment<Calendar>(
                        value: Calendar.everyDay,
                        label: Text('Diário'),
                        icon: Icon(Icons.calendar_view_day)),
                    ButtonSegment<Calendar>(
                        value: Calendar.workDays,
                        label: Text('Seg-Sex'),
                        icon: Icon(Icons.calendar_view_week)),
                    ButtonSegment<Calendar>(
                        value: Calendar.weekEnds,
                        label: Text('Sab-Dom'),
                        icon: Icon(Icons.calendar_view_month)),
                  ],
                  selected: <Calendar>{calendarViewTwo},
                  onSelectionChanged: (Set<Calendar> newSelection) {
                    setState(() {
                      calendarViewTwo = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  // Text field for the second frequency
                  readOnly: true,
                  decoration:
                      const InputDecoration(label: Text("Selecionar hora")),
                  controller: _controllerTwo,
                  onTap: () => _selectTimeTwo(context),
                ),
              ],
              IconButton(
                  onPressed: () => setState(() {
                        alarmTwoEnabled = !alarmTwoEnabled;
                      }),
                  icon: alarmTwoEnabled
                      ? const Icon(Icons.cancel_outlined)
                      : const Icon(Icons.add_circle_outline)),
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
                Navigator.pop(context);
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
      repEnabled = prefs.getBool('repEnabled') ?? false;
      alarmTwoEnabled = prefs.getBool('alarmTwoEnabled') ?? false;
      frequency = prefs.getString('frequency') ?? "";
      frequencyTwo = prefs.getString('frequencyTwo') ?? "";
      final savedHour = prefs.getInt('selectedHour') ?? TimeOfDay.now().hour;
      final savedMinute =
          prefs.getInt('selectedMinute') ?? TimeOfDay.now().minute;
      final savedHourTwo =
          prefs.getInt('selectedHourTwo') ?? TimeOfDay.now().hour;
      final savedMinuteTwo =
          prefs.getInt('selectedMinuteTwo') ?? TimeOfDay.now().minute;
      selectedTime = TimeOfDay(hour: savedHour, minute: savedMinute);
      selectedTimeTwo = TimeOfDay(hour: savedHourTwo, minute: savedMinuteTwo);

      switch (frequency) {
        case 'everyDay':
          calendarView = Calendar.everyDay;
          break;
        case 'workDays':
          calendarView = Calendar.workDays;
          break;
        case 'weekEnds':
          calendarView = Calendar.weekEnds;
          break;
        // Add more cases if needed
        default:
          calendarView = Calendar.everyDay;
      }
      switch (frequencyTwo) {
        case 'everyDay':
          calendarViewTwo = Calendar.everyDay;
          break;
        case 'workDays':
          calendarViewTwo = Calendar.workDays;
          break;
        case 'weekEnds':
          calendarViewTwo = Calendar.weekEnds;
          break;
        default:
          calendarViewTwo = Calendar.everyDay;
      }
    });
  }

  Future<void> _saveSettings() async {
    switch (calendarView) {
      case Calendar.everyDay:
        frequency = 'everyDay';
        break;
      case Calendar.workDays:
        frequency = 'workDays';
        break;
      case Calendar.weekEnds:
        frequency = 'weekEnds';
        break;
      // Add more cases if needed
      default:
        // Default case if none of the above matches
        frequency = '';
    }
    switch (calendarViewTwo) {
      case Calendar.everyDay:
        frequencyTwo = 'everyDay';
        break;
      case Calendar.workDays:
        frequencyTwo = 'workDays';
        break;
      case Calendar.weekEnds:
        frequencyTwo = 'weekEnds';
        break;
      // Add more cases if needed
      default:
        // Default case if none of the above matches
        frequencyTwo = '';
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      prefs.setBool('repEnabled', repEnabled);
      prefs.setBool('alarmTwoEnabled', alarmTwoEnabled);
      prefs.setString('server', _serverController.text);
      prefs.setString('frequency', frequency);
      prefs.setString('frequencyTwo', frequencyTwo);
      prefs.setInt('selectedHour', selectedTime.hour);
      prefs.setInt('selectedMinute', selectedTime.minute);
      prefs.setInt('selectedHourTwo', selectedTimeTwo.hour);
      prefs.setInt('selectedMinuteTwo', selectedTimeTwo.minute);
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
        _controller.text =
            '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}';
        _saveSettings();
      });
    }
  }

  Future<void> _selectTimeTwo(BuildContext context) async {
    final TimeOfDay picked = (await showTimePicker(
      context: context,
      initialTime: selectedTimeTwo,
    ))!;
    if (picked != selectedTimeTwo) {
      setState(() {
        selectedTimeTwo = picked;
        _controllerTwo.text =
            '${selectedTimeTwo.hour}:${selectedTimeTwo.minute.toString().padLeft(2, '0')}';
        _saveSettings();
      });
    }
  }

  void showDisableEnergySavingMessage() {
    bool energySavingMessageEnabled = false;
    int counter = 5;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Timer t = Timer.periodic(const Duration(seconds: 1), (t) {
              if (counter > 0) {
                counter--;
                setState(() {});
              } else {
                energySavingMessageEnabled = true;
                t.cancel();
              }
            });
            return AlertDialog(
              title: const Text('Atenção'),
              content: SizedBox(
                height: 400,
                width: 400,
                child: Column(
                  children: [
                    const Text(
                        "Devido a economia de energia do Android, é necessário desativar a otimização de energia para este aplicativo."),
                    const SizedBox(height: 20),
                    Image.asset(
                        'assets/images/battery-optmization-disable.gif'),
                  ],
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  style: energySavingMessageEnabled
                      ? ElevatedButton.styleFrom(backgroundColor: Colors.white)
                      : ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  onPressed: energySavingMessageEnabled
                      ? () {
                          t.cancel();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: energySavingMessageEnabled
                      ? const Text("Fechar")
                      : Text("Fechar ($counter)"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
