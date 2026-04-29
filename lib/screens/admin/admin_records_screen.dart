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
  bool _loadingRequests = true;
  bool _loadingBookings = true;
  String _requestFilter = 'all';
  String _bookingFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadRequests();
    _loadBookings();
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
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildBookingsTab(),
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
                    itemBuilder: (_, i) =>
                        _RequestCard(request: _filteredRequests[i]),
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
                    itemBuilder: (_, i) =>
                        _BookingCard(booking: _filteredBookings[i]),
                  ),
                ),
        ),
      ],
    );
  }

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
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final category =
        (request['category'] ?? 'Service').toString();
    final description =
        (request['description'] ?? 'No description').toString();
    final status = (request['status'] ?? 'open').toString();
    final location =
        (request['location'] ?? 'Unknown location').toString();
    final budget = (request['budget'] ?? 'N/A').toString();
    final isUrgent = request['isUrgent'] as bool? ?? false;
    final date = _formatTimestamp(request['createdAt']);

    return Container(
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
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final clientId =
        (booking['clientId'] ?? 'Unknown').toString();
    final providerId =
        (booking['providerId'] ?? 'Unknown').toString();
    final status = (booking['status'] ?? 'pending').toString();
    final price =
        (booking['agreedPrice'] ?? 'N/A').toString();
    final date = _formatTimestamp(booking['createdAt']);

    return Container(
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
          _InfoRow(
              label: 'Client ID',
              value: clientId.length > 18
                  ? '${clientId.substring(0, 18)}...'
                  : clientId),
          const SizedBox(height: 4),
          _InfoRow(
              label: 'Provider ID',
              value: providerId.length > 18
                  ? '${providerId.substring(0, 18)}...'
                  : providerId),
          const SizedBox(height: 4),
          _InfoRow(label: 'Agreed Price', value: price),
        ],
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

String _formatTimestamp(dynamic ts) {
  if (ts is! Timestamp) return 'Unknown date';
  final dt = ts.toDate();
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
