// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});
  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  late Future<List<_Item>> _items;
  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  Future<void> _refresh() {
    final nextItems = _load();
    setState(() => _items = nextItems);
    return nextItems.then<void>((_) {}, onError: (Object _) {});
  }

  Future<List<_Item>> _load() async {
    final db = Supabase.instance.client;
    final results = await Future.wait([
      db.from('inventory_items').select().order('name'),
      db
          .from('stock_movements')
          .select('inventory_item_id,delta,reason,created_at')
          .order('created_at', ascending: false),
    ]);
    final totals = <String, double>{};
    final latest = <String, String>{};
    for (final raw in results[1] as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final id = row['inventory_item_id'] as String;
      totals[id] = (totals[id] ?? 0) + (row['delta'] as num).toDouble();
      latest.putIfAbsent(id, () => row['reason'] as String);
    }
    return (results[0] as List<dynamic>).map((raw) {
      final row = raw as Map<String, dynamic>;
      final id = row['id'] as String;
      return _Item(
        id,
        row['name'] as String,
        row['unit'] as String,
        (row['low_stock_threshold'] as num).toDouble(),
        totals[id] ?? 0,
        latest[id],
      );
    }).toList();
  }

  Future<void> _dialog({_Item? item}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _SupplyDialog(item: item),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Pantry'),
    ),
    floatingActionButton: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.sizeOf(context).width < 900 ? 96 : 0,
      ),
      child: FloatingActionButton.extended(
        onPressed: _dialog,
        icon: const Icon(Icons.add),
        label: const Text('Add supply'),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<_Item>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 44),
                        const SizedBox(height: 12),
                        Text(snapshot.error.toString()),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          if (!snapshot.hasData)
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          if (snapshot.data!.isEmpty)
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  child: Center(
                    child: FilledButton(
                      onPressed: _dialog,
                      child: const Text('Add first supply'),
                    ),
                  ),
                ),
              ],
            );
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final item = snapshot.data![index];
              final low = item.quantity <= item.threshold;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (low)
                            Chip(
                              label: const Text('LOW'),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.quantity.toStringAsFixed(2) +
                            ' ' +
                            item.unit +
                            ' on hand · low at ' +
                            item.threshold.toStringAsFixed(2),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: item.threshold == 0
                            ? 1
                            : (item.quantity / (item.threshold * 3)).clamp(
                                0.0,
                                1.0,
                              ),
                        color: low
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.latest == null
                                  ? 'No movements yet'
                                  : 'Last: ' + item.latest!,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _dialog(item: item),
                            icon: const Icon(Icons.tune),
                            label: const Text('Record movement'),
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
      ),
    ),
  );
}

class _SupplyDialog extends StatefulWidget {
  const _SupplyDialog({this.item});
  final _Item? item;
  @override
  State<_SupplyDialog> createState() => _SupplyDialogState();
}

class _SupplyDialogState extends State<_SupplyDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController(text: '0');
  final _threshold = TextEditingController(text: '0');
  final _note = TextEditingController();
  String _unit = 'pcs';
  String _reason = 'delivery';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _threshold.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      String id;
      if (widget.item == null) {
        final row = await db
            .from('inventory_items')
            .insert({
              'name': _name.text.trim(),
              'unit': _unit,
              'low_stock_threshold': num.parse(_threshold.text),
            })
            .select('id')
            .single();
        id = row['id'] as String;
      } else {
        id = widget.item!.id;
      }
      var delta = num.parse(_amount.text);
      if (_reason == 'sale' || _reason == 'spoilage') delta = -delta.abs();
      if (_reason == 'delivery') delta = delta.abs();
      if (delta != 0)
        await db.from('stock_movements').insert({
          'inventory_item_id': id,
          'delta': delta,
          'reason': _reason,
          'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        });
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _number(String? value) =>
      num.tryParse(value ?? '') == null ? 'Enter a number' : null;
  @override
  Widget build(BuildContext context) {
    final existing = widget.item != null;
    return AlertDialog(
      title: Text(existing ? 'Record movement' : 'Add supply'),
      content: SizedBox(
        width: 390,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!existing) ...[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Supply name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  value: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const ['pcs', 'kg', 'g', 'litres', 'ml']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (value) => setState(() => _unit = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _threshold,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Low-stock threshold',
                  ),
                  validator: _number,
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField(
                value: _reason,
                decoration: const InputDecoration(labelText: 'Movement type'),
                items: const [
                  DropdownMenuItem(
                    value: 'delivery',
                    child: Text('Delivery (+)'),
                  ),
                  DropdownMenuItem(
                    value: 'sale',
                    child: Text('Sale / use (-)'),
                  ),
                  DropdownMenuItem(
                    value: 'spoilage',
                    child: Text('Spoilage (-)'),
                  ),
                  DropdownMenuItem(
                    value: 'correction',
                    child: Text('Correction (+ or -)'),
                  ),
                ],
                onChanged: (value) => setState(() => _reason = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: _number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _Item {
  const _Item(
    this.id,
    this.name,
    this.unit,
    this.threshold,
    this.quantity,
    this.latest,
  );
  final String id, name, unit;
  final double threshold, quantity;
  final String? latest;
}
