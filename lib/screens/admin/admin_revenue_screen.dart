import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _exporting = false;
  String _filter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await DatabaseService.getRevenueData();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load revenue data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final totalRevenue = (_data['totalRevenue'] as double?) ?? 0.0;
      final forecast = (_data['forecastNextMonth'] as double?) ?? 0.0;
      final growthPct = (_data['forecastGrowthPct'] as double?) ?? 0.0;
      final userEarnings =
          ((_data['userEarnings'] ?? []) as List).cast<Map<String, dynamic>>();
      final monthlyRevenue =
          ((_data['monthlyRevenue'] ?? []) as List).cast<Map<String, dynamic>>();

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
                    'Revenue & Earnings Report',
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
              pw.Divider(color: PdfColors.teal700),
              pw.SizedBox(height: 6),
            ],
          ),
          build: (_) => [
            // Summary box
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfKV('Total Revenue',
                      '\$${totalRevenue.toStringAsFixed(2)}'),
                  _pdfKV('Next Month Forecast',
                      '\$${forecast.toStringAsFixed(2)}'),
                  _pdfKV(
                    'Growth Trend',
                    '${growthPct >= 0 ? '+' : ''}${growthPct.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Monthly revenue table
            if (monthlyRevenue.isNotEmpty) ...[
              pw.Text(
                'Monthly Revenue (Last 6 Months)',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  _pdfHeaderRow(['Month', 'Revenue', 'Bookings']),
                  ...monthlyRevenue.map((m) => _pdfDataRow([
                        m['label']?.toString() ?? '',
                        '\$${(m['amount'] as double? ?? 0).toStringAsFixed(2)}',
                        '${m['count'] ?? 0}',
                      ])),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // User earnings table
            pw.Text(
              'Individual Earnings Records',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.2),
              },
              children: [
                _pdfHeaderRow(['Name', 'Role', 'Amount', 'Jobs']),
                ...userEarnings.map((u) => _pdfDataRow([
                      u['name']?.toString() ?? '—',
                      u['type']?.toString() ?? '—',
                      '\$${(u['amount'] as double? ?? 0).toStringAsFixed(2)}',
                      '${u['transactionCount'] ?? 0}',
                    ])),
                if (userEarnings.isEmpty)
                  _pdfDataRow(['No records found', '', '', '']),
              ],
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'revenue_report_$dateStr.pdf',
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

  pw.Widget _pdfKV(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.TableRow _pdfHeaderRow(List<String> cells) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.teal700),
      children: cells
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
    );
  }

  pw.TableRow _pdfDataRow(List<String> cells) {
    return pw.TableRow(
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                child: pw.Text(c,
                    style: const pw.TextStyle(fontSize: 9)),
              ))
          .toList(),
    );
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final list =
        ((_data['userEarnings'] ?? []) as List).cast<Map<String, dynamic>>();
    return list.where((u) {
      final matchFilter =
          _filter == 'all' || u['type']?.toString() == _filter;
      final matchSearch = _search.isEmpty ||
          (u['name']?.toString() ?? '')
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = (_data['totalRevenue'] as double?) ?? 0.0;
    final forecast = (_data['forecastNextMonth'] as double?) ?? 0.0;
    final growthPct = (_data['forecastGrowthPct'] as double?) ?? 0.0;
    final monthly = ((_data['monthlyRevenue'] ?? []) as List)
        .cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 3 summary cards
                          _SummaryRow(
                            totalRevenue: totalRevenue,
                            forecast: forecast,
                            growthPct: growthPct,
                          ),
                          const SizedBox(height: 16),

                          // Forecast chart
                          _ForecastChartCard(
                              monthly: monthly, forecast: forecast),
                          const SizedBox(height: 16),

                          // Earnings list header + filter
                          _buildEarningsHeader(),
                          const SizedBox(height: 10),

                          // Search
                          _buildSearchBar(),
                          const SizedBox(height: 10),

                          // User list
                          if (_filteredUsers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined,
                                        size: 48,
                                        color: AppColors.textTertiary),
                                    SizedBox(height: 12),
                                    Text(
                                      'No earnings records found',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Complete some bookings to see data here',
                                      style: TextStyle(
                                          color: AppColors.textTertiary,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._filteredUsers.asMap().entries.map((e) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _UserEarningsTile(
                                    user: e.value,
                                    rank: e.key + 1,
                                    onTap: () =>
                                        _showUserDetail(e.value),
                                  ),
                                )),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1A7A4A),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue & Earnings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text('Financial overview & forecasts',
                    style:
                        TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _exporting ? null : _exportPdf,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Export PDF',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHeader() {
    const filters = [
      ('all', 'All'),
      ('provider', 'Providers'),
      ('client', 'Clients'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Individual Earnings',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2),
            ),
            Text(
              '${_filteredUsers.length} record${_filteredUsers.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: filters.map((f) {
            final isSelected = _filter == f.$1;
            return GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1A7A4A)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1A7A4A)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Search by name...',
          hintStyle:
              TextStyle(fontSize: 13, color: AppColors.textTertiary),
          prefixIcon: Icon(Icons.search_rounded,
              size: 18, color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user),
    );
  }
}

// ── Summary Row ────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final double totalRevenue;
  final double forecast;
  final double growthPct;
  const _SummaryRow(
      {required this.totalRevenue,
      required this.forecast,
      required this.growthPct});

  @override
  Widget build(BuildContext context) {
    final isPositive = growthPct >= 0;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF1A7A4A),
            bg: const Color(0xFFE8F5EE),
            label: 'Total Revenue',
            value: '\$${_fmt(totalRevenue)}',
            sub: 'All completed bookings',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF2980B9),
            bg: const Color(0xFFEAF4FC),
            label: 'Next Month',
            value: '\$${_fmt(forecast)}',
            sub: 'Revenue forecast',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: isPositive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: isPositive
                ? const Color(0xFF2ECC71)
                : const Color(0xFFE74C3C),
            bg: isPositive
                ? const Color(0xFFE9FAF0)
                : const Color(0xFFFDECEC),
            label: 'Growth',
            value:
                '${isPositive ? '+' : ''}${growthPct.toStringAsFixed(1)}%',
            sub: 'Month-over-month',
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String label, value, sub;
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textTertiary),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Forecast Chart Card ────────────────────────────────────────────────────

class _ForecastChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  final double forecast;
  const _ForecastChartCard(
      {required this.monthly, required this.forecast});

  @override
  Widget build(BuildContext context) {
    // Build bars: 6 months + 1 forecast
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final forecastLabel =
        '${monthNames[nextMonth.month]} ${nextMonth.year.toString().substring(2)}';

    final bars = [
      ...monthly.map((m) => _Bar(
            label: m['label']?.toString() ?? '',
            amount: (m['amount'] as double?) ?? 0,
            isForecast: false,
          )),
      _Bar(
        label: forecastLabel,
        amount: forecast,
        isForecast: true,
      ),
    ];

    final maxAmt =
        bars.fold(0.0, (m, b) => math.max(m, b.amount));
    const barAreaH = 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue Forecast',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2980B9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Next Month Predicted',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2980B9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Value labels
          Row(
            children: bars.asMap().entries.map((e) {
              final b = e.value;
              final isLast = e.key == bars.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 4),
                  child: Text(
                    _fmtAmt(b.amount),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: b.isForecast
                          ? const Color(0xFF2980B9)
                          : const Color(0xFF1A7A4A),
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
              children: bars.asMap().entries.map((e) {
                final b = e.value;
                final isLast = e.key == bars.length - 1;
                final effectiveMax = maxAmt == 0 ? 1 : maxAmt;
                final barH =
                    (b.amount / effectiveMax * barAreaH).clamp(4.0, barAreaH);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 4),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5)),
                      child: Container(
                        height: barH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: b.isForecast
                                ? [
                                    const Color(0xFF2980B9),
                                    const Color(0xFF2980B9).withOpacity(0.5),
                                  ]
                                : [
                                    const Color(0xFF1A7A4A),
                                    const Color(0xFF1A7A4A).withOpacity(0.65),
                                  ],
                          ),
                        ),
                        // Dashed border for forecast
                        child: b.isForecast
                            ? Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFF2980B9),
                                      width: 1.5),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5)),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Labels
          Row(
            children: bars.asMap().entries.map((e) {
              final b = e.value;
              final isLast = e.key == bars.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 4),
                  child: Text(
                    b.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: b.isForecast
                          ? const Color(0xFF2980B9)
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A7A4A),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              const Text('Actual',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: const Color(0xFF2980B9),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              const Text('Forecast',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtAmt(double v) {
    if (v == 0) return '\$0';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _Bar {
  final String label;
  final double amount;
  final bool isForecast;
  const _Bar({required this.label, required this.amount, required this.isForecast});
}

// ── User Earnings Tile ─────────────────────────────────────────────────────

class _UserEarningsTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final int rank;
  final VoidCallback onTap;
  const _UserEarningsTile(
      {required this.user, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] ?? '—').toString();
    final type = (user['type'] ?? 'client').toString();
    final amount = (user['amount'] as double?) ?? 0.0;
    final txCount = (user['transactionCount'] as int?) ?? 0;
    final isProvider = type == 'provider';

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarColor = isProvider
        ? const Color(0xFF17A589)
        : const Color(0xFF4B91F1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 22,
              child: Text(
                '#$rank',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(width: 8),

            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor.withOpacity(0.15),
              child: Text(
                initial,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: avatarColor),
              ),
            ),
            const SizedBox(width: 12),

            // Name + type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: avatarColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isProvider ? 'Provider' : 'Client',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: avatarColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$txCount job${txCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isProvider
                          ? const Color(0xFF1A7A4A)
                          : const Color(0xFF2980B9),
                      letterSpacing: -0.5),
                ),
                Text(
                  isProvider ? 'Earned' : 'Spent',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── User Detail Sheet ──────────────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] ?? '—').toString();
    final type = (user['type'] ?? 'client').toString();
    final amount = (user['amount'] as double?) ?? 0.0;
    final txCount = (user['transactionCount'] as int?) ?? 0;
    final userId = (user['userId'] ?? '—').toString();
    final isProvider = type == 'provider';
    final transactions =
        ((user['transactions'] ?? []) as List).cast<Map<String, dynamic>>();

    final avatarColor = isProvider
        ? const Color(0xFF17A589)
        : const Color(0xFF4B91F1);
    final headerColor = isProvider
        ? const Color(0xFF1A7A4A)
        : const Color(0xFF1A5276);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(initial,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isProvider ? 'Service Provider' : 'Client',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5),
                          ),
                          Text(
                            isProvider
                                ? 'Total Earned'
                                : 'Total Spent',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _HeaderStat(
                          label: 'Jobs',
                          value: '$txCount',
                          color: avatarColor),
                      const SizedBox(width: 16),
                      _HeaderStat(
                          label: 'Avg per Job',
                          value: txCount == 0
                              ? '\$0'
                              : '\$${(amount / txCount).toStringAsFixed(2)}',
                          color: avatarColor),
                      const SizedBox(width: 16),
                      _HeaderStat(
                          label: 'User ID',
                          value: userId.length > 8
                              ? '${userId.substring(0, 8)}...'
                              : userId,
                          color: avatarColor),
                    ],
                  ),
                ],
              ),
            ),

            // Transaction list
            Expanded(
              child: transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions found',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)))
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Transaction History',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: headerColor),
                        ),
                        const SizedBox(height: 10),
                        ...transactions.asMap().entries.map((e) =>
                            _TransactionRow(
                              index: e.key + 1,
                              txn: e.value,
                              isProvider: isProvider,
                              color: avatarColor,
                            )),
                        const SizedBox(height: 16),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeaderStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> txn;
  final bool isProvider;
  final Color color;
  const _TransactionRow(
      {required this.index,
      required this.txn,
      required this.isProvider,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final amount = (txn['amount'] as double?) ?? 0.0;
    final specialty = (txn['specialty'] ?? '').toString();
    final createdAt = txn['createdAt'];
    final dateStr = _fmtTs(createdAt);
    final otherId = isProvider
        ? (txn['clientId'] ?? '—').toString()
        : (txn['providerId'] ?? '—').toString();
    final otherLabel = isProvider ? 'Client' : 'Provider';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(
                '#$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specialty.isEmpty ? 'Service Booking' : specialty,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                Text(
                  '$otherLabel: ${otherId.length > 14 ? '${otherId.substring(0, 14)}...' : otherId}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }

  String _fmtTs(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final dt = ts.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
