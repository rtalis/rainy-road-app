import 'dart:convert';
import 'dart:core';
import 'dart:developer' as developer;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rainy_road_app/src/alarm_manager.dart';
import 'package:rainy_road_app/src/frosted_glass.dart';
import 'package:rainy_road_app/src/notification_service.dart';
import 'package:rainy_road_app/src/settings.dart';
import 'package:rainy_road_app/src/update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

Future<void> showNotification(MyAppState appState) async {
  try {
    if (!appState.isServerConfigured ||
        appState.startCity.isEmpty ||
        appState.endCity.isEmpty) {
      developer.log('Servidor ou cidades não configurados. Notificação cancelada.');
      return;
    }

    final html = await appState.fetchMapHtml(
      start: appState.startCity,
      end: appState.endCity,
    );

    appState.htmlContent = html;
    appState.controller.loadHtmlString(appState.htmlContent);
    final colorValues = appState.extractColorValues(appState.htmlContent);
    appState.isColorDifferent = colorValues.any((color) => color != "#00c600");
    String shortNameStartCity = appState.shortName(appState.startCity);
    String shortNameEndCity = appState.shortName(appState.endCity);
    if (appState.isColorDifferent) {
      NotificationService().showNotification(
          "Chuvas - Rainy Road",
          "Haverá chuva no caminho entre $shortNameStartCity e $shortNameEndCity",
          'ic_stat_rr');
    } else {
      NotificationService().showNotification(
          "Sem chuvas - Rainy Road",
          "Sem chuvas no caminho entre $shortNameStartCity e $shortNameEndCity",
          'ic_stat_rr_sun');
    }
  } on MapGenerationException catch (error) {
    developer.log('Falha ao gerar mapa para notificação: ${error.message}');
  } catch (error) {
    developer.log('Erro inesperado na notificação: $error');
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

  void handleClick(int item) {
    switch (item) {
      case 0:
        String texto = """
        Primeiramente defina o servidor nas configurações, ele deve ser compativel com o serviço disponível em: https://github.com/rtalis/rainy-road.

        Coloque a cidade de partida no primeiro campo e a cidade de destino no segundo campo. O Aplicativo irá verificar em vários pontos neste trajeto se existe chuva. 
      
        Você pode definir até dois horários para receber notificações automáticas sobre o ultimo trajeto verificado nas configurações.
      """;
        appState.showMessageDialog(
            "Usando o app",
            Text(
              texto,
              textAlign: TextAlign.justify,
            ),
            0,
            context);

        break;
      case 1:
        showAboutDialog(context: context, children: <Widget>[
          const Center(
              child: Text(
                  "Evitando que você pegue chuvas inesperadas no seu trajeto.")),
          const SizedBox(
            height: 20,
          ),
          const Center(child: Text("Feito por Ronaldo Talison"))
        ]);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rainy Road App'),
        actions: <Widget>[
          PopupMenuButton<int>(
            onSelected: (item) => handleClick(item),
            itemBuilder: (context) => [
              const PopupMenuItem<int>(value: 0, child: Text('Ajuda')),
              const PopupMenuItem<int>(value: 1, child: Text('Sobre')),
            ],
          ),
        ],
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
                height: 228.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 65),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.thunderstorm),
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  appState.endCity =
                                      _endLocationController.text;
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
                                    appState.saveSettings();
                                    appState
                                        .generateMap(
                                          context,
                                          onProgress: () {
                                            if (mounted) {
                                              setState(() {});
                                            }
                                          },
                                        )
                                        .then((_) {
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    });
                                  }
                                }
                              },
                              label: const Text('Verificar rota'),
                            ),
                            const SizedBox(width: 15),
                            IconButton(
                                onPressed: () => setState(() {
                                      appState.openSettings(context);
                                    }),
                                icon: const Icon(Icons.settings))
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: appState.isLoading,
            child: Center(
              child: FrostedGlassBox(
                height: 220.0,
                width: 320.0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        value:/* appState.progressPercent > 0
                            ? appState.progressPercent / 100
                            : */
                             null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        appState.progressStageLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      /*if (appState.progressDetail.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          appState.progressDetail,
                          textAlign: TextAlign.center,
                        ),
                      ],*/
                      if (appState.progressPercent > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${appState.progressPercent.toStringAsFixed(0)}% concluído',
                          textAlign: TextAlign.center,
                        ),
                      ],
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
}

class MapGenerationException implements Exception {
  MapGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MapProgress {
  MapProgress({
    required this.state,
    required this.stage,
    required this.percent,
    required this.detail,
  });

  final String state;
  final String stage;
  final double percent;
  final String detail;
}

typedef ProgressCallback = void Function(MapProgress progress);

class MyAppState extends ChangeNotifier {
  MyAppState() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            developer.log(progress.toString());
          },
        ),
      );
  }

  late final WebViewController controller;
  bool isColorDifferent = false;
  bool isLoading = false;
  String startCity = "";
  bool alarmTwoEnabled = false;
  String endCity = "";
  String htmlContent = "";
  String server = "http://";
  List<String> citiesList = List.empty();
  String progressStage = "";
  String progressDetail = "";
  double progressPercent = 0;

  static const Map<String, String> _stageLabels = {
    "queued": "Tarefa na fila",
    "coordinates": "Buscando coordenadas",
    "memory_check": "Verificando requisitos",
    "graph_primary": "Gerando rota principal",
    "graph_secondary": "Gerando grafo filtrado",
    "graph_full": "Gerando grafo completo",
    "graph_radius": "Gerando grafo por raio",
    "route": "Calculando rota",
    "map": "Renderizando mapa",
    "saving": "Salvando mapa",
    "complete": "Mapa pronto",
    "failed": "Falha na geração",
  };

  bool get isServerConfigured =>
      server.trim().isNotEmpty && server.trim() != 'http://';

  String get progressStageLabel {
    if (progressStage.isEmpty) {
      return 'Preparando requisição';
    }
    return _stageLabels[progressStage] ?? progressStage;
  }

  void showMessageDialog(
      String title, Widget widget, int timeToContinue, BuildContext context) {
    bool allowContinue = true;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            if (timeToContinue > 0) {
              setState(() {
                allowContinue = false;
              });
              Future.delayed(Duration(seconds: timeToContinue)).then((_) {
                allowContinue = true;
                timeToContinue = 0;
                setState(() {});
              });
            }
            return AlertDialog(
              title: Text(title),
              content: widget,
              actions: <Widget>[
                ElevatedButton(
                  style: allowContinue
                      ? ElevatedButton.styleFrom(backgroundColor: Colors.white)
                      : ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  onPressed: allowContinue
                      ? () {
                          Navigator.of(context).maybePop();
                        }
                      : null,
                  child: allowContinue
                      ? const Text("Continuar")
                      : const Text("Aguarde..."),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
    await prefs.reload();
    alarmTwoEnabled = prefs.getBool("alarmTwoEnabled") ?? false;
    endCity = prefs.getString('end') ?? '';
    startCity = prefs.getString('start') ?? '';
    server = prefs.getString('server') ?? 'http://';
    notifyListeners();
  }

  Future<void> saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('start', startCity);
    await prefs.setString('end', endCity);
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

  Future<String> fetchMapHtml({
    String? start,
    String? end,
    ProgressCallback? onProgress,
    Duration pollInterval = const Duration(seconds: 1),
    Duration requestTimeout = const Duration(seconds: 15),
    Duration maxWait = const Duration(minutes: 5),
  }) async {
    final String startLocation = (start ?? startCity).trim();
    final String endLocation = (end ?? endCity).trim();

    if (startLocation.isEmpty || endLocation.isEmpty) {
      throw MapGenerationException(
        'As cidades de origem e destino são obrigatórias.',
      );
    }

    final String baseUrl = _normalizedServerUrl();
    late final Uri requestUri;
    try {
      requestUri = _buildEndpointUri(
        baseUrl,
        'generate_map_v2',
        <String, String>{
          'start_location': startLocation,
          'end_location': endLocation,
        },
      );
    } catch (error) {
      throw MapGenerationException('Servidor inválido: $error');
    }

    http.Response response;
    try {
      response = await http.get(requestUri).timeout(requestTimeout);
    } catch (error) {
      throw MapGenerationException('Erro ao conectar ao servidor: $error');
    }

    if (response.statusCode != 202) {
      final String message = _extractErrorMessage(response.body) ??
          'Erro ao iniciar a geração do mapa (código ${response.statusCode}).';
      throw MapGenerationException(message);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw MapGenerationException(
          'Resposta inválida ao iniciar a geração do mapa.');
    }
    final String? taskId = (decoded is Map && decoded['task_id'] != null)
        ? decoded['task_id'].toString()
        : null;
    if (taskId == null || taskId.isEmpty) {
      throw MapGenerationException(
          'Resposta inválida do servidor: task_id ausente.');
    }

    final DateTime deadline = DateTime.now().add(maxWait);

    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw MapGenerationException(
            'Tempo limite excedido ao gerar o mapa.');
      }

      http.Response progressResponse;
      try {
        progressResponse = await http
            .get(_buildEndpointUri(baseUrl, 'progress/$taskId'))
            .timeout(requestTimeout);
      } catch (error) {
        throw MapGenerationException('Erro ao consultar progresso: $error');
      }

    if (progressResponse.statusCode != 200) {
      final String message = _extractErrorMessage(progressResponse.body) ??
          'Erro ao consultar progresso (código ${progressResponse.statusCode}).';
      throw MapGenerationException(message);
    }

      final dynamic progressBody;
      try {
        progressBody = jsonDecode(progressResponse.body);
      } catch (_) {
        throw MapGenerationException(
            'Resposta inválida ao consultar o progresso.');
      }
      if (progressResponse.statusCode != 200) {
        throw MapGenerationException(progressBody['detail']);        
      }
      final MapProgress progress = MapProgress(
        state: progressBody is Map && progressBody['state'] != null
            ? progressBody['state'].toString()
            : '',
        stage: progressBody is Map && progressBody['stage'] != null
            ? progressBody['stage'].toString()
            : '',
        percent: _parsePercent(progressBody is Map ? progressBody['percent'] : null),
        detail: progressBody is Map && progressBody['detail'] != null
            ? progressBody['detail'].toString()
            : '',
      );

      onProgress?.call(progress);

      if (progress.state == 'SUCCESS') {
        http.Response resultResponse;
        try {
          resultResponse = await http
              .get(_buildEndpointUri(baseUrl, 'result/$taskId'))
              .timeout(requestTimeout);
        } catch (error) {
          throw MapGenerationException('Erro ao baixar o mapa: $error');
        }

        if (resultResponse.statusCode != 200) {
          final String message = _extractErrorMessage(resultResponse.body) ??
              'Erro ao baixar mapa (código ${resultResponse.statusCode}).';
          throw MapGenerationException(message);
        }

        return resultResponse.body;
      }

      if (progress.state == 'FAILURE' || progress.stage == 'failed') {
        final String message = progress.detail.isNotEmpty
            ? progress.detail
            : 'Falha ao gerar o mapa.';
        throw MapGenerationException(message);
      }

      await Future.delayed(pollInterval);
    }
  }

  Future<void> generateMap(BuildContext context,
      {VoidCallback? onProgress}) async {
    if (!isServerConfigured) {
      _showSnackBar(
        context,
        'Você precisa definir o servidor nas configurações',
        Colors.red,
      );
      return;
    }

    final String normalizedStart = startCity.trim();
    final String normalizedEnd = endCity.trim();
    if (normalizedStart.isEmpty || normalizedEnd.isEmpty) {
      _showSnackBar(
        context,
        'Informe cidades válidas para iniciar a rota',
        Colors.red,
      );
      return;
    }

    if (normalizedStart.toLowerCase() == normalizedEnd.toLowerCase()) {
      _showSnackBar(
        context,
        'Digite o nome de cidades diferentes',
        Colors.red,
      );
      return;
    }

    isLoading = true;
    progressStage = 'queued';
    progressDetail = 'Tarefa enviada para processamento';
    progressPercent = 0;
    notifyListeners();
    onProgress?.call();

    try {
      final String html = await fetchMapHtml(onProgress: (progress) {
        progressStage = progress.stage;
        progressDetail = progress.detail;
        progressPercent = progress.percent;
        notifyListeners();
        onProgress?.call();
      });

      htmlContent = html;
      controller.loadHtmlString(htmlContent);
      final List<String> colorValues = extractColorValues(htmlContent);
      isColorDifferent = colorValues.any((color) => color != "#00c600");
      notifyListeners();
      onProgress?.call();

      _showSnackBar(
        context,
        isColorDifferent
            ? 'Existe chuva esperada no caminho'
            : 'Sem chuvas no caminho',
        isColorDifferent ? Colors.amber : Colors.lightGreen,
      );
    } on MapGenerationException catch (error) {
      _showSnackBar(context, error.message, Colors.red);
    } catch (error) {
      _showSnackBar(
        context,
        'Erro ao gerar mapa: ${_truncate(error.toString(), 120)}',
        Colors.red,
      );
    } finally {
      isLoading = false;
      progressStage = '';
      progressDetail = '';
      progressPercent = 0;
      notifyListeners();
      onProgress?.call();
    }
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
    }
    return input;
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  String _normalizedServerUrl() {
    var value = server.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Uri _buildEndpointUri(String base, String segment,
      [Map<String, String>? queryParameters]) {
    final Uri baseUri = Uri.parse(base);
    final String combinedPath;
    if (baseUri.path.isEmpty || baseUri.path == '/') {
      combinedPath = segment;
    } else if (baseUri.path.endsWith('/')) {
      combinedPath = '${baseUri.path}$segment';
    } else {
      combinedPath = '${baseUri.path}/$segment';
    }
    return baseUri.replace(path: combinedPath, queryParameters: queryParameters);
  }

  String? _extractErrorMessage(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded['detail'] is String) {
        return decoded['detail'];
      }
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      } else {
        return decoded['detail'];
      }
    } catch (_) {
      // conteúdo não JSON, usa texto bruto
    }
    return _truncate(body, 200);
  }

  double _parsePercent(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final double? parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
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
