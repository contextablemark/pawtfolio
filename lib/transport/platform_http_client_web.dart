// Web: use the Fetch API (ReadableStream) so the SSE response body streams in
// live. RequestMode.cors is required for the cross-origin call to the backend.
import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;

http.Client? makePlatformHttpClient() => FetchClient(mode: RequestMode.cors);
