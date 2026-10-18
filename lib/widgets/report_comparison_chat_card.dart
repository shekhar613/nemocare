import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/report_comparison.dart';
import '../theme/app_theme.dart';

/// Rich chat bubble matching the Nemo Care report-comparison mock.
class ReportComparisonChatCard extends StatelessWidget {
  const ReportComparisonChatCard({
    super.key,
    required this.comparison,
    this.onUnderstandMore,
  });

  final ReportComparison comparison;
  final VoidCallback? onUnderstandMore;

  static const _increase = Color(0xFF2D8A5E);
  static const _increaseBg = Color(0xFFE8F6EE);
  static const _increaseBadge = Color(0xFFD4F0E0);
  static const _decrease = Color(0xFFB45F06);
  static const _decreaseBg = Color(0xFFFFF1E6);
  static const _decreaseBadge = Color(0xFFFFE4CC);
  static const _neutral = Color(0xFF718096);
  static const _neutralBg = Color(0xFFF1F3F5);
  static const _insightBg = Color(0xFFEBF8FF);
  static const _insightIcon = Color(0xFF3182CE);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.94,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(comparison: comparison),
            const SizedBox(height: 10),
            if (comparison.increased.isNotEmpty)
              _GroupCard(
                title: 'Increased',
                icon: Icons.arrow_upward_rounded,
                accent: _increase,
                softBg: _increaseBg,
                badgeBg: _increaseBadge,
                metrics: comparison.increased,
              ),
            if (comparison.increased.isNotEmpty) const SizedBox(height: 10),
            if (comparison.decreased.isNotEmpty)
              _GroupCard(
                title: 'Decreased',
                icon: Icons.arrow_downward_rounded,
                accent: _decrease,
                softBg: _decreaseBg,
                badgeBg: _decreaseBadge,
                metrics: comparison.decreased,
              ),
            if (comparison.decreased.isNotEmpty) const SizedBox(height: 10),
            if (comparison.unchanged.isNotEmpty)
              _GroupCard(
                title: 'Unchanged',
                icon: Icons.remove_rounded,
                accent: _neutral,
                softBg: _neutralBg,
                badgeBg: const Color(0xFFE2E8F0),
                metrics: comparison.unchanged,
                showChangeArrow: false,
              ),
            if (comparison.unchanged.isNotEmpty) const SizedBox(height: 10),
            if (comparison.insight.trim().isNotEmpty) ...[
              _InsightCard(text: comparison.insight.trim()),
              const SizedBox(height: 10),
            ],
            Text(
              comparison.disclaimer,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onUnderstandMore,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepTeal,
                side: const BorderSide(color: AppColors.softAqua, width: 1.4),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Understand more  →',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.comparison});
  final ReportComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepTeal.withValues(alpha: 0.05),
            blurRadius: 18,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: AppColors.deepTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your report comparison',
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (comparison.dateRangeLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        comparison.dateRangeLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (comparison.intro.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comparison.intro.trim(),
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.softBg,
    required this.badgeBg,
    required this.metrics,
    this.showChangeArrow = true,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color softBg;
  final Color badgeBg;
  final List<ComparisonMetric> metrics;
  final bool showChangeArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: softBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.55)),
            ],
          ),
          const SizedBox(height: 8),
          ...metrics.map(
            (m) => Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label,
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          showChangeArrow
                              ? '${m.previousRaw ?? m.previousValue} → ${m.currentRaw ?? m.currentValue}'
                                  '${m.unit.isEmpty ? '' : ' ${m.unit}'}'
                              : '${m.currentRaw ?? m.currentValue}'
                                  '${m.unit.isEmpty ? '' : ' ${m.unit}'}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (m.badgeText.isNotEmpty && m.badgeText != '—')
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        m.badgeText,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ReportComparisonChatCard._insightBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBEE3F8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: ReportComparisonChatCard._insightIcon,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What this means',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ReportComparisonChatCard._insightIcon,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.ink,
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
