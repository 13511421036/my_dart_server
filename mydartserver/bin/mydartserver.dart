// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

Future<void> main() async {
  // If the "PORT" environment variable is set, listen to it. Otherwise, 8080.
  // https://cloud.google.com/run/docs/reference/container-contract#port
  final port =
      int.parse(Platform.environment['PORT'] ?? '8080'); //定义port,设置port的环境变量

  // See https://pub.dev/documentation/shelf/latest/shelf/Cascade-class.html
  final cascade = Cascade()
      // First, serve files from the 'public' directory
      .add(_staticHandler)
      // If a corresponding file is not found, send requests to a `Router`
      .add(_router);

  // See https://pub.dev/documentation/shelf/latest/shelf_io/serve.html
  final server = await shelf_io.serve(
    //封装http io的问题
    // See https://pub.dev/documentation/shelf/latest/shelf/logRequests.html
    logRequests()
        // See https://pub.dev/documentation/shelf/latest/shelf/MiddlewareExtensions/addHandler.html
        .addHandler(cascade.handler), //line19
    InternetAddress
        .anyIPv4, // Allows external connections    IP-CIDR 0.0.0.0/24  0.0.0.0/0
    port,
  );

  print('Serving at http://${server.address.host}:${server.port}'); //服务器端地址

  // Used for tracking uptime of the demo server.
  _watch.start();
}

// Serve files from the file system.
final _staticHandler =
    shelf_static.createStaticHandler('public', defaultDocument: 'index.html');

// Router instance to handler requests.
final _router = shelf_router.Router()
  ..get('/helloworld', _helloWorldHandler)
  ..get(
    '/time',
    (request) => Response.ok(DateTime.now().toUtc().toIso8601String()),
  )
  ..get('/info.json', _infoHandler)
  ..get('/sum/<a|[0-9]+>/<b|[0-9]+>',
      _sumHandler) //尖括号左边a代表名称，后面代表数据类型+代表至少有一个和多个的数字
  ..get('/sum/<a|[0-9]+>/<b|[0-9]+>/<c|[0-9]+>', _sumthreeHandler)
  ..get('/sum/<a>/<b>', _concatenateHandler);
Response _helloWorldHandler(Request request) =>
    Response.ok('Hello, World!'); //函数定义，ok

String _jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data); //编码

const _jsonHeaders = {
  'content-type': 'application/json',
};

Response _sumHandler(Request request, String a, String b) {
  final aNum = int.parse(a);
  final bNum = int.parse(b);
  return Response.ok(
    _jsonEncode({'a': aNum, 'b': bNum, 'sum': aNum + bNum}),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    },
  );
}

Response _sumthreeHandler(Request request, String a, String b, String c) {
  final aNum = int.parse(a);
  final bNum = int.parse(b);
  final cNum = int.parse(c);
  return Response.ok(
    _jsonEncode({'a': aNum, 'b': bNum, 'c': cNum, 'sum': aNum + bNum + cNum}),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    },
  );
}

Response _concatenateHandler(Request request, String a, String b) {
  final concatenatedString = '$a$b';
  return Response.ok(
    _jsonEncode({'a': a, 'b': b, 'concatenatedString': concatenatedString}),
    headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    },
  );
}

final _watch = Stopwatch();

int _requestCount = 0;

final _dartVersion = () {
  final version = Platform.version;
  return version.substring(0, version.indexOf(' '));
}();

Response _infoHandler(Request request) => Response(
      200,
      headers: {
        ..._jsonHeaders, //...原有的上面增加新的
        'Cache-Control': 'no-store',
      },
      body: _jsonEncode(
        //Java script 的编码重新打开，因为单引号
        {
          'Dart version': _dartVersion,
          'uptime': _watch.elapsed.toString(),
          'requestCount': ++_requestCount, //刷新计数器
        },
      ),
    );
