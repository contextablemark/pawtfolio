// Returns the http.Client AgUiClient should use, per platform.
//
// On web the default BrowserClient (XHR) cannot read a streaming SSE body, so
// AgUiClient never resolves and the run dies at its request timeout. The web
// implementation returns a Fetch-API client that streams the body. On non-web
// platforms the default dart:io client streams fine, so we return null and let
// AgUiClient build its own.
import 'package:pawtfolio/transport/platform_http_client_stub.dart'
    if (dart.library.html)
        'package:pawtfolio/transport/platform_http_client_web.dart';
import 'package:http/http.dart' as http;

/// Null lets AgUiClient fall back to its default `http.Client()`.
http.Client? createPlatformHttpClient() => makePlatformHttpClient();
