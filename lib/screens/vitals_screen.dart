import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/medical_report.dart';
import '../models/vital_panel_templates.dart';
import '../models/vital_row.dart';
import '../services/reports_service.dart';
import '../theme/app_theme.dart';

/// Shows uploaded reports using the standard vitals panel templates.
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({
    super.key,
    this.initialReports = const [],
    this.embedded = false,
  });

  final List<MedicalReport> initialReports;
  final bool embedded;

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _reports = ReportsService();
  List<MedicalReport> _reportsList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reportsList = List<MedicalReport>.from(widget.initialReports);
    _loading = widget.initialReports.isEmpty;
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final all = await _reports.fetchReports();
      if (!mounted) return;
      setState(() {
        _reportsList = all.isNotEmpty ? all : widget.initialReports;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            _reportsList.isEmpty ? 'Could not load your reports.' : null;
      });
    }
  }

  /// One section per panel template. Values from all matching uploads are merged
  /// (so KFT + Urine fill the same Kidney & Urine table).
  List<_PanelSectionData> _buildSections(List<MedicalReport> reports) {
    final byPanel = <String, _PanelBucket>{};

    for (final report in reports) {
      final panel = VitalPanelTemplates.matchByReportName(report.reportName);
      if (panel == null) continue;

      final bucket = byPanel.putIfAbsent(
        panel.id,
        () => _PanelBucket(panel: panel),
      );
      bucket.reports.add(report);
      bucket.extracted.addAll(report.displayVitals);
    }

    final sections = <_PanelSectionData>[];
    for (final bucket in byPanel.values) {
      bucket.reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final primary = bucket.reports.first;
      final rows = VitalPanelTemplates.presentReport(
        panel: bucket.panel,
        extracted: bucket.extracted,
      );
      sections.add(
        _PanelSectionData(
          panel: bucket.panel,
          report: primary,
          sourceReports: List<MedicalReport>.from(bucket.reports),
          rows: rows,
        ),
      );
    }

    sections.sort((a, b) => a.panel.order.compareTo(b.panel.order));
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading && _reportsList.isEmpty) {
      body = const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.deepTeal,
        ),
      );
    } else if (_reportsList.isEmpty) {
      body = _VitalsEmptyState(message: _error);
    } else {
      final sections = _buildSections(_reportsList);
      body = RefreshIndicator(
        color: AppColors.deepTeal,
        onRefresh: _loadAll,
        child: sections.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  _VitalsEmptyState(
                    message:
                        'No matching panel templates yet. Upload CBC, Lipid, LFT, or similar lab reports.',
                  ),
                ],
              )
            : _VitalsBody(sections: sections),
      );
    }

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: Text(
          'Vitals',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _PanelBucket {
  _PanelBucket({required this.panel});

  final VitalPanelTemplate panel;
  final List<MedicalReport> reports = [];
  final List<VitalRow> extracted = [];
}

class _PanelSectionData {
  const _PanelSectionData({
    required this.panel,
    required this.report,
    required this.sourceReports,
    required this.rows,
  });

  final VitalPanelTemplate panel;
  final MedicalReport report;
  final List<MedicalReport> sourceReports;
  final List<PresentedPanelRow> rows;
}

class _VitalsBody extends StatelessWidget {
  const _VitalsBody({required this.sections});

  final List<_PanelSectionData> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          _PanelSection(data: sections[i]),
          if (i < sections.length - 1) const SizedBox(height: 22),
        ],
        const SizedBox(height: 16),
        _Legend(),
      ],
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.data});

  final _PanelSectionData data;

  @override
  Widget build(BuildContext context) {
    final report = data.report;
    final panel = data.panel;
    final sources = data.sourceReports;

    final sourceLine = sources.length == 1
        ? report.labLocationLine
        : sources.map((r) => r.reportName).toSet().join(' · ');

    final dateLine = sources.length == 1
        ? 'Test Date · ${report.testDate}'
        : 'Sources · ${sources.map((r) => '${r.reportName} (${r.testDate})').join(', ')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${panel.order}. ${panel.title}',
          style: GoogleFonts.sora(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sourceLine,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.ink.withValues(alpha: 0.85),
          ),
        ),
        Text(
          dateLine,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        _TemplateTable(rows: data.rows),
      ],
    );
  }
}

class _TemplateTable extends StatelessWidget {
  const _TemplateTable({required this.rows});

  final List<PresentedPanelRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const _TableHeader(),
          const Divider(height: 1, color: AppColors.border),
          for (var i = 0; i < rows.length; i++) ...[
            _TableRow(row: rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _headerCell('Parameter', flex: 4),
          _headerCell('Report', flex: 3),
          _headerCell('Unit', flex: 2),
          _headerCell('Normal Range', flex: 4),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.deepTeal,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.row});

  final PresentedPanelRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
            child: _ReportCell(row: row),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.unit,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              row.normalRange,
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

class _ReportCell extends StatelessWidget {
  const _ReportCell({required this.row});

  final PresentedPanelRow row;

  Color get _color {
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

  IconData get _icon {
    switch (row.status) {
      case VitalStatus.normal:
        return Icons.check_circle_rounded;
      case VitalStatus.high:
        return Icons.arrow_upward_rounded;
      case VitalStatus.low:
        return Icons.arrow_downward_rounded;
      case VitalStatus.unknown:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Row(
      children: [
        Icon(_icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            row.value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF2F9E7B),
          label: 'Normal',
        ),
        _LegendItem(
          icon: Icons.arrow_upward_rounded,
          color: AppColors.coral,
          label: 'High',
        ),
        _LegendItem(
          icon: Icons.arrow_downward_rounded,
          color: Color(0xFF3B82A0),
          label: 'Low',
        ),
        _LegendItem(
          icon: Icons.remove_rounded,
          color: AppColors.muted,
          label: 'Not in report',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VitalsEmptyState extends StatelessWidget {
  const _VitalsEmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mist,
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: AppColors.deepTeal,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No report yet',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  'Upload a lab report (CBC, Lipid, LFT, …) to see it in the vitals template.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
