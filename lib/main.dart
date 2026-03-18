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
      title: 'Acelerómetro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 183, 58, 173),
        ),
        useMaterial3: true,
      ),
      home: const AcelerometroPage(title: 'Acelerómetro'),
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
  int numObstacles = 7;
  List<Map<String, double>> obstacles = [];
  double goalX = 0.0;
  double goalY = 0.0;
  double ballX = 0.0;
  double ballY = 0.0;

  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  SharedPreferences? _prefs;

  // Para detectar entrada/salida de colisión
  bool _wasColliding = false;

  // Dimensiones (aumenté un poco el área para mejor jugabilidad)
  final double playWidth = 340.0;
  final double playHeight = 680.0;
  final double ballSize = 28.0;
  final double obsSize = 42.0;
  final double goalSize = 34.0;

  final double sensitivity = 1.1; // un poco más sensible

  @override
  void initState() {
    super.initState();
    _loadHighScore();

    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!_gameRunning) return;

      setState(() {
        x = event.x;
        y = event.y;
        z = event.z;
        orientacion = detectarOrientacion(x, y);

        double dx = (event.x * -1) * sensitivity;
        double dy = event.y * sensitivity;

        double newX = ballX + dx;
        double newY = ballY + dy;

        newX = newX.clamp(0.0, playWidth - ballSize);
        newY = newY.clamp(0.0, playHeight - ballSize);

        // Verificar si la nueva posición colisionaría FUERTE (penetración)
        bool wouldPenetrate = false;
        for (var obs in obstacles) {
          if (_rectsOverlap(
            newX,
            newY,
            ballSize,
            ballSize,
            obs['x']! - 2, // margen pequeño para permitir desliz
            obs['y']! - 2,
            obsSize + 4,
            obsSize + 4,
          )) {
            wouldPenetrate = true;
            break;
          }
        }

        // Permitimos mover si NO penetra más de lo actual
        if (!wouldPenetrate) {
          ballX = newX;
          ballY = newY;
        }

        // Detectar si AHORA está tocando algún obstáculo
        bool nowColliding = false;
        for (var obs in obstacles) {
          if (_rectsOverlap(
            ballX,
            ballY,
            ballSize,
            ballSize,
            obs['x']!,
            obs['y']!,
            obsSize,
            obsSize,
          )) {
            nowColliding = true;
            break;
          }
        }

        // Restamos punto SOLO cuando entra en colisión (de no-colisión → colisión)
        if (nowColliding && !_wasColliding) {
          currentLevelPoints--;
          if (currentLevelPoints <= 0) {
            _triggerGameOver();
          }
        }

        _wasColliding = nowColliding;

        // Meta
        if (_rectsOverlap(
          ballX,
          ballY,
          ballSize,
          ballSize,
          goalX,
          goalY,
          goalSize,
          goalSize,
        )) {
          _completeLevel();
        }
      });
    });
  }

  bool _rectsOverlap(double x1, double y1, double w1, double h1, double x2, double y2, double w2, double h2) {
    return !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1);
  }

  String detectarOrientacion(double x, double y) {
    if (x > 4) return "Izquierda";
    if (x < -4) return "Derecha";
    if (y > 4) return "Arriba";
    if (y < -4) return "Abajo";
    return "Estable";
  }

  Future<void> _loadHighScore() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = _prefs?.getInt('highScore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    await _prefs?.setInt('highScore', highScore);
  }

  void _selectDifficulty(int level) {
    setState(() {
      if (level == 1) {
        numObstacles = 7;
        difficultyName = "Normal";
      } else if (level == 2) {
        numObstacles = 11;
        difficultyName = "Medio";
      } else {
        numObstacles = 16;
        difficultyName = "Dificil";
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
      obstacles.clear();
      _generateNewLevel();
      ballX = playWidth / 2 - ballSize / 2;
      ballY = 50.0;
      _wasColliding = false;
    });
  }

  void _generateNewLevel() {
    final random = math.Random();
    currentLevelPoints = 10;
    obstacles.clear();

    final startX = playWidth / 2 - ballSize / 2;
    final startY = 50.0;

    // Obstáculos
    for (int i = 0; i < numObstacles; i++) {
      int attempts = 0;
      while (attempts < 120) {
        attempts++;
        final ox = random.nextDouble() * (playWidth - obsSize);
        final oy = 100 + random.nextDouble() * (playHeight - 220 - obsSize);

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
    while (attempts < 120) {
      attempts++;
      goalX = random.nextDouble() * (playWidth - goalSize);
      goalY = 140 + random.nextDouble() * (playHeight - 240 - goalSize);

      bool overlap = _rectsOverlap(startX, startY, ballSize, ballSize, goalX, goalY, goalSize, goalSize);

      for (var obs in obstacles) {
        if (_rectsOverlap(goalX, goalY, goalSize, goalSize, obs['x']!, obs['y']!, obsSize, obsSize)) {
          overlap = true;
          break;
        }
      }

      if (!overlap) break;
    }

    _wasColliding = false;
  }

  void _completeLevel() {
    totalScore += currentLevelPoints;
    if (totalScore > highScore) {
      highScore = totalScore;
      _saveHighScore();
    }
    _generateNewLevel();
    ballX = playWidth / 2 - ballSize / 2;
    ballY = 50.0;
  }

  void _triggerGameOver() {
    if (totalScore > highScore) {
      highScore = totalScore;
      _saveHighScore();
    }
    _gameRunning = false;
    _gameOverTriggered = true;
  }

  void _restartLevel() {
    if (totalScore < 5) return;

    setState(() {
      totalScore -= 5;
      _generateNewLevel();
      ballX = playWidth / 2 - ballSize / 2;
      ballY = 50.0;
      _wasColliding = false;
    });
  }

  void _endGame() {
    setState(() {
      _isInMenu = true;
      _gameRunning = false;
      _gameOverTriggered = false;
    });
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
        backgroundColor: const Color.fromARGB(255, 54, 23, 107),
        foregroundColor: Colors.white,
      ),
      body: _isInMenu ? _buildMenu() : _buildGameScreen(),
    );
  }

  Widget _buildMenu() {
    return Container(
      color: const Color.fromARGB(255, 42, 20, 75),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_soccer, size: 90, color: Color.fromARGB(255, 183, 58, 183)),
            const Text('Acelerometro', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 234, 222, 255))),
            const SizedBox(height: 10),
            Text('Record: $highScore', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 40),
            const Text('Elige la dificultad', style: TextStyle(fontSize: 22, color: Colors.white)),
            const SizedBox(height: 20),
            _difficultyButton('Normal', const Color.fromARGB(255, 26, 116, 190), 1, '7 obstaculos'),
            const SizedBox(height: 15),
            _difficultyButton('Medio', const Color.fromARGB(255, 212, 197, 53), 2, '11 obstaculos'),
            const SizedBox(height: 15),
            _difficultyButton('Dificil', const Color.fromARGB(255, 219, 49, 37), 3, '16 obstaculos'),
            const SizedBox(height: 30),
            const Text('Inclina el telefono y\n¡Evita los obstaculos!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white)),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: const Color.fromARGB(255, 70, 25, 136),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Puntos: $totalScore', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Dificultad: $difficultyName', style: const TextStyle(fontSize: 15, color: Colors.white70)),
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              Container(
                color: Colors.black87,
                child: Center(
                  child: Container(
                    width: playWidth,
                    height: playHeight,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 55, 55, 62),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.deepPurpleAccent, width: 6),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 6)],
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
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [Colors.white70, Colors.white], center: Alignment(-0.4, -0.4), radius: 0.9),
                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(3, 5))],
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
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.redAccent.shade700, width: 4),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_gameOverTriggered)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sentiment_dissatisfied, size: 90, color: Colors.redAccent),
                          const SizedBox(height: 20),
                          const Text('¡GAME OVER!', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 16),
                          Text('Puntaje final: $totalScore', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('Récord: $highScore', style: const TextStyle(fontSize: 24, color: Colors.yellowAccent)),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16)),
                            onPressed: () {
                              setState(() {
                                _isInMenu = true;
                                _gameOverTriggered = false;
                              });
                            },
                            child: const Text('Volver al Menú', style: TextStyle(fontSize: 20)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Botones inferiores - fondo NEGRO
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: totalScore >= 5 ? _restartLevel : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                  ),
                ),
                child: const Column(
                  children: [
                    Text('Reiniciar Nivel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('(-5 pts)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _endGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                child: const Text('Terminar Partida', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}