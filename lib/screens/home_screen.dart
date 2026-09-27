import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/document_analysis.dart';
import '../models/medical_report.dart';
import '../models/report_category.dart';
import '../services/auth_service.dart';
import '../services/groq_service.dart';
import '../services/reports_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
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
  bool _isLoadingReports = true;
  String? _selectedFileName;
  final _promptController = TextEditingController();
  late final AnimationController _sidebarController;
  late final Animation<double> _sidebarSlide;
  final List<MedicalReport> _timeline = [];
  final _groq = GroqService();
  final _reports = ReportsService();

  final _navItems = const [
    _NavItem(Icons.home_rounded, 'Home'),
    _NavItem(Icons.folder_rounded, 'Records'),
    _NavItem(Icons.monitor_heart_outlined, 'Vitals'),
    _NavItem(Icons.calendar_month_rounded, 'Schedule'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];
  int _selectedNav = 0;

  static const _homeIndex = 0;
  static const _vitalsIndex = 2;

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
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    try {
      final reports = await _reports.fetchReports();
      if (!mounted) return;
      setState(() {
        _timeline
          ..clear()
          ..addAll(reports);
        _isLoadingReports = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReports = false);
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
    return MedicalReport(
      id: MedicalReport.buildDocumentId(
        category: analysis.category,
        reportName: analysis.reportName,
        testDate: analysis.testDate,
      ),
      reportName: analysis.reportName,
      category: analysis.category,
      labName: analysis.labName,
      cityName: analysis.cityName,
      sampleType: analysis.sampleType,
      collectionDate: analysis.collectionDate,
      testDate: analysis.testDate,
      parameters: analysis.parameters,
      vitals: analysis.vitals,
      conclusion: analysis.conclusion,
      fileName: fileName,
      fullReport: analysis.fullReport,
      confidence: analysis.confidence,
      createdAt: DateTime.now(),
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
    setState(() {
      final index = _timeline.indexWhere((r) => r.id == report.id);
      if (index < 0) return;
      _timeline[index] = report.copyWith(isStarred: next);
      _timeline.sort((a, b) {
        if (a.isStarred != b.isStarred) return a.isStarred ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    });

    try {
      await _reports.setStarred(reportId: report.id, starred: next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final index = _timeline.indexWhere((r) => r.id == report.id);
        if (index < 0) return;
        _timeline[index] = report.copyWith(isStarred: !next);
        _timeline.sort((a, b) {
          if (a.isStarred != b.isStarred) return a.isStarred ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
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

  void _submitPrompt() {
    final text = _promptController.text.trim();
    if (text.isEmpty && _selectedFileName == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          text.isEmpty
              ? 'Uploaded $_selectedFileName'
              : 'Prompt sent${_selectedFileName != null ? ' with $_selectedFileName' : ''}',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
      ),
    );
    _promptController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAF7F6),
              AppColors.foam,
              Color(0xFFF8FCFC),
            ],
          ),
        ),
        child: SafeArea(
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
                        : Stack(
                            children: [
                              _BodySection(
                                timeline: _timeline,
                                isLoadingReports: _isLoadingReports,
                                onOpenDetails: _openReportDetails,
                                onToggleStar: _toggleStar,
                              ),
                              if (_selectedNav == _homeIndex)
                                Positioned(
                                  right: 16,
                                  bottom: 12,
                                  child: _UploadFab(
                                    isVerifying: _isVerifying,
                                    onPressed: _pickFile,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (_selectedNav == _homeIndex)
                    _PromptSection(
                      controller: _promptController,
                      onSubmit: _submitPrompt,
                      hasFile: _selectedFileName != null,
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
                            color: Colors.black.withValues(alpha: 0.28 * t),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _IconAction(
            icon: sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTap: onMenuTap,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Nemo Care',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.softAqua, AppColors.deepTeal],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _BodySection extends StatelessWidget {
  const _BodySection({
    required this.timeline,
    required this.isLoadingReports,
    required this.onOpenDetails,
    required this.onToggleStar,
  });

  final List<MedicalReport> timeline;
  final bool isLoadingReports;
  final ValueChanged<MedicalReport> onOpenDetails;
  final ValueChanged<MedicalReport> onToggleStar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
      children: [
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
                  Text(
                    'TIMELINE',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your records',
                    style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading && entries.isNotEmpty)
              Text(
                '${entries.length}',
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: AppColors.deepTeal.withValues(alpha: 0.35),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isLoading
              ? 'Syncing your latest reports…'
              : entries.isEmpty
                  ? 'Upload a report to begin tracking.'
                  : 'Tap a row to expand · star to pin',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 18),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.55),
                  AppColors.mist.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  _TimelineTile(
                    report: entries[i],
                    isFirst: i == 0,
                    isLast: i == entries.length - 1,
                    onDetails: () => onOpenDetails(entries[i]),
                    onToggleStar: () => onToggleStar(entries[i]),
                  ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            AppColors.mist.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.softAqua.withValues(alpha: 0.45),
                  AppColors.mist,
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_motion_rounded,
              color: AppColors.deepTeal,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing on the timeline yet',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your lab panels and clinical notes will land here as slim, expandable rows.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatefulWidget {
  const _TimelineTile({
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
  final VoidCallback onToggleStar;

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile> {
  bool _expanded = false;

  String get _dateLabel {
    final raw = widget.report.testDate.trim();
    if (raw.isNotEmpty && raw.toLowerCase() != 'unknown date') {
      // Prefer short date if ISO-like
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return _formatShort(parsed);
      return raw;
    }
    return _formatShort(widget.report.createdAt);
  }

  String _formatShort(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text(
                  _dateLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: report.isStarred ? const Color(0xFFE8B84A) : accent,
                    boxShadow: [
                      BoxShadow(
                        color: (report.isStarred
                                ? const Color(0xFFE8B84A)
                                : accent)
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                if (!widget.isLast)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 1.5,
                    height: _expanded ? 88 : 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.45),
                          AppColors.border,
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
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: _expanded
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _expanded
                          ? accent.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                    boxShadow: _expanded
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.1),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 3.5, color: accent),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          report.category.label.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          report.reportName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.sora(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 30,
                                          minHeight: 30,
                                        ),
                                        tooltip:
                                            report.isStarred ? 'Unstar' : 'Star',
                                        onPressed: widget.onToggleStar,
                                        icon: Icon(
                                          report.isStarred
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          size: 18,
                                          color: report.isStarred
                                              ? const Color(0xFFE8B84A)
                                              : AppColors.muted
                                                  .withValues(alpha: 0.7),
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
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                    ],
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.topCenter,
                                    child: _expanded
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                              right: 6,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  report.labLocationLine,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.ink
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  report.conclusion,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    height: 1.4,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Text(
                                                      _dateLabel,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: accent,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    TextButton(
                                                      onPressed:
                                                          widget.onDetails,
                                                      style:
                                                          TextButton.styleFrom(
                                                        foregroundColor:
                                                            AppColors.deepTeal,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Open report',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox(width: double.infinity),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

class _UploadFab extends StatelessWidget {
  const _UploadFab({
    required this.isVerifying,
    required this.onPressed,
  });

  final bool isVerifying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: isVerifying ? null : onPressed,
      backgroundColor: AppColors.deepTeal,
      foregroundColor: Colors.white,
      elevation: 4,
      tooltip: isVerifying ? 'Verifying…' : 'Upload report',
      child: isVerifying
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_rounded, size: 28),
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.controller,
    required this.onSubmit,
    required this.hasFile,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool hasFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepTeal.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                hasFile
                    ? 'Ask about your uploaded record'
                    : 'Ask Nemo Care anything about your health',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      hintText: 'Describe symptoms, ask about a report…',
                      hintStyle: GoogleFonts.outfit(
                        color: AppColors.muted.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: Material(
                    color: AppColors.deepTeal,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onSubmit,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [AppColors.teal, AppColors.deepTeal],
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                          ),
                        ),
                        if (displayName != null && displayName.isNotEmpty)
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          )
                        else if (email != null)
                          Text(
                            email,
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: AppColors.border),
            ),
            const SizedBox(height: 8),
            ...List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.deepTeal : AppColors.ink,
                    ),
                  ),
                  onTap: () => onSelect(index),
                ),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.logout_rounded, color: AppColors.coral),
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

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
          child: Icon(icon, color: AppColors.ink, size: 22),
        ),
      ),
    );
  }
}
