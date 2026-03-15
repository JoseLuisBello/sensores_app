import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba Acelerometro',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AcelerometroPage(title: 'Prueba'),
    );
  }
}

class AcelerometroPage extends StatefulWidget {
  const AcelerometroPage({super.key, required this.title});

  final String title;

  @override
  State<AcelerometroPage> createState() => _AcelerometroPageState();
}

class _AcelerometroPageState extends State<AcelerometroPage> {
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
  String orientacion = "Sin movimientos";

  @override
  void initState() {
    super.initState();
    accelerometerEventStream().listen((AccelerometerEvent event) {
      x = event.x;
      y = event.y;
      z = event.z;
      orientacion = detectarOrientacion(x, y);
      setState(() {
        
      });
    });
  }

  String detectarOrientacion(double x, double y) {
    if (x > 4) {
      return "Inclinacion a la izquierda";
    } else if (x < -4) {
      return "Inclinacion a la derecha";
    } else if (y > 4) {
      return "Inclinacion a la izquierda";
    } else if (y < -4) {
      return "Inclinacion a la derecha";
    }
    return "Dipositivo estable";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            Text("X: ${x.toStringAsFixed(2)}", style: TextStyle(fontSize: 20)),
            Text("Y: ${y.toStringAsFixed(2)}", style: TextStyle(fontSize: 20)),
            Text("Z: ${z.toStringAsFixed(2)}", style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            Text("Orientacion"),
            Text(
              orientacion,
              style: TextStyle(fontSize: 25, color: Colors.purple),
            ),
          ],
        ),
      ),
    );
  }
}
