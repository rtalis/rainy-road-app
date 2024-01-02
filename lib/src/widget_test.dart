import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // Start a timer to enable the button after 3 seconds
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialog with GIF'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            _showPopup(context);
          },
          child: const Text('Show Dialog'),
        ),
      ),
    );
  }

  Future<void> _showPopup(BuildContext context) async {
    bool enabled = false;
    int i = 0;
    const seconds = 5;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Container(
              height: 400,
              width: 400,
              child:
                  Image.asset('assets/images/battery-optmization-disable.gif'),
            ),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () {
                  enabled ? Navigator.of(context).pop() : null;
                },
                style: enabled
                    ? ButtonStyle(
                        surfaceTintColor:
                            const MaterialStatePropertyAll<Color>(Colors.black),
                        textStyle: MaterialStateProperty.all<TextStyle>(
                            const TextStyle(color: Colors.yellow)))
                    : ButtonStyle(
                        textStyle: MaterialStateProperty.all<TextStyle>(
                          const TextStyle(color: Colors.red),
                        ),
                      ),
                child: enabled ? const Text('OK') : Text('$i...'),
              ),
            ],
          );
        },
      );
    }
    while (i < seconds) {
      setState(() {
        i++;
        if (i <= seconds) {
          enabled = true;
        }
      });
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
