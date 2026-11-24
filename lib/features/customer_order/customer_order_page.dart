import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

class CustomerOrderPage extends StatefulWidget {
  const CustomerOrderPage({super.key});

  static const routeName = '/order';

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  late Future<List<_CustomerMenuItem>> _menuFuture;
  final Map<String, int> _cart = {}; // menu_item_id -> quantity
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _deliveryLocation = TextEditingController();
  final _orderNotes = TextEditingController();

  bool _isSubmitting = false;
  Map<String, dynamic>? _placedOrder;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _menuFuture = _loadAvailableMenu();
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _deliveryLocation.dispose();
    _orderNotes.dispose();
    super.dispose();
  }

  Future<List<_CustomerMenuItem>> _loadAvailableMenu() async {
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('daily_menu')
          .select(
            'id, is_active, '
            'menu_items(id, name, price_kes, category, image_url)',
          )
          .eq('menu_date', date)
          .eq('is_active', true)
          .order('created_at');

      final list = (response as List<dynamic>).map((row) {
        final itemMap =
            (row as Map<String, dynamic>)['menu_items'] as Map<String, dynamic>;
        return _CustomerMenuItem(
          menuItemId: itemMap['id'] as String,
          name: itemMap['name'] as String,
          priceKes: (itemMap['price_kes'] as num).toDouble(),
          category: itemMap['category'] as String?,
          imageUrl: itemMap['image_url'] as String?,
        );
      }).toList();

      return list;
    } catch (e) {
      try {
        Supabase.instance.client;
      } catch (_) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> _refreshMenu() {
    final nextMenu = _loadAvailableMenu();
    setState(() => _menuFuture = nextMenu);
    return nextMenu.then<void>((_) {}, onError: (Object _) {});
  }

  void _changeQuantity(String menuItemId, int delta) {
    setState(() {
      final current = _cart[menuItemId] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _cart.remove(menuItemId);
      } else {
        _cart[menuItemId] = next;
      }
    });
  }

  int get _totalItemsCount => _cart.values.fold(0, (sum, q) => sum + q);

  double _calculateTotal(List<_CustomerMenuItem> items) {
    final itemMap = {for (final item in items) item.menuItemId: item};
    return _cart.entries.fold<double>(0.0, (total, entry) {
      final item = itemMap[entry.key];
      if (item == null) return total;
      return total + (item.priceKes * entry.value);
    });
  }

  Future<void> _submitOrder(List<_CustomerMenuItem> items) async {
    final name = _customerName.text.trim();
    if (name.isEmpty) {
      setState(
        () => _errorMessage = 'Please enter your name to place the order.',
      );
      return;
    }
    if (_deliveryLocation.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a delivery location.');
      return;
    }
    if (_cart.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one item.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final itemPayload = _cart.entries
          .where((e) => e.value > 0)
          .map((e) => {'menu_item_id': e.key, 'quantity': e.value})
          .toList();

      final response = await Supabase.instance.client.rpc(
        'place_customer_order',
        params: {
          'p_customer_name': name,
          'p_customer_phone': _customerPhone.text.trim(),
          'p_delivery_location': _deliveryLocation.text.trim(),
          'p_order_notes': _orderNotes.text.trim(),
          'p_items': itemPayload,
        },
      );

      final result = response as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _placedOrder = {
            'order_id': result['order_id'],
            'total_kes': result['total_kes'],
            'customer_name': name,
            'item_count': _totalItemsCount,
          };
          _cart.clear();
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not place order: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetOrder() {
    setState(() {
      _placedOrder = null;
      _cart.clear();
      _customerName.clear();
      _customerPhone.clear();
      _deliveryLocation.clear();
      _orderNotes.clear();
      _errorMessage = null;
      _menuFuture = _loadAvailableMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_placedOrder != null) {
      return _OrderSuccessView(order: _placedOrder!, onNewOrder: _resetOrder);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.coffee_outlined,
                color: AppColors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cafe Service',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Today’s Chalkboard',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMenu,
        child: FutureBuilder<List<_CustomerMenuItem>>(
          future: _menuFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_off_outlined,
                              size: 48,
                              color: AppColors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Could not load today’s menu',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _refreshMenu,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.restaurant_menu_outlined,
                                size: 56,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No menu items available right now',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Today’s chalkboard is being updated by the kitchen. Please check back in a few minutes!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Pull down to check again.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: AppColors.green,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'FRESH TODAY',
                                      style: TextStyle(
                                        color: AppColors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${items.length} dishes available',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Order Online',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select your favorite dishes and order directly with the cafe kitchen without visiting in person.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Available dishes', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 14),
                    for (final item in items)
                      _CustomerMenuItemCard(
                        item: item,
                        quantity: _cart[item.menuItemId] ?? 0,
                        onAdd: () => _changeQuantity(item.menuItemId, 1),
                        onRemove: () => _changeQuantity(item.menuItemId, -1),
                      ),
                    const SizedBox(height: 28),
                    if (_cart.isNotEmpty) ...[
                      Text('Your details', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _customerName,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Your name *',
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _customerPhone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number (optional)',
                                  hintText: '0712 345 678',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _deliveryLocation,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Delivery location *',
                                  hintText: 'e.g. Building, estate, or room number',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _orderNotes,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Special instructions / delivery note',
                                  hintText: 'e.g. Pack takeaway, room number, or extra soup',
                                  prefixIcon: Icon(Icons.notes_outlined),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: FutureBuilder<List<_CustomerMenuItem>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final total = _calculateTotal(items);

          if (_cart.isEmpty || items.isEmpty) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalItemsCount ${_totalItemsCount == 1 ? 'item' : 'items'} in order',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        'KES ${total.toStringAsFixed(0)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : () => _submitOrder(items),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Sending order…'
                          : 'Place order · KES ${total.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomerMenuItem {
  const _CustomerMenuItem({
    required this.menuItemId,
    required this.name,
    required this.priceKes,
    this.category,
    this.imageUrl,
  });

  final String menuItemId;
  final String name;
  final double priceKes;
  final String? category;
  final String? imageUrl;
}

class _CustomerMenuItemCard extends StatelessWidget {
  const _CustomerMenuItemCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final _CustomerMenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${item.priceKes.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (quantity == 0)
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF252A30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease',
                        onPressed: onRemove,
                        icon: const Icon(Icons.remove, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$quantity',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase',
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSuccessView extends StatelessWidget {
  const _OrderSuccessView({required this.order, required this.onNewOrder});

  final Map<String, dynamic> order;
  final VoidCallback onNewOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = (order['order_id'] as String? ?? '').toUpperCase();
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final totalKes = (order['total_kes'] as num?)?.toDouble() ?? 0.0;
    final customerName = order['customer_name'] as String? ?? 'Customer';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.green,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Order Received!',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Thank you, $customerName! Your order has been placed directly with the kitchen.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16191D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER NUMBER',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '#$shortId',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blue,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'TOTAL',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'KES ${totalKes.toStringAsFixed(0)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: onNewOrder,
                      child: const Text('Place another order'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
