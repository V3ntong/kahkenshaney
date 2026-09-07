import 'package:flutter/material.dart';

import '../data/firestore/item_repository.dart';
import '../models/lost_found_item.dart';
import '../theme/app_theme.dart';
import '../widgets/item_grid_card.dart';
import '../screens/item_detail_screen.dart';

/// A single page with tabs for browsing Lost and Found items.
///
/// Includes search functionality and pull-to-refresh.
class BrowseItemsPage extends StatefulWidget {
  const BrowseItemsPage({
    super.key,
    this.initialKind = ItemKind.lost,
    this.repository,
    this.initialSearchQuery,
  });

  final ItemKind initialKind;
  final ItemRepository? repository;
  final String? initialSearchQuery;

  @override
  State<BrowseItemsPage> createState() => _BrowseItemsPageState();
}

class _BrowseItemsPageState extends State<BrowseItemsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ItemRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ItemRepository();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialKind == ItemKind.found ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Browse Items'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.fmd_bad_rounded),
              text: 'Lost Items',
            ),
            Tab(
              icon: Icon(Icons.inventory_2_rounded),
              text: 'Found Items',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BrowseTab(
            kind: ItemKind.lost,
            repository: _repository,
            initialSearchQuery: widget.initialSearchQuery,
          ),
          _BrowseTab(
            kind: ItemKind.found,
            repository: _repository,
            initialSearchQuery: widget.initialSearchQuery,
          ),
        ],
      ),
    );
  }
}

/// A single tab displaying items of a specific kind with search and refresh.
class _BrowseTab extends StatefulWidget {
  const _BrowseTab({
    required this.kind,
    required this.repository,
    this.initialSearchQuery,
  });

  final ItemKind kind;
  final ItemRepository repository;
  final String? initialSearchQuery;

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!;
      _searchController.text = _searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    // StreamBuilder automatically updates, but we can force a rebuild
    // by toggling the search query briefly
    final currentQuery = _searchQuery;
    setState(() => _searchQuery = '');
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _searchQuery = currentQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isLost = widget.kind == ItemKind.lost;
    final accent = isLost ? AppColors.error : AppColors.success;
    final accentSurface =
        isLost ? AppColors.errorSurface : AppColors.successSurface;

    return Column(
      children: [
        // ── Search Bar ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search ${isLost ? "lost" : "found"} items...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
        ),

        // ── Items Grid ─────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<LostFoundItem>>(
            stream: widget.repository.streamItemsWithSearch(
              kind: widget.kind,
              searchQuery: _searchQuery,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: accent),
                      const SizedBox(height: 16),
                      Text(
                        'Loading ${isLost ? "lost" : "found"} items...',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not load items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _onRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <LostFoundItem>[];

              if (items.isEmpty) {
                return _buildEmpty(isLost, accent);
              }

              return RefreshIndicator(
                onRefresh: _onRefresh,
                color: accent,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 900 ? 3 : (width >= 600 ? 2 : 2);
                    return GridView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ItemGridCard(
                          item: item,
                          heroTagPrefix: 'browse',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemDetailScreen(
                                item: item,
                                heroTagPrefix: 'browse',
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool isLost, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLost ? Icons.search_off_rounded : Icons.inventory_2_rounded,
                size: 36,
                color: accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results found'
                  : (isLost ? 'No lost items yet' : 'No found items yet'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : (isLost
                      ? 'When you report a lost item it will show up here.'
                      : 'Found something? Submit it and help reunite it with its owner.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
