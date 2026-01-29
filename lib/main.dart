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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: GameWidget(
            game: MyGame(balls: list, listBoxes: listBox),
          ),
        ),
      ),
    );
  }
}

class MyGame extends Forge2DGame with TapCallbacks {
  MyGame({required this.balls, required this.listBoxes}) : super(gravity: Vector2(0, 120));

  final List<String> balls;
  final List<String> listBoxes;
  final _rnd = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ✅ грузим все ассеты (шары + пины)
    await images.loadAll([
      ...balls,
      ...listBoxes,
      'ball.png',
      'sel_ball.png',
      // 'assets/peg_hit.png', // <-- если хочешь менять картинку при касании
    ]);

    add(Walls());
  }

  @override
  Color backgroundColor() => Colors.purple;

  @override
  void onTapDown(TapDownEvent event) {
    final asset = balls[_rnd.nextInt(balls.length)];
    add(Ball(position: event.localPosition, asset: asset));
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
      ..friction = 0.2;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = position
      ..bullet = true; // ✅ чтобы не "пропускал" пины

    final body = world.createBody(bodyDef);
    body.userData = this; // ✅ чтобы пины могли понять "кто ударил"
    body.createFixture(fixtureDef);
    return body;
  }
}

// ======================= WALLS + PEG GRID =======================

class Walls extends BodyComponent<MyGame> {
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final rect = game.size.toRect();

    final top = Vector2(rect.topCenter.dx, rect.top);
    final leftBottom = Vector2(rect.left, rect.bottom);
    final rightBottom = Vector2(rect.right, rect.bottom);

    // ===== красиво: 3..10 =====
    const int startCount = 3;
    const int endCount = 10;
    final int rows = endCount - startCount + 1;

    const double startY = 200;
    const double spacingY = 60;
    const double spacingX = 80;

    const double pegRadius = 6;
    const double extraMargin = 14;

    final bottomY = rect.bottom;
    final height = bottomY - top.y;

    for (int row = 0; row < rows; row++) {
      final y = startY + row * spacingY;
      if (y >= bottomY - (pegRadius + extraMargin)) break;

      final pegsInRow = startCount + row;

      final t = height == 0 ? 0.0 : ((y - top.y) / height).clamp(0.0, 1.0);

      final leftX = top.x + (leftBottom.x - top.x) * t;
      final rightX = top.x + (rightBottom.x - top.x) * t;

      final minX = leftX + pegRadius + extraMargin;
      final maxX = rightX - pegRadius - extraMargin;

      final available = maxX - minX;
      if (available <= 0) continue;

      final neededWidth = (pegsInRow - 1) * spacingX;
      final effectiveSpacingX =
          neededWidth <= available ? spacingX : (available / (pegsInRow - 1));

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
    final body = world.createBody(BodyDef()..type = BodyType.static);

    final rect = game.size.toRect();
    final shape = EdgeShape();
    final fix = FixtureDef(shape);

    // правая наклонная
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

    // левая наклонная
    shape.set(
      Vector2(rect.left, rect.bottom),
      Vector2(rect.topLeft.dx , rect.top),
    );
    body.createFixture(fix);

    return body;
  }
}

// ======================= PEG (image + border on hit) =======================

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

    // Картинка пина
    _spriteComp = SpriteComponent(
      sprite: Sprite(game.images.fromCache('ball.png')),
      size: Vector2.all(radius * 2),
      anchor: Anchor.center,
    );

    // Бордер (ring) — по умолчанию прозрачный
    _border = CircleComponent(
      radius: radius + 3,
      paint: Paint()..color = Colors.transparent,
      anchor: Anchor.center,
    );

    // порядок важен: сначала бордер (сзади), потом картинка
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

    // включаем бордер
    _border.paint.color = Color(0xFFF971B2);

    // если хочешь смену картинки при касании — раскомментируй:
    // _spriteComp.sprite = Sprite(game.images.fromCache('sel_ball.png'));

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!isMounted) return;

      _border.paint.color = Colors.transparent;

      // и обратно вернуть картинку:
      // _spriteComp.sprite = Sprite(game.images.fromCache('assets/peg.png'));

      _hit = false;
    });
  }
}
