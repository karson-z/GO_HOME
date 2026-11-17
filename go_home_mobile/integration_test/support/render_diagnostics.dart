import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_angle/flutter_angle.dart' as angle;

/// Diagnostic-only wrapper: preserves GL behavior and times selected calls.
class RenderDiagnostics extends angle.RenderingContext {
  RenderDiagnostics(angle.RenderingContext original)
    : super.create(
        original.gl,
        original.width,
        original.height,
        original.checkGlErrorOnEveryCall,
      );

  String phase = 'background';
  String? window;
  int frameId = 0;
  final slowCalls = <Map<String, Object?>>[];
  final gpuSamples = <Map<String, Object?>>[];
  final Map<String, List<int>> _frameCalls = {};
  final Map<int, Map<String, Object?>> _queries = {};
  final _queryValue = calloc<Uint32>();
  bool gpuEnabled = false;
  String? gpuUnavailable;
  int? _activeQuery;

  void initializeGpuTimer() {
    try {
      final extensions = getExtension('') as List;
      gpuEnabled = extensions.any(
        (e) => e.toString().contains('disjoint_timer_query'),
      );
      if (!gpuEnabled) {
        gpuUnavailable = 'EXT_disjoint_timer_query unavailable';
        return;
      }
      gl.glGenQueries(1, _queryValue);
      final probe = _queryValue.value;
      gl.glBeginQuery(angle.GL_TIME_ELAPSED_EXT, probe);
      final error = gl.glGetError();
      if (error == 0) {
        gl.glEndQuery(angle.GL_TIME_ELAPSED_EXT);
      } else {
        gpuEnabled = false;
        gpuUnavailable = 'Timer query probe failed with GL error $error';
      }
      _queryValue.value = probe;
      gl.glDeleteQueries(1, _queryValue);
    } catch (error) {
      gpuEnabled = false;
      gpuUnavailable = '$error';
    }
  }

  T measure<T>(String name, T Function() call) {
    final start = developer.Timeline.now;
    try {
      return call();
    } finally {
      final duration = developer.Timeline.now - start;
      if (phase != 'background') {
        final stats = _frameCalls.putIfAbsent(name, () => [0, 0, 0]);
        stats[0]++;
        stats[1] += duration;
        if (duration > stats[2]) stats[2] = duration;
      }
      if (duration >= 1000 && slowCalls.length < 20000) {
        slowCalls.add({
          'tUs': start,
          'durationUs': duration,
          'call': name,
          'phase': phase,
          'window': window,
          'frameId': frameId,
        });
      }
    }
  }

  void beginFrame() {
    collectGpu();
    frameId++;
    _frameCalls.clear();
    phase = 'charactersAndCulling';
    if (gpuEnabled && _queries.length < 16) {
      gl.glGenQueries(1, _queryValue);
      _activeQuery = _queryValue.value;
      gl.glBeginQuery(angle.GL_TIME_ELAPSED_EXT, _activeQuery!);
      _queries[_activeQuery!] = {
        'frameId': frameId,
        'window': window,
        'tUs': developer.Timeline.now,
      };
    }
  }

  Map<String, Object?> endFrame() {
    if (_activeQuery != null) {
      gl.glEndQuery(angle.GL_TIME_ELAPSED_EXT);
      _activeQuery = null;
    }
    phase = 'background';
    return {
      'frameId': frameId,
      'calls': {
        for (final entry in _frameCalls.entries)
          entry.key: {
            'count': entry.value[0],
            'totalUs': entry.value[1],
            'maxUs': entry.value[2],
          },
      },
    };
  }

  void collectGpu() {
    if (!gpuEnabled) return;
    final disjoint = getIntegerv(angle.GL_GPU_DISJOINT_EXT) != 0;
    for (final query in _queries.keys.toList()) {
      gl.glGetQueryObjectuiv(
        query,
        angle.GL_QUERY_RESULT_AVAILABLE,
        _queryValue,
      );
      if (_queryValue.value == 0 && !disjoint) continue;
      if (!disjoint) {
        gl.glGetQueryObjectuiv(query, angle.GL_QUERY_RESULT, _queryValue);
        gpuSamples.add({
          ..._queries[query]!,
          'elapsedNs32': _queryValue.value,
          'disjoint': false,
        });
      } else {
        gpuSamples.add({..._queries[query]!, 'disjoint': true});
      }
      _queryValue.value = query;
      gl.glDeleteQueries(1, _queryValue);
      _queries.remove(query);
    }
  }

  void disposeDiagnostics() {
    for (final query in _queries.keys) {
      _queryValue.value = query;
      gl.glDeleteQueries(1, _queryValue);
    }
    _queries.clear();
    calloc.free(_queryValue);
  }

  @override
  void compileShader(angle.WebGLShader shader, [bool checkForErrors = true]) =>
      measure(
        'compileShader',
        () => super.compileShader(shader, checkForErrors),
      );

  @override
  void linkProgram(angle.Program program, [bool checkForErrors = true]) =>
      measure('linkProgram', () => super.linkProgram(program, checkForErrors));

  @override
  angle.WebGLParameter getProgramParameter(angle.Program program, int pname) =>
      measure(
        'getProgramParameter',
        () => super.getProgramParameter(program, pname),
      );

  @override
  angle.ActiveInfo getActiveUniform(angle.Program program, int index) =>
      measure('getActiveUniform', () => super.getActiveUniform(program, index));

  @override
  angle.ActiveInfo getActiveAttrib(angle.Program program, int index) =>
      measure('getActiveAttrib', () => super.getActiveAttrib(program, index));

  @override
  angle.UniformLocation getUniformLocation(
    angle.Program program,
    String name,
  ) => measure(
    'getUniformLocation',
    () => super.getUniformLocation(program, name),
  );

  @override
  angle.UniformLocation getAttribLocation(angle.Program program, String name) =>
      measure(
        'getAttribLocation',
        () => super.getAttribLocation(program, name),
      );

  @override
  void bufferDataTyped(int target, TypedData data, int? usage) => measure(
    'bufferDataTyped',
    () => super.bufferDataTyped(target, data, usage),
  );

  @override
  void bufferSubData(int target, int offset, TypedData data) =>
      measure('bufferSubData', () => super.bufferSubData(target, offset, data));

  @override
  void texImage2D(
    int target,
    int level,
    int format,
    int width,
    int height,
    int border,
    int pixelFormat,
    int type,
    TypedData? pixels,
  ) => measure(
    'texImage2D',
    () => super.texImage2D(
      target,
      level,
      format,
      width,
      height,
      border,
      pixelFormat,
      type,
      pixels,
    ),
  );

  @override
  void texSubImage2D(
    int target,
    int level,
    int x,
    int y,
    int width,
    int height,
    int format,
    int type,
    TypedData? pixels,
  ) => measure(
    'texSubImage2D',
    () => super.texSubImage2D(
      target,
      level,
      x,
      y,
      width,
      height,
      format,
      type,
      pixels,
    ),
  );

  @override
  void generateMipmap(int target) =>
      measure('generateMipmap', () => super.generateMipmap(target));

  @override
  void drawArrays(int mode, int first, int count) =>
      measure('drawArrays', () => super.drawArrays(mode, first, count));

  @override
  void drawElements(int mode, int count, int type, int offset) => measure(
    'drawElements',
    () => super.drawElements(mode, count, type, offset),
  );

  @override
  void drawArraysInstanced(int mode, int first, int count, int instances) =>
      measure(
        'drawArraysInstanced',
        () => super.drawArraysInstanced(mode, first, count, instances),
      );

  @override
  void drawElementsInstanced(
    int mode,
    int count,
    int type,
    int offset,
    int instances,
  ) => measure(
    'drawElementsInstanced',
    () => super.drawElementsInstanced(mode, count, type, offset, instances),
  );

  @override
  void useProgram(angle.Program? program) =>
      measure('useProgram', () => super.useProgram(program));

  @override
  void bindFramebuffer(int target, angle.Framebuffer? framebuffer) => measure(
    'bindFramebuffer',
    () => super.bindFramebuffer(target, framebuffer),
  );

  @override
  void framebufferTexture2D(
    int target,
    int attachment,
    int textarget,
    angle.WebGLTexture? texture,
    int level,
  ) => measure(
    'framebufferTexture2D',
    () => super.framebufferTexture2D(
      target,
      attachment,
      textarget,
      texture,
      level,
    ),
  );

  @override
  void clear(int mask) => measure('clear', () => super.clear(mask));

  @override
  void uniform1f(angle.UniformLocation location, double x) =>
      measure('uniform1f', () => super.uniform1f(location, x));

  @override
  void uniform1i(angle.UniformLocation location, int x) =>
      measure('uniform1i', () => super.uniform1i(location, x));

  @override
  void uniform1fv(angle.UniformLocation location, Float32List values) =>
      measure('uniform1fv', () => super.uniform1fv(location, values));

  @override
  void uniform2fv(angle.UniformLocation location, Float32List values) =>
      measure('uniform2fv', () => super.uniform2fv(location, values));

  @override
  void uniform3fv(angle.UniformLocation location, Float32List values) =>
      measure('uniform3fv', () => super.uniform3fv(location, values));

  @override
  void uniform4fv(angle.UniformLocation location, Float32List values) =>
      measure('uniform4fv', () => super.uniform4fv(location, values));

  @override
  void uniformMatrix3fv(
    angle.UniformLocation location,
    bool transpose,
    Float32List values,
  ) => measure(
    'uniformMatrix3fv',
    () => super.uniformMatrix3fv(location, transpose, values),
  );

  @override
  void uniformMatrix4fv(
    angle.UniformLocation location,
    bool transpose,
    Float32List values,
  ) => measure(
    'uniformMatrix4fv',
    () => super.uniformMatrix4fv(location, transpose, values),
  );
}
