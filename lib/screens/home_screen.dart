import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/product_card.dart';
import '../widgets/search_bar_widget.dart';

enum ViewState { initial, loading, loaded, error }

enum SortOption {
  defaultSort('Featured'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  highestRated('Highest Rated'),
  nameAZ('Name: A to Z');

  final String label;
  const SortOption(this.label);
}

class HomeScreen extends StatefulWidget {
  final ApiService? apiService;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const HomeScreen({
    super.key,
    this.apiService,
    this.isDarkMode = false,
    this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ViewState _viewState = ViewState.initial;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  String _errorMessage = '';
  String _selectedCategory = 'All';
  SortOption _sortOption = SortOption.defaultSort;
  final Set<int> _favoriteIds = {};
  int _cartCount = 0;
  bool _showFavoritesOnly = false;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _scrollController.addListener(_onScroll);
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (widget.apiService == null) {
      _apiService.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final shouldShow = _scrollController.offset > 300;
      if (shouldShow != _showScrollToTop) {
        setState(() {
          _showScrollToTop = shouldShow;
        });
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Fetches the product list from the FakeStore API.
  Future<void> _fetchProducts() async {
    setState(() {
      _viewState = ViewState.loading;
      _errorMessage = '';
    });

    try {
      final products = await _apiService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _applyFilters();
        _viewState = ViewState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _viewState = ViewState.error;
      });
    }
  }

  /// Filters and sorts the products list based on search, category, and sort option.
  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = _allProducts.where((product) {
      final matchesQuery = query.isEmpty ||
          product.title.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == 'All' ||
          product.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesWishlist =
          !_showFavoritesOnly || _favoriteIds.contains(product.id);

      return matchesQuery && matchesCategory && matchesWishlist;
    }).toList();

    switch (_sortOption) {
      case SortOption.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.highestRated:
        filtered.sort((a, b) =>
            (b.rating?.rate ?? 0.0).compareTo(a.rating?.rate ?? 0.0));
        break;
      case SortOption.nameAZ:
        filtered.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.defaultSort:
        // maintain API order
        break;
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _onSearchChanged(String value) {
    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    _applyFilters();
  }

  void _toggleFavorite(Product product) {
    final isFav = _favoriteIds.contains(product.id);
    setState(() {
      if (isFav) {
        _favoriteIds.remove(product.id);
      } else {
        _favoriteIds.add(product.id);
      }
      if (_showFavoritesOnly) {
        _applyFilters();
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFav
              ? 'Removed "${product.title}" from Wishlist'
              : 'Added "${product.title}" to Wishlist',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addToCart(Product product) {
    setState(() {
      _cartCount++;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${product.title}" to Cart!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              if (_cartCount > 0) _cartCount--;
            });
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower == 'all') return Icons.grid_view_rounded;
    if (lower.contains('electr')) return Icons.bolt_rounded;
    if (lower.contains('jewel')) return Icons.diamond_outlined;
    if (lower.contains('men')) return Icons.male_rounded;
    if (lower.contains('women')) return Icons.female_rounded;
    return Icons.category_outlined;
  }

  List<String> get _categories {
    final categoriesSet = <String>{'All'};
    for (final p in _allProducts) {
      if (p.category.isNotEmpty) {
        categoriesSet.add(p.category);
      }
    }
    return categoriesSet.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.storefront_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FakeStore',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Discover Products',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Theme toggle
          if (widget.onToggleTheme != null)
            IconButton(
              icon: Icon(
                widget.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              tooltip: widget.isDarkMode
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
              onPressed: widget.onToggleTheme,
            ),

          // Cart badge
          IconButton(
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              backgroundColor: theme.colorScheme.error,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            tooltip: 'Shopping Cart',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _cartCount > 0
                        ? '$_cartCount items in cart'
                        : 'Your cart is empty',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload products',
            onPressed: _viewState == ViewState.loading ? null : _fetchProducts,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              tooltip: 'Scroll to top',
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_viewState) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Fetching products from FakeStore...');

      case ViewState.error:
        return ErrorView(
          message: _errorMessage,
          onRetry: _fetchProducts,
        );

      case ViewState.loaded:
        return RefreshIndicator(
          onRefresh: _fetchProducts,
          color: theme.colorScheme.primary,
          child: Column(
            children: [
              // Search Bar & Filter Header
              _buildSearchHeader(theme),

              // Vertical Products List
              Expanded(
                child: _filteredProducts.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildProductList(),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSearchHeader(ThemeData theme) {
    final categories = _categories;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          CustomSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
            hintText: 'Search products by title or category...',
          ),

          const SizedBox(height: 10),

          // Category Chips Row
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Wishlist quick filter chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      _showFavoritesOnly
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: _showFavoritesOnly
                          ? Colors.white
                          : Colors.redAccent,
                    ),
                    label: Text(
                      'WISHLIST (${_favoriteIds.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _showFavoritesOnly
                            ? FontWeight.bold
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                        color: _showFavoritesOnly
                            ? Colors.white
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    selected: _showFavoritesOnly,
                    showCheckmark: false,
                    selectedColor: Colors.redAccent,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _showFavoritesOnly
                            ? Colors.redAccent
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _showFavoritesOnly = selected;
                        _applyFilters();
                      });
                    },
                  ),
                ),

                // Category chips
                for (final cat in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        _getCategoryIcon(cat),
                        size: 14,
                        color: _selectedCategory.toLowerCase() ==
                                cat.toLowerCase()
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                      label: Text(
                        cat.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedCategory.toLowerCase() ==
                                  cat.toLowerCase()
                              ? FontWeight.bold
                              : FontWeight.w500,
                          letterSpacing: 0.3,
                          color: _selectedCategory.toLowerCase() ==
                                  cat.toLowerCase()
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      selected: _selectedCategory.toLowerCase() ==
                          cat.toLowerCase(),
                      showCheckmark: false,
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _selectedCategory.toLowerCase() ==
                                  cat.toLowerCase()
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results counter and Sort Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_filteredProducts.length} of ${_allProducts.length} items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<SortOption>(
                    initialValue: _sortOption,
                    tooltip: 'Sort products',
                    onSelected: (SortOption option) {
                      setState(() {
                        _sortOption = option;
                        _applyFilters();
                      });
                    },
                    itemBuilder: (BuildContext context) =>
                        SortOption.values.map((SortOption option) {
                      return PopupMenuItem<SortOption>(
                        value: option,
                        child: Row(
                          children: [
                            if (_sortOption == option)
                              Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: theme.colorScheme.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(
                              option.label,
                              style: TextStyle(
                                fontWeight: _sortOption == option
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sort_rounded,
                            size: 15,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sortOption.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty ||
                      _selectedCategory != 'All' ||
                      _showFavoritesOnly) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _selectedCategory = 'All';
                          _showFavoritesOnly = false;
                          _sortOption = SortOption.defaultSort;
                          _applyFilters();
                        });
                      },
                      child: Text(
                        'Reset',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _filteredProducts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isFav = _favoriteIds.contains(product.id);

        return ProductCard(
          key: ValueKey(product.id),
          product: product,
          isFavorite: isFav,
          onToggleFavorite: () => _toggleFavorite(product),
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showFavoritesOnly
                    ? Icons.favorite_border_rounded
                    : Icons.search_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _showFavoritesOnly
                  ? 'Your Wishlist is Empty'
                  : 'No Products Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showFavoritesOnly
                  ? 'Tap the heart icon on any product to save it here for later.'
                  : 'We could not find anything matching your filters.\nTry searching for something else.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedCategory = 'All';
                  _showFavoritesOnly = false;
                  _sortOption = SortOption.defaultSort;
                  _applyFilters();
                });
              },
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Reset All Filters'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
