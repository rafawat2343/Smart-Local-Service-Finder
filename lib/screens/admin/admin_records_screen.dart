import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class AdminRecordsScreen extends StatefulWidget {
  final int initialTab;
  const AdminRecordsScreen({super.key, this.initialTab = 0});

  @override
  State<AdminRecordsScreen> createState() => _AdminRecordsScreenState();
}

class _AdminRecordsScreenState extends State<AdminRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _ledger = [];
  bool _loadingRequests = true;
  bool _loadingBookings = true;
  bool _loadingLedger = true;
  String _requestFilter = 'all';
  String _bookingFilter = 'all';
  String _ledgerFilter = 'all';
  DateTimeRange? _ledgerRange;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadRequests();
    _loadBookings();
    _loadLedger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final data = await DatabaseService.getAllServiceRequests();
      if (mounted) setState(() => _requests = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final data = await DatabaseService.getAllBookings();
      if (mounted) setState(() => _bookings = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  Future<void> _loadLedger() async {
    setState(() => _loadingLedger = true);
    try {
      final data = await DatabaseService.getTransactions(
        type: _ledgerFilter == 'all' ? null : _ledgerFilter,
        since: _ledgerRange?.start,
        until: _ledgerRange?.end,
      );
      if (mounted) setState(() => _ledger = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ledger: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLedger = false);
    }
  }

  void _showRequestDetail(BuildContext context, Map<String, dynamic> request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailSheet(request: request),
    );
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(booking: booking),
    );
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_requestFilter == 'all') return _requests;
    return _requests
        .where((r) => r['status'] == _requestFilter)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_bookingFilter == 'all') return _bookings;
    return _bookings
        .where((b) => b['status'] == _bookingFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0B7285),
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: const Color(0xFF0B7285),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              isScrollable: true,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Requests (${_requests.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Bookings (${_bookings.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Ledger (${_ledger.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildBookingsTab(),
                _buildLedgerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF0B7285),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        16,
      ),
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
                  'Application Records',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Service requests & booking records',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    final requestStatuses = [
      'all',
      'open',
      'accepted',
      'in_progress',
      'completed',
      'cancelled',
    ];

    return Column(
      children: [
        _buildStatusFilterBar(
          statuses: requestStatuses,
          selected: _requestFilter,
          onSelect: (s) => setState(() => _requestFilter = s),
          activeColor: const Color(0xFF0B7285),
        ),
        Expanded(
          child: _filteredRequests.isEmpty
              ? _buildEmpty('No service requests found')
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRequests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RequestCard(
                      request: _filteredRequests[i],
                      onTap: () => _showRequestDetail(context, _filteredRequests[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab() {
    if (_loadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }

    final bookingStatuses = [
      'all',
      'pending',
      'confirmed',
      'in_progress',
      'completed',
      'cancelled',
    ];

    return Column(
      children: [
        _buildStatusFilterBar(
          statuses: bookingStatuses,
          selected: _bookingFilter,
          onSelect: (s) => setState(() => _bookingFilter = s),
          activeColor: const Color(0xFF2F9E44),
        ),
        Expanded(
          child: _filteredBookings.isEmpty
              ? _buildEmpty('No bookings found')
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBookings.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _BookingCard(
                      booking: _filteredBookings[i],
                      onTap: () => _showBookingDetail(context, _filteredBookings[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab() {
    if (_loadingLedger) {
      return const Center(child: CircularProgressIndicator());
    }

    const ledgerTypes = [
      ('all', 'All'),
      ('points_earned', 'Points earned'),
      ('points_redeemed', 'Points redeemed'),
      ('commission_charged', 'Commission'),
    ];

    int totalCommission = 0;
    int totalPointsEarned = 0;
    int totalPointsRedeemed = 0;
    for (final t in _ledger) {
      final amt = (t['amount'] is num) ? (t['amount'] as num).toInt() : 0;
      switch ((t['type'] ?? '').toString()) {
        case 'commission_charged':
          totalCommission += amt;
          break;
        case 'points_earned':
          totalPointsEarned += amt;
          break;
        case 'points_redeemed':
          totalPointsRedeemed += amt;
          break;
      }
    }

    return Column(
      children: [
        Container(
          height: 44,
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: ledgerTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final t = ledgerTypes[i];
                    final isSelected = _ledgerFilter == t.$1;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _ledgerFilter = t.$1);
                        _loadLedger();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
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
                          t.$2,
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
                  },
                ),
              ),
              IconButton(
                tooltip: 'Date range',
                icon: Icon(
                  Icons.event_rounded,
                  size: 18,
                  color: _ledgerRange == null
                      ? AppColors.textSecondary
                      : const Color(0xFF1A7A4A),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: now,
                    initialDateRange: _ledgerRange,
                  );
                  if (picked != null) {
                    setState(() => _ledgerRange = picked);
                    _loadLedger();
                  }
                },
              ),
              if (_ledgerRange != null)
                IconButton(
                  tooltip: 'Clear range',
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textTertiary),
                  onPressed: () {
                    setState(() => _ledgerRange = null);
                    _loadLedger();
                  },
                ),
            ],
          ),
        ),
        if (_ledgerRange != null)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.event_note_rounded,
                    size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${_fmtDate(_ledgerRange!.start)} → ${_fmtDate(_ledgerRange!.end)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _ledger.isEmpty
              ? _buildEmpty('No transactions found')
              : RefreshIndicator(
                  onRefresh: _loadLedger,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _ledger.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _LedgerCard(entry: _ledger[i]),
                  ),
                ),
        ),
        // Totals footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LedgerTotal(
                label: 'Commission',
                value: '৳$totalCommission',
                color: const Color(0xFF1A7A4A),
              ),
              _LedgerTotal(
                label: 'Earned',
                value: '+$totalPointsEarned pts',
                color: AppColors.star,
              ),
              _LedgerTotal(
                label: 'Redeemed',
                value: '-$totalPointsRedeemed pts',
                color: AppColors.urgent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildStatusFilterBar({
    required List<String> statuses,
    required String selected,
    required ValueChanged<String> onSelect,
    required Color activeColor,
  }) {
    return Container(
      height: 44,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = statuses[i];
          final isSelected = s == selected;
          return GestureDetector(
            onTap: () => onSelect(s),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? activeColor : AppColors.border,
                ),
              ),
              child: Text(
                s == 'all'
                    ? 'All'
                    : s.replaceAll('_', ' ').split(' ').map((w) =>
                        '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
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
        },
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;
  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category =
        (request['category'] ?? request['specialty'] ?? 'Service').toString();
    final description =
        (request['description'] ?? 'No description').toString();
    final status = (request['status'] ?? 'open').toString();
    final location =
        (request['location'] ?? 'Unknown location').toString();
    final budget = (request['budget'] ?? 'N/A').toString();
    final isUrgent = request['isUrgent'] as bool? ?? false;
    final date = _formatTimestamp(request['createdAt']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B7285).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.assignment_rounded,
                    size: 18, color: Color(0xFF0B7285)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadgeForStatus(status: status),
              if (isUrgent) ...[
                const SizedBox(width: 6),
                StatusBadge(
                  label: 'URGENT',
                  color: AppColors.urgent,
                  bgColor: AppColors.urgent.withOpacity(0.1),
                  icon: Icons.priority_high_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  location,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.attach_money_rounded,
                  size: 12, color: AppColors.textTertiary),
              Text(
                budget,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ));   // GestureDetector
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;
  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final clientId = (booking['clientId'] ?? '').toString();
    final providerId = (booking['providerId'] ?? '').toString();
    final storedClient = (booking['clientName'] ?? '').toString();
    final storedProvider = (booking['providerName'] ?? '').toString();
    final clientName = storedClient.isNotEmpty
        ? storedClient
        : (clientId.isEmpty ? 'Unknown' : 'Client');
    final providerName = storedProvider.isNotEmpty
        ? storedProvider
        : (providerId.isEmpty ? 'Unknown' : 'Provider');
    final status = (booking['status'] ?? 'pending').toString();
    final price =
        (booking['agreedPrice'] ?? 'N/A').toString();
    final date = _formatTimestamp(booking['createdAt']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F9E44).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.bookmark_rounded,
                      size: 18, color: Color(0xFF2F9E44)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadgeForStatus(status: status),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(label: 'Client', value: clientName),
            const SizedBox(height: 4),
            _InfoRow(label: 'Provider', value: providerName),
            const SizedBox(height: 4),
            _InfoRow(label: 'Agreed Price', value: price),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadgeForStatus extends StatelessWidget {
  final String status;
  const _StatusBadgeForStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bgColor;
    IconData icon;

    switch (status) {
      case 'completed':
        color = AppColors.success;
        bgColor = AppColors.success.withOpacity(0.1);
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'in_progress':
        color = Colors.blue.shade700;
        bgColor = Colors.blue.withOpacity(0.1);
        icon = Icons.autorenew_rounded;
        break;
      case 'cancelled':
        color = Colors.red.shade600;
        bgColor = Colors.red.withOpacity(0.1);
        icon = Icons.cancel_outlined;
        break;
      case 'accepted':
      case 'confirmed':
        color = Colors.green.shade700;
        bgColor = Colors.green.withOpacity(0.1);
        icon = Icons.thumb_up_outlined;
        break;
      default:
        color = Colors.orange.shade700;
        bgColor = Colors.orange.withOpacity(0.1);
        icon = Icons.hourglass_empty_rounded;
    }

    return StatusBadge(
      label: status.toUpperCase().replaceAll('_', ' '),
      color: color,
      bgColor: bgColor,
      icon: icon,
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LedgerCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = (entry['type'] ?? '').toString();
    final amount =
        (entry['amount'] is num) ? (entry['amount'] as num).toInt() : 0;
    final currency = (entry['currency'] ?? '').toString();
    final desc = (entry['description'] ?? '').toString();
    final userId = (entry['userId'] ?? '').toString();
    final userRole = (entry['userRole'] ?? '').toString();
    final bookingId = (entry['bookingId'] ?? '').toString();
    final dateStr = _formatTimestamp(entry['createdAt']);

    Color color;
    Color bg;
    IconData icon;
    String prefix;
    String label;
    switch (type) {
      case 'commission_charged':
        color = const Color(0xFF1A7A4A);
        bg = const Color(0xFFE8F5EE);
        icon = Icons.account_balance_rounded;
        prefix = '৳';
        label = 'Commission';
        break;
      case 'points_earned':
        color = AppColors.star;
        bg = AppColors.starBg;
        icon = Icons.add_circle_outline_rounded;
        prefix = '+';
        label = 'Points earned';
        break;
      case 'points_redeemed':
        color = AppColors.urgent;
        bg = AppColors.urgentBg;
        icon = Icons.remove_circle_outline_rounded;
        prefix = '−';
        label = 'Points redeemed';
        break;
      default:
        color = AppColors.textSecondary;
        bg = AppColors.background;
        icon = Icons.receipt_long_rounded;
        prefix = '';
        label = type.isEmpty ? 'Transaction' : type;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (userRole.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.navyLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          userRole,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr • user ${userId.isEmpty ? '—' : userId.substring(0, userId.length.clamp(0, 8))}'
                  '${bookingId.isEmpty ? '' : ' • booking ${bookingId.substring(0, bookingId.length.clamp(0, 6))}'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency == 'POINTS'
                ? '$prefix$amount pts'
                : '$prefix$amount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTotal extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _LedgerTotal({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

String _formatTimestamp(dynamic ts) {
  if (ts is! Timestamp) return 'Unknown date';
  final dt = ts.toDate();
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ── Request Detail Sheet ───────────────────────────────────────────────────

class _RequestDetailSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RequestDetailSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final category = (request['category'] ?? request['specialty'] ?? 'Service').toString();
    final specialty = (request['specialty'] ?? '—').toString();
    final description = (request['description'] ?? '—').toString();
    final location = (request['location'] ?? '—').toString();
    final budget = (request['budget'] ?? '—').toString();
    final status = (request['status'] ?? 'open').toString();
    final isUrgent = request['isUrgent'] as bool? ?? false;
    final clientId = (request['clientId'] ?? '—').toString();
    final providerId = (request['providerId'] ?? '—').toString();
    final requestId = (request['id'] ?? '—').toString();
    final createdAt = _formatTimestamp(request['createdAt']);
    final updatedAt = _formatTimestamp(request['updatedAt']);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B7285),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Service Request Details',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadgeForStatus(status: status),
                      if (isUrgent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  _DetailSection(title: 'Service Information', children: [
                    _DetailField(label: 'Category', value: category),
                    _DetailField(label: 'Specialty', value: specialty),
                    _DetailField(label: 'Description', value: description, multiLine: true),
                    _DetailField(label: 'Location', value: location),
                    _DetailField(label: 'Budget', value: budget),
                    _DetailField(label: 'Urgent', value: isUrgent ? 'Yes' : 'No'),
                  ]),
                  const SizedBox(height: 16),
                  _DetailSection(title: 'Parties', children: [
                    _DetailField(label: 'Client ID', value: clientId, mono: true),
                    _DetailField(label: 'Provider ID', value: providerId.isEmpty || providerId == '—' ? 'Not assigned' : providerId, mono: true),
                  ]),
                  const SizedBox(height: 16),
                  _DetailSection(title: 'Record Info', children: [
                    _DetailField(label: 'Request ID', value: requestId, mono: true),
                    _DetailField(label: 'Created', value: createdAt),
                    _DetailField(label: 'Last Updated', value: updatedAt),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Booking Detail Sheet ───────────────────────────────────────────────────

class _BookingDetailSheet extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingDetailSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final clientId = (booking['clientId'] ?? '—').toString();
    final clientName = (booking['clientName'] ?? '—').toString();
    final providerId = (booking['providerId'] ?? '—').toString();
    final providerName = (booking['providerName'] ?? '—').toString();
    final specialty = (booking['specialty'] ?? booking['serviceType'] ?? '—').toString();
    final status = (booking['status'] ?? 'pending').toString();
    final agreedPrice = (booking['agreedPrice'] ?? '—').toString();
    final totalAmount = (booking['totalAmount'] ?? '—').toString();
    final scheduledDate = _formatTimestamp(booking['scheduledDate']);
    final notes = (booking['notes'] ?? '—').toString();
    final bookingId = (booking['id'] ?? '—').toString();
    final createdAt = _formatTimestamp(booking['createdAt']);
    final updatedAt = _formatTimestamp(booking['updatedAt']);

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
            // Handle + header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2F9E44),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bookmark_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              specialty == '—' ? 'Booking' : specialty,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Booking Details',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadgeForStatus(status: status),
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  _DetailSection(title: 'Service', children: [
                    _DetailField(label: 'Specialty / Service', value: specialty),
                    _DetailField(label: 'Status', value: status.replaceAll('_', ' ').toUpperCase()),
                    _DetailField(label: 'Scheduled Date', value: scheduledDate),
                    _DetailField(label: 'Notes', value: notes, multiLine: true),
                  ]),
                  const SizedBox(height: 16),
                  _DetailSection(title: 'Pricing', children: [
                    _DetailField(label: 'Agreed Price', value: agreedPrice),
                    _DetailField(label: 'Total Amount', value: totalAmount),
                  ]),
                  const SizedBox(height: 16),
                  _DetailSection(title: 'Parties', children: [
                    _DetailField(label: 'Client Name', value: clientName),
                    _DetailField(label: 'Client ID', value: clientId, mono: true),
                    _DetailField(label: 'Provider Name', value: providerName),
                    _DetailField(label: 'Provider ID', value: providerId, mono: true),
                  ]),
                  const SizedBox(height: 16),
                  _DetailSection(title: 'Record Info', children: [
                    _DetailField(label: 'Booking ID', value: bookingId, mono: true),
                    _DetailField(label: 'Created', value: createdAt),
                    _DetailField(label: 'Last Updated', value: updatedAt),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared detail UI helpers ───────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final bool multiLine;
  final bool mono;
  const _DetailField({
    required this.label,
    required this.value,
    this.multiLine = false,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: multiLine
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontFamily: mono ? 'monospace' : null,
                    height: 1.5,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontFamily: mono ? 'monospace' : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
