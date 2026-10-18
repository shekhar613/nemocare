import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';
import '../models/document_analysis.dart';
import '../models/finding.dart';
import '../models/medical_report.dart';
import '../models/report_category.dart';
import '../services/auth_service.dart';
import '../services/chat_history_service.dart';
import '../services/groq_service.dart';
import '../services/health_agent_service.dart';
import '../services/report_comparison_service.dart';
import '../services/reports_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/report_comparison_chat_card.dart';
import 'auth_screen.dart';
import 'insights_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'report_details_screen.dart';
import 'vitals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const double _sidebarWidth = 280;

  bool _sidebarOpen = false;
  bool _isVerifying = false;
  bool _isAsking = false;
  bool _isLoadingReports = true;
  /// When true, show the health timeline even if chat history exists.
  bool _showTimelineOverChat = false;
  String? _selectedFileName;
  final _promptController = TextEditingController();
  final _chatScrollController = ScrollController();
  late final AnimationController _sidebarController;
  late final Animation<double> _sidebarSlide;
  final List<MedicalReport> _timeline = [];
  final List<ChatMessage> _messages = [];
  final List<Finding> _findings = [];
  final _groq = GroqService();
  final _reports = ReportsService();
  final _healthAgent = HealthAgentService();
  final _chatHistory = ChatHistoryService();
  final _profiles = UserProfileService();

  final _navItems = const [
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.folder_rounded, 'Records'),
    _NavItem(Icons.monitor_heart_outlined, 'Vitals'),
    _NavItem(Icons.insights_outlined, 'Insights'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];
  int _selectedNav = 0;

  static const _homeIndex = 0;
  static const _vitalsIndex = 2;
  static const _insightsIndex = 3;

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _sidebarSlide = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _loadReports();
    _loadChatHistory();
    // Ensure USERS/{email} exists for already-signed-in sessions.
    unawaited(_profiles.ensureCurrentUserDocument());
    // Warm NVIDIA connection so the first chat reply starts sooner.
    unawaited(_healthAgent.warmUp());
  }

  Future<void> _loadChatHistory() async {
    final saved = await _chatHistory.load();
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(saved);
      _showTimelineOverChat = false;
    });
    _scrollChatToBottom();
  }

  Future<void> _persistChatHistory() async {
    await _chatHistory.save(_messages);
  }

  void _openChat() {
    setState(() => _showTimelineOverChat = false);
    _scrollChatToBottom();
  }

  void _openTimeline() {
    setState(() => _showTimelineOverChat = true);
  }

  Future<void> _clearChat() async {
    setState(() {
      _messages.clear();
      _showTimelineOverChat = false;
    });
    await _chatHistory.clear();
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _promptController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadReports() async {
    try {
      final reports = await _reports.fetchReports();
      final findings = await _reports.fetchActiveFindings();
      if (!mounted) return;
      setState(() {
        _timeline
          ..clear()
          ..addAll(reports);
        _findings
          ..clear()
          ..addAll(findings);
        _isLoadingReports = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _reloadFindings() async {
    try {
      final findings = await _reports.fetchActiveFindings();
      if (!mounted) return;
      setState(() {
        _findings
          ..clear()
          ..addAll(findings);
      });
    } catch (_) {
      // Non-blocking.
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
    if (_sidebarOpen) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  void _closeSidebar() {
    if (!_sidebarOpen) return;
    setState(() => _sidebarOpen = false);
    _sidebarController.reverse();
  }

  MedicalReport _reportFromAnalysis(
    String fileName,
    DocumentAnalysis analysis,
  ) {
    final createdAt = DateTime.now();
    final docType = MedicalReport.slugify(
      analysis.docType.isNotEmpty ? analysis.docType : analysis.reportName,
    );
    final testDate = MedicalReport.normalizeDateKey(
      analysis.testDate.isNotEmpty
          ? analysis.testDate
          : analysis.reportApprovedDate,
    );
    return MedicalReport(
      id: '$docType/$testDate',
      reportName: analysis.reportName,
      docType: docType,
      category: analysis.category,
      labName: analysis.labName,
      cityName: analysis.cityName,
      sampleType: analysis.sampleType,
      collectionDate: MedicalReport.normalizeDateKey(
        analysis.collectionDate.isNotEmpty
            ? analysis.collectionDate
            : testDate,
      ),
      testDate: testDate,
      reportApprovedDate: MedicalReport.normalizeDateKey(
        analysis.reportApprovedDate.isNotEmpty
            ? analysis.reportApprovedDate
            : testDate,
      ),
      patientName: analysis.patientName,
      patientSex: analysis.patientSex,
      patientAge: analysis.patientAge,
      regnNo: analysis.regnNo,
      mrdNo: analysis.mrdNo,
      parameters: analysis.parameters,
      vitals: analysis.vitals,
      values: analysis.values,
      conclusion: analysis.conclusion,
      fileName: fileName,
      fullReport: analysis.fullReport,
      confidence: analysis.confidence,
      createdAt: createdAt,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.coral : AppColors.deepTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
      ),
    );
  }

  void _openReportDetails(MedicalReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailsScreen(report: report),
      ),
    );
  }

  Future<void> _toggleStar(MedicalReport report) async {
    final next = !report.isStarred;
    // Match the exact list entry (id can collide when name+date match).
    final matchIndex = _timeline.indexWhere(
      (r) =>
          r.id == report.id &&
          r.createdAt.millisecondsSinceEpoch ==
              report.createdAt.millisecondsSinceEpoch,
    );
    final index = matchIndex >= 0
        ? matchIndex
        : _timeline.indexWhere((r) => r.id == report.id);
    if (index < 0) return;

    final target = _timeline[index];
    setState(() {
      _timeline[index] = target.copyWith(isStarred: next);
      // Keep chronological order so starring does not jump another card
      // into this slot (which looked like the wrong report got starred).
    });

    try {
      await _reports.setStarred(reportId: target.id, starred: next);
    } catch (_) {
      if (!mounted) return;
      final revertIndex = _timeline.indexWhere(
        (r) =>
            r.id == target.id &&
            r.createdAt.millisecondsSinceEpoch ==
                target.createdAt.millisecondsSinceEpoch,
      );
      setState(() {
        if (revertIndex >= 0) {
          _timeline[revertIndex] =
              _timeline[revertIndex].copyWith(isStarred: !next);
        }
      });
      _showMessage('Could not update star. Try again.', isError: true);
    }
  }

  Future<void> _pickFile() async {
    if (_isVerifying) return;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (file == null) return;

    final name = file.name;
    late final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      _showMessage(
        'Could not read that file. Try another PDF or image.',
        isError: true,
      );
      return;
    }
    if (bytes.isEmpty) {
      _showMessage(
        'Could not read that file. Try another PDF or image.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _selectedFileName = name;
    });

    try {
      final analysis = await _groq.analyzeDocument(
        bytes: bytes,
        fileName: name,
      );

      if (!mounted) return;

      if (!analysis.isMedical) {
        setState(() {
          _selectedFileName = null;
          _isVerifying = false;
        });
        _showMessage(
          analysis.rejectionReason?.isNotEmpty == true
              ? analysis.rejectionReason!
              : 'This file does not look like a medical document, so it was not added.',
          isError: true,
        );
        return;
      }

      final draft = _reportFromAnalysis(name, analysis);
      final saved = await _reports.saveReport(draft);

      if (!mounted) return;
      setState(() {
        _timeline.removeWhere((r) => r.id == saved.id);
        _timeline.insert(0, saved);
        _isVerifying = false;
      });
      await _reloadFindings();
      _showMessage('Medical report verified and saved to your account.');
    } on GroqException catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedFileName = null;
        _isVerifying = false;
      });
      _showMessage(e.message, isError: true);
    } on ReportsException catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedFileName = null;
        _isVerifying = false;
      });
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedFileName = null;
        _isVerifying = false;
      });
      _showMessage(
        'Could not verify or save this document. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Future<void> _openHealthProfileEditor() async {
    _closeSidebar();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isEditing: true),
      ),
    );
  }

  Future<void> _submitPrompt() async {
    final text = _promptController.text.trim();

    // Attach-only: pick already triggers verification; just acknowledge.
    if (text.isEmpty) {
      if (_selectedFileName != null && !_isVerifying) {
        _showMessage('Attached $_selectedFileName — verifying upload.');
      }
      return;
    }

    if (_isAsking || _isVerifying) return;

    final historySnapshot = List<ChatMessage>.from(_messages);
    setState(() {
      _messages.add(ChatMessage.user(text));
      _messages.add(ChatMessage.assistant(''));
      _isAsking = true;
      _showTimelineOverChat = false;
    });
    _promptController.clear();
    _scrollChatToBottom();

    final assistantIndex = _messages.length - 1;

    final comparisonDraft = ReportComparisonService.isComparisonIntent(text)
        ? ReportComparisonService().compareLatestPair(_timeline)
        : null;

    // Rich comparison card path (Increased / Decreased / Unchanged).
    if (comparisonDraft != null) {
      try {
        final result = await _healthAgent.askDetailed(
          question: text,
          reports: _timeline,
          history: historySnapshot,
          findings: _findings,
          comparisonContext: comparisonDraft,
        );
        if (!mounted) return;
        final insight = _cleanComparisonInsight(
          result.reply,
          fallback: comparisonDraft.insight,
        );
        final comparison = comparisonDraft.copyWith(insight: insight);
        setState(() {
          _messages[assistantIndex] = ChatMessage.assistant(
            comparison.intro,
            comparison: comparison,
          );
          _isAsking = false;
        });
        _scrollChatToBottom();
        await _persistChatHistory();
      } on HealthAgentException catch (e) {
        if (!mounted) return;
        // Still show the structured card with local insight if the API fails.
        setState(() {
          _messages[assistantIndex] = ChatMessage.assistant(
            comparisonDraft.intro,
            comparison: comparisonDraft,
          );
          _isAsking = false;
        });
        await _persistChatHistory();
        _showMessage(e.message, isError: true);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex] = ChatMessage.assistant(
            comparisonDraft.intro,
            comparison: comparisonDraft,
          );
          _isAsking = false;
        });
        await _persistChatHistory();
      }
      return;
    }

    var pendingUpdate = false;
    var lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await for (final piece in _healthAgent.askStream(
        question: text,
        reports: _timeline,
        history: historySnapshot,
        findings: _findings,
      )) {
        if (!mounted) return;
        final current = _messages[assistantIndex].content;
        _messages[assistantIndex] =
            _messages[assistantIndex].copyWith(content: current + piece);

        final now = DateTime.now();
        final shouldPaint = current.isEmpty ||
            now.difference(lastUiUpdate).inMilliseconds >= 80;
        if (shouldPaint) {
          lastUiUpdate = now;
          setState(() {});
          _scrollChatToBottom();
          pendingUpdate = false;
        } else {
          pendingUpdate = true;
        }
      }
      if (!mounted) return;
      if (pendingUpdate) setState(() {});
      setState(() => _isAsking = false);
      _scrollChatToBottom();
      await _persistChatHistory();
    } on HealthAgentException catch (e) {
      if (!mounted) return;
      setState(() {
        if (_messages.length > assistantIndex &&
            !_messages[assistantIndex].isPersistable) {
          _messages.removeAt(assistantIndex);
        }
        _isAsking = false;
      });
      await _persistChatHistory();
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_messages.length > assistantIndex &&
            !_messages[assistantIndex].isPersistable) {
          _messages.removeAt(assistantIndex);
        }
        _isAsking = false;
      });
      await _persistChatHistory();
      _showMessage(
        'Could not get an answer from Nemotron. Please try again.',
        isError: true,
      );
    }
  }

  String _cleanComparisonInsight(String reply, {required String fallback}) {
    var out = reply.trim();
    if (out.isEmpty) return fallback;
    out = out
        .replaceAll(
          RegExp(
            r'Not medical advice[—.–-]?\s*ask your clinician\.?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'This is a simple summary, not a diagnosis\.?',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return out.isEmpty ? fallback : out;
  }

  void _openInsightsFromComparison() {
    setState(() {
      _selectedNav = _insightsIndex;
      _showTimelineOverChat = false;
    });
    _closeSidebar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDFF3F2),
              AppColors.foam,
              Color(0xFFF7FBFA),
            ],
            stops: [0.0, 0.28, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.softAqua.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -70,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.teal.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _HeaderSection(
                        onMenuTap: _toggleSidebar,
                        sidebarOpen: _sidebarOpen,
                      ),
                      Expanded(
                        child: _selectedNav == _vitalsIndex
                            ? VitalsScreen(
                                initialReports: _timeline,
                                embedded: true,
                              )
                            : _selectedNav == _insightsIndex
                                ? const InsightsScreen(embedded: true)
                                : (!_showTimelineOverChat &&
                                        (_messages.isNotEmpty || _isAsking))
                                    ? _ChatSection(
                                        messages: _messages,
                                        isAsking: _isAsking,
                                        scrollController: _chatScrollController,
                                        reportCount: _timeline.length,
                                        onClear: _clearChat,
                                        onShowTimeline: _openTimeline,
                                        onUnderstandMore:
                                            _openInsightsFromComparison,
                                      )
                                    : _BodySection(
                                        timeline: _timeline,
                                        findings: _findings,
                                        isLoadingReports: _isLoadingReports,
                                        onOpenDetails: _openReportDetails,
                                        onToggleStar: _toggleStar,
                                        chatMessageCount: _messages.length,
                                        onOpenChat: _messages.isNotEmpty
                                            ? _openChat
                                            : null,
                                      ),
                      ),
                      if (_selectedNav == _homeIndex)
                        _PromptSection(
                          controller: _promptController,
                          onSubmit: _submitPrompt,
                          onAttach: _pickFile,
                          onClearFile: () =>
                              setState(() => _selectedFileName = null),
                          fileName: _selectedFileName,
                          isVerifying: _isVerifying,
                          isAsking: _isAsking,
                        ),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: _sidebarSlide,
                    builder: (context, _) {
                      final t = _sidebarSlide.value;
                      if (t == 0) return const SizedBox.shrink();
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _closeSidebar,
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.32 * t),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -_sidebarWidth * (1 - t),
                            top: 0,
                            bottom: 0,
                            width: _sidebarWidth,
                            child: _Sidebar(
                              items: _navItems,
                              selectedIndex: _selectedNav,
                              onSelect: (index) {
                                setState(() => _selectedNav = index);
                                _closeSidebar();
                              },
                              onClose: _closeSidebar,
                              onEditHealthProfile: _openHealthProfileEditor,
                              onSignOut: _signOut,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.onMenuTap,
    required this.sidebarOpen,
  });

  final VoidCallback onMenuTap;
  final bool sidebarOpen;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _firstName {
    final raw = AuthService().currentUser?.displayName?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.split(RegExp(r'\s+')).first;
  }

  String get _dateLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName;
    final subtitle = firstName != null
        ? '$_greeting, $firstName'
        : _greeting;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTap: onMenuTap,
            tooltip: sidebarOpen ? 'Close menu' : 'Open menu',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.teal.withValues(alpha: 0.55),
                        AppColors.deepTeal.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: const AppLogoMark(size: 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nemo Care',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.45,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.muted.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Text(
                            _dateLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepTeal.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.foam.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.ink, size: 21),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _BodySection extends StatelessWidget {
  const _BodySection({
    required this.timeline,
    required this.findings,
    required this.isLoadingReports,
    required this.onOpenDetails,
    required this.onToggleStar,
    this.chatMessageCount = 0,
    this.onOpenChat,
  });

  final List<MedicalReport> timeline;
  final List<Finding> findings;
  final bool isLoadingReports;
  final ValueChanged<MedicalReport> onOpenDetails;
  final ValueChanged<MedicalReport> onToggleStar;
  final int chatMessageCount;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        if (onOpenChat != null && chatMessageCount > 0) ...[
          Material(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onOpenChat,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: AppColors.deepTeal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Continue chat · $chatMessageCount saved messages',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (findings.isNotEmpty) ...[
          _FindingsStrip(findings: findings),
          const SizedBox(height: 14),
        ],
        _HealthTimelineSection(
          entries: timeline,
          isLoading: isLoadingReports,
          onOpenDetails: onOpenDetails,
          onToggleStar: onToggleStar,
        ),
      ],
    );
  }
}

class _FindingsStrip extends StatelessWidget {
  const _FindingsStrip({required this.findings});

  final List<Finding> findings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'ACTIVE FINDINGS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.coral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: findings.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.coral.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f.displayLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Since ${f.sinceDate}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ChatSection extends StatelessWidget {
  const _ChatSection({
    required this.messages,
    required this.isAsking,
    required this.scrollController,
    required this.reportCount,
    required this.onClear,
    required this.onShowTimeline,
    this.onUnderstandMore,
  });

  final List<ChatMessage> messages;
  final bool isAsking;
  final ScrollController scrollController;
  final int reportCount;
  final VoidCallback onClear;
  final VoidCallback onShowTimeline;
  final VoidCallback? onUnderstandMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reportCount > 0
                      ? 'Asking about $reportCount report${reportCount == 1 ? '' : 's'}'
                      : 'General health chat · upload reports for personal context',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              TextButton(
                onPressed: onShowTimeline,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.deepTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'Timeline',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClear,
                tooltip: 'Clear chat',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isStreamingPlaceholder = isAsking &&
                  !message.isUser &&
                  !message.hasRichComparison &&
                  message.content.isEmpty &&
                  index == messages.length - 1;
              if (isStreamingPlaceholder) {
                return const _TypingBubble();
              }
              if (message.hasRichComparison) {
                return ReportComparisonChatCard(
                  comparison: message.comparison!,
                  onUnderstandMore: onUnderstandMore,
                );
              }
              final isStreamingReply = isAsking &&
                  !message.isUser &&
                  index == messages.length - 1 &&
                  message.content.isNotEmpty;
              return _ChatBubble(
                message: message,
                isStreaming: isStreamingReply,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.isStreaming = false});

  final ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.deepTeal : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message.content,
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  height: 1.45,
                  color: isUser ? Colors.white : AppColors.ink,
                ),
              ),
            ),
            if (isStreaming) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.teal.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.teal.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Nemotron is reading your reports…',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthTimelineSection extends StatelessWidget {
  const _HealthTimelineSection({
    required this.entries,
    required this.isLoading,
    required this.onOpenDetails,
    required this.onToggleStar,
  });

  final List<MedicalReport> entries;
  final bool isLoading;
  final ValueChanged<MedicalReport> onOpenDetails;
  final ValueChanged<MedicalReport> onToggleStar;

  int get _starredCount => entries.where((e) => e.isStarred).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HEALTH TIMELINE',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your records',
                    style: GoogleFonts.sora(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLoading
                        ? 'Syncing your latest reports…'
                        : entries.isEmpty
                            ? 'Upload a lab report to start your timeline.'
                            : 'Expand a row for details · star to pin favorites',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading && entries.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.9),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${entries.length}',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepTeal,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _starredCount > 0 ? '$_starredCount★' : 'total',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.deepTeal,
              ),
            ),
          )
        else if (entries.isEmpty)
          const _TimelineEmptyState()
        else
          Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                _TimelineTile(
                  key: ValueKey(
                    '${entries[i].id}_${entries[i].createdAt.millisecondsSinceEpoch}',
                  ),
                  report: entries[i],
                  isFirst: i == 0,
                  isLast: i == entries.length - 1,
                  onDetails: () => onOpenDetails(entries[i]),
                  onToggleStar: onToggleStar,
                ),
            ],
          ),
      ],
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const AppLogoMark(size: 88),
          ),
          const SizedBox(height: 20),
          Text(
            'Your timeline is ready',
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the upload button to add a lab report, prescription, or imaging result.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatefulWidget {
  const _TimelineTile({
    super.key,
    required this.report,
    required this.isFirst,
    required this.isLast,
    required this.onDetails,
    required this.onToggleStar,
  });

  final MedicalReport report;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onDetails;
  final ValueChanged<MedicalReport> onToggleStar;

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile> {
  bool _expanded = false;

  String get _dateLabel {
    final raw = widget.report.testDate.trim();
    if (raw.isNotEmpty && raw.toLowerCase() != 'unknown date') {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return _formatShort(parsed);
      return raw;
    }
    return _formatShort(widget.report.createdAt);
  }

  String _formatShort(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Color get _accent {
    switch (widget.report.category) {
      case ReportCategory.lab:
        return AppColors.teal;
      case ReportCategory.prescription:
        return AppColors.coral;
      case ReportCategory.imaging:
        return const Color(0xFF3B82A0);
      case ReportCategory.clinicalReport:
        return const Color(0xFF2F9E7B);
      case ReportCategory.otherMedical:
        return AppColors.deepTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final accent = _accent;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: report.isStarred
                          ? const Color(0xFFE8B84A)
                          : accent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (report.isStarred
                                ? const Color(0xFFE8B84A)
                                : accent)
                            .withValues(alpha: 0.28),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!widget.isLast)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 2,
                    height: _expanded ? 120 : 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.4),
                          AppColors.border.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: _expanded ? 1 : 0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _expanded
                            ? accent.withValues(alpha: 0.4)
                            : AppColors.border.withValues(alpha: 0.85),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_expanded ? accent : AppColors.deepTeal)
                              .withValues(alpha: _expanded ? 0.12 : 0.05),
                          blurRadius: _expanded ? 22 : 14,
                          offset: Offset(0, _expanded ? 10 : 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: accent, width: 4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      report.category.label.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.7,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _dateLabel,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    tooltip:
                                        report.isStarred ? 'Unstar' : 'Star',
                                    onPressed: () =>
                                        widget.onToggleStar(report),
                                    icon: Icon(
                                      report.isStarred
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18,
                                      color: report.isStarred
                                          ? const Color(0xFFE8B84A)
                                          : AppColors.muted
                                              .withValues(alpha: 0.65),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _expanded ? 0.5 : 0,
                                    duration:
                                        const Duration(milliseconds: 220),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: AppColors.muted
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                report.reportName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (!_expanded) ...[
                                const SizedBox(height: 4),
                                Text(
                                  report.labLocationLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                if (report.labLocationLine != 'Lab unknown')
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: AppColors.muted
                                            .withValues(alpha: 0.9),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          report.labLocationLine,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.ink
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  report.conclusion,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: widget.onDetails,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.deepTeal,
                                      backgroundColor: AppColors.mist
                                          .withValues(alpha: 0.85),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      'Open report',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptSection extends StatefulWidget {
  const _PromptSection({
    required this.controller,
    required this.onSubmit,
    required this.onAttach,
    required this.onClearFile,
    required this.fileName,
    required this.isVerifying,
    required this.isAsking,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onAttach;
  final VoidCallback onClearFile;
  final String? fileName;
  final bool isVerifying;
  final bool isAsking;

  @override
  State<_PromptSection> createState() => _PromptSectionState();
}

class _PromptSectionState extends State<_PromptSection> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  bool get _canSend =>
      (_hasText || widget.fileName != null) &&
      !widget.isVerifying &&
      !widget.isAsking;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final fileName = widget.fileName;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(12, 4, 12, 10 + (bottomInset > 0 ? 0 : 4)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFE5E5E5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fileName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.mist,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                widget.isVerifying
                                    ? Icons.hourglass_top_rounded
                                    : Icons.description_rounded,
                                size: 16,
                                color: AppColors.deepTeal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    widget.isVerifying
                                        ? 'Verifying…'
                                        : 'Attached',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: widget.isVerifying
                                  ? null
                                  : widget.onClearFile,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ComposerIconButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Attach report',
                        onTap: (widget.isVerifying || widget.isAsking)
                            ? null
                            : widget.onAttach,
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          enabled: !widget.isAsking,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: widget.isAsking
                                ? 'Nemotron is thinking…'
                                : 'Ask about your health reports',
                            hintStyle: GoogleFonts.outfit(
                              color: AppColors.muted.withValues(alpha: 0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            height: 1.35,
                            color: AppColors.ink,
                          ),
                          onSubmitted: (_) {
                            if (_canSend) widget.onSubmit();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      _SendButton(
                        enabled: _canSend,
                        onTap: widget.onSubmit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nemo Care can make mistakes. Check important health info.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.muted.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 24,
            color: onTap == null
                ? AppColors.muted.withValues(alpha: 0.4)
                : AppColors.ink.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(bottom: 2, right: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? AppColors.ink : const Color(0xFFD0D0D0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 20,
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onClose,
    required this.onEditHealthProfile,
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  final VoidCallback onEditHealthProfile;
  final VoidCallback onSignOut;

  String get _initials {
    final user = AuthService().currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
      final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
      if (letters.isNotEmpty) return letters;
    }
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return 'N';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email;

    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.mist,
                    Colors.white.withValues(alpha: 0.4),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const AppLogoMark(size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nemo Care',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName != null && displayName.isNotEmpty
                              ? displayName
                              : (email ?? 'Health companion'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.softAqua, AppColors.deepTeal],
                      ),
                    ),
                    child: Text(
                      _initials,
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Signed in',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'MENU',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.muted.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  selected: selected,
                  selectedTileColor: AppColors.mist,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    item.icon,
                    color: selected ? AppColors.deepTeal : AppColors.muted,
                  ),
                  title: Text(
                    item.label,
                    style: GoogleFonts.outfit(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.deepTeal : AppColors.ink,
                    ),
                  ),
                  trailing: selected
                      ? Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.deepTeal,
                          ),
                        )
                      : null,
                  onTap: () => onSelect(index),
                ),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.deepTeal,
                ),
                title: Text(
                  'Health profile',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Text(
                  'Update onboarding details',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
                onTap: onEditHealthProfile,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading:
                    const Icon(Icons.logout_rounded, color: AppColors.coral),
                title: Text(
                  'Sign out',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral,
                  ),
                ),
                onTap: onSignOut,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Personal health, simply kept.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
