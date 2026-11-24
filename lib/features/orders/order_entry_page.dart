import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderEntryPage extends StatefulWidget {
  const OrderEntryPage({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<OrderEntryPage> createState() => _OrderEntryPageState();
}

class _OrderEntryPageState extends State<OrderEntryPage> {
  final _customerName = TextEditingController(text: 'Customer');
  final Map<String, int> _quantities = {};
  late Future<List<_OrderableItem>> _items;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = _loadItems();
  }

  @override
  void dispose() {
    _customerName.dispose();
    super.dispose();
  }

  Future<List<_OrderableItem>> _loadItems() async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final response = await Supabase.instance.client
        .from('daily_menu')
        .select('menu_items(id, name, price_kes)')
        .eq('menu_date', date)
        .eq('is_active', true)
        .order('created_at');
    return (response as List<dynamic>).map((row) {
      final menuItem =
          (row as Map<String, dynamic>)['menu_items'] as Map<String, dynamic>;
      return _OrderableItem(
        id: menuItem['id'] as String,
        name: menuItem['name'] as String,
        price: (menuItem['price_kes'] as num).toDouble(),
      );
    }).toList();
  }

  void _changeQuantity(_OrderableItem item, int change) {
    setState(() {
      final quantity = (_quantities[item.id] ?? 0) + change;
      if (quantity <= 0) {
        _quantities.remove(item.id);
      } else {
        _quantities[item.id] = quantity;
      }
    });
  }

  Future<void> _saveOrder() async {
    if (_quantities.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'place_order',
        params: {
          'p_customer_name': _customerName.text.trim().isEmpty
              ? 'Customer'
              : _customerName.text.trim(),
          'p_items': _quantities.entries
              .map(
                (entry) => {'menu_item_id': entry.key, 'quantity': entry.value},
              )
              .toList(),
        },
      );
      if (mounted) {
        setState(() {
          _quantities.clear();
          _customerName.text = 'Customer';
        });
        widget.onSaved?.call();
      }
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('New order'),
    ),
    body: FutureBuilder<List<_OrderableItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load today’s available menu.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            TextField(
              controller: _customerName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Customer name',
                hintText: 'Customer',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),
            Text('Select items', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('There are no available menu items today.'),
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text('KES ${item.price.toStringAsFixed(0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remove one ${item.name}',
                            onPressed: _busy
                                ? null
                                : () => _changeQuantity(item, -1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${_quantities[item.id] ?? 0}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add one ${item.name}',
                            onPressed: _busy
                                ? null
                                : () => _changeQuantity(item, 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: _busy || _quantities.isEmpty ? null : _saveOrder,
        child: Text(_busy ? 'Saving order…' : 'Save order'),
      ),
    ),
  );
}

class _OrderableItem {
  const _OrderableItem({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final double price;
}
