import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rainy_road_app/src/alarm_manager.dart';
import 'package:rainy_road_app/src/frosted_glass.dart';
import 'package:rainy_road_app/src/notification_service.dart';
import 'package:rainy_road_app/src/settings.dart';
import 'package:rainy_road_app/src/update.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:core';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:developer' as developer;

Future<void> showNotification(MyAppState appState) async {
  try {
    appState.response = await http.get(Uri.parse(
        '${appState.server}/generate_map?start_location=${appState.startCity}&end_location=${appState.endCity}}'));
    appState.htmlContent = appState.response.body;
    appState.controller.loadHtmlString(appState.htmlContent);
    final colorValues = appState.extractColorValues(appState.htmlContent);
    appState.isColorDifferent = colorValues.any((color) => color != "#00c600");
    String shortNameStartCity = appState.shortName(appState.startCity);
    String shortNameEndCity = appState.shortName(appState.endCity);
    if (appState.isColorDifferent) {
      NotificationService().showNotification("Rainy Road",
          "Haverá chuva no caminho entre $shortNameStartCity e $shortNameEndCity");
    } else {
      NotificationService().showNotification("Rainy Road",
          "Sem chuvas no caminho entre $shortNameStartCity e $shortNameEndCity");
    }
  } catch (error) {
    developer.log(error.toString());
  }
}

@pragma('vm:entry-point')
void setNotification(int id) {
  developer.log("triggered the Alarm");
  MyAppState appState = MyAppState();
  appState.loadSettings().then((_) {
    MyAlarmManager()
        .alarmDateTime(id)
        .then((value) => appState.initAlarm(value, id));
    MyAlarmManager().shouldRunToday(id).then((value) async {
      if (value) {
        developer.log("Running Alarm $id");
        showNotification(appState);
      }
    });
  });
}

main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().initialize();
  runApp(const RainyRoadApp());
}

class RainyRoadApp extends StatelessWidget {
  const RainyRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Rainy Road App ',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MapScreen(),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  MyAppState appState = MyAppState();
  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();

  @override
  initState() {
    super.initState();
    AndroidAlarmManager.initialize();
    UpdateChecker().checkForUpdates(context);
    appState.loadCities();
    appState.loadSettings().then((_) => setState(() {
          _startLocationController.text = appState.startCity;
          _endLocationController.text = appState.endCity;
        }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rainy Road App'),
      ),
      body: Stack(
        children: [
          Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              alignment: Alignment.center,
              child: const Text("")),
          Visibility(
            visible: !appState.isLoading,
            child: WebViewWidget(controller: appState.controller),
          ),
          Visibility(
            visible: !appState.isLoading,
            child: Center(
              child: FrostedGlassBox(
                width: 300.0,
                height: 288.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 230),
                            IconButton(
                                onPressed: () => setState(() {
                                      appState.openSettings(context);
                                    }),
                                icon: const Icon(Icons.settings)),
                          ],
                        ),
                        TypeAheadField(
                          emptyBuilder: (context) =>
                              const Text('Insira o nome da cidade de partida'),
                          builder: (context, controller, focusNode) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Insira uma cidade';
                                }
                                return null;
                              },
                            );
                          },
                          controller: _startLocationController,
                          suggestionsCallback: (pattern) async {
                            if (pattern == '') {
                              return List.empty();
                            }
                            return appState.citiesList.where((String option) {
                              return option
                                  .toLowerCase()
                                  .withoutDiacriticalMarks
                                  .contains(pattern
                                      .toLowerCase()
                                      .withoutDiacriticalMarks);
                            }).toList();
                          },
                          itemBuilder: (context, suggestion) {
                            return ListTile(
                              title: Text(suggestion),
                            );
                          },
                          onSelected: (suggestion) {
                            _startLocationController.text = suggestion;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TypeAheadField(
                            emptyBuilder: (context) => const Text(
                                'Insira o nome da cidade de destino'),
                            builder: (context, controller, focusNode) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Insira outra cidade';
                                  }
                                  return null;
                                },
                              );
                            },
                            controller: _endLocationController,
                            suggestionsCallback: (pattern) async {
                              if (pattern == '') {
                                return List.empty();
                              }
                              return appState.citiesList.where((String option) {
                                return option
                                    .toLowerCase()
                                    .withoutDiacriticalMarks
                                    .contains(pattern
                                        .toLowerCase()
                                        .withoutDiacriticalMarks);
                              }).toList();
                            },
                            itemBuilder: (context, suggestion) {
                              return ListTile(
                                title: Text(suggestion),
                              );
                            },
                            onSelected: (suggestion) {
                              _endLocationController.text = suggestion;
                            }),
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              appState.endCity = _endLocationController.text;
                              appState.startCity =
                                  _startLocationController.text;
                              if (_endLocationController.text ==
                                  _startLocationController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text(
                                        'Digite o nome de cidades diferentes'),
                                  ),
                                );
                              } else {
                                setState(() {});
                                appState
                                    .generateMap(context)
                                    .then((_) => setState(() {}));
                                appState.saveSettings();
                              }
                            }
                          },
                          child: const Text('Gerar mapa'),
                        ),
                        const SizedBox(height: 16.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: appState.isLoading,
            child: const Center(
              child: FrostedGlassBox(
                height: 200.0,
                width: 300.0,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text("Gerando mapa, isso pode levar até um minuto",
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> extractColorValues(String content) {
    final List<String> colorValues = [];
    final RegExp colorRegex = RegExp(r'"color":\s*"#([0-9a-fA-F]{6})"');
    final Iterable<Match> matches = colorRegex.allMatches(content);
    for (var match in matches) {
      if (match.groupCount == 1) {
        colorValues.add("#${match.group(1)}");
      }
    }
    return colorValues;
  }
}

class MyAppState extends ChangeNotifier {
  WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          developer.log(progress.toString());
        },
      ),
    );
  bool isColorDifferent = false;
  bool isLoading = false;
  String startCity = "";
  bool alarmTwoEnabled = false;
  String endCity = "";
  String htmlContent = "";
  String server = "http://";
  List<String> citiesList = List.empty();
  http.Response response = http.Response("", 404);

  void initAlarm(DateTime date, int id) {
    developer.log("Novo alarme $id em : ${date.toString()}");
    AndroidAlarmManager.oneShotAt(
      alarmClock: true,
      date,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
      wakeup: true,
      id,
      setNotification,
    );
  }

  Future<void> loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    alarmTwoEnabled = prefs.getBool("alarmTwoEnabled") ?? false;
    endCity = prefs.getString('end') ?? '';
    startCity = prefs.getString('start') ?? '';
    server = prefs.getString('server') ?? 'http://';
    notifyListeners();
  }

  Future<void> saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('start', startCity);
    prefs.setString('end', endCity);
  }

  Future<void> loadCities() async {
    try {
      const String citiesAssetPath = 'assets/text/cities.txt';
      final String contents = await rootBundle.loadString(citiesAssetPath);
      citiesList = contents.split('\n').map((line) => line.trim()).toList();
    } catch (e) {
      developer.log('Error loading cities: $e');
    }
  }

  Future<void> generateMap(var context) async {
    if (server == "http://") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Você precisa definir o servidor nas configurações'),
        ),
      );
      return;
    }

    isLoading = true;
    notifyListeners();
    try {
      response = await http.get(Uri.parse(
          '$server/generate_map?start_location=$startCity&end_location=$endCity'));
    } catch (error) {
      isLoading = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
              'Erro na conexão com o servidor\n ${error.toString().substring(0, 50)}...'),
        ),
      );
    }
    if (response.statusCode == 200) {
      htmlContent = response.body;
      controller.loadHtmlString(htmlContent);
      final colorValues = extractColorValues(htmlContent);
      isColorDifferent = colorValues.any((color) => color != "#00c600");
      if (isColorDifferent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.amber,
            content: Text('Existe chuva esperada no caminho'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.lightGreen,
            content: Text('Sem chuvas no caminho'),
          ),
        );
      }

      isLoading = false;
      notifyListeners();
    }
    if (response.statusCode == 507) {
      htmlContent = response.body;
      controller.loadHtmlString(htmlContent);
      isLoading = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Servidor sem memória para esta requisição'),
        ),
      );
    }
    notifyListeners();
  }

  void openSettings(var context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      loadSettings();
      MyAlarmManager().alarmDateTime(1).then((value) => initAlarm(value, 1));
      if (alarmTwoEnabled) {
        MyAlarmManager().alarmDateTime(2).then((value) => initAlarm(value, 2));
      }
    });
    notifyListeners();
  }

  List<String> extractColorValues(String content) {
    final List<String> colorValues = [];
    final RegExp colorRegex = RegExp(r'"color":\s*"#([0-9a-fA-F]{6})"');
    final Iterable<Match> matches = colorRegex.allMatches(content);
    for (var match in matches) {
      if (match.groupCount == 1) {
        colorValues.add("#${match.group(1)}");
      }
    }

    return colorValues;
  }

  String shortName(String input) {
    if (input.contains(',')) {
      return input.substring(0, input.indexOf(','));
    } else {
      return input;
    }
  }
}

extension DiacriticsAwareString on String {
  static const diacritics =
      'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËĚèéêëěðČÇçčÐĎďÌÍÎÏìíîïĽľÙÚÛÜŮùúûüůŇÑñňŘřŠšŤťŸÝÿýŽž';
  static const nonDiacritics =
      'AAAAAAaaaaaaOOOOOOOooooooEEEEEeeeeeeCCccDDdIIIIiiiiLlUUUUUuuuuuNNnnRrSsTtYYyyZz';

  String get withoutDiacriticalMarks => splitMapJoin('',
      onNonMatch: (char) => char.isNotEmpty && diacritics.contains(char)
          ? nonDiacritics[diacritics.indexOf(char)]
          : char);
}
