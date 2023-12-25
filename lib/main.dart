import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rainy_road_app/src/frosted_glass.dart';
import 'package:rainy_road_app/src/settings.dart';
import 'package:rainy_road_app/src/update.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:core';

void main() {
  runApp(const RainyRoadApp());
}

class RainyRoadApp extends StatelessWidget {
  const RainyRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool isLoading = false;
  String server = "http://";
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isColorDifferent = false;
  http.Response response = http.Response("", 404);
  List<String> _kOptions = List.empty();

  final TextEditingController _startLocationController =
      TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();
  WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          debugPrint(progress.toString());
        },
      ),
    );

  @override
  void initState() {
    super.initState();
    UpdateChecker().checkForUpdates(context);
    _loadCities();
    _loadSettings();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) => setState(() {
          _loadSettings();
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
            visible: !isLoading,
            child: WebViewWidget(controller: controller),
          ),
          Visibility(
            visible: !isLoading,
            child: Center(
              child: FrostedGlassBox(
                // theWidth is the width of the frostedglass
                theWidth: 300.0,
                // theHeight is the height of the frostedglass
                theHeight: 288.0,
                // theChild is the child of the frostedglass
                theChild: Padding(
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
                                onPressed: _openSettings,
                                icon: const Icon(Icons.settings)),
                          ],
                        ),
                        TypeAheadField(
                          hideOnEmpty: true,
                          builder: (context, controller, focusNode) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Insira uma cidade';
                                }
                                return null; // Return null for valid input
                              },
                            );
                          },
                          controller: _startLocationController,
                          suggestionsCallback: (pattern) async {
                            if (pattern == '') {
                              return List.empty();
                            }
                            return _kOptions.where((String option) {
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
                            builder: (context, controller, focusNode) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Insira uma cidade';
                                  }
                                  return null; // Return null for valid input
                                },
                              );
                            },
                            controller: _endLocationController,
                            suggestionsCallback: (pattern) async {
                              if (pattern == '') {
                                return List.empty();
                              }
                              return _kOptions.where((String option) {
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
                                _generateMap();
                                _saveSettings();
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
            visible: isLoading,
            child: const Center(
              child: FrostedGlassBox(
                theHeight: 200.0,
                theWidth: 300.0,
                theChild: Padding(
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

  Future<void> _generateMap() async {
    if (server == "http://") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Você precisa definir o servidor nas configurações'),
        ),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    String htmlContent = "";
    final startLocation = _startLocationController.text;
    final endLocation = _endLocationController.text;
    try {
      response = await http.get(Uri.parse(
          '$server/generate_map?start_location=$startLocation&end_location=$endLocation'));
    } catch (error) {
      if (context.mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro na conexão com o servidor\n'),
          ),
        );
      }
    }
    if (response.statusCode == 200) {
      setState(() {
        htmlContent = response.body;
      });
      // Check if any color is different from "#3388ff"
      controller.loadHtmlString(htmlContent);
      final colorValues = extractColorValues(htmlContent);
      isColorDifferent = colorValues.any((color) => color != "#00c600");

      if (context.mounted) {
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
      }
      setState(() {
        isLoading = false;
      });
    }
    if (response.statusCode == 507) {
      setState(() {
        htmlContent = response.body;
      });
      controller.loadHtmlString(htmlContent);
      if (context.mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Servidor sem memória para esta requisição'),
          ),
        );
      }
    }
  }

  Future<void> _loadCities() async {
    try {
      const String citiesAssetPath = 'assets/text/cities.txt';
      final String contents = await rootBundle.loadString(citiesAssetPath);
      setState(() {
        _kOptions = contents.split('\n').map((line) => line.trim()).toList();
      });
    } catch (e) {
      debugPrint('Error loading cities: $e');
    }
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _endLocationController.text = prefs.getString('end') ?? '';
      _startLocationController.text = prefs.getString('start') ?? '';
      server = prefs.getString('server') ?? 'http://';
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('start', _startLocationController.text);
    prefs.setString('end', _endLocationController.text);
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
