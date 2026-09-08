import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// One review fed to the summarizer.
typedef ReviewInput = ({String text, String lang, double rating});

/// ML-style review summarization for worker profiles.
///
/// Primary path: the backend proxy's `POST /summarize` endpoint, which
/// brings every review into the target language (neural MT) and runs an
/// extractive TF-IDF summarizer. Fallback: an offline extractive
/// summarizer using the same TF-IDF + sentiment-lexicon approach so the
/// "Overall summary" card works without a network.
///
/// Output contract: 1 paragraph for up to 4 reviews, 2 paragraphs for
/// more (the second highlights the negative feedback when present).
class SummaryService {
  static const String _proxyUrl = String.fromEnvironment('SUMMARY_PROXY_URL');

  final http.Client _client;

  SummaryService({http.Client? client}) : _client = client ?? http.Client();

  /// Summarizes [reviews] into 1-2 paragraphs in [target] for
  /// [workerName].
  Future<List<String>> summarize({
    required String workerName,
    required List<ReviewInput> reviews,
    required String target,
  }) async {
    if (reviews.isEmpty) return const [];

    if (_proxyUrl.isNotEmpty) {
      try {
        final resp = await _client.post(
          Uri.parse(_proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'workerName': workerName,
            'target': target,
            'reviews': [
              for (final r in reviews)
                {'text': r.text, 'lang': r.lang, 'rating': r.rating},
            ],
          }),
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final raw = data['paragraphs'];
          if (raw is List) {
            final paragraphs = raw
                .map((p) => p.toString().trim())
                .where((p) => p.isNotEmpty)
                .toList();
            if (paragraphs.isNotEmpty) return paragraphs;
          }
        }
      } catch (_) {
        // fall through to the offline summarizer
      }
    }
    return summarizeLocal(
      workerName: workerName,
      reviews: reviews,
      target: target,
    );
  }

  // --------------------------------------------------------------------
  // Offline extractive fallback: TF-IDF sentence scoring guided by
  // sentiment lexicons, same algorithm as the proxy endpoint.
  // --------------------------------------------------------------------

  static const Set<String> _stop = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'of', 'and', 'or', 'to',
    'in', 'on', 'at', 'it', 'he', 'she', 'they', 'i', 'you', 'we', 'my',
    'your', 'for', 'with', 'this', 'that', 'now', 'very', 'but', 'not',
    'ہے', 'ہیں', 'تھا', 'ہو', 'اور', 'کی', 'کا', 'کے', 'کو', 'سے', 'پر', 'یہ', 'وہ', 'میں', 'اس',
    'है', 'हैं', 'था', 'और', 'का', 'की', 'के', 'को', 'से', 'पर', 'यह', 'वह', 'में', 'इस',
  };

  static const Set<String> _rtl = {'ur', 'ar', 'fa', 'ps', 'sd'};

  static const Map<String, Set<String>> _pos = {
    'en': {
      'good', 'great', 'excellent', 'fast', 'quickly', 'quick',
      'professional', 'skilled', 'fair', 'recommended', 'satisfied',
      'beautiful', 'quality', 'punctual', 'polite', 'friendly', 'careful',
      'on', 'time', 'perfectly', 'neat', 'bright', 'fresh', 'thank',
      'highly',
    },
    'ur': {
      'اچھا', 'اچھی', 'بہترین', 'بہت', 'مہارت', 'پیشہ', 'مناسب',
      'تیزی', 'وقت', 'مطمئن', 'خوبصورت', 'معیاری', 'شکریہ', 'دوست',
      'مؤدب', 'احتیاط', 'روشن', 'سبز', 'تازہ', 'زبردست', 'مؤثر',
      'ہمواری',
    },
    'hi': {
      'अच्छा', 'अच्छी', 'उत्कृष्ट', 'बहुत', 'हुनरमंद', 'पेशेवर', 'उचित',
      'तेज़ी', 'समय', 'संतुष्ट', 'खूबसूरत', 'गुणवत्ता', 'धन्यवाद',
      'दोस्ताना', 'शिष्ट', 'सावधान', 'स्पष्ट', 'रोशन', 'हरा', 'ताज़ा',
      'सुचारू',
    },
  };

  static const Map<String, Set<String>> _neg = {
    'en': {
      'late', 'delayed', 'delay', 'slow', 'slowly', 'expensive', 'poor',
      'problem', 'issue', 'bad', 'broken', 'leak', 'leaked', 'refuse',
      'refused',
    },
    'ur': {'دیر', 'مہنگا', 'مسئلہ', 'آہستہ', 'بری', 'خراب'},
    'hi': {'देर', 'महँगा', 'समस्या', 'धीरे', 'बुरा', 'खराब'},
  };

  static const Map<String, String Function(String, String, int)> _lead = {
    'en': (name, avg, n) =>
        'Overall, customers rate $name $avg/5 across $n reviews.',
    'ur': (name, avg, n) =>
        'کل طور پر، گاہکوں نے $name کو $n جائزوں میں $avg/5 درجہ دیا ہے۔',
    'hi': (name, avg, n) =>
        'सामान्य रूप से, ग्राहकों ने $n समीक्षाओं में $name को $avg/5 रेट किया है।',
  };

  static List<String> _tokenize(String text, String lang) {
    final rtl = _rtl.contains(lang);
    var t = text.toLowerCase();
    final punct =
        rtl ? RegExp('[،۔؟?!،؛;.,:]') : RegExp(r"[.,!?;:'’-]+");
    t = t.replaceAll(punct, ' ');
    return t
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_stop.contains(w))
        .toList();
  }

  /// Extractive TF-IDF summary; pure function, safe offline.
  static List<String> summarizeLocal({
    required String workerName,
    required List<ReviewInput> reviews,
    required String target,
  }) {
    final n = reviews.length;
    if (n == 0) return const [];

    final avg = (reviews
            .fold<double>(0, (sum, r) => sum + (r.rating <= 0 ? 5 : r.rating)) /
        n)
        .toStringAsFixed(1);
    final lead = (_lead[target] ?? _lead['en']!)(workerName, avg, n);

    final sentences = <String>[];
    for (final r in reviews) {
      for (final s in r.text
          .split(RegExp(r'(?<=[।.!؟?])'))
          .map((x) => x.trim())
          .where((x) => x.length > 2)) {
        sentences.add(s);
      }
    }
    if (sentences.isEmpty) return [lead];

    final docs = sentences.map((s) => _tokenize(s, target)).toList();
    final df = <String, int>{};
    for (final d in docs) {
      for (final w in d.toSet()) {
        df[w] = (df[w] ?? 0) + 1;
      }
    }
    final total = docs.length;
    double scoreDoc(List<String> d) {
      final tf = <String, int>{};
      for (final w in d) {
        tf[w] = (tf[w] ?? 0) + 1;
      }
      var score = 0.0;
      for (final entry in tf.entries) {
        score += entry.value * math.log(1 + total / (df[entry.key] ?? 1));
      }
      return d.isEmpty ? 0.0 : score / math.sqrt(d.length);
    }

    final scored = [
      for (var i = 0; i < sentences.length; i++)
        (index: i, sentence: sentences[i], score: scoreDoc(docs[i])),
    ];

    final pos = _pos[target] ?? _pos['en']!;
    final neg = _neg[target] ?? _neg['en']!;
    bool isNegative(String s) =>
        _tokenize(s, target).any((w) => neg.contains(w));
    bool isPositive(String s) =>
        _tokenize(s, target).any((w) => pos.contains(w));

    final twoParas = n > 4;
    final picked = <int>{};
    List<int> pick(bool Function(String) pred, int k) {
      final cands = scored
          .where((x) => !picked.contains(x.index) && pred(x.sentence))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      final take = cands.take(k).map((x) => x.index).toList();
      picked.addAll(take);
      return take;
    }

    final p1count = twoParas ? 3 : 2;
    var p1 = pick((s) => isPositive(s) || !isNegative(s), p1count);
    if (p1.length < p1count) {
      p1 = p1 + pick((_) => true, p1count - p1.length);
    }
    p1.sort();

    var p2 = <int>[];
    if (twoParas) {
      p2 = pick(isNegative, 2);
      if (p2.length < 2) p2 = p2 + pick((_) => true, 2 - p2.length);
      p2.sort();
    }

    String join(List<int> idx) =>
        idx.map((i) => sentences[i]).join(' ');

    final paragraphs = [lead + ' ' + join(p1)];
    if (twoParas) paragraphs.add(join(p2));
    return paragraphs;
  }
}
