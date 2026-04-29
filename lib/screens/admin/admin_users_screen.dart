import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  final String initialFilter;
  const AdminUsersScreen({super.key, this.initialFilter = 'all'});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  late String _filterType;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilter;
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await DatabaseService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = _allUsers;
    if (_filterType != 'all') {
      list = list.where((u) => u['userType'] == _filterType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        final name = (u['displayName'] ?? '').toString().toLowerCase();
        final phone = (u['phoneNumber'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }
    _filtered = list;
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final name = (user['displayName'] ?? 'this user').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to permanently delete $name\'s account?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final userId = user['id'].toString();
      final userType = (user['userType'] ?? 'client').toString();
      await DatabaseService.deleteUser(userId, userType);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final currentlyActive = user['isActive'] as bool? ?? true;
    final action = currentlyActive ? 'deactivate' : 'activate';
    final name = (user['displayName'] ?? 'this user').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Account'),
        content: Text('Are you sure you want to $action $name\'s account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action[0].toUpperCase() + action.substring(1),
              style: TextStyle(
                  color: currentlyActive ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await DatabaseService.setUserActiveStatus(
          user['id'].toString(), !currentlyActive);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Account ${!currentlyActive ? 'activated' : 'deactivated'} successfully.'),
            backgroundColor: !currentlyActive ? Colors.green : Colors.orange,
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

  void _showUserDetails(Map<String, dynamic> user) {
    final userId = user['id'].toString();
    final userType = (user['userType'] ?? 'client').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        userId: userId,
        userType: userType,
        onToggle: () {
          Navigator.pop(context);
          _toggleActive(user);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteUser(user);
        },
      ),
    );
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
                        onRefresh: _loadUsers,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _UserCard(
                            user: _filtered[i],
                            onToggle: () => _toggleActive(_filtered[i]),
                            onDelete: () => _deleteUser(_filtered[i]),
                            onTap: () => _showUserDetails(_filtered[i]),
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
      color: AppColors.navy,
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'User Accounts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
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
              hintText: 'Search by name or phone...',
              hintStyle:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.navy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filterType == 'all',
                onTap: () => setState(() {
                  _filterType = 'all';
                  _applyFilter();
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Clients',
                selected: _filterType == 'client',
                onTap: () => setState(() {
                  _filterType = 'client';
                  _applyFilter();
                }),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Providers',
                selected: _filterType == 'provider',
                onTap: () => setState(() {
                  _filterType = 'provider';
                  _applyFilter();
                }),
              ),
            ],
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
          Icon(Icons.people_outline_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text(
            'No users found',
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

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (user['displayName'] ?? 'Unknown User').toString();
    final phone = (user['phoneNumber'] ?? 'No phone').toString();
    final userType = (user['userType'] ?? 'client').toString();
    final isActive = user['isActive'] as bool? ?? true;
    final isClient = userType == 'client';

    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.border : Colors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isClient
                    ? AppColors.navy.withOpacity(0.1)
                    : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isClient ? AppColors.navy : AppColors.accent,
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
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusBadge(
                        label: userType.toUpperCase(),
                        color: isClient ? AppColors.navy : AppColors.accent,
                        bgColor: isClient
                            ? AppColors.navy.withOpacity(0.1)
                            : AppColors.accent.withOpacity(0.1),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge(
                        label: isActive ? 'ACTIVE' : 'INACTIVE',
                        color: isActive
                            ? AppColors.success
                            : Colors.red.shade600,
                        bgColor: isActive
                            ? AppColors.success.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        icon: isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.block_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Deactivate / Activate
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.red.withOpacity(0.08)
                          : Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? Colors.red.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.red.shade600 : Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Delete
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _UserDetailSheet extends StatefulWidget {
  final String userId;
  final String userType;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _UserDetailSheet({
    required this.userId,
    required this.userType,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await DatabaseService.getUserFullDetails(
          widget.userId, widget.userType);
      if (mounted) setState(() => _data = d);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.userType == 'client';
    final color = isClient ? AppColors.navy : AppColors.accent;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Sheet header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                border:
                    Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isClient
                          ? Icons.person_rounded
                          : Icons.construction_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading
                              ? 'Loading...'
                              : (_data?['displayName'] ?? 'Unknown')
                                  .toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.userType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null
                      ? const Center(child: Text('No data found'))
                      : ListView(
                          controller: ctrl,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _section('ACCOUNT INFO', [
                              _row('Full Name',
                                  (_data!['displayName'] ?? '-').toString()),
                              _row('Phone',
                                  (_data!['phoneNumber'] ?? '-').toString()),
                              _row('Email',
                                  (_data!['email'] ?? '-').toString()),
                              _row('User Type',
                                  widget.userType.toUpperCase()),
                              _row(
                                'Status',
                                (_data!['isActive'] as bool? ?? true)
                                    ? 'Active'
                                    : 'Inactive',
                              ),
                              _row('Joined', _formatTs(_data!['createdAt'])),
                            ]),
                            const SizedBox(height: 16),
                            _section('IDENTITY INFO', [
                              _row('NID Number',
                                  (_data!['nidNumber'] ?? '-').toString()),
                              _row('Date of Birth',
                                  (_data!['dateOfBirth'] ?? '-').toString()),
                              _row("Father's Name",
                                  (_data!['fatherName'] ?? '-').toString()),
                              _row("Mother's Name",
                                  (_data!['motherName'] ?? '-').toString()),
                              _row('Address',
                                  (_data!['address'] ?? '-').toString()),
                            ]),
                            const SizedBox(height: 16),
                            _section('SECURITY', [
                              _passwordRow(
                                  (_data!['password'] ?? '').toString()),
                            ]),
                            const SizedBox(height: 24),
                            // Deactivate / Activate
                            GestureDetector(
                              onTap: widget.onToggle,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: (_data!['isActive'] as bool? ?? true)
                                      ? Colors.red.withOpacity(0.08)
                                      : Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (_data!['isActive'] as bool? ?? true)
                                        ? Colors.red.withOpacity(0.4)
                                        : Colors.green.withOpacity(0.4),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  (_data!['isActive'] as bool? ?? true)
                                      ? 'Deactivate Account'
                                      : 'Activate Account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: (_data!['isActive'] as bool? ?? true)
                                        ? Colors.red.shade600
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Delete Account
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade700.withOpacity(0.5)),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_forever_rounded,
                                        size: 18, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete Account Permanently',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(rows.length, (i) {
              final isLast = i == rows.length - 1;
              return Container(
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.border)),
                ),
                child: rows[i],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordRow(String password) {
    final display = password.isEmpty ? '-' : password;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'Password',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _showPassword
                  ? display
                  : '•' * (display == '-' ? 1 : display.length),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (password.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _showPassword = !_showPassword),
              child: Icon(
                _showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final dt = ts.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
