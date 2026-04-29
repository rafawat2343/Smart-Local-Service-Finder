import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  List<Map<String, dynamic>> _allProviders = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _filterStatus = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() => _loading = true);
    try {
      final providers =
          await DatabaseService.getAllUsers(filterType: 'provider');
      if (mounted) {
        setState(() {
          _allProviders = providers;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load providers: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = _allProviders;
    if (_filterStatus == 'approved') {
      list = list
          .where((p) => p['isApproved'] == true && (p['isActive'] ?? true))
          .toList();
    } else if (_filterStatus == 'pending') {
      list = list
          .where((p) =>
              p['isApproved'] != true && (p['isActive'] ?? true))
          .toList();
    } else if (_filterStatus == 'suspended') {
      list = list.where((p) => p['isActive'] == false).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name =
            (p['displayName'] ?? '').toString().toLowerCase();
        final specialty =
            (p['specialty'] ?? p['serviceType'] ?? '')
                .toString()
                .toLowerCase();
        return name.contains(q) || specialty.contains(q);
      }).toList();
    }
    _filtered = list;
  }

  Future<void> _approveProvider(Map<String, dynamic> provider) async {
    final name =
        (provider['displayName'] ?? 'this provider').toString();
    final isApproved = provider['isApproved'] as bool? ?? false;
    final action = isApproved ? 'revoke approval from' : 'approve';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApproved ? 'Revoke Approval' : 'Approve Listing'),
        content: Text(
            'Are you sure you want to $action $name\'s listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isApproved ? 'Revoke' : 'Approve',
              style: TextStyle(
                  color: isApproved ? Colors.orange : Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await DatabaseService.approveProvider(
          provider['id'].toString(), !isApproved);
      await _loadProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Listing ${!isApproved ? 'approved' : 'approval revoked'} successfully.'),
            backgroundColor: !isApproved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _suspendProvider(Map<String, dynamic> provider) async {
    final isActive = provider['isActive'] as bool? ?? true;
    final name =
        (provider['displayName'] ?? 'this provider').toString();
    final action = isActive ? 'suspend' : 'restore';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(isActive ? 'Suspend Listing' : 'Restore Listing'),
        content: Text(
            'Are you sure you want to $action $name\'s listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isActive ? 'Suspend' : 'Restore',
              style: TextStyle(
                  color: isActive ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await DatabaseService.setUserActiveStatus(
          provider['id'].toString(), !isActive);
      await _loadProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Listing ${!isActive ? 'restored' : 'suspended'} successfully.'),
            backgroundColor:
                !isActive ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchAndFilter(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadProviders,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ProviderListingCard(
                            provider: _filtered[i],
                            onApprove: () =>
                                _approveProvider(_filtered[i]),
                            onSuspend: () =>
                                _suspendProvider(_filtered[i]),
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
      color: AppColors.accent,
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
            child: Text(
              'Provider Listings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_filtered.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _searchController,
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
                _applyFilter();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name or specialty...',
              hintStyle: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilter();
                        });
                      },
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textTertiary, size: 18),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _filterStatus == 'all',
                    onTap: () => setState(() {
                          _filterStatus = 'all';
                          _applyFilter();
                        })),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Approved',
                    selected: _filterStatus == 'approved',
                    selectedColor: Colors.green,
                    onTap: () => setState(() {
                          _filterStatus = 'approved';
                          _applyFilter();
                        })),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Pending',
                    selected: _filterStatus == 'pending',
                    selectedColor: Colors.orange,
                    onTap: () => setState(() {
                          _filterStatus = 'pending';
                          _applyFilter();
                        })),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Suspended',
                    selected: _filterStatus == 'suspended',
                    selectedColor: Colors.red,
                    onTap: () => setState(() {
                          _filterStatus = 'suspended';
                          _applyFilter();
                        })),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_outlined,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'No listings found',
            style: TextStyle(
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.navy;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProviderListingCard extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;

  const _ProviderListingCard({
    required this.provider,
    required this.onApprove,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (provider['displayName'] ?? 'Unknown Provider').toString();
    final specialty =
        (provider['specialty'] ?? provider['serviceType'] ?? 'Service Provider')
            .toString();
    final phone =
        (provider['phoneNumber'] ?? 'No phone').toString();
    final isActive = provider['isActive'] as bool? ?? true;
    final isApproved = provider['isApproved'] as bool? ?? false;
    final rating = provider['ratingAvg'] ?? provider['rating'] ?? 0.0;
    final jobs =
        provider['jobsCompleted'] ?? provider['jobs'] ?? 0;

    final initials = name.trim().split(RegExp(r'\s+')).length >= 2
        ? '${name.trim().split(RegExp(r'\s+'))[0][0]}${name.trim().split(RegExp(r'\s+'))[1][0]}'
            .toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : 'P';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: !isActive
              ? Colors.red.withOpacity(0.3)
              : isApproved
                  ? Colors.green.withOpacity(0.3)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!isActive)
                StatusBadge(
                  label: 'SUSPENDED',
                  color: Colors.red.shade700,
                  bgColor: Colors.red.withOpacity(0.1),
                  icon: Icons.block_rounded,
                )
              else if (isApproved)
                StatusBadge(
                  label: 'APPROVED',
                  color: Colors.green.shade700,
                  bgColor: Colors.green.withOpacity(0.1),
                  icon: Icons.verified_rounded,
                )
              else
                StatusBadge(
                  label: 'PENDING',
                  color: Colors.orange.shade700,
                  bgColor: Colors.orange.withOpacity(0.1),
                  icon: Icons.pending_rounded,
                ),
              const SizedBox(width: 8),
              Icon(Icons.star_rounded,
                  size: 12, color: AppColors.star),
              const SizedBox(width: 3),
              Text(
                '${(rating is num ? rating.toStringAsFixed(1) : '0.0')} · $jobs jobs',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.orange.withOpacity(0.08)
                          : Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isApproved
                            ? Colors.orange.withOpacity(0.4)
                            : Colors.green.withOpacity(0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isApproved ? 'Revoke Approval' : 'Approve',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isApproved
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onSuspend,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.red.withOpacity(0.08)
                          : Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? Colors.red.withOpacity(0.4)
                            : Colors.blue.withOpacity(0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isActive ? 'Suspend' : 'Restore',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                      ),
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
