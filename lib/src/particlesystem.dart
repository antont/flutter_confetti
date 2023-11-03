import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import 'package:confetti/src/helper.dart';
import 'package:vector_math/vector_math_64.dart';

import 'enums/blast_directionality.dart';

enum ParticleSystemStatus {
  started,
  finished,
  stopped,
}

class ParticleSystem extends ChangeNotifier {
    ParticleSystemStatus? _particleSystemStatus;

  //instead of list of objects, we have arrays per component
  int arrCount = -1;
  List<ParticlePath> _particlePaths = []; //generate method adds to here when puts data to the arrays too
  late List<vmath.Vector2> arrLocation;
  late List<vmath.Vector2> arrVelocity;
  late List<vmath.Vector2> arrAcceleration;
  late List<vmath.Vector2> arrStartUpForce;
  late List<Color> arrColor;
  late List<double> arrGravity;

  /// A frequency between 0 and 1 to determine how often the emitter
  /// should emit new particles.
  final double _frequency;
  final int _numberOfParticles;
  final double _maxBlastForce;
  final double _minBlastForce;
  final double _blastDirection;
  final BlastDirectionality _blastDirectionality;
  final double _gravity;
  final List<Color>? _colors;
  final Size _minimumSize;
  final Size _maximumSize;
  final double _particleDrag;
  final Path Function(Size size)? _createParticlePath;

  Offset? _particleSystemPosition;
  Size? _screenSize;

  late double _bottomBorder;
  late double _rightBorder;
  late double _leftBorder;

  final Random _rand;

  ParticleSystem({
    required double emissionFrequency,
    required int numberOfParticles,
    required double maxBlastForce,
    required double minBlastForce,
    required double blastDirection,
    required BlastDirectionality blastDirectionality,
    required List<Color>? colors,
    required Size minimumSize,
    required Size maximumSize,
    required double particleDrag,
    required double gravity,
    Path Function(Size size)? createParticlePath,
  }) : assert(maxBlastForce > 0 &&
            minBlastForce > 0 &&
            emissionFrequency >= 0 &&
            emissionFrequency <= 1 &&
            numberOfParticles > 0 &&
            minimumSize.width > 0 &&
            minimumSize.height > 0 &&
            maximumSize.width > 0 &&
            maximumSize.height > 0 &&
            minimumSize.width <= maximumSize.width &&
            minimumSize.height <= maximumSize.height &&
            particleDrag >= 0.0 &&
            particleDrag <= 1 &&
            minimumSize.height <= maximumSize.height),
        assert(gravity >= 0 && gravity <= 1),
        _blastDirection = blastDirection,
        _blastDirectionality = blastDirectionality,
        _gravity = gravity,
        _maxBlastForce = maxBlastForce,
        _minBlastForce = minBlastForce,
        _frequency = emissionFrequency,
        _numberOfParticles = numberOfParticles,
        _colors = colors,
        _minimumSize = minimumSize,
        _maximumSize = maximumSize,
        _particleDrag = particleDrag,
        _rand = Random(),
        _createParticlePath = createParticlePath
        {
          print("[ParticleSystem constructor] initing with $numberOfParticles particles.");
          Color uninitColor = const Color.fromRGBO(1, 1, 1, 1);
          arrLocation = List<vmath.Vector2>.filled(numberOfParticles, vmath.Vector2.zero());
          arrVelocity = List<vmath.Vector2>.filled(numberOfParticles, vmath.Vector2.zero());
          arrAcceleration = List<vmath.Vector2>.filled(numberOfParticles, vmath.Vector2.zero());
          arrStartUpForce = List<vmath.Vector2>.filled(numberOfParticles, vmath.Vector2.zero());
          arrColor = List<Color>.filled(numberOfParticles, uninitColor);
          arrGravity = List<double>.filled(numberOfParticles, 0.0);
        }


  set particleSystemPosition(Offset? position) {
    _particleSystemPosition = position;
  }

  set screenSize(Size size) {
    _screenSize = size;
    _setScreenBorderPositions(); // needs to be called here to only set the borders once
  }

  void stopParticleEmission() {
    _particleSystemStatus = ParticleSystemStatus.stopped;
  }

  void startParticleEmission() {
    _particleSystemStatus = ParticleSystemStatus.started;
  }

  void finishParticleEmission() {
    _particleSystemStatus = ParticleSystemStatus.finished;
  }

  List<ParticlePath> get particlePaths => _particlePaths;

  ParticleSystemStatus? get particleSystemStatus => _particleSystemStatus;

  void update() {
    _clean();
    if (_particleSystemStatus != ParticleSystemStatus.finished) {
      _updateParticles();
    }

    if (_particleSystemStatus == ParticleSystemStatus.started) {
      // If there are no particles then immediately generate particles
      // This also ensures that particles are emitted on the first frame
      if (arrCount == 0) {
        _generateParticles(number: _numberOfParticles);
        return;
      }

      // Determines whether to generate new particles based on the [frequency]
      /* WIP TODO
      final chanceToGenerate = _rand.nextDouble();
      if (chanceToGenerate < _frequency) {
        _particles.addAll(_generateParticles(number: _numberOfParticles));
      }
      */
    }

    /* WIP TODO
    if (_particleSystemStatus == ParticleSystemStatus.stopped &&
        _particles.isEmpty) {
      finishParticleEmission();
      notifyListeners();
    }
    */
  }

  void _setScreenBorderPositions() {
    _bottomBorder = _screenSize!.height * 1.1;
    _rightBorder = _screenSize!.width * 1.1;
    _leftBorder = _screenSize!.width - _rightBorder;
  }

  vmath.Vector2 applyForce(vmath.Vector2 force) {
    //note: doesn't clone anymore, assumes that the param is a clone, like was in drag() already
    final f = force..divide(vmath.Vector2.all(1)); //TODO: _mass));
    return f;
  }

  void arrDrag(List<vmath.Vector2> forces) {
    for (var i = 0; i < arrCount; i++) {
      final velocity = arrVelocity[i];
      final speed = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2));
      final dragMagnitude = _particleDrag * speed * speed;
      final drag = velocity.clone()
        ..multiply(vmath.Vector2.all(-1))
        ..normalize()
        ..multiply(vmath.Vector2.all(dragMagnitude));
      final force = applyForce(drag);
      forces[i] = force;  
    }
  }

  void _updateParticles() {
    final arrCount = arrLocation.length;

    //WIP TODO XXX reuse this
    List<vmath.Vector2> forces = List<vmath.Vector2>.filled(
      arrCount,
      vmath.Vector2.zero(),
      growable: false
    ); 

    arrDrag(forces);

    /* WIP TODO
    if (_timeAlive < 5) {
      _applyStartUpForce();
    }
    if (_timeAlive < 25) {
      _applyWindForceUp();
    }

    _timeAlive += 1;*/

    final gravityVec = vmath.Vector2(0, _gravity);
    for (var i = 0; i < arrCount; i++) {
      //applyForce(vmath.Vector2(0, _gravity));
      forces[i].add(applyForce(gravityVec));
      arrVelocity[i].add(forces[i]);
      arrLocation[i].add(arrVelocity[i]);

      /* TODO WIP
      _aVelocityX += _aAcceleration / _mass;
      _aVelocityY += _aAcceleration / _mass;
      _aVelocityZ += _aAcceleration / _mass;
      _aX += _aVelocityX;
      _aY += _aVelocityY;
      _aZ += _aVelocityZ;*/
    }
  }

  void _clean() {
    if (_particleSystemPosition != null && _screenSize != null) {
/* TODO
      _particles
          .removeWhere((particle) => _isOutsideOfBorder(particle.location));
*/
    }
  }

  bool _isOutsideOfBorder(Offset particleLocation) {
    final globalParticlePosition = particleLocation + _particleSystemPosition!;
    return (globalParticlePosition.dy >= _bottomBorder) ||
        (globalParticlePosition.dx >= _rightBorder) ||
        (globalParticlePosition.dx <= _leftBorder);
  }

  void _generateParticles({int number = 1}) {
    for (var i = 0; i < number; i++) {
        arrLocation[i] = vmath.Vector2.zero();
        arrAcceleration[i] = vmath.Vector2.zero();
        arrVelocity[i] = vmath.Vector2(Helper.randomize(-3, 3), Helper.randomize(-3, 3));
        arrStartUpForce[i] = _generateParticleForce();
        arrColor[i] = _randomColor();
        //arr_size[i] = _randomSize();
        arrGravity[i] = _gravity;
        
        _particlePaths[i] = ParticlePath(_randomSize(), _createParticlePath);
    }
    arrCount = number;
  }

  double get _randomBlastDirection =>
      vmath.radians(Random().nextInt(359).toDouble());

  vmath.Vector2 _generateParticleForce() {
    var blastDirection = _blastDirection;
    if (_blastDirectionality == BlastDirectionality.explosive) {
      blastDirection = _randomBlastDirection;
    }
    final blastRadius = Helper.randomize(_minBlastForce, _maxBlastForce);
    final y = blastRadius * sin(blastDirection);
    final x = blastRadius * cos(blastDirection);
    return vmath.Vector2(x, y);
  }

  Color _randomColor() {
    if (_colors != null) {
      if (_colors!.length == 1) {
        return _colors![0];
      }
      final index = _rand.nextInt(_colors!.length);
      return _colors![index];
    }
    return Helper.randomColor();
  }

  Size _randomSize() {
    return Size(
      Helper.randomize(_minimumSize.width, _maximumSize.width),
      Helper.randomize(_minimumSize.height, _maximumSize.height),
    );
  }
}

class ParticlePath {
  ParticlePath(Size size, Path Function(Size size)? createParticlePath)
  : pathShape = createParticlePath != null
            ? createParticlePath(size)
            : createPath(size);

  final Path pathShape;

  static Path createPath(Size size) {
    final pathShape = Path()
      ..moveTo(0, 0)
      ..lineTo(-size.width, 0)
      ..lineTo(-size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return pathShape;
  }
}

/*
void _applyStartUpForce() {
  applyForce(_startUpForce);
}

void _applyWindForceUp() {
  applyForce(vmath.Vector2(0, -1));
}
*/

/*
  Offset get location {
    if (_location.x.isNaN || _location.y.isNaN) {
      return const Offset(0, 0);
    }
    return Offset(_location.x, _location.y);
  }

  Color get color => _color;
  Path get path => _pathShape;

  double get angleX => _aX;
  double get angleY => _aY;
  double get angleZ => _aZ;
}
*/