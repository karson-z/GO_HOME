/// Small value types for authored game transforms, backed by vector_math.
/// Rendering and GPU resources are owned exclusively by Flutter Scene.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

class Vector2 extends vm.Vector2 {
  Vector2([double x = 0, double y = 0]) : super.zero() {
    setValues(x, y);
  }
  @override
  Vector2 clone() => Vector2(x, y);
}

class Vector3 extends vm.Vector3 {
  Vector3([double x = 0, double y = 0, double z = 0]) : super.zero() {
    setValues(x, y, z);
  }
  @override
  Vector3 clone() => Vector3(x, y, z);
  @override
  Vector3 setFrom(vm.Vector3 other) {
    super.setFrom(other);
    return this;
  }

  Vector3 setScalar(double v) {
    setValues(v, v, v);
    return this;
  }

  Vector3 multiplyScalar(double v) {
    scale(v);
    return this;
  }

  @override
  Vector3 sub(vm.Vector3 arg) {
    super.sub(arg);
    return this;
  }

  Vector3 lerp(vm.Vector3 v, double t) {
    x += (v.x - x) * t;
    y += (v.y - y) * t;
    z += (v.z - z) * t;
    return this;
  }

  @override
  Vector3 applyMatrix4(vm.Matrix4 arg) {
    applyProjection(arg);
    return this;
  }

  Vector3 setFromMatrixPosition(vm.Matrix4 m) {
    setValues(m.storage[12], m.storage[13], m.storage[14]);
    return this;
  }

  Vector3 project(dynamic camera) {
    camera.updateMatrixWorld();
    applyMatrix4(camera.matrixWorldInverse as vm.Matrix4);
    applyMatrix4(camera.projectionMatrix as vm.Matrix4);
    return this;
  }

  List<double> toList() => [x, y, z];
}

class Vector4 extends vm.Vector4 {
  Vector4([double x = 0, double y = 0, double z = 0, double w = 1])
    : super.zero() {
    setValues(x, y, z, w);
  }
  @override
  Vector4 clone() => Vector4(x, y, z, w);
  @override
  Vector4 applyMatrix4(vm.Matrix4 arg) {
    arg.transform(this);
    return this;
  }
}

class Matrix3 extends vm.Matrix3 {
  Matrix3.identity() : super.zero() {
    setIdentity();
  }
}

class Matrix4 extends vm.Matrix4 {
  Matrix4.identity() : super.zero() {
    setIdentity();
  }
  Matrix4.fromList(List<double> values) : super.zero() {
    storage.setAll(0, values);
  }
  @override
  Matrix4 clone() => Matrix4.fromList(storage);
  @override
  Matrix4 operator *(dynamic arg) =>
      Matrix4.fromList((super * arg as vm.Matrix4).storage);
  Matrix4 fromNativeArray(List<double> values, [int offset = 0]) {
    for (var i = 0; i < 16; i++) {
      storage[i] = values[i + offset];
    }
    return this;
  }

  Matrix4 multiply2(vm.Matrix4 a, vm.Matrix4 b) {
    setFrom(a);
    multiply(b);
    return this;
  }

  Matrix4 makeTranslation(double x, double y, double z) {
    setIdentity();
    setTranslationRaw(x, y, z);
    return this;
  }

  Matrix4 makeRotationZ(double radians) {
    setIdentity();
    rotateZ(radians);
    return this;
  }

  Matrix4 makeScale(double x, double y, double z) {
    setIdentity();
    scaleByDouble(x, y, z, 1);
    return this;
  }

  Matrix4 compose(vm.Vector3 p, vm.Quaternion q, vm.Vector3 s) {
    setFromTranslationRotationScale(p, q, s);
    return this;
  }
}

class Quaternion extends vm.Quaternion {
  Quaternion() : super.fromFloat32List(Float32List.fromList([0, 0, 0, 1]));
  Quaternion setFromEuler(Euler e) {
    final a = e.x / 2, b = e.y / 2, c = e.z / 2;
    final cx = math.cos(a),
        sx = math.sin(a),
        cy = math.cos(b),
        sy = math.sin(b),
        cz = math.cos(c),
        sz = math.sin(c);
    setValues(
      sx * cy * cz + cx * sy * sz,
      cx * sy * cz - sx * cy * sz,
      cx * cy * sz + sx * sy * cz,
      cx * cy * cz - sx * sy * sz,
    );
    return this;
  }
}

class Euler {
  Euler([this.x = 0, this.y = 0, this.z = 0]);
  double x, y, z;
  Euler set(double x, double y, double z) {
    this.x = x;
    this.y = y;
    this.z = z;
    return this;
  }

  Euler copy(Euler other) => set(other.x, other.y, other.z);
  void setFromQuaternion(vm.Quaternion q) {
    final m = q.asRotationMatrix();
    y = math.asin(m.entry(0, 2).clamp(-1.0, 1.0));
    if (m.entry(0, 2).abs() < .9999999) {
      x = math.atan2(-m.entry(1, 2), m.entry(2, 2));
      z = math.atan2(-m.entry(0, 1), m.entry(0, 0));
    } else {
      x = math.atan2(m.entry(2, 1), m.entry(1, 1));
      z = 0;
    }
  }
}

class Color {
  Color([double red = 0, double green = 0, double blue = 0])
    : _channels = Float32List.fromList([red, green, blue]);
  Color.fromHex32(int hex)
    : this(
        ((hex >> 16) & 255) / 255,
        ((hex >> 8) & 255) / 255,
        (hex & 255) / 255,
      );
  final Float32List _channels;
  double get red => _channels[0];
  set red(double value) => _channels[0] = value;
  double get green => _channels[1];
  set green(double value) => _channels[1] = value;
  double get blue => _channels[2];
  set blue(double value) => _channels[2] = value;
  Color setRGB(double r, double g, double b) {
    red = r;
    green = g;
    blue = b;
    return this;
  }

  Color setFrom(Color c) => setRGB(c.red, c.green, c.blue);
  Color lerpColors(Color a, Color b, double t) => setRGB(
    a.red + (b.red - a.red) * t,
    a.green + (b.green - a.green) * t,
    a.blue + (b.blue - a.blue) * t,
  );
  Color scale(double value) => setRGB(red * value, green * value, blue * value);
  Color clone() => Color(red, green, blue);
  Color toLinear() {
    double f(double n) =>
        n < .04045 ? n / 12.92 : math.pow((n + .055) / 1.055, 2.4).toDouble();
    return setRGB(f(red), f(green), f(blue));
  }
}
