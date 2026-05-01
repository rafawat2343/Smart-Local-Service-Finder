import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../utils/app_colors.dart';
import 'admin_records_screen.dart';

class AdminCategoryScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  const AdminCategoryScreen({super.key, required this.stats});

  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  bool _exporting = false;

  static const _categories = [
    _CatConfig('Plumbing',   Icons.water_drop_rounded,        Color(0xFF4B91F1), Color(0xFFEAF2FF)),
    _CatConfig('Cleaning',   Icons.cleaning_services_rounded, Color(0xFF2ECC71), Color(0xFFE9FAF0)),
    _CatConfig('Electrical', Icons.bolt_rounded,              Color(0xFFE67E22), Color(0xFFFEF3E7)),
    _CatConfig('Painter',    Icons.format_paint_rounded,      Color(0xFF9B59B6), Color(0xFFF4E8F9)),
  ];

  List<_CatData> _buildData() {
    final raw = (widget.stats['categoryBreakdown'] as Map?)?.cast<String, int>() ?? {};

    // Merge real data into canonical buckets. Only merge values whose label
    // genuinely matches a known category — anything else stays in an "Other"
    // counter we keep aside, so unknown labels don't get silently dumped into
    // the Painter bucket (which produced the original miscategorization bug).
    final Map<String, int> merged = {for (final c in _categories) c.name: 0};
    int other = 0;
    for (final e in raw.entries) {
      final s = e.key.toLowerCase();
      if (s.contains('plumb')) {
        merged['Plumbing'] = (merged['Plumbing'] ?? 0) + e.value;
      } else if (s.contains('clean')) {
        merged['Cleaning'] = (merged['Cleaning'] ?? 0) + e.value;
      } else if (s.contains('electric')) {
        merged['Electrical'] = (merged['Electrical'] ?? 0) + e.value;
      } else if (s.contains('paint')) {
        merged['Painter'] = (merged['Painter'] ?? 0) + e.value;
      } else {
        other += e.value;
      }
    }

    final total = merged.values.fold(0, (s, v) => s + v) + other;

    // Fallback sample data when no real bookings exist
    if (total == 0) {
      return [
        _CatData(_categories[0], 32, 32.00),
        _CatData(_categories[1], 28, 28.00),
        _CatData(_categories[2], 18, 18.00),
        _CatData(_categories[3], 22, 22.00),
      ];
    }

    return _categories.map((cfg) {
      final count = merged[cfg.name] ?? 0;
      final pct = (count * 100 / total).clamp(0.0, 100.0);
      return _CatData(cfg, count, pct);
    }).toList();
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final data = _buildData();
      final totalBookings = (widget.stats['totalBookings'] as int?) ?? 0;
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
                    'Category Breakdown Report',
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
              pw.Divider(color: PdfColors.purple700),
              pw.SizedBox(height: 6),
            ],
          ),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.purple50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Bookings',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('$totalBookings',
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Text('Across all service categories',
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Distribution by Category',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.purple700),
                  children: ['Category', 'Bookings', 'Share']
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
                ...data.map((d) => pw.TableRow(
                      children: [
                        d.cfg.name,
                        '${d.count}',
                        '${d.percent.toStringAsFixed(2)}%',
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
        filename: 'category_breakdown_$dateStr.pdf',
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
    final data = _buildData();
    final totalBookings = (widget.stats['totalBookings'] as int?) ?? 0;
    final maxPct = data.fold<double>(0, (m, d) => math.max(m, d.percent));

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
          'Category Breakdown',
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
                  color: const Color(0xFF9B59B6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF9B59B6).withOpacity(0.4)),
                ),
                child: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF9B59B6)),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf_rounded,
                              size: 14, color: Color(0xFF9B59B6)),
                          SizedBox(width: 4),
                          Text(
                            'Export PDF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9B59B6),
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
            // Summary header card
            Container(
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
                          'Total Bookings',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$totalBookings',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Across all service categories',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.pie_chart_rounded,
                    size: 60,
                    color: Colors.white10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Vertical bar chart
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
                    'Distribution Chart',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BigVerticalChart(data: data, maxPct: maxPct),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category detail cards
            ...data.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryDetailCard(
                    data: d,
                    onViewRecords: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminRecordsScreen()),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Big vertical bar chart ─────────────────────────────────────────────────

class _BigVerticalChart extends StatelessWidget {
  final List<_CatData> data;
  final double maxPct;
  const _BigVerticalChart({required this.data, required this.maxPct});

  @override
  Widget build(BuildContext context) {
    const barAreaH = 140.0;
    final effectiveMax = maxPct == 0 ? 1.0 : maxPct;

    return Column(
      children: [
        // Value labels
        Row(
          children: data.asMap().entries.map((e) {
            final isLast = e.key == data.length - 1;
            final d = e.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 12),
                child: Text(
                  '${d.percent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: d.cfg.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Bars
        SizedBox(
          height: barAreaH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.asMap().entries.map((e) {
              final isLast = e.key == data.length - 1;
              final d = e.value;
              final barH =
                  (d.percent / effectiveMax * barAreaH).clamp(4.0, barAreaH);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                    child: Container(
                      height: barH,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            d.cfg.color,
                            d.cfg.color.withOpacity(0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Category labels with icon
        Row(
          children: data.asMap().entries.map((e) {
            final isLast = e.key == data.length - 1;
            final d = e.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 12),
                child: Column(
                  children: [
                    Icon(d.cfg.icon, size: 16, color: d.cfg.color),
                    const SizedBox(height: 2),
                    Text(
                      d.cfg.name,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Category detail card ───────────────────────────────────────────────────

class _CategoryDetailCard extends StatelessWidget {
  final _CatData data;
  final VoidCallback onViewRecords;
  const _CategoryDetailCard({required this.data, required this.onViewRecords});

  @override
  Widget build(BuildContext context) {
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
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: data.cfg.bg,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(data.cfg.icon, color: data.cfg.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.cfg.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${data.count} booking${data.count == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.percent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: data.cfg.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: onViewRecords,
                    child: Text(
                      'View records',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: data.cfg.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: data.percent / 100,
              minHeight: 8,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(data.cfg.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────

class _CatConfig {
  final String name;
  final IconData icon;
  final Color color, bg;
  const _CatConfig(this.name, this.icon, this.color, this.bg);
}

class _CatData {
  final _CatConfig cfg;
  final int count;
  final double percent;
  const _CatData(this.cfg, this.count, this.percent);
}
