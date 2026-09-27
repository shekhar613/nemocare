import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../config/groq_config.dart';
import '../models/document_analysis.dart';

class GroqException implements Exception {
  GroqException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls Groq to extract document content and verify it is medical-related.
class GroqService {
  GroqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _systemPrompt = '''
You are a medical document classifier and extractor for Nemo Care, a personal
health records app. Analyze the uploaded document (image or PDF page) and decide
if it is a genuine medical / health-care record.

Medical documents include: lab reports, blood tests, prescriptions, pharmacy
receipts for medicines, imaging (X-ray, MRI, CT, ultrasound), discharge summaries,
doctor consultation notes, vaccination records, insurance medical claims, and
similar clinical paperwork.

Non-medical examples: invoices for non-health goods, school docs, random photos,
ID cards alone (unless a medical ID), memes, screenshots of unrelated apps.

Respond with ONLY a JSON object (no markdown) using this exact schema:
{
  "is_medical": boolean,
  "category": "lab" | "prescription" | "imaging" | "clinical_report" | "other_medical" | "non_medical",
  "document_type": "lab" | "prescription" | "imaging" | "clinical_report" | "other_medical" | "non_medical",
  "report_name": "prefer a standard panel name when possible: CBC, Blood Sugar / Diabetes Panel, Blood Pressure, Lipid Profile, Liver Function Test (LFT), Kidney Function Test (KFT/RFT), Urine Routine, Thyroid Profile, Vitamin Panel, Iron Studies — otherwise a short test name",
  "lab_name": "lab / hospital / clinic name if printed, else empty string",
  "city_name": "city or locality printed on the report, or empty string if unknown",
  "sample_type": "specimen / sample type if printed (e.g. Blood, Serum, Urine, Plasma), else empty string",
  "collection_date": "sample collection date if printed (prefer YYYY-MM-DD); else same as test_date when only one date exists",
  "test_date": "date of the test / report as written on the document (prefer YYYY-MM-DD if clear)",
  "parameters": ["ONLY short parameter or analyte names, e.g. Hemoglobin, WBC, Platelets — no values, no explanations"],
  "vitals": [
    {
      "parameter": "Hemoglobin",
      "value": "13.5",
      "unit": "g/dL",
      "reference": "12.0 - 15.0",
      "status": "normal"
    }
  ],
  "conclusion": "1-3 sentence clinical conclusion / impression / overall result from the document (no medical advice)",
  "confidence": number between 0 and 1,
  "full_report": {
    "patient_name": "string or empty",
    "lab_or_hospital": "string or empty",
    "doctor_name": "string or empty",
    "sample_type": "string or empty",
    "collection_date": "string or empty",
    "key_findings": ["list of important findings / values"],
    "medications": ["list if any"],
    "notes": "any other important text",
    "raw_extract": "longer readable extract of the document text (max 1200 chars)"
  },
  "rejection_reason": "if is_medical is false, explain briefly why; otherwise null"
}

category groups the document type so different medical reports can be stored separately:
- lab = blood/urine/pathology lab panels
- prescription = medicines / pharmacy
- imaging = X-ray, MRI, CT, ultrasound
- clinical_report = discharge, consultation, checkup notes
- other_medical = other genuine medical paperwork
- non_medical = reject
Always set category and document_type to the same value.
Always fill full_report with as much structured detail as you can read.
parameters must be short names only — never long sentences.
vitals must list ONLY measurable medical lab parameters (analytes / vitals),
never patient demographics, dates, doctor names, addresses, or notes.
Each vitals row:
- value = reported result number/text
- unit = measurement unit if present
- reference = standard adult reference interval for comparison
  (use common clinical ranges; include report range only if standard is unknown)
- status = "low" | "normal" | "high" | "unknown" by comparing value to reference
  (use flags on the report like H/L/* if present; otherwise compare numerically)
If a field is missing on the document, use an empty string or empty array.
''';

  Future<DocumentAnalysis> analyzeDocument({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!GroqConfig.isConfigured) {
      throw GroqException(
        'Groq API key is missing. Run with '
        '--dart-define=GROQ_API_KEY=your_key '
        '(create one at https://console.groq.com/keys).',
      );
    }

    final ext = _extension(fileName);
    final imagePayload = await _toImagePayload(bytes: bytes, extension: ext);
    return _analyzeImage(
      base64Image: imagePayload.base64,
      mimeType: imagePayload.mimeType,
      fileName: fileName,
    );
  }

  Future<DocumentAnalysis> _analyzeImage({
    required String base64Image,
    required String mimeType,
    required String fileName,
  }) async {
    final uri = Uri.parse('${GroqConfig.baseUrl}/chat/completions');
    final body = {
      'model': GroqConfig.visionModel,
      'temperature': 0.1,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  'Filename: "$fileName". Verify whether this document is medical, '
                  'extract category, report_name, lab_name, city_name, '
                  'sample_type, collection_date, test_date, '
                  'parameters (short names only), vitals rows '
                  '(parameter, value, unit, reference, status), '
                  'conclusion, and full_report JSON.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Image',
              },
            },
          ],
        },
      ],
    };

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${GroqConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GroqException(_friendlyHttpError(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw GroqException('Groq returned an empty response. Please try again.');
    }

    final message = choices.first as Map<String, dynamic>;
    final content =
        (message['message'] as Map<String, dynamic>?)?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw GroqException('Groq returned no analysis content.');
    }

    final jsonMap = jsonDecode(_stripFences(content)) as Map<String, dynamic>;
    return DocumentAnalysis.fromJson(jsonMap);
  }

  Future<({String base64, String mimeType})> _toImagePayload({
    required Uint8List bytes,
    required String extension,
  }) async {
    switch (extension) {
      case 'png':
        _ensureUnderLimit(bytes);
        return (base64: base64Encode(bytes), mimeType: 'image/png');
      case 'jpg':
      case 'jpeg':
        _ensureUnderLimit(bytes);
        return (base64: base64Encode(bytes), mimeType: 'image/jpeg');
      case 'heic':
        throw GroqException(
          'HEIC is not supported for AI verification yet. '
          'Please upload a JPG, PNG, or PDF.',
        );
      case 'pdf':
        final rendered = await _renderPdfFirstPage(bytes);
        _ensureUnderLimit(rendered);
        return (base64: base64Encode(rendered), mimeType: 'image/png');
      case 'doc':
      case 'docx':
        throw GroqException(
          'Word documents are not supported for AI verification yet. '
          'Please upload a PDF or an image of the document.',
        );
      default:
        throw GroqException(
          'Unsupported file type ".$extension". '
          'Use PDF, PNG, JPG, or JPEG.',
        );
    }
  }

  Future<Uint8List> _renderPdfFirstPage(Uint8List bytes) async {
    PdfDocument? document;
    PdfPage? page;
    try {
      document = await PdfDocument.openData(bytes);
      if (document.pagesCount < 1) {
        throw GroqException('This PDF has no pages to analyze.');
      }
      page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );
      if (pageImage?.bytes == null || pageImage!.bytes.isEmpty) {
        throw GroqException('Could not render this PDF for analysis.');
      }
      return pageImage.bytes;
    } on GroqException {
      rethrow;
    } catch (e) {
      throw GroqException(
        'Could not read this PDF. Try exporting it again or upload a photo of the page.',
      );
    } finally {
      await page?.close();
      await document?.close();
    }
  }

  void _ensureUnderLimit(Uint8List bytes) {
    // Groq base64 image limit is ~4MB encoded; keep raw under ~3MB.
    const maxBytes = 3 * 1024 * 1024;
    if (bytes.lengthInBytes > maxBytes) {
      throw GroqException(
        'This file is too large for AI verification (max ~3 MB). '
        'Try a smaller image or a single PDF page.',
      );
    }
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _stripFences(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return text.trim();
  }

  String _friendlyHttpError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        if (message != null && message.isNotEmpty) {
          return 'Groq error: $message';
        }
      }
    } catch (_) {
      // Fall through to status-based message.
    }

    if (response.statusCode == 401) {
      return 'Invalid Groq API key. Check GROQ_API_KEY at https://console.groq.com/keys';
    }
    if (response.statusCode == 429) {
      return 'Groq rate limit reached. Please wait a moment and try again.';
    }
    return 'Groq request failed (${response.statusCode}). Please try again.';
  }
}
