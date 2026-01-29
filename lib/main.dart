import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/body_component.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_forge2d/forge2d_game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyFlame());
}

class MyFlame extends StatefulWidget {
  const MyFlame({super.key});

  @override
  State<MyFlame> createState() => _MyFlameState();
}

class _MyFlameState extends State<MyFlame> {
  // late MyGame game;

  @override
  void initState() {
    // game = MyGame();
    super.initState();
  }

  List<String> list = [
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            Center(
              child: GameWidget(game: MyGame(balls: list)),
            ),
          ],
        ),
      ),
    );
  }
}

class MyGame extends Forge2DGame with TapCallbacks {
  List<String>? balls;
  MyGame({required this.balls}) : super(gravity: Vector2(0, 100));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    images.loadAll(balls!);
    add(Walls());
  }

  @override
  Color backgroundColor() => Colors.purple;

  @override
  void onTapDown(TapDownEvent event) {
    add(Ball(position: event.localPosition, imagesAssets: balls!));
  }
}

class Ball extends BodyComponent {
  @override
  final Vector2 position;
  List<String> imagesAssets;
  Ball({required this.position, required this.imagesAssets});
  static final Random _random = Random();
  late final String selectedAsset;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    selectedAsset = imagesAssets[_random.nextInt(imagesAssets.length)];
    add(
      SpriteComponent(
        sprite: Sprite(game.images.fromCache(selectedAsset)),
        size: Vector2.all(32),
        anchor: Anchor.center,
      ),
    );
  }

  @override
  Body createBody() {
    final shape = CircleShape()..radius = 12;
    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..restitution = 0.6
      ..friction = 0.2
      ..isSensor = false
      ..userData = this
      ..shape = shape;
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = position;
    final body = world.createBody(bodyDef);
    body.createFixture(fixtureDef);
    return body;
  }
}

class Walls extends BodyComponent<MyGame> {
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  @override
Future<void> onLoad() async {
  await super.onLoad();

  final rect = game.size.toRect();

  // Треугольник (как у тебя)
  final top = Vector2(rect.topCenter.dx, rect.top);
  final leftBottom = Vector2(rect.left, rect.bottom);
  final rightBottom = Vector2(rect.right, rect.bottom);

  // ==== НАСТРОЙКИ ====
  final int startCount = 3; // ✅ первый ряд: 3 точки
  final int endCount = 10;  // ✅ последний ряд: 10 точек
  final int rows = (endCount - startCount + 1); // 3..10 => 8 рядов (как на фото)

  final double startY = 200;   // где начинается верхний ряд
  final double spacingY = 60;  // расстояние между рядами
  final double spacingX = 80;  // расстояние между точками

  final double pegRadius = 2;
  final double extraMargin = 7; // отступ от стен, чтобы “красиво”

  final bottomY = rect.bottom;
  final height = bottomY - top.y;

  for (int row = 0; row < rows; row++) {
    final y = startY + row * spacingY;

    if (y >= bottomY - (pegRadius + extraMargin)) break;

    // Сколько точек в этом ряду: 3,4,5,...,10
    final int pegsInRow = startCount + row;

    // t: 0 (верх) .. 1 (низ)
    final t = height == 0 ? 0.0 : ((y - top.y) / height).clamp(0.0, 1.0);

    // границы треугольника на высоте y
    final leftX = top.x + (leftBottom.x - top.x) * t;
    final rightX = top.x + (rightBottom.x - top.x) * t;

    // внутренняя зона для центров пинов
    final margin = pegRadius + extraMargin;
    final minX = leftX + margin;
    final maxX = rightX - margin;

    final available = maxX - minX;
    if (available <= 0) continue;

    // если ряд не помещается — уменьшаем spacingX (чтобы всё равно было N точек)
    final neededWidth = (pegsInRow - 1) * spacingX;
    final double effectiveSpacingX =
        neededWidth <= available ? spacingX : (available / (pegsInRow - 1));

    // центрируем ряд
    final totalWidth = (pegsInRow - 1) * effectiveSpacingX;
    final startX = (minX + maxX) / 2 - totalWidth / 2;

    for (int col = 0; col < pegsInRow; col++) {
      final x = startX + col * effectiveSpacingX;
      add(Peg(position: Vector2(x, y), radius: pegRadius));
    }
  }
}


  @override
  Body createBody() {
    final bodyDef = BodyDef()..type = BodyType.static;
    final body = world.createBody(bodyDef);

    final rect = game.size.toRect();
    final shape = EdgeShape();
    final fix = FixtureDef(shape);

    // верхняя линия (у тебя была)
    shape.set(
      Vector2(rect.topLeft.dx, rect.topLeft.dy),
      Vector2(rect.topRight.dx, rect.topRight.dy),
    );
    body.createFixture(fix);

    // правая наклонная
    shape.set(
      Vector2(rect.topCenter.dx+50, rect.top),
      Vector2(rect.right, rect.bottom),
    );
    body.createFixture(fix);

    // низ
    shape.set(
      Vector2(rect.right, rect.bottom),
      Vector2(rect.left, rect.bottom),
    );
    body.createFixture(fix);

    // левая наклонная
    shape.set(
      Vector2(rect.left, rect.bottom),
      Vector2(rect.topCenter.dx-50, rect.top),
    );
    body.createFixture(fix);

    return body;
  }
}


class Peg extends BodyComponent {
  Peg({required this.position, this.radius = 6});

  final Vector2 position;
  final double radius;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..restitution =
          0.3 // можно 0.2-0.6 по вкусу
      ..friction = 0.1;

    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = position;

    final body = world.createBody(bodyDef);
    body.createFixture(fixtureDef);
    return body;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(
      CircleComponent(
        radius: radius,
        paint: Paint()..color = Colors.white,
        anchor: Anchor.center,
      ),
    );
  }
}
