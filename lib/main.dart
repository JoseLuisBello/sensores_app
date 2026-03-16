import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tilt Ball - Física Real',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AcelerometroPage(title: 'Tilt Ball Física'),
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
  // Sensor
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;
  String orientacion = "Estable";

  // Juego
  bool _isInMenu = true;
  bool _gameRunning = false;
  bool _gameOverTriggered = false;

  int totalScore = 0;
  int highScore = 0;
  int currentLevelPoints = 10;

  String difficultyName = "Normal";
  int numObstacles = 4;

  List<Map<String, double>> obstacles = [];
  double goalX = 0.0;
  double goalY = 0.0;

  double ballX = 0.0;
  double ballY = 0.0;
  double ballVX = 0.0;
  double ballVY = 0.0;

  bool _wasCollidingObs = false;
  bool _wasInGoal = false;

  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  SharedPreferences? _prefs;

  // Dimensiones
  final double playWidth = 380.0;
  final double playHeight = 550.0;
  final double ballSize = 35.0;
  final double obsSize = 40.0;
  final double goalSize = 45.0;

  final double accelFactor = 1.85;
  final double friction = 0.935;
  final double bounceFactor = 0.78;

  @override
  void initState() {
    super.initState();
    _loadHighScore();

    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!_gameRunning) return;

      setState(() {
        x = event.x;
        y = event.y;
        z = event.z;
        orientacion = detectarOrientacion(x, y);

        // === FÍSICA REAL ===
        ballVX += (event.x * -1) * accelFactor;
        ballVY += event.y * accelFactor;

        ballVX *= friction;
        ballVY *= friction;

        double newX = ballX + ballVX;
        double newY = ballY + ballVY;

        // --- MOVIMIENTO X ---
        bool hitX = false;
        if (newX < 0) {
          newX = 0;
          ballVX = -ballVX * bounceFactor;
          hitX = true;
        } else if (newX > playWidth - ballSize) {
          newX = playWidth - ballSize;
          ballVX = -ballVX * bounceFactor;
          hitX = true;
        }
        if (!hitX) {
          for (var obs in obstacles) {
            if (_rectsOverlap(newX, ballY, ballSize, ballSize, obs['x']!, obs['y']!, obsSize, obsSize)) {
              ballVX = -ballVX * bounceFactor;
              newX = ballX + ballVX;
              hitX = true;
              break;
            }
          }
        }

        // --- MOVIMIENTO Y ---
        bool hitY = false;
        if (newY < 0) {
          newY = 0;
          ballVY = -ballVY * bounceFactor;
          hitY = true;
        } else if (newY > playHeight - ballSize) {
          newY = playHeight - ballSize;
          ballVY = -ballVY * bounceFactor;
          hitY = true;
        }
        if (!hitY) {
          for (var obs in obstacles) {
            if (_rectsOverlap(newX, newY, ballSize, ballSize, obs['x']!, obs['y']!, obsSize, obsSize)) {
              ballVY = -ballVY * bounceFactor;
              newY = ballY + ballVY;
              hitY = true;
              break;
            }
          }
        }

        ballX = newX.clamp(0.0, playWidth - ballSize);
        ballY = newY.clamp(0.0, playHeight - ballSize);

        // Colisión con obstáculos (descontar punto)
        bool nowCollidingObs = false;
        for (var obs in obstacles) {
          if (_rectsOverlap(ballX, ballY, ballSize, ballSize, obs['x']!, obs['y']!, obsSize, obsSize)) {
            nowCollidingObs = true;
            break;
          }
        }
        if (nowCollidingObs && _wasCollidingObs) {
          currentLevelPoints--;
          if (currentLevelPoints <= 0) {
            _triggerGameOver();
          }
        }
        _wasCollidingObs = nowCollidingObs;

        // Meta (hoyo)
        bool nowInGoal = _rectsOverlap(
            ballX, ballY, ballSize, ballSize, goalX, goalY, goalSize, goalSize);
        if (nowInGoal && !_wasInGoal) {
          _completeLevel();
        }
        _wasInGoal = nowInGoal;
      });
    });
  }

  bool _rectsOverlap(double x1, double y1, double w1, double h1, double x2, double y2, double w2, double h2) {
    return !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1);
  }

  String detectarOrientacion(double x, double y) {
    if (x > -5) return "Izquierda";
    if (x < 5) return "Derecha";
    if (y > 5) return "Arriba";
    if (y < -5) return "Abajo";
    return "Estable";
  }

  Future<void> _loadHighScore() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() => highScore = _prefs?.getInt('highScore') ?? 0);
  }

  Future<void> _saveHighScore() async {
    await _prefs?.setInt('highScore', highScore);
  }

  void _selectDifficulty(int level) {
    setState(() {
      if (level == 1) {
        numObstacles = 4;
        difficultyName = "Normal";
      } else if (level == 2) {
        numObstacles = 7;
        difficultyName = "Medio";
      } else {
        numObstacles = 12;
        difficultyName = "Difícil";
      }
    });
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      _isInMenu = false;
      _gameRunning = true;
      _gameOverTriggered = false;
      totalScore = 0;
      currentLevelPoints = 10;
      ballVX = 0;
      ballVY = 0;
      obstacles.clear();
      _generateNewLevel();
      ballX = playWidth / 2 - ballSize / 2;
      ballY = 40.0;
      _wasCollidingObs = false;
      _wasInGoal = false;
    });
  }

  void _generateNewLevel() {
    final random = math.Random();
    currentLevelPoints = 10;
    obstacles.clear();

    final startX = playWidth / 2 - ballSize / 2;
    final startY = 40.0;

    for (int i = 0; i < numObstacles; i++) {
      int attempts = 0;
      while (attempts < 100) {
        attempts++;
        final ox = random.nextDouble() * (playWidth - obsSize);
        final oy = 80 + random.nextDouble() * (playHeight - obsSize - 170);
        bool overlap = _rectsOverlap(startX, startY, ballSize, ballSize, ox, oy, obsSize, obsSize);
        for (var obs in obstacles) {
          if (_rectsOverlap(ox, oy, obsSize, obsSize, obs['x']!, obs['y']!, obsSize, obsSize)) {
            overlap = true;
            break;
          }
        }
        if (!overlap) {
          obstacles.add({'x': ox, 'y': oy});
          break;
        }
      }
    }

    // Hoyo
    int attempts = 0;
    while (attempts < 100) {
      attempts++;
      goalX = random.nextDouble() * (playWidth - goalSize);
      goalY = 100 + random.nextDouble() * (playHeight - goalSize - 120);
      bool overlap = _rectsOverlap(startX, startY, ballSize, ballSize, goalX, goalY, goalSize, goalSize);
      for (var obs in obstacles) {
        if (_rectsOverlap(goalX, goalY, goalSize, goalSize, obs['x']!, obs['y']!, obsSize, obsSize)) {
          overlap = true;
          break;
        }
      }
      if (!overlap) break;
    }
  }

  void _completeLevel() {
    totalScore += currentLevelPoints;
    if (totalScore > highScore) {
      highScore = totalScore;
      _saveHighScore();
    }
    _generateNewLevel();
    ballX = playWidth / 2 - ballSize / 2;
    ballY = 40.0;
    ballVX = 0;
    ballVY = 0;
    _wasCollidingObs = false;
    _wasInGoal = false;
  }

  void _triggerGameOver() {
    if (totalScore > highScore) {
      highScore = totalScore;
      _saveHighScore();
    }
    _gameRunning = false;
    _gameOverTriggered = true;
  }

  @override
  void dispose() {
    _accelerometerSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isInMenu ? _buildMenu() : _buildGameScreen(),
    );
  }

  Widget _buildMenu() {
    return Container(
      color: Colors.deepPurple.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_soccer, size: 90, color: Colors.deepPurple),
            const Text(
              'TILT BALL',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 10),
            Text(
              'Récord: $highScore',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const Text('Elige dificultad', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 20),
            _difficultyButton('Normal', Colors.green, 1, '4 obstáculos'),
            const SizedBox(height: 15),
            _difficultyButton('Medio', Colors.orange, 2, '7 obstáculos'),
            const SizedBox(height: 15),
            _difficultyButton('Difícil', Colors.red, 3, '12 obstáculos'),
            const SizedBox(height: 30),
            const Text(
              'Inclina el teléfono\n¡Los obstáculos REBOTAN!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyButton(String text, Color color, int level, String subtitle) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => _selectDifficulty(level),
      child: Column(
        children: [
          Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return Stack(
      children: [
        // Contenido normal del juego
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: Colors.deepPurple,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: $totalScore',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Nivel: $currentLevelPoints',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(difficultyName,
                      style: const TextStyle(fontSize: 20, color: Colors.white70)),
                ],
              ),
            ),
            Center(
              child: Container(
                width: playWidth,
                height: playHeight,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.brown, width: 14),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 25, spreadRadius: 5)],
                ),
                child: Stack(
                  children: [
                    // Pelota
                    Positioned(
                      left: ballX,
                      top: ballY,
                      child: Container(
                        width: ballSize,
                        height: ballSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Colors.white, Colors.red, Colors.redAccent],
                            center: Alignment(-0.4, -0.4),
                            radius: 0.8,
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(4, 6))],
                        ),
                      ),
                    ),
                    // Obstáculos
                    for (var obs in obstacles)
                      Positioned(
                        left: obs['x']!,
                        top: obs['y']!,
                        child: Container(
                          width: obsSize,
                          height: obsSize,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade900,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade700, width: 4),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                          ),
                        ),
                      ),
                    // Hoyo
                    Positioned(
                      left: goalX,
                      top: goalY,
                      child: Container(
                        width: goalSize,
                        height: goalSize,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.yellowAccent, width: 7),
                          boxShadow: const [BoxShadow(color: Colors.yellow, blurRadius: 20, spreadRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Orientación: $orientacion',
                      style: const TextStyle(fontSize: 18, color: Colors.deepPurple)),
                  const SizedBox(height: 8),
                  const Text(
                    'Inclina el teléfono • Los obstáculos REBOTAN\n¡No los traspases!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),

        // GAME OVER OVERLAY (CORREGIDO - cubre toda la pantalla)
        if (_gameOverTriggered)
          Positioned.fill(
            child: Container(
              color: Colors.black87.withOpacity(0.92),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gamepad, size: 90, color: Colors.redAccent),
                    const SizedBox(height: 20),
                    const Text(
                      '¡GAME OVER!',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Puntaje final: $totalScore',
                      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Récord: $highScore',
                      style: const TextStyle(fontSize: 26, color: Colors.yellowAccent),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isInMenu = true;
                          _gameOverTriggered = false;
                          totalScore = 0;
                        });
                      },
                      child: const Text('Volver al Menú', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}