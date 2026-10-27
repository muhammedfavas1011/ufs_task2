import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufs_task/models/product.dart';
import 'package:ufs_task/screens/home_screen.dart';
import 'package:ufs_task/services/api_service.dart';
import 'package:ufs_task/widgets/error_view.dart';
import 'package:ufs_task/widgets/loading_view.dart';
import 'package:ufs_task/widgets/product_card.dart';

class MockApiService extends ApiService {
  final List<Product>? mockProducts;
  final bool shouldThrow;
  final String errorMessage;

  MockApiService({
    this.mockProducts,
    this.shouldThrow = false,
    this.errorMessage = 'Network connection failed',
  });

  @override
  Future<List<Product>> fetchProducts() async {
    if (shouldThrow) {
      throw ApiException(errorMessage);
    }
    return mockProducts ?? [];
  }
}

void main() {
  final testProducts = [
    const Product(
      id: 1,
      title: 'Fjallraven Backpack',
      price: 109.95,
      description: 'Your perfect pack for everyday use',
      category: "men's clothing",
      image: 'https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_.jpg',
      rating: Rating(rate: 3.9, count: 120),
    ),
    const Product(
      id: 2,
      title: 'Mens Casual Premium Slim Fit T-Shirts',
      price: 22.30,
      description: 'Slim-fitting style, contrast raglan long sleeve',
      category: "men's clothing",
      image: 'https://fakestoreapi.com/img/71-3HjGNDUL._AC_SY879._SX._UX._SY._UY_.jpg',
      rating: Rating(rate: 4.1, count: 259),
    ),
    const Product(
      id: 3,
      title: 'SanDisk SSD PLUS 1TB',
      price: 109.00,
      description: 'Easy upgrade for faster boot up',
      category: 'electronics',
      image: 'https://fakestoreapi.com/img/61U7T1koQqL._AC_SX679_.jpg',
      rating: Rating(rate: 4.5, count: 470),
    ),
  ];

  testWidgets('Renders product list and searches items successfully', (WidgetTester tester) async {
    final mockService = MockApiService(mockProducts: testProducts);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(apiService: mockService),
      ),
    );

    // Initial pump triggers loading
    expect(find.byType(LoadingView), findsOneWidget);

    // Let async operations complete
    await tester.pumpAndSettle();

    // Verify products are loaded
    expect(find.byType(ProductCard), findsNWidgets(3));
    expect(find.text('Fjallraven Backpack'), findsOneWidget);
    expect(find.text('\$109.95'), findsOneWidget);
    expect(find.text('SanDisk SSD PLUS 1TB'), findsOneWidget);

    // Test Search Functionality: search for "SanDisk"
    await tester.enterText(find.byType(TextField), 'SanDisk');
    await tester.pumpAndSettle();

    expect(find.text('SanDisk SSD PLUS 1TB'), findsOneWidget);
    expect(find.text('Fjallraven Backpack'), findsNothing);
    expect(find.byType(ProductCard), findsOneWidget);

    // Clear search using clear button
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    // All 3 items should reappear
    expect(find.byType(ProductCard), findsNWidgets(3));
  });

  testWidgets('Adds product to cart and updates cart count', (WidgetTester tester) async {
    final mockService = MockApiService(mockProducts: testProducts);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(apiService: mockService),
      ),
    );

    await tester.pumpAndSettle();

    // Tap first "Add to Cart" icon button
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
    await tester.pumpAndSettle();

    // Badge should show 1
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Added "Fjallraven Backpack" to Cart!'), findsOneWidget);
  });

  testWidgets('Toggles product wishlist favorite', (WidgetTester tester) async {
    final mockService = MockApiService(mockProducts: testProducts);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(apiService: mockService),
      ),
    );

    await tester.pumpAndSettle();

    // Find heart icon on the first product card
    final cardHeart = find.descendant(
      of: find.byType(ProductCard).first,
      matching: find.byIcon(Icons.favorite_border_rounded),
    );
    expect(cardHeart, findsOneWidget);

    // Tap heart icon on the card
    await tester.tap(cardHeart);
    await tester.pumpAndSettle();

    // First card should now show a filled favorite heart icon
    final filledHeart = find.descendant(
      of: find.byType(ProductCard).first,
      matching: find.byIcon(Icons.favorite_rounded),
    );
    expect(filledHeart, findsOneWidget);
    expect(find.text('Added "Fjallraven Backpack" to Wishlist'), findsOneWidget);
  });

  testWidgets('Shows error view and retry button on API failure', (WidgetTester tester) async {
    final mockService = MockApiService(
      shouldThrow: true,
      errorMessage: 'Server unavailable',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(apiService: mockService),
      ),
    );

    await tester.pumpAndSettle();

    // Verify error state
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Unable to Load Products'), findsOneWidget);
    expect(find.text('Server unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
