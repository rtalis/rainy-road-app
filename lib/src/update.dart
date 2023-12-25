import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const String repoUrl =
      'https://api.github.com/repos/rtalis/rainy-road-app/releases';

  Future<void> checkForUpdates(BuildContext context) async {
    String currentVersion = "";
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      currentVersion = packageInfo.version;
      try {
        final response = await http.get(Uri.parse(repoUrl));
        if (response.statusCode == 200) {
          final List<dynamic> releases = json.decode(response.body);
          if (releases.isNotEmpty) {
            final latestVersion = releases[0]['tag_name'];
            if (context.mounted) {
              if (_compareVersions(currentVersion, latestVersion) < 0) {
                _showUpdateDialog(context, latestVersion);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching releases: $e');
      }
    } catch (e) {
      debugPrint('Error getting version from package: $e');
    }
  }

  int _compareVersions(String versionA, String versionB) {
    final List<int> a = versionA.split('.').map(int.parse).toList();
    final List<int> b = versionB.split('.').map(int.parse).toList();

    for (int i = 0; i < a.length; i++) {
      if (i >= b.length) return 1;
      if (a[i] < b[i]) return -1;
      if (a[i] > b[i]) return 1;
    }

    if (a.length < b.length) return -1;

    return 0;
  }

  Future<void> _showUpdateDialog(
      BuildContext context, String latestVersion) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Atualização disponível'),
          content: Text(
              'Uma nova versão ($latestVersion) está disponível. Você quer atualizar?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Depois'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(Uri.parse(
                    "https://github.com/rtalis/rainy-road-app/releases/tag/$latestVersion"));
              },
              child: const Text('Atualizar agora'),
            ),
          ],
        );
      },
    );
  }
}
