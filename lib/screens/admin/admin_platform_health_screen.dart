import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../utils/app_colors.dart';

class AdminPlatformHealthScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  const AdminPlatformHealthScreen({super.key, required this.stats});

  @override
  State<AdminPlatformHealthScreen> createState() =>
      _AdminPlatformHealthScreenState();
}

class _AdminPlatformHealthScreenState
    extends State<AdminPlatformHealthScreen> {
  bool _exporting = false;

  List<_MetricCardData> _buildMetrics() {
    final stats = widget.stats;
    final activeProvPct  = (stats['activeProviderPct']   as int?) ?? 0;
    final bookingCompPct = (stats['bookingCompletionPct'] as int?) ?? 0;
    final avgRating      = (stats['avgRating']           as double?) ?? 0.0;
    final resolvedPct    = (stats['resolvedReportsPct']  as int?) ?? 0;

    final totalProviders   = (stats['totalProviders']   as int?) ?? 0;
    final activeProviders  = (stats['activeProviders']  as int?) ?? 0;
    final totalBookings    = (stats['totalBookings']    as int?) ?? 0;
    final completedBookings= (stats['completedBookings']as int?) ?? 0;
    final totalReports     = (stats['totalReports']     as int?) ?? 0;
    final resolvedReports  = (stats['resolvedReports']  as int?) ?? 0;
    final totalReviews     = (stats['totalReviews']     as int?) ?? 0;
    final ratingPct        = (avgRating / 5.0 * 100).round().clamp(0, 100);

    return [
      _MetricCardData(
        label: 'Active Providers',
        icon: Icons.construction_rounded,
        color: const Color(0xFF2ECC71),
        bg: const Color(0xFFE9FAF0),
        percent: activeProvPct,
        displayValue: '$activeProvPct%',
        detail: '$activeProviders of $totalProviders providers are active',
        status: _statusLabel(activeProvPct),
      ),
      _MetricCardData(
        label: 'Booking Completion',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF4B91F1),
        bg: const Color(0xFFEAF2FF),
        percent: bookingCompPct,
        displayValue: '$bookingCompPct%',
        detail: '$completedBookings of $totalBookings bookings completed',
        status: _statusLabel(bookingCompPct),
      ),
      _MetricCardData(
        label: 'User Satisfaction',
        icon: Icons.star_rounded,
        color: const Color(0xFFE67E22),
        bg: const Color(0xFFFEF3E7),
        percent: ratingPct,
        displayValue:
            avgRating == 0.0 ? 'N/A' : '${avgRating.toStringAsFixed(1)} / 5',
        detail: 'Based on $totalReviews review${totalReviews == 1 ? '' : 's'}',
        status: avgRating == 0.0
            ? 'No data'
            : avgRating >= 4.5
                ? 'Excellent'
                : avgRating >= 3.5
                    ? 'Good'
                    : 'Needs attention',
        isRating: true,
        ratingValue: avgRating,
      ),
      _MetricCardData(
        label: 'Resolved Complaints',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF9B59B6),
        bg: const Color(0xFFF4E8F9),
        percent: resolvedPct,
        displayValue: '$resolvedPct%',
        detail: '$resolvedReports of $totalReports complaints resolved',
        status: _statusLabel(resolvedPct),
      ),
    ];
  }

  static String _statusLabel(int pct) {
    if (pct >= 90) return 'Excellent';
    if (pct >= 70) return 'Good';
    if (pct >= 50) return 'Fair';
    return 'Needs attention';
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final metrics = _buildMetrics();
      final overallPct =
          metrics.fold(0, (s, m) => s + m.percent) ~/ metrics.length;
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Platform Health Report',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Generated: $dateStr',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.indigo700),
              pw.SizedBox(height: 6),
            ],
          ),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Overall Health Score',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('$overallPct%',
                          style: pw.TextStyle(
                              fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Text(_statusLabel(overallPct),
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Metrics',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.indigo700),
                  children: ['Metric', 'Value', 'Status', 'Detail']
                      .map((c) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            child: pw.Text(c,
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white)),
                          ))
                      .toList(),
                ),
                ...metrics.map((m) => pw.TableRow(
                      children: [
                        m.label,
                        m.displayValue,
                        m.status,
                        m.detail,
                      ]
                          .map((c) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                child: pw.Text(c,
                                    style: const pw.TextStyle(fontSize: 9)),
                              ))
                          .toList(),
                    )),
              ],
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'platform_health_$dateStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _buildMetrics();
    final overallPct =
        metrics.fold(0, (s, m) => s + m.percent) ~/ metrics.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Platform Health',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _exporting ? null : _exportPdf,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.4)),
                ),
                child: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF6C63FF)),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded,
                              size: 14, color: Color(0xFF6C63FF)),
                          SizedBox(width: 4),
                          Text(
                            'Export PDF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Overall score card
            _OverallScoreCard(percent: overallPct),
            const SizedBox(height: 16),

            // Bar chart for all 4 metrics
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Metrics Overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HealthBarChart(metrics: metrics),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Individual metric cards
            ...metrics.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MetricDetailCard(data: m),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Overall score card ─────────────────────────────────────────────────────

class _OverallScoreCard extends StatelessWidget {
  final int percent;
  const _OverallScoreCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 80
        ? const Color(0xFF2ECC71)
        : percent >= 60
            ? const Color(0xFFE67E22)
            : const Color(0xFFE74C3C);
    final label = percent >= 80 ? 'Excellent' : percent >= 60 ? 'Good' : 'Needs Improvement';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2B3A), Color(0xFF0F1F2D)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Health Score',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: color,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

// ── Horizontal bar chart ───────────────────────────────────────────────────

class _HealthBarChart extends StatelessWidget {
  final List<_MetricCardData> metrics;
  const _HealthBarChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: metrics.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: m.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(m.label,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ]),
                    Text(m.displayValue,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: m.color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.percent / 100,
                    minHeight: 7,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(m.color),
                  ),
                ),
              ],
            ),
          )).toList(),
    );
  }
}

// ── Metric detail card ─────────────────────────────────────────────────────

class _MetricDetailCard extends StatelessWidget {
  final _MetricCardData data;
  const _MetricDetailCard({required this.data});

  static Color _statusColor(String status) {
    if (status == 'Excellent') return const Color(0xFF2ECC71);
    if (status == 'Good') return const Color(0xFF4B91F1);
    if (status == 'Fair') return const Color(0xFFE67E22);
    if (status == 'No data') return AppColors.textTertiary;
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(data.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: data.bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(data.detail,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    data.displayValue,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: data.color,
                        letterSpacing: -0.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      data.status,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Star display for rating, progress bar for others
          if (data.isRating)
            _StarRow(rating: data.ratingValue)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: data.percent / 100,
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(data.color),
              ),
            ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half ? Icons.star_half_rounded : Icons.star_rounded,
          size: 22,
          color: filled || half ? const Color(0xFFE67E22) : AppColors.border,
        );
      }),
    );
  }
}

class _MetricCardData {
  final String label, displayValue, detail, status;
  final IconData icon;
  final Color color, bg;
  final int percent;
  final bool isRating;
  final double ratingValue;
  const _MetricCardData({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.percent,
    required this.displayValue,
    required this.detail,
    required this.status,
    this.isRating = false,
    this.ratingValue = 0.0,
  });
}
