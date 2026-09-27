import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/medical_report.dart';
import '../models/report_category.dart';
import '../models/vital_row.dart';
import '../theme/app_theme.dart';

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({super.key, required this.report});

  final MedicalReport report;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  MedicalReport get report => widget.report;

  Color get _accent {
    switch (report.category) {
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
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.foam,
      body: Stack(
        children: [
          // Atmospheric background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    AppColors.mist.withValues(alpha: 0.9),
                    AppColors.foam,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: topPad),
              _TopBar(accent: accent),
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      children: [
                        _HeroHeader(report: report, accent: accent),
                        const SizedBox(height: 22),
                        // 1 · Sample type  ·  2 · Collection date
                        Row(
                          children: [
                            Expanded(
                              child: _MetaTile(
                                index: '01',
                                label: 'Sample type',
                                value: report.displaySampleType,
                                icon: Icons.science_outlined,
                                accent: accent,
                                delay: 0,
                                controller: _enter,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetaTile(
                                index: '02',
                                label: 'Collection date',
                                value: report.displayCollectionDate,
                                icon: Icons.event_outlined,
                                accent: accent,
                                delay: 0.08,
                                controller: _enter,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        // 3 · Report data
                        _SectionLabel(
                          index: '03',
                          title: 'Report data',
                          accent: accent,
                        ),
                        const SizedBox(height: 12),
                        _ReportDataPanel(report: report, accent: accent),
                        const SizedBox(height: 22),
                        // 4 · Conclusion
                        _SectionLabel(
                          index: '04',
                          title: 'Conclusion',
                          accent: accent,
                        ),
                        const SizedBox(height: 12),
                        _ConclusionBlock(
                          text: report.conclusion,
                          accent: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.ink,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Report',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.report, required this.accent});

  final MedicalReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.category.label.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: accent,
                ),
              ),
            ),
            if (report.isStarred) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: Color(0xFFE8B84A),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          report.reportName,
          style: GoogleFonts.sora(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        if (report.labLocationLine != 'Lab unknown') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.muted.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  report.labLocationLine,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Container(
          height: 3,
          width: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.2)],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.index,
    required this.title,
    required this.accent,
  });

  final String index;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          index,
          style: GoogleFonts.sora(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: accent.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.index,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.delay,
    required this.controller,
  });

  final String index;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final double delay;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, (delay + 0.55).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const Spacer(),
                  Text(
                    index,
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.25,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDataPanel extends StatelessWidget {
  const _ReportDataPanel({required this.report, required this.accent});

  final MedicalReport report;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rows = report.displayVitals;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                report.reportDataText,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.1),
                        accent.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      _colHeader('Parameter', flex: 4),
                      _colHeader('Report', flex: 3),
                      _colHeader('Unit', flex: 2),
                      _colHeader('Normal', flex: 3),
                    ],
                  ),
                ),
                for (var i = 0; i < rows.length; i++)
                  _VitalRowTile(
                    row: rows[i],
                    accent: accent,
                    isLast: i == rows.length - 1,
                    striped: i.isOdd,
                  ),
              ],
            ),
    );
  }

  Widget _colHeader(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: accent,
        ),
      ),
    );
  }
}

class _VitalRowTile extends StatelessWidget {
  const _VitalRowTile({
    required this.row,
    required this.accent,
    required this.isLast,
    required this.striped,
  });

  final VitalRow row;
  final Color accent;
  final bool isLast;
  final bool striped;

  Color get _statusColor {
    switch (row.status) {
      case VitalStatus.normal:
        return const Color(0xFF2F9E7B);
      case VitalStatus.high:
        return AppColors.coral;
      case VitalStatus.low:
        return const Color(0xFF3B82A0);
      case VitalStatus.unknown:
        return AppColors.muted;
    }
  }

  String get _statusLabel {
    switch (row.status) {
      case VitalStatus.normal:
        return 'OK';
      case VitalStatus.high:
        return 'H';
      case VitalStatus.low:
        return 'L';
      case VitalStatus.unknown:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final value = row.value.trim().isEmpty ? '—' : row.value;

    return Container(
      decoration: BoxDecoration(
        color: striped
            ? AppColors.foam.withValues(alpha: 0.55)
            : Colors.transparent,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              row.parameter,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (_statusLabel.isNotEmpty) ...[
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _statusLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.unit.isEmpty ? '—' : row.unit,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.reference.isEmpty ? '—' : row.reference,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConclusionBlock extends StatelessWidget {
  const _ConclusionBlock({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent, accent.withValues(alpha: 0.35)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 22,
                      color: accent.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
