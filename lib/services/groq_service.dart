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
  "doc_type": "short snake_case panel key used for storage, e.g. cbc, lipid_profile, lft, kft, thyroid_profile, urine_routine, vitamin_panel, iron_studies, blood_sugar, prescription, imaging, clinical_report",
  "report_name": "human title e.g. CBC, Lipid Profile",
  "lab_name": "lab / hospital / clinic name if printed, else empty string",
  "city_name": "city or locality printed on the report, or empty string if unknown",
  "sample_type": "specimen / sample type if printed (e.g. Blood, Serum, Urine, Plasma), else empty string",
  "collection_date": "sample collection date (prefer YYYY-MM-DD)",
  "test_date": "report / approved date (prefer YYYY-MM-DD)",
  "report_approved_date": "same as test_date when only one date exists (YYYY-MM-DD)",
  "patient_name": "string or empty",
  "patient_sex": "male | female | other | empty",
  "patient_age": number or null,
  "regn_no": "registration number if printed, else empty",
  "mrd_no": "MRD / hospital id if printed, else empty",
  "values": [
    {
      "parameterKey": "hemoglobin",
      "rawLabel": "Haemoglobin (Hb)",
      "valueType": "numeric",
      "value": 12.2,
      "unit": "g/dL",
      "refLow": 12.0,
      "refHigh": 15.0,
      "flag": null
    }
  ],
  "parameters": ["short analyte names only"],
  "vitals": [
    {
      "parameter": "Hemoglobin",
      "value": "12.2",
      "unit": "g/dL",
      "reference": "12.0 - 15.0",
      "status": "normal"
    }
  ],
  "conclusion": "1-3 sentence clinical conclusion / impression (no medical advice)",
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

Rules:
- Always set doc_type to a stable snake_case key (cbc for Complete Blood Count, etc.).
- values[] is required for lab panels: one row per analyte.
- parameterKey = snake_case id; rawLabel = printed label; value = number when possible.
- flag = "L" | "H" | null from the report marks or by comparing value to refLow/refHigh.
- refLow/refHigh = numeric ends of the printed reference interval when available.
- vitals can mirror values for UI compatibility.
- Never diagnose or prescribe. If a field is missing, use empty string, empty array, or null.
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
                  'extract doc_type, report_name, lab_name, patient fields, '
                  'dates, values[] (parameterKey, rawLabel, value, unit, '
                  'refLow, refHigh, flag), vitals, conclusion, and full_report.',
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
