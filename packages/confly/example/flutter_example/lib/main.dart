import 'package:confly_flutter_example/confly_example.dart';
import 'package:flutter/material.dart';

ExampleConfig? config;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  config = await ExampleConfig.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confly Flutter Example'),
              const SizedBox(height: 20),
              Text(config.toString()),
            ],
          ),
        ),
      ),
    );
  }
}
