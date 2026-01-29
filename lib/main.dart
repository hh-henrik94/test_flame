import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyFlame());
}

class MyFlame extends StatelessWidget {
  const MyFlame({super.key});

  final List<String> list = const [
    "Ball 01.png",
    "Ball 02.png",
    "Ball 03.png",
    "Ball 04.png",
    "Ball 05.png",
    "Ball 06.png",
    "Ball 07.png",
    "Ball 08.png",
    "Ball 09.png",
    "Ball 10.png",
    "Ball 11.png",
    "Ball 12.png",
  ];

  final List<String> listBox = const [
    "box_1.png",
    "box_2.png",
    "box_3.png",
    "box_4.png",
    "box_5.png",
    "box_6.png",
    "box_7.png",
    "box_8.png",
    "box_9.png",
  ];

  @override
  Widget build(BuildContext context) {
    MyGame game = MyGame(balls: list, listBoxes: listBox);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          children: [
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height / 1.8,
                child: GameWidget(game: game),
              ),
            ),
            ElevatedButton(
              onPressed: () {
game.requestBall();
                // final random = Random();
                // final x =
                //     MediaQuery.of(context).size.width / 2 +
                //     (random.nextBool() ? -2 : 2);

                // game.addBall(x, 100);
              
              },
              child: Text("VAY ARA"),
            ),
          ],
        ),
      ),
    );
  }
}

class MyGame extends Forge2DGame with TapCallbacks {
  MyGame({required this.balls, required this.listBoxes})
    : super(gravity: Vector2(0, 120));

  final List<String> balls;
  final List<String> listBoxes;
  final _rnd = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.loadAll([...balls, ...listBoxes, 'ball.png', 'sel_ball.png']);

    add(Walls());
    add(HoleComponent(game: this));
  }

  @override
  Color backgroundColor() => Colors.purple;

  int ballsQueue = 0;
  double spawnTimer = 0;
  double spawnInterval = 0.4; 

  @override
  void update(double dt) {
    super.update(dt);

   
  if (ballsQueue > 0) {
    spawnTimer += dt;

    if (spawnTimer >= spawnInterval) {
      spawnTimer -= spawnInterval; // ВАЖНО
      _spawnBall();
      ballsQueue--;
    }}
  }

  void requestBall() {
    ballsQueue++;
  }

  void _spawnBall() {
    final random = Random();
    final centerX = size.x / 2;
    final offset = random.nextBool() ? -2.0 : 2.0;

    addBall(centerX + offset, 80);
  }
  
  void addBall(double x, double y) {
    final asset = balls[_rnd.nextInt(balls.length)];
    add(Ball(position: Vector2(x, y), asset: asset));
  }

  // @override
  // void onTapDown(TapDownEvent event) {
  //   final asset = balls[_rnd.nextInt(balls.length)];
  //   add(Ball(position: event.localPosition, asset: asset));
  // }
}

class HoleComponent extends PositionComponent {
  final MyGame game;

  HoleComponent({required this.game});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4
      ..color = Colors.blue;

    canvas.drawCircle(
      Offset(game.size.x / 2,80),
      game.size.toRect().width / (Walls.startCount * Walls.steps),
      paint,
    );
  }
}

// ======================= BALL =======================

class Ball extends BodyComponent<MyGame> {
  Ball({required this.position, required this.asset});

  final Vector2 position;
  final String asset;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(
      SpriteComponent(
        sprite: Sprite(game.images.fromCache(asset)),
        size: Vector2.all(max(18, game.size.x / (Walls.endCount * 1.5))),
        anchor: Anchor.center,
      ),
    );
  }

  @override
  Body createBody() {
    final r = max(8.0, game.size.x / (Walls.endCount * 4));

    final shape = CircleShape()..radius = r;

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..restitution = 0.6
      ..friction = 0.2;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = position
      ..bullet = true;

    final body = world.createBody(bodyDef);
    body.userData = this;
    body.createFixture(fixtureDef);
    return body;
  }
}

// ======================= WALLS + PEG GRID =======================

class Walls extends BodyComponent<MyGame> {
  // ✅ меняешь ТОЛЬКО это:
  static const int startCount = 3; // верхний ряд
  static const int steps = 8; // сколько рядов вниз

  // ✅ авто:
  static int get endCount => startCount + (steps - 1);

  static const double pegRadius = 6;
  static const double bottomPadding = 40;
  static const double topPadding = 120;

  // если хочешь чтобы прям “в край” — оставляй 0
  static const double wallMargin = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final rect = game.size.toRect();

    final topY = rect.top + topPadding;
    final bottomY = rect.bottom - bottomPadding;

    final height = (bottomY - topY).clamp(0.0, double.infinity);
    final spacingY = steps <= 1 ? 0.0 : height / (steps - 1);

    // доступная ширина "внутри"
    final minXGlobal = rect.left + pegRadius + wallMargin;
    final maxXGlobal = rect.right - pegRadius - wallMargin;
    final fullWidth = (maxXGlobal - minXGlobal).clamp(0.0, double.infinity);

    // базовый spacing по низу (чтобы низ лег ровно)
    final baseSpacingX = endCount <= 1 ? 0.0 : fullWidth / (endCount - 1);

    final centerX = rect.center.dx;

    for (int row = 0; row < steps; row++) {
      final pegsInRow = startCount + row; // 3,4,5...

      final y = topY + row * spacingY;

      if (pegsInRow <= 1) {
        add(Peg(position: Vector2(centerX, y), radius: pegRadius));
        continue;
      }

      // ✅ ключ: ширина ряда считается от baseSpacingX,
      // поэтому границы всех рядов идут по прямой, без “дуги”
      var rowWidth = baseSpacingX * (pegsInRow - 1);

      // на всякий случай clamp (если вдруг огромные значения)
      rowWidth = rowWidth.clamp(0.0, fullWidth);

      final leftX = (centerX - rowWidth / 2).clamp(minXGlobal, maxXGlobal);
      final rightX = (centerX + rowWidth / 2).clamp(minXGlobal, maxXGlobal);

      final effectiveWidth = (rightX - leftX).clamp(0.0, double.infinity);
      final spacingX = effectiveWidth / (pegsInRow - 1);

      for (int col = 0; col < pegsInRow; col++) {
        final x = leftX + col * spacingX;
        add(
          Peg(
            position: Vector2(x, y),
            radius: rect.width / (startCount * steps * pegRadius-10),
          ),
        );
      }
    }
  }

  @override
  Body createBody() {
    // ❌ стены НЕ трогаю (как ты просил)
    final body = world.createBody(BodyDef()..type = BodyType.static);

    final rect = game.size.toRect();
    final shape = EdgeShape();
    final fix = FixtureDef(shape);

    // правая
    shape.set(
      Vector2(rect.topRight.dx, rect.top),
      Vector2(rect.right, rect.bottom),
    );
    body.createFixture(fix);

    // низ
    shape.set(
      Vector2(rect.right, rect.bottom),
      Vector2(rect.left, rect.bottom),
    );
    body.createFixture(fix);

    // левая
    shape.set(
      Vector2(rect.left, rect.bottom),
      Vector2(rect.topLeft.dx, rect.top),
    );
    body.createFixture(fix);

    return body;
  }
}

// ======================= PEG =======================

class Peg extends BodyComponent<MyGame> with ContactCallbacks {
  Peg({required this.position, this.radius = 7});

  final Vector2 position;
  final double radius;

  late final SpriteComponent _spriteComp;
  late final CircleComponent _border;

  bool _hit = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _spriteComp = SpriteComponent(
      sprite: Sprite(game.images.fromCache('ball.png')),
      size: Vector2.all(radius * 2),
      anchor: Anchor.center,
    );

    _border = CircleComponent(
      radius: radius + 3,
      paint: Paint()..color = Colors.transparent,
      anchor: Anchor.center,
    );

    add(_border);
    add(_spriteComp);
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..restitution = 0.3
      ..friction = 0.1;

    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = position;

    final body = world.createBody(bodyDef);
    body.userData = this;
    body.createFixture(fixtureDef);
    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Ball) _flash();
  }

  void _flash() {
    if (_hit) return;
    _hit = true;

    _border.paint.color = const Color(0xFFF971B2);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!isMounted) return;
      _border.paint.color = Colors.transparent;
      _hit = false;
    });
  }
}
