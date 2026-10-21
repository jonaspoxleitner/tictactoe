import 'dart:convert';
import 'dart:io';

/// The answer to a choice question: the chosen label plus, when the server
/// reported them, the probability of every candidate.
class DecisionChoice {
  /// Reports [label] as the chosen criterion key, with [probabilities] mapping
  /// every candidate to its probability.
  const DecisionChoice(this.label, {this.probabilities});

  /// The chosen criterion key.
  final String label;

  /// Each candidate's probability, keyed by criterion label, or `null` when
  /// the server did not report any.
  final Map<String, double>? probabilities;
}

/// Chooses among labelled options for a described state.
///
/// Callers treat a real model and an in-memory fake alike.
abstract interface class DecisionClient {
  /// Returns the [DecisionChoice] for [state].
  ///
  /// [state] is the JSON object to decide about, [instructions] poses the
  /// question, and [criteria] maps every candidate label to a description of
  /// it. Throws an [OllamaException] when no label can be obtained.
  Future<DecisionChoice> choose({
    required Map<String, String> state,
    required String instructions,
    required Map<String, String> criteria,
  });
}

/// Thrown when a [DecisionClient] cannot obtain a label.
class OllamaException implements Exception {
  /// Reports [message] as the reason no label was obtained.
  OllamaException(this.message);

  /// What went wrong, phrased for a one-line warning.
  final String message;

  @override
  String toString() => 'OllamaException: $message';
}

/// A [DecisionClient] backed by Ollama's System One endpoint.
///
/// Sends a single `choice` question named `move` to `POST /v1/systemone` and
/// returns the label the model picked, which is always one of the criteria
/// keys. Anything else counts as a failure and throws an [OllamaException].
class OllamaClient implements DecisionClient {
  /// Creates a client that asks [model] on [baseUri], or on the default local
  /// Ollama server (`http://localhost:11434`) when [baseUri] is omitted.
  OllamaClient({required this.model, Uri? baseUri})
    : baseUri = baseUri ?? Uri(scheme: 'http', host: 'localhost', port: 11434);

  /// The decision model to ask, such as `tev1:0.8b`.
  final String model;

  /// The Ollama server that serves `/v1/systemone`.
  final Uri baseUri;

  /// The name of the single question; the response answers under the same name.
  static const String _questionName = 'move';

  @override
  Future<DecisionChoice> choose({
    required Map<String, String> state,
    required String instructions,
    required Map<String, String> criteria,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(baseUri.resolve('/v1/systemone'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'model': model,
          'state': state,
          'questions': {
            _questionName: {'type': 'choice', 'instructions': instructions, 'criteria': criteria},
          },
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw OllamaException('Ollama answered HTTP ${response.statusCode}: ${body.trim()}');
      }
      return _choiceFrom(body, criteria.keys);
    } on IOException catch (error) {
      throw OllamaException('Could not reach Ollama at $baseUri: $error');
    } finally {
      client.close();
    }
  }

  /// Extracts the chosen label and probabilities from the response [body];
  /// the label has to name one of [labels].
  DecisionChoice _choiceFrom(String body, Iterable<String> labels) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw OllamaException('Ollama answered with malformed JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw OllamaException('Ollama answered with unexpected JSON: $body');
    }
    final answers = decoded['answers'];
    if (answers is! Map<String, dynamic>) {
      throw OllamaException('Ollama answered without "answers": $body');
    }
    final answer = answers[_questionName];
    if (answer is! Map<String, dynamic>) {
      throw OllamaException('Ollama answered without a "$_questionName" answer: $body');
    }
    final choice = answer['choice'];
    if (choice is! String) {
      throw OllamaException('Ollama answered without a choice: $body');
    }
    if (!labels.contains(choice)) {
      throw OllamaException('Ollama chose "$choice", which is not one of the criteria');
    }
    return DecisionChoice(choice, probabilities: _probabilitiesFrom(answer));
  }

  /// The candidate probabilities of [answer], or `null` when absent or
  /// malformed - they are informational, never a failure.
  Map<String, double>? _probabilitiesFrom(Map<String, dynamic> answer) {
    final raw = answer['probabilities'];
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return {
      for (final entry in raw.entries)
        if (entry.value is num) entry.key: (entry.value as num).toDouble(),
    };
  }
}
