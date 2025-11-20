import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_survey_js_expression/flutter_survey_js_expression.dart';
import 'package:synchronized/synchronized.dart';

String escapeJson(String raw) {
  return raw
      .replaceAll("\\", "\\\\")
      .replaceAll("\"", "\\\"")
      .replaceAll("\n", "\\n");
}

Future<JavascriptRuntime> initJsEngine() async {
  final jsRuntime = getJavascriptRuntime(xhr: false);

  final setup = jsRuntime.evaluate("""
    var window = global = globalThis;
  """);

  if (setup.isError) throw Exception(setup.rawResult);

  final expressionJs = await rootBundle.loadString(
    "packages/flutter_survey_js_expression/assets/index.js",
  );

  final load = jsRuntime.evaluate(expressionJs);
  if (load.isError) throw Exception(load.rawResult);

  final loaded = jsRuntime.evaluate("""
    (typeof surveyjs === "undefined") ? "0" : "1";
  """).stringResult;

  if (loaded != "1") throw Exception("Failed to load JS survey engine");

  return jsRuntime;
}

class VMRunner implements Runner {
  JavascriptRuntime? jsRuntime;
  final lock = Lock();

  @override
  Future<bool> init() async {
    await lock.synchronized(() async {
      jsRuntime ??= await initJsEngine();
    });
    return true;
  }

  @override
  bool? runCondition(
    String expression,
    Map<String, Object?> value, {
    Map<String, Object?>? properties,
  }) {
    if (jsRuntime == null) return false;

    final jsonStr = escapeJson(json.encode(value));
    final exp = '''
      surveyjs.runCondition("${escapeJson(expression)}","$jsonStr")
    ''';

    final result = jsRuntime!.evaluate(exp);
    if (result.isError) throw Exception(result.rawResult);

    final v = result.stringResult.trim().toLowerCase();
    if (v == "true") return true;
    if (v == "false") return false;
    return null;
  }

  @override
  Object? runExpression(
    String expression,
    Map<String, Object?> value, {
    Map<String, Object?>? properties,
  }) {
    if (jsRuntime == null) return null;

    final jsonStr = escapeJson(json.encode(value));
    final exp = '''
      surveyjs.runExpression("${escapeJson(expression)}","$jsonStr")
    ''';

    final result = jsRuntime!.evaluate(exp);
    if (result.isError) throw Exception(result.rawResult);

    // JS returns stringResult, not rawResult
    final raw = result.stringResult.trim();

    // Try parse int/double/bool
    if (int.tryParse(raw) != null) return int.parse(raw);
    if (double.tryParse(raw) != null) return double.parse(raw);

    if (raw.toLowerCase() == "true") return true;
    if (raw.toLowerCase() == "false") return false;

    return raw;
  }

  @override
  Future<bool> dispose() async {
    jsRuntime?.dispose();
    jsRuntime = null;
    return true;
  }
}

final VMRunner _singleton = VMRunner();

Runner getRunner() => _singleton;
