// lib/features/trust/presentation/screens/admin_user_management_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/role_labels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends ConsumerState<AdminUserManagementScreen> 
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _query = '';
  String _filterStatus = 'all';
  String _filterRole = 'all';
  late TabController _tabController;
  String? get _queryOrNull => _query.isEmpty ? null : _query;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _setStatus({
    required String userId,
    required String userName,
    required String status,
  }) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_capitalizeStatus(status)} User'),
        content: Text(
          'Are you sure you want to ${status.toLowerCase()} $userName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _getStatusColor(status),
            ),
            child: Text(_capitalizeStatus(status)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref.read(adminUserManagementProvider.notifier).setStatus(
          targetUserId: userId,
          status: status,
          reason: 'Admin moderation action',
        );
    
    if (!mounted) return;
    
    if (ok) {
      ref.invalidate(adminUsersProvider(_queryOrNull));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ User $status successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final actionState = ref.read(adminUserManagementProvider);
      final errorMessage = actionState.maybeWhen(
        error: (err, _) => err.toString(),
        orElse: () => 'Unknown error',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Failed: $errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserDetails(dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailsSheet(
        user: user,
        onStatusChange: (status) {
          Navigator.pop(context);
          _setStatus(
            userId: user.id,
            userName: user.name,
            status: status,
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Users',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Status Filter
                    Text('Status', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All', _filterStatus == 'all', () {
                          setState(() => _filterStatus = 'all');
                          this.setState(() => _filterStatus = 'all');
                        }),
                        _buildFilterChip('Active', _filterStatus == 'active', () {
                          setState(() => _filterStatus = 'active');
                          this.setState(() => _filterStatus = 'active');
                        }),
                        _buildFilterChip('Suspended', _filterStatus == 'suspended', () {
                          setState(() => _filterStatus = 'suspended');
                          this.setState(() => _filterStatus = 'suspended');
                        }),
                        _buildFilterChip('Blocked', _filterStatus == 'blocked', () {
                          setState(() => _filterStatus = 'blocked');
                          this.setState(() => _filterStatus = 'blocked');
                        }),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Role Filter
                    Text('Role', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All', _filterRole == 'all', () {
                          setState(() => _filterRole = 'all');
                          this.setState(() => _filterRole = 'all');
                        }),
                        _buildFilterChip('Artisan', _filterRole == 'artisan', () {
                          setState(() => _filterRole = 'artisan');
                          this.setState(() => _filterRole = 'artisan');
                        }),
                        _buildFilterChip(RoleLabels.client, _filterRole == 'customer', () {
                          setState(() => _filterRole = 'customer');
                          this.setState(() => _filterRole = 'customer');
                        }),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _filterStatus = 'all';
                                _filterRole = 'all';
                              });
                              this.setState(() {
                                _filterStatus = 'all';
                                _filterRole = 'all';
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  List<dynamic> _applyFilters(List<dynamic> users) {
    return users.where((user) {
      final statusMatch = _filterStatus == 'all' || 
          user.moderationStatus == _filterStatus;
      final roleMatch = _filterRole == 'all' || 
          user.userType == _filterRole;
      return statusMatch && roleMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final usersAsync = ref.watch(adminUsersProvider(_queryOrNull));
    final loading = ref.watch(adminUserManagementProvider).isLoading;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              title: const Text('User Management'),
              actions: [
                IconButton(
                  icon: Badge(
                    isLabelVisible: _filterStatus != 'all' || _filterRole != 'all',
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: _showFilterDialog,
                  tooltip: 'Filter',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(120),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                        onChanged: (value) {
                          setState(() => _query = value.trim());
                        },
                      ),
                    ),
                    
                    // Quick Stats Tabs
                    Container(
                      color: colorScheme.surface,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: const [
                          Tab(text: 'All Users'),
                          Tab(text: 'Artisans'),
                          Tab(text: '${RoleLabels.client}s'),
                          Tab(text: 'Flagged'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUserList(usersAsync, loading, null),
            _buildUserList(usersAsync, loading, 'artisan'),
            _buildUserList(usersAsync, loading, 'customer'),
            _buildUserList(usersAsync, loading, 'flagged'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(
    AsyncValue<List<dynamic>> usersAsync,
    bool loading,
    String? roleFilter,
  ) {
    return usersAsync.when(
      data: (users) {
        // Apply filters
        var filteredUsers = _applyFilters(users);
        
        // Apply tab filter
        if (roleFilter == 'artisan' || roleFilter == 'customer') {
          filteredUsers = filteredUsers
              .where((u) => u.userType == roleFilter)
              .toList();
        } else if (roleFilter == 'flagged') {
          filteredUsers = filteredUsers
              .where((u) => u.moderationStatus != 'active')
              .toList();
        }
        
        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminUsersProvider(_queryOrNull));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return _buildUserCard(user, loading);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading users',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(adminUsersProvider(_queryOrNull)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user, bool loading) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(user.moderationStatus);
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: user.moderationStatus != 'active'
              ? statusColor.withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: user.verified 
                            ? Colors.blue 
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            user.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (user.verified)
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.blue,
                              child: Icon(
                                Icons.verified,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Name and Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showUserDetails(user),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Status and Role Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user.userType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getRoleColor(user.userType).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRoleIcon(user.userType),
                          size: 14,
                          color: _getRoleColor(user.userType),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.userType.toUpperCase(),
                          style: TextStyle(
                            color: _getRoleColor(user.userType),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(user.moderationStatus),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.moderationStatus.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Verified Badge
                  if (user.verified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VERIFIED',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'blocked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'artisan':
        return Colors.blue;
      case 'customer':
        return Colors.purple;
      case 'admin':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'suspended':
        return Icons.pause_circle;
      case 'blocked':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'artisan':
        return Icons.construction;
      case 'customer':
        return Icons.person;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.help;
    }
  }

  String _capitalizeStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }
}

// User Details Bottom Sheet
class _UserDetailsSheet extends StatelessWidget {
  final dynamic user;
  final Function(String) onStatusChange;

  const _UserDetailsSheet({
    required this.user,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              user.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // User Info
                    _buildInfoRow(
                      context,
                      Icons.badge,
                      'User ID',
                      user.id.substring(0, 8) + '...',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.work_outline,
                      'Role',
                      user.userType.toUpperCase(),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.verified_outlined,
                      'Verified',
                      user.verified ? 'Yes' : 'No',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.info_outline,
                      'Status',
                      user.moderationStatus.toUpperCase(),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Actions
                    Text(
                      'Moderation Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    FilledButton.icon(
                      onPressed: user.moderationStatus == 'active'
                          ? null
                          : () => onStatusChange('active'),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Activate User'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: user.moderationStatus == 'suspended'
                          ? null
                          : () => onStatusChange('suspended'),
                      icon: const Icon(Icons.pause_circle),
                      label: const Text('Suspend User'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: user.moderationStatus == 'blocked'
                          ? null
                          : () => onStatusChange('blocked'),
                      icon: const Icon(Icons.block),
                      label: const Text('Block User'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}




