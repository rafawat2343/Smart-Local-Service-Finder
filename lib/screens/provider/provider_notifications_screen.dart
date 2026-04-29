import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class ProviderNotificationsScreen extends StatefulWidget {
  final int initialTabIndex;
  const ProviderNotificationsScreen({super.key, this.initialTabIndex = 1});

  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> {
  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    }
    return '';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'rate_change':
        return Icons.attach_money_rounded;
      case 'new_booking':
        return Icons.inbox_rounded;
      case 'payment_received':
        return Icons.payments_rounded;
      case 'booking_completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'rate_change':
        return AppColors.accent;
      case 'payment_received':
      case 'booking_completed':
        return AppColors.success;
      default:
        return AppColors.navy;
    }
  }

  void _onNotificationTap(Map<String, dynamic> n) {
    DatabaseService.markAppNotificationRead((n['id'] ?? '').toString());
    // Return to caller so it can switch to the Booking Requests tab if needed.
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.getCurrentUserId();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BackgroundWatermark(
        child: Column(
          children: [
            Container(
              color: AppColors.navy,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 12,
                20,
                20,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Rate changes, bookings & payments',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: userId == null
                  ? _buildEmpty('Not signed in')
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: DatabaseService.streamUserNotifications(userId),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.navy,
                            ),
                          );
                        }
                        final items = snap.data ?? [];
                        if (items.isEmpty) {
                          return _buildEmpty('No notifications yet');
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(20),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildCard(items[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 26,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Updates about bookings, rates and payments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final title = (n['title'] ?? 'Notification').toString();
    final message = (n['message'] ?? '').toString();
    final isUnread = n['read'] != true;
    final dateStr = _formatDate(n['createdAt']);
    final iconColor = _colorForType(type);

    return CorpCard(
      onTap: () => _onNotificationTap(n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconForType(type), size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isUnread ? FontWeight.w800 : FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                )
              else if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (isUnread && dateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
