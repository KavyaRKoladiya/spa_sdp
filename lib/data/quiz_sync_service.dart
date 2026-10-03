import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Result returned by [QuizSyncService.fetchScore]
class QuizSyncResponse {
  final bool isSuccess;
  final bool found;
  final double? score;
  final double? totalMarks;
  final String message;
  final DateTime? submittedAt;

  const QuizSyncResponse({
    required this.isSuccess,
    this.found = false,
    this.score,
    this.totalMarks,
    required this.message,
    this.submittedAt,
  });

  factory QuizSyncResponse.notFound(String message) => QuizSyncResponse(
        isSuccess: true,
        found: false,
        message: message,
      );

  factory QuizSyncResponse.error(String message) => QuizSyncResponse(
        isSuccess: false,
        found: false,
        message: message,
      );

  factory QuizSyncResponse.success({
    required double score,
    required double totalMarks,
    String? message,
    DateTime? submittedAt,
  }) =>
      QuizSyncResponse(
        isSuccess: true,
        found: true,
        score: score,
        totalMarks: totalMarks,
        message: message ?? 'Quiz score retrieved successfully.',
        submittedAt: submittedAt,
      );
}

/// Service to synchronize student quiz results from Google Sheets via Google Apps Script Web App.
class QuizSyncService {
  final http.Client _client;

  QuizSyncService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the latest quiz score for a student from the Google Apps Script Web App.
  Future<QuizSyncResponse> fetchScore({
    required String syncUrl,
    required String studentEmail,
    int? quizId,
  }) async {
    final trimmedUrl = syncUrl.trim();
    if (trimmedUrl.isEmpty) {
      return QuizSyncResponse.error(
        'No Google Apps Script Sync URL is configured for this quiz.',
      );
    }

    // Ensure valid URL
    Uri uri;
    try {
      uri = Uri.parse(trimmedUrl);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$trimmedUrl');
      }
    } catch (e) {
      return QuizSyncResponse.error('Invalid Sync URL format: $trimmedUrl');
    }

    // Append query parameters
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['action'] = 'getScore';
    queryParams['email'] = studentEmail.trim().toLowerCase();
    if (quizId != null) {
      queryParams['quizId'] = quizId.toString();
    }
    final finalUri = uri.replace(queryParameters: queryParams);

    try {
      final response = await _client
          .get(
            finalUri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return QuizSyncResponse.error(
          'Google Apps Script returned HTTP status ${response.statusCode}.',
        );
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return QuizSyncResponse.error(
          'Failed to parse response from Google Sheets. Ensure Apps Script is returning JSON.',
        );
      }

      final status = data['status']?.toString().toLowerCase();
      if (status == 'error') {
        return QuizSyncResponse.error(
          data['message']?.toString() ?? 'Error reported by Google Sheets script.',
        );
      }

      final bool found = data['found'] == true;
      if (!found) {
        final msg = data['message']?.toString() ??
            'No submission found for "$studentEmail". Please complete the quiz first.';
        return QuizSyncResponse.notFound(msg);
      }

      // Extract score and totalMarks
      final parsed = _parseScoreData(data);
      if (parsed == null) {
        return QuizSyncResponse.error(
          'Submission found, but score could not be parsed from: ${data['score']}',
        );
      }

      DateTime? submittedAt;
      if (data['submittedAt'] != null) {
        submittedAt = DateTime.tryParse(data['submittedAt'].toString());
      }

      return QuizSyncResponse.success(
        score: parsed.$1,
        totalMarks: parsed.$2,
        message: data['message']?.toString(),
        submittedAt: submittedAt,
      );
    } on SocketException {
      return QuizSyncResponse.error(
        'Network error: Unable to connect to Google Sheets. Check your internet connection.',
      );
    } on http.ClientException catch (e) {
      return QuizSyncResponse.error('Network client error: ${e.message}');
    } on FormatException catch (e) {
      return QuizSyncResponse.error('Data format error: ${e.message}');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return QuizSyncResponse.error(
          'Request timed out while connecting to Google Sheets. Please try again.',
        );
      }
      return QuizSyncResponse.error('Unexpected error: $e');
    }
  }

  /// Parses score and total marks from various Google Forms / Sheet formats:
  /// - Numeric: {score: 8, totalMarks: 10}
  /// - String: {score: "8 / 10"} or {score: "8/10"}
  /// - Score only: {score: 85} (defaults totalMarks to 100)
  static (double, double)? _parseScoreData(Map<String, dynamic> data) {
    double? rawScore;
    double? rawTotal;

    // Check direct numeric/string fields
    if (data['score'] != null) {
      final scoreVal = data['score'];
      if (scoreVal is num) {
        rawScore = scoreVal.toDouble();
      } else if (scoreVal is String) {
        // Try matching "8 / 10" or "8/10"
        final slashMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$')
            .firstMatch(scoreVal.trim());
        if (slashMatch != null) {
          rawScore = double.tryParse(slashMatch.group(1)!);
          rawTotal = double.tryParse(slashMatch.group(2)!);
        } else {
          rawScore = double.tryParse(scoreVal.trim());
        }
      }
    }

    if (data['totalMarks'] != null) {
      final totalVal = data['totalMarks'];
      if (totalVal is num) {
        rawTotal = totalVal.toDouble();
      } else if (totalVal is String) {
        rawTotal = double.tryParse(totalVal.trim());
      }
    }

    if (rawScore == null) return null;

    // If total marks is still null, default to 10 if score <= 10, else 100
    rawTotal ??= (rawScore <= 10 ? 10.0 : 100.0);

    return (rawScore, rawTotal);
  }

  /// Helper to optionally append prefilled email entry parameter to a Google Form URL
  static String buildFormUrlWithEmail(String baseFormUrl, String studentEmail) {
    var url = baseFormUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    // If the form URL is already pre-configured with a prefill query entry
    // (e.g. entry.123456=), replace or leave intact.
    return url;
  }
}
