import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/menu/menu_management_page.dart';
import 'features/inventory/inventory_management_page.dart';
import 'features/orders/order_entry_page.dart';
import 'features/statistics/statistics_page.dart';
import 'features/customer_order/customer_order_page.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured =
      _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
  runApp(CafeServiceApp(configured: configured));
}

class AppColors {
  static const background = Color(0xFF121417);
  static const surface = Color(0xFF1B1E22);
  static const border = Color(0xFF2D3238);
  static const muted = Color(0xFF9198A1);
  static const green = Color(0xFF0BC853);
  static const amber = Color(0xFFFFAB00);
  static const blue = Color(0xFF2979FF);
  static const red = Color(0xFFFF8A80);
}

class CafeServiceApp extends StatelessWidget {
  const CafeServiceApp({super.key, this.configured = false});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    const text = TextTheme(
      headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
    return MaterialApp(
      title: 'Cafe Service',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.green,
          onPrimary: AppColors.background,
          surface: AppColors.surface,
          error: AppColors.red,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: text.apply(
          bodyColor: const Color(0xFFE4E7EB),
          displayColor: const Color(0xFFE4E7EB),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 2),
          ),
        ),
        scrollbarTheme: const ScrollbarThemeData(
          thumbVisibility: WidgetStatePropertyAll(false),
          trackVisibility: WidgetStatePropertyAll(false),
          thickness: WidgetStatePropertyAll(0),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE4E7EB),
            side: const BorderSide(color: Color(0xFF515860), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ),
      scrollBehavior: const _NoScrollbarBehavior(),
      onGenerateRoute: (settings) {
        if (settings.name == CustomerOrderPage.routeName) {
          return MaterialPageRoute<void>(
            builder: (_) => const CustomerOrderPage(),
            settings: settings,
          );
        }
        return null;
      },
      home: configured ? const _AuthGate() : const _SetupRequiredPage(),
    );
  }
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _SetupRequiredPage extends StatelessWidget {
  const _SetupRequiredPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  color: AppColors.green,
                  size: 34,
                ),
                const SizedBox(height: 20),
                Text(
                  'Connect your cafe',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Create a Supabase project, then run with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY. The publishable key is safe for the client; access is protected by Row Level Security.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  'flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) =>
        Supabase.instance.client.auth.currentSession == null
        ? const _SignInPage()
        : const ServiceDashboard(),
  );
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();
  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.coffee_outlined,
                  color: AppColors.green,
                  size: 38,
                ),
                const SizedBox(height: 20),
                Text(
                  'Owner sign in',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage today’s service from anywhere.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: Text(_busy ? 'Signing in…' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ServiceDashboard extends StatefulWidget {
  const ServiceDashboard({super.key});

  @override
  State<ServiceDashboard> createState() => _ServiceDashboardState();
}

class _ServiceDashboardState extends State<ServiceDashboard> {
  int _ordersRefreshKey = 0;
  int _selectedSection = 0;

  void _takeOrder() => _selectSection(1);

  void _selectSection(int index) {
    if (index != _selectedSection) setState(() => _selectedSection = index);
  }

  void _orderSaved() {
    setState(() {
      _ordersRefreshKey++;
      _selectedSection = 0;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Order saved')));
  }

  void _openSection(String section) {
    _selectSection(['Service', 'Orders', 'Menu', 'Pantry', 'Statistics']
        .indexOf(section));
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final sections = [
      SafeArea(
        child: Padding(
          padding: EdgeInsets.all(desktop ? 42 : 20),
          child: _DashboardContent(
            onTakeOrder: _takeOrder,
            onManageMenu: () => _selectSection(2),
            onManageInventory: () => _selectSection(3),
            ordersRefreshKey: _ordersRefreshKey,
          ),
        ),
      ),
      OrderEntryPage(onSaved: _orderSaved),
      const MenuManagementPage(),
      const InventoryManagementPage(),
      const StatisticsPage(),
    ];
    return Scaffold(
      extendBody: !desktop,
      body: Row(
        children: [
          if (desktop)
            _Sidebar(onSelect: _openSection, selectedSection: _selectedSection),
          Expanded(
            child: IndexedStack(index: _selectedSection, children: sections),
          ),
        ],
      ),
      bottomNavigationBar: desktop
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _MobileNavigation(
                  selectedIndex: _selectedSection,
                  onSelect: _openSection,
                ),
              ),
            ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({
    required this.onTakeOrder,
    required this.onManageMenu,
    required this.onManageInventory,
    required this.ordersRefreshKey,
  });

  final VoidCallback onTakeOrder;
  final VoidCallback onManageMenu;
  final VoidCallback onManageInventory;
  final int ordersRefreshKey;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final _ordersPanelKey = GlobalKey<_TodayOrdersPanelState>();
  bool _hasOrders = false;

  @override
  void didUpdateWidget(covariant _DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ordersRefreshKey != widget.ordersRefreshKey) {
      _ordersPanelKey.currentState?.refresh();
    }
  }

  Future<void> _refreshOrders() =>
      _ordersPanelKey.currentState?.refresh() ?? Future<void>.value();

  void _onOrdersLoaded(bool hasOrders) {
    if (mounted && _hasOrders != hasOrders) {
      setState(() => _hasOrders = hasOrders);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refreshOrders,
    child: LayoutBuilder(
      builder: (context, _) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            runSpacing: 18,
            spacing: 20,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAFE SERVICE',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Service dashboard',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: widget.onTakeOrder,
                    child: const Text('New order'),
                  ),
                  OutlinedButton(
                    onPressed: widget.onManageMenu,
                    child: const Text('Manage menu'),
                  ),
                ],
              ),
            ],
          ),
          if (!_hasOrders) ...[
            const SizedBox(height: 38),
            _DashboardActions(
              onTakeOrder: widget.onTakeOrder,
              onManageMenu: widget.onManageMenu,
              onManageInventory: widget.onManageInventory,
            ),
          ],
          const SizedBox(height: 32),
          _TodayOrdersPanel(
            key: _ordersPanelKey,
            onTakeOrder: widget.onTakeOrder,
            onOrdersLoaded: _onOrdersLoaded,
          ),
        ],
      ),
      ),
    ),
  );
}

class _TodayOrdersPanel extends StatefulWidget {
  const _TodayOrdersPanel({
    super.key,
    required this.onTakeOrder,
    this.onOrdersLoaded,
  });

  final VoidCallback onTakeOrder;
  final ValueChanged<bool>? onOrdersLoaded;

  @override
  State<_TodayOrdersPanel> createState() => _TodayOrdersPanelState();
}

class _TodayOrdersPanelState extends State<_TodayOrdersPanel> {
  late Future<List<_ServiceOrder>> _orders;
  final Set<String> _settlingOrders = {};
  final Set<String> _updatingDelivery = {};
  RealtimeChannel? _subscription;
  Timer? _carryoverTimer;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _orders = _loadOrders();
    _subscribe();
    _scheduleCarryoverRefresh();
  }

  void _subscribe() {
    try {
      _subscription = Supabase.instance.client
          .channel('public:cafe_orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cafe_orders',
            callback: (_) {
              if (mounted) _refresh();
            },
          )
          .subscribe();
    } catch (_) {
      // Supabase not initialized or not supported
    }
  }

  @override
  void dispose() {
    _carryoverTimer?.cancel();
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _scheduleCarryoverRefresh() {
    final now = DateTime.now();
    var cutoff = DateTime(now.year, now.month, now.day, 18);
    if (!now.isBefore(cutoff)) {
      cutoff = DateTime(now.year, now.month, now.day + 1, 18);
    }
    _carryoverTimer = Timer(cutoff.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleCarryoverRefresh();
    });
  }

  Future<List<_ServiceOrder>> _loadOrders() async {
    try {
      final response = await Supabase.instance.client
          .from('cafe_orders')
          .select(
            'id, customer_name, customer_phone, delivery_location, '
            'order_source, is_delivered, created_at, '
            'cafe_order_items(item_name, quantity, unit_price)',
          )
          .order('created_at', ascending: false)
          .limit(1000);
      return (response as List<dynamic>)
          .map((row) => _ServiceOrder.fromJson(row as Map<String, dynamic>))
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

  Future<void> refresh() async {
    final nextOrders = _loadOrders();
    setState(() => _orders = nextOrders);
    await nextOrders.then<void>((_) {}, onError: (Object _) {});
  }

  void _refresh() {
    refresh();
  }

  Future<void> _markPaid(_ServiceOrder order) async {
    if (_settlingOrders.contains(order.id)) return;
    setState(() => _settlingOrders.add(order.id));
    try {
      await Supabase.instance.client.rpc(
        'settle_order',
        params: {'p_order_id': order.id},
      );
      if (mounted) _refresh();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not mark order paid: ${error.message}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark order paid: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _settlingOrders.remove(order.id));
    }
  }

  Future<void> _toggleDelivery(_ServiceOrder order) async {
    if (_updatingDelivery.contains(order.id)) return;
    setState(() => _updatingDelivery.add(order.id));
    try {
      await Supabase.instance.client.rpc(
        'set_online_order_delivery_status',
        params: {
          'p_order_id': order.id,
          'p_is_delivered': !order.isDelivered,
        },
      );
      if (mounted) _refresh();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update delivery: ${error.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingDelivery.remove(order.id));
    }
  }

  bool _isCarryover(_ServiceOrder order, DateTime now) {
    final created = order.createdAt;
    final createdDay = DateTime(created.year, created.month, created.day);
    final today = DateTime(now.year, now.month, now.day);
    return createdDay.isBefore(today) ||
        !now.isBefore(DateTime(now.year, now.month, now.day, 18));
  }

  String _formatOrderTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    if (isToday) return 'Today at $timeStr';

    final isYesterday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day - 1;
    if (isYesterday) return 'Yesterday at $timeStr';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, $timeStr';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('Orders', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<_ServiceOrder>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.red,
                ),
                title: const Text('Could not load orders'),
                subtitle: Text(snapshot.error.toString()),
                trailing: TextButton(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final orders = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onOrdersLoaded?.call(orders.isNotEmpty);
          });
          final now = DateTime.now();
          final todayOrders = orders
              .where((order) => !_isCarryover(order, now))
              .toList();
          final carryovers = orders
              .where((order) => _isCarryover(order, now))
              .toList();
          return Column(
            children: [
              _OrderTabSwitcher(
                selectedTab: _selectedTab,
                todayCount: todayOrders.length,
                carryoverCount: carryovers.length,
                onTabChanged: (selected) {
                  setState(() => _selectedTab = selected);
                },
              ),
              const SizedBox(height: 20),
              if (_selectedTab == 0)
                _buildOrderSection(
                  context,
                  title: 'Today’s orders',
                  emptyMessage: 'No unpaid orders today.',
                  orders: todayOrders,
                  isCarryover: false,
                )
              else ...[
                if (carryovers.isNotEmpty) ...[
                  Card(
                    color: AppColors.amber.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.amber,
                      ),
                      title: const Text('Total outstanding debt'),
                      trailing: Text(
                        'KES ${carryovers.fold<double>(0.0, (sum, o) => sum + o.total).toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _buildOrderSection(
                  context,
                  title: 'Carryovers / Debts',
                  emptyMessage: 'No unpaid carryovers.',
                  orders: carryovers,
                  isCarryover: true,
                ),
              ],
            ],
          );
        },
      ),
    ],
  );

  Widget _buildOrderSection(
    BuildContext context, {
    required String title,
    required String emptyMessage,
    required List<_ServiceOrder> orders,
    required bool isCarryover,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (orders.isEmpty)
        Card(
          child: ListTile(
            leading: Icon(
              isCarryover
                  ? Icons.history_outlined
                  : Icons.receipt_long_outlined,
              color: AppColors.muted,
            ),
            title: Text(emptyMessage),
            trailing: isCarryover
                ? null
                : TextButton.icon(
                    onPressed: widget.onTakeOrder,
                    icon: const Icon(Icons.add),
                    label: const Text('New order'),
                  ),
          ),
        )
      else
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOrderCard(context, order, isCarryover),
          ),
    ],
  );

  Widget _buildOrderCard(
    BuildContext context,
    _ServiceOrder order,
    bool isCarryover,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isCarryover ? AppColors.amber : AppColors.green)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_outlined,
                  color: isCarryover ? AppColors.amber : AppColors.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.customerName,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Tag(
                          'UNPAID',
                          isCarryover ? AppColors.amber : AppColors.blue,
                        ),
                        if (order.isOnline) ...[
                          const SizedBox(width: 8),
                          _Tag('ONLINE ORDER', AppColors.green),
                        ],
                        if (order.id.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _Tag(
                            '#${order.id.substring(0, order.id.length >= 6 ? 6 : order.id.length).toUpperCase()}',
                            AppColors.blue,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatOrderTime(order.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${order.total.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.totalItemsCount} ${order.totalItemsCount == 1 ? 'item' : 'items'}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2F35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.quantity}×',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      'KES ${(item.quantity * item.unitPrice).toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
          ],
          if (order.isOnline && order.deliveryLocation != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryLocation!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (order.isOnline)
                OutlinedButton.icon(
                  onPressed: _updatingDelivery.contains(order.id)
                      ? null
                      : () => _toggleDelivery(order),
                  icon: _updatingDelivery.contains(order.id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          order.isDelivered
                              ? Icons.local_shipping_outlined
                              : Icons.local_shipping,
                        ),
                  label: Text(
                    _updatingDelivery.contains(order.id)
                        ? 'Saving…'
                        : order.isDelivered
                        ? 'Delivered'
                        : 'Mark delivered',
                  ),
                ),
              FilledButton.icon(
                onPressed: _settlingOrders.contains(order.id)
                    ? null
                    : () => _markPaid(order),
                icon: _settlingOrders.contains(order.id)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _settlingOrders.contains(order.id) ? 'Saving…' : 'Mark paid',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OrderTabSwitcher extends StatelessWidget {
  const _OrderTabSwitcher({
    required this.selectedTab,
    required this.todayCount,
    required this.carryoverCount,
    required this.onTabChanged,
  });

  final int selectedTab;
  final int todayCount;
  final int carryoverCount;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border, width: 1.5),
    ),
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        Expanded(
          child: _OrderTabButton(
            icon: Icons.receipt_long_outlined,
            label: 'Today’s orders',
            count: todayCount,
            isSelected: selectedTab == 0,
            onTap: () => onTabChanged(0),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _OrderTabButton(
            icon: Icons.history_outlined,
            label: 'Carryovers / Debts',
            count: carryoverCount,
            isSelected: selectedTab == 1,
            badgeColor: carryoverCount > 0 ? AppColors.amber : null,
            onTap: () => onTabChanged(1),
          ),
        ),
      ],
    ),
  );
}

class _OrderTabButton extends StatelessWidget {
  const _OrderTabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = isSelected ? AppColors.background : const Color(0xFFE4E7EB);
    final mutedFg = isSelected
        ? AppColors.background.withValues(alpha: 0.75)
        : AppColors.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: fg,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.background.withValues(alpha: 0.22)
                    : (badgeColor != null
                        ? badgeColor!.withValues(alpha: 0.18)
                        : const Color(0xFF2A2F35)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.background
                      : (badgeColor ?? mutedFg),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOrder {
  const _ServiceOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryLocation,
    required this.orderSource,
    required this.isDelivered,
    required this.createdAt,
    required this.items,
  });

  factory _ServiceOrder.fromJson(Map<String, dynamic> json) => _ServiceOrder(
    id: json['id'] as String? ?? '',
    customerName: (json['customer_name'] as String?)?.trim().isNotEmpty == true
        ? json['customer_name'] as String
        : 'Customer',
    customerPhone: json['customer_phone'] as String?,
    deliveryLocation: json['delivery_location'] as String?,
    orderSource: json['order_source'] as String? ?? 'counter',
    isDelivered: json['is_delivered'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    items: (json['cafe_order_items'] as List<dynamic>? ?? [])
        .map((item) => _ServiceOrderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String customerName;
  final String? customerPhone;
  final String? deliveryLocation;
  final String orderSource;
  final bool isDelivered;
  final DateTime createdAt;
  final List<_ServiceOrderItem> items;

  int get totalItemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get total =>
      items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));

  bool get isOnline => orderSource == 'online';
}

class _ServiceOrderItem {
  const _ServiceOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  factory _ServiceOrderItem.fromJson(Map<String, dynamic> json) =>
      _ServiceOrderItem(
        name: json['item_name'] as String? ?? 'Item',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      );

  final String name;
  final int quantity;
  final double unitPrice;
}

class _DashboardActions extends StatelessWidget {
  const _DashboardActions({
    required this.onTakeOrder,
    required this.onManageMenu,
    required this.onManageInventory,
  });
  final VoidCallback onTakeOrder;
  final VoidCallback onManageMenu;
  final VoidCallback onManageInventory;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ActionCard(
        icon: Icons.receipt_long_outlined,
        title: 'Take an order',
        description: 'Choose today’s menu items and add a customer name.',
        button: 'New order',
        onPressed: onTakeOrder,
      ),
      const SizedBox(height: 18),
      _ActionCard(
        icon: Icons.restaurant_menu_outlined,
        title: 'Today’s menu',
        description: 'Add items, prices, and availability.',
        button: 'Manage menu',
        onPressed: onManageMenu,
      ),
      const SizedBox(height: 18),
      _ActionCard(
        icon: Icons.inventory_2_outlined,
        title: 'Pantry',
        description: 'Record stock and watch low supplies.',
        button: 'Manage pantry',
        onPressed: onManageInventory,
      ),
    ],
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.button,
    required this.onPressed,
  });
  final IconData icon;
  final String title, description, button;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.green, size: 32),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: onPressed, child: Text(button)),
          ],
        ),
      ),
    ),
  );
}

class _Metrics extends StatelessWidget {
  const _Metrics();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 900
          ? 3
          : box.maxWidth >= 560
          ? 2
          : 1;
      return GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 26,
        mainAxisSpacing: 18,
        childAspectRatio: 2.2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _Metric(
            label: 'ORDERS TODAY',
            value: '24',
            color: AppColors.green,
            level: .60,
          ),
          _Metric(
            label: 'SALES (KES)',
            value: '18,450',
            color: AppColors.amber,
            level: .78,
          ),
          _Metric(
            label: 'ITEMS RUNNING LOW',
            value: '3',
            color: AppColors.blue,
            level: .30,
          ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    required this.level,
  });
  final String label, value;
  final Color color;
  final double level;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 14),
          _Bar(value: level, color: color),
        ],
      ),
    ),
  );
}

class _MainPanels extends StatelessWidget {
  const _MainPanels({required this.onManageMenu});

  final VoidCallback onManageMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final menu = _MenuPanel(onEdit: onManageMenu);
      const pantry = _PantryPanel();
      return box.maxWidth >= 1050
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: menu),
                const SizedBox(width: 26),
                Expanded(child: pantry),
              ],
            )
          : Column(children: [menu, const SizedBox(height: 26), pantry]);
    },
  );
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.onEdit});

  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => _Panel(
    'TODAY\'S CHALKBOARD',
    OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
    const [
      _Line('Masala chai', 'KES 120 · 14 LEFT', .70, AppColors.green),
      _Line('Mandazi (4)', 'KES 80 · 6 LEFT', .25, AppColors.amber),
      _Line('Chapati & beans', 'KES 250 · 9 LEFT', .45, AppColors.blue),
      _Line('Beef samosa', 'SOLD OUT', 0, AppColors.red),
    ],
  );
}

class _PantryPanel extends StatelessWidget {
  const _PantryPanel();
  @override
  Widget build(BuildContext context) =>
      const _Panel('PANTRY', _Tag('3 LOW', AppColors.amber), [
        _Line('Flour', '18 KG', .72, AppColors.green),
        _Line('Milk', '6 L', .24, AppColors.amber),
        _Line('Cooking oil', '2 L', .08, AppColors.red),
      ]);
}

class _Panel extends StatelessWidget {
  const _Panel(this.title, this.trailing, this.lines);
  final String title;
  final Widget trailing;
  final List<Widget> lines;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              trailing,
            ],
          ),
          const SizedBox(height: 22),
          ...lines,
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.name, this.right, this.value, this.color);
  final String name, right;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 19),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color == AppColors.red ? color : AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Bar(value: value, color: color),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 8,
      color: color,
      backgroundColor: const Color(0xFF2A2F35),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onSelect, required this.selectedSection});

  final ValueChanged<String> onSelect;
  final int selectedSection;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 106,
    child: Column(
      children: [
        const SizedBox(height: 28),
        _Nav(Icons.coffee_outlined, true, () => onSelect('Service')),
        const SizedBox(height: 38),
        _Nav(Icons.home_outlined, selectedSection == 0, () => onSelect('Service')),
        _Nav(Icons.receipt_long_outlined, selectedSection == 1, () => onSelect('Orders')),
        _Nav(Icons.restaurant_menu_outlined, selectedSection == 2, () => onSelect('Menu')),
        _Nav(Icons.inventory_2_outlined, selectedSection == 3, () => onSelect('Pantry')),
        _Nav(Icons.bar_chart_outlined, selectedSection == 4, () => onSelect('Statistics')),
      ],
    ),
  );
}

class _Nav extends StatelessWidget {
  const _Nav(this.icon, this.selected, this.onPressed);
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: IconButton(
      style: IconButton.styleFrom(
        backgroundColor: selected ? AppColors.green : Colors.transparent,
        foregroundColor: selected ? AppColors.background : AppColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  );
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 10)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: NavigationBar(
          height: 76,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => onSelect(
            ['Service', 'Orders', 'Menu', 'Pantry', 'Statistics'][index],
          ),
          backgroundColor: AppColors.surface.withValues(alpha: 0.72),
          indicatorColor: AppColors.green.withValues(alpha: 0.9),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Service'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), label: 'Menu'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Pantry'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Statistics'),
          ],
        ),
      ),
    ),
  );
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: Text(title),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                title == 'Pantry'
                    ? Icons.inventory_2_outlined
                    : Icons.bar_chart_outlined,
                color: AppColors.green,
                size: 48,
              ),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                title == 'Pantry'
                    ? 'Inventory management is the next feature to connect.'
                    : 'Sales reporting will appear here once checkout is connected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to service'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
