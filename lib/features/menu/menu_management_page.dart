import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  List<_DailyMenuItem>? _items;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  bool _showUnavailable = false;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    try {
      _subscription = Supabase.instance.client
          .channel('public:daily_menu')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'daily_menu',
            callback: (_) {
              if (mounted) _refresh();
            },
          )
          .subscribe();
    } catch (_) {
      // Supabase not initialized or not supported
    }
  }

  Future<List<_DailyMenuItem>> _load() async {
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('daily_menu')
          .select(
            'id, is_active, '
            'menu_items(id, name, price_kes)',
          )
          .eq('menu_date', date)
          .order('created_at');
      return (response as List<dynamic>)
          .map((row) => _DailyMenuItem.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        Supabase.instance.client;
      } catch (_) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final items = await _load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggle(_DailyMenuItem item, bool active) async {
    // Optimistically update the UI immediately
    setState(() {
      _items = _items?.map((it) {
        if (it.id == item.id) {
          return it.copyWith(isActive: active);
        }
        return it;
      }).toList();
    });

    try {
      await Supabase.instance.client
          .from('daily_menu')
          .update({'is_active': active})
          .eq('id', item.id);
    } catch (_) {
      if (mounted) _refresh();
    }
  }

  Future<void> _addItem() async {
    final newItem = await showDialog<_DailyMenuItem>(
      context: context,
      builder: (_) => const _AddMenuItemDialog(),
    );
    if (newItem != null && mounted) {
      // Optimistically add the new item immediately so it appears instantly
      setState(() {
        _items = [...?_items, newItem];
      });
      // Sync with server in background
      _refresh();
    }
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _items == null) {
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

    if (_error != null && _items == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: _ErrorState(
              error: _error!,
              retry: _refresh,
            ),
          ),
        ],
      );
    }

    final allItems = _items ?? const [];
    final items = allItems
        .where((item) => _showUnavailable || item.isActive)
        .toList();

    if (items.isEmpty) {
      if (allItems.isNotEmpty) {
        // Items exist but all are inactive/hidden
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: _AllHiddenState(
                onShowAll: () => setState(() => _showUnavailable = true),
              ),
            ),
          ],
        );
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: _EmptyState(onAdd: _addItem),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: SwitchListTile(
            value: item.isActive,
            onChanged: (value) => _toggle(item, value),
            title: Text(item.name),
            subtitle: Text('KES ${item.price.toStringAsFixed(0)}'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Today’s menu'),
      actions: [
        IconButton(
          tooltip: _showUnavailable
              ? 'Hide unavailable items'
              : 'Show unavailable items',
          onPressed: () => setState(() => _showUnavailable = !_showUnavailable),
          icon: Icon(
            _showUnavailable
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
        IconButton(
          tooltip: 'Refresh menu',
          onPressed: _isRefreshing ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
      ],
    ),
    floatingActionButton: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.sizeOf(context).width < 900 ? 96 : 0,
      ),
      child: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          if (_isRefreshing && _items != null)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'Your chalkboard is empty',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Add the first item you are selling today.'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAdd,
            child: const Text('Add today’s first item'),
          ),
        ],
      ),
    ),
  );
}

class _AllHiddenState extends StatelessWidget {
  const _AllHiddenState({required this.onShowAll});
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_off_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'All menu items are currently hidden',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Toggle visibility to view and activate unavailable items.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onShowAll,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Show unavailable items'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.retry});
  final String error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'Could not load today’s menu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _AddMenuItemDialog extends StatefulWidget {
  const _AddMenuItemDialog();

  @override
  State<_AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<_AddMenuItemDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final menu = await client
          .from('menu_items')
          .insert({
            'name': _name.text.trim(),
            'price_kes': num.parse(_price.text.trim()),
          })
          .select('id, name, price_kes')
          .single();
      final daily = await client
          .from('daily_menu')
          .insert({
            'menu_item_id': menu['id'],
            'menu_date': DateTime.now().toIso8601String().substring(0, 10),
            'is_active': true,
          })
          .select('id, is_active')
          .single();

      final newItem = _DailyMenuItem(
        id: daily['id'] as String,
        name: menu['name'] as String,
        price: (menu['price_kes'] as num).toDouble(),
        isActive: (daily['is_active'] as bool?) ?? true,
      );

      if (mounted) Navigator.pop(context, newItem);
    } on PostgrestException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add menu item'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (KES)'),
              validator: (value) => num.tryParse(value ?? '') == null
                  ? 'Enter a valid price'
                  : null,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Add to today'),
      ),
    ],
  );
}

class _DailyMenuItem {
  const _DailyMenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
  });

  factory _DailyMenuItem.fromJson(Map<String, dynamic> json) {
    final menu = json['menu_items'] as Map<String, dynamic>;
    return _DailyMenuItem(
      id: json['id'] as String,
      name: menu['name'] as String,
      price: (menu['price_kes'] as num).toDouble(),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  _DailyMenuItem copyWith({
    String? id,
    String? name,
    double? price,
    bool? isActive,
  }) {
    return _DailyMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
    );
  }

  final String id;
  final String name;
  final double price;
  final bool isActive;
}
