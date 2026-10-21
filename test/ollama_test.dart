import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tictactoe/src/ollama.dart';

/// A request captured by [startFakeOllama].
typedef RecordedRequest = ({String method, String path, Map<String, dynamic> body});

/// The state every test asks about, in the 1-based layout the game uses.
const Map<String, String> boardState = {'1': 'X', '5': 'O', '9': 'empty'};

/// The candidate cells every test offers.
const Map<String, String> cellCriteria = {'1': 'top-left cell', '5': 'center cell', '9': 'bottom-right cell'};

/// The single question every test asks.
const String instructions = 'Which cell completes a line for X?';

/// A well-formed response that picks the `5` criterion.
const String choiceBody = '''
{
  "model": "tev1:0.8b",
  "answers": {
    "move": {
      "type": "choice",
      "choice": "5",
      "probabilities": {"1": 0.0125, "5": 0.9781, "9": 0.0093},
      "confidence": 0.8906
    }
  },
  "usage": {"input_tokens": 174, "output_tokens": 1}
}
''';

/// Starts a loopback server standing in for Ollama.
///
/// It records every request and answers each one with [status] and [body].
Future<({Uri baseUri, List<RecordedRequest> requests})> startFakeOllama({
  required String body,
  int status = HttpStatus.ok,
}) async {
  final requests = <RecordedRequest>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final raw = await utf8.decoder.bind(request).join();
    requests.add((method: request.method, path: request.uri.path, body: jsonDecode(raw) as Map<String, dynamic>));
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(body);
    await request.response.close();
  });
  addTearDown(() => server.close(force: true));
  return (
    baseUri: Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port),
    requests: requests,
  );
}

/// Asks [client] the shared board question.
Future<DecisionChoice> ask(OllamaClient client) =>
    client.choose(state: boardState, instructions: instructions, criteria: cellCriteria);

/// Matches a thrown [OllamaException] whose message matches [message].
Matcher throwsOllamaException([Matcher? message]) =>
    throwsA(isA<OllamaException>().having((error) => error.message, 'message', message ?? anything));

void main() {
  group('OllamaClient', () {
    test('posts one choice question to /v1/systemone and returns the chosen label', () async {
      final fake = await startFakeOllama(body: choiceBody);
      final client = OllamaClient(model: 'tev1:0.8b', baseUri: fake.baseUri);

      final choice = await ask(client);

      expect(choice.label, '5');
      expect(choice.probabilities, {'1': 0.0125, '5': 0.9781, '9': 0.0093});
      expect(fake.requests, hasLength(1));
      final request = fake.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/systemone');
      expect(request.body['model'], 'tev1:0.8b');
      expect(request.body['state'], boardState);
      expect(request.body['questions'], {
        'move': {'type': 'choice', 'instructions': instructions, 'criteria': cellCriteria},
      });
    });

    test('reports no probabilities when the answer omits them', () async {
      final fake = await startFakeOllama(body: '{"answers": {"move": {"type": "choice", "choice": "5"}}}');
      final client = OllamaClient(model: 'tev1:0.8b', baseUri: fake.baseUri);

      final choice = await ask(client);

      expect(choice.label, '5');
      expect(choice.probabilities, isNull);
    });

    test('throws when the server answers with malformed JSON', () async {
      final fake = await startFakeOllama(body: '{"model": "tev1:0.8b", "answers"');
      final client = OllamaClient(model: 'tev1:0.8b', baseUri: fake.baseUri);

      expect(ask(client), throwsOllamaException(contains('malformed JSON')));
    });

    test('throws when the answer carries no choice', () async {
      final fake = await startFakeOllama(body: '{"answers": {"move": {"type": "choice"}}}');
      final client = OllamaClient(model: 'tev1:0.8b', baseUri: fake.baseUri);

      expect(ask(client), throwsOllamaException(contains('without a choice')));
    });

    test('throws on a non-200 response', () async {
      final fake = await startFakeOllama(
        status: HttpStatus.notFound,
        body: '{"error": "model \\"tev1:0.8b\\" not found"}',
      );
      final client = OllamaClient(model: 'tev1:0.8b', baseUri: fake.baseUri);

      expect(ask(client), throwsOllamaException(allOf(contains('404'), contains('not found'))));
    });

    test('throws when the choice is not one of the criteria', () async {
      final fake = await startFakeOllama(body: '{"answers": {"move": {"type": "choice", "choice": "7"}}}');
      final client = OllamaClient(model: 'tev1:0.8b', baseUri: fake.baseUri);

      expect(ask(client), throwsOllamaException(contains('"7"')));
    });

    test('throws when nothing listens on the server address', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close(force: true);
      final client = OllamaClient(
        model: 'tev1:0.8b',
        baseUri: Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: port),
      );

      expect(ask(client), throwsOllamaException(contains('Could not reach Ollama')));
    });
  });
}
