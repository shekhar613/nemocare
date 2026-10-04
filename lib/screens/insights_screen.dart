import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/insight.dart';
import '../services/insights_service.dart';
import '../theme/app_theme.dart';

/// Reads cached insights from Firestore; regenerates if findings/labs are newer.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _insights = InsightsService();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // If a newer CBC landed but insights still cite an older date, refresh now.
    unawaited(_syncIfStale());
  }

  Future<void> _syncIfStale() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await _insights.ensureUpToDate();
    } catch (e) {
      debugPrint('Insights sync failed: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<InsightsBundle>(
      stream: _insights.watchCached(),
      builder: (context, snapshot) {
        if ((snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) ||
            (_syncing && (snapshot.data?.isEmpty ?? true))) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          );
        }

        final bundle = snapshot.data ??
            const InsightsBundle(fingerprint: '', cards: []);

        if (bundle.isEmpty) {
          return const _EmptyInsightsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: bundle.cards.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _InsightsHeader(
                count: bundle.cards.length,
                generatedAt: bundle.generatedAt,
              );
            }
            return _InsightCard(insight: bundle.cards[index - 1]);
          },
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.foam,
      appBar: AppBar(
        title: Text(
          'Insights',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: body,
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader({required this.count, this.generatedAt});

  final int count;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final subtitle = generatedAt == null
        ? 'Grounded in your active findings and trusted sources.'
        : 'Updated ${_formatRelative(generatedAt!)} · grounded in your findings.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1 ? '1 insight for you' : '$count insights for you',
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRelative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.day}/${at.month}/${at.year}';
  }
}

class _EmptyInsightsState extends StatelessWidget {
  const _EmptyInsightsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mist,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.insights_outlined,
                size: 34,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'All clear for now',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No active findings from your labs. When a value looks off, '
              'personalized insights grounded in trusted sources will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final meta = _categoryMeta(insight.category);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: meta.tint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(meta.icon, size: 14, color: meta.color),
                    const SizedBox(width: 5),
                    Text(
                      meta.label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: meta.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.title,
            style: GoogleFonts.sora(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.body,
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              height: 1.45,
              color: AppColors.ink.withValues(alpha: 0.88),
            ),
          ),
          if (insight.sourceUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < insight.sourceUrls.length; i++)
                  _SourceChip(
                    label: 'Source ${i + 1}',
                    url: insight.sourceUrls[i],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static _CategoryMeta _categoryMeta(String category) {
    switch (category) {
      case 'risk':
        return _CategoryMeta(
          label: 'Risk',
          icon: Icons.warning_amber_rounded,
          color: AppColors.coral,
          tint: AppColors.coral.withValues(alpha: 0.12),
        );
      case 'remedy':
        return _CategoryMeta(
          label: 'What you can do',
          icon: Icons.favorite_outline_rounded,
          color: AppColors.deepTeal,
          tint: AppColors.mist,
        );
      default:
        return _CategoryMeta(
          label: 'Explained',
          icon: Icons.lightbulb_outline_rounded,
          color: AppColors.teal,
          tint: AppColors.softAqua.withValues(alpha: 0.18),
        );
    }
  }
}

class _CategoryMeta {
  const _CategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.foam,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_rounded, size: 14, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
