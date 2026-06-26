// Non-web platforms: the default dart:io-backed http.Client already streams SSE
// bodies, so let AgUiClient construct its own.
import 'package:http/http.dart' as http;

http.Client? makePlatformHttpClient() => null;
