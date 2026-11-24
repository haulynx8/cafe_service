import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<_Statistics> _statistics;
  bool _savingExpense = false;

  @override
  void initState() {
    super.initState();
    _statistics = _loadStatistics();
  }

  Future<_Statistics> _loadStatistics() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final tomorrowUtc = today.add(const Duration(days: 1)).toUtc();
    final weekStartUtc = weekStart.toUtc();

    final salesRows = await _loadRows(
      table: 'paid_sales',
      select: 'paid_at, total_amount',
      dateColumn: 'paid_at',
      start: weekStartUtc,
      end: tomorrowUtc,
    );
    final expenseRows = await _loadRows(
      table: 'cafe_expenses',
      select: 'id, description, amount, created_at',
      dateColumn: 'created_at',
      start: weekStartUtc,
      end: tomorrowUtc,
    );
    final dailySales = List<double>.filled(7, 0);
    final dailyExpenses = List<double>.filled(7, 0);
    var paidToday = 0.0;
    var expenseToday = 0.0;
    var paidOrderCount = 0;

    for (final row in salesRows) {
      final paidAt = DateTime.parse(row['paid_at'] as String).toLocal();
      final amount = (row['total_amount'] as num).toDouble();
      final dayIndex = _dayIndex(
        DateTime(paidAt.year, paidAt.month, paidAt.day),
        weekStart,
      );
      if (dayIndex >= 0 && dayIndex < 7) dailySales[dayIndex] += amount;
      if (_sameDay(paidAt, now)) {
        paidToday += amount;
        paidOrderCount++;
      }
    }

    for (final row in expenseRows) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final amount = (row['amount'] as num).toDouble();
      final dayIndex = _dayIndex(
        DateTime(createdAt.year, createdAt.month, createdAt.day),
        weekStart,
      );
      if (dayIndex >= 0 && dayIndex < 7) dailyExpenses[dayIndex] += amount;
      if (_sameDay(createdAt, now)) expenseToday += amount;
    }

    var debtTotal = 0.0;
    var unpaidOrderCount = 0;
    var unpaidOffset = 0;
    while (true) {
      final unpaidResponse = await Supabase.instance.client
          .from('cafe_orders')
          .select('cafe_order_items(quantity, unit_price)')
          .range(unpaidOffset, unpaidOffset + 999);
      final unpaidOrders = unpaidResponse as List<dynamic>;
      unpaidOrderCount += unpaidOrders.length;
      debtTotal += unpaidOrders.fold<double>(0, (total, order) {
        final items =
            (order as Map<String, dynamic>)['cafe_order_items']
                as List<dynamic>;
        return total +
            items.fold<double>(0, (orderTotal, item) {
              final row = item as Map<String, dynamic>;
              return orderTotal +
                  (row['quantity'] as int) *
                      (row['unit_price'] as num).toDouble();
            });
      });
      if (unpaidOrders.length < 1000) break;
      unpaidOffset += unpaidOrders.length;
    }

    final recentExpenses = [...expenseRows]
      ..sort(
        (a, b) =>
            DateTime.parse(b['created_at'] as String)
                .compareTo(DateTime.parse(a['created_at'] as String)),
      );

    return _Statistics(
      paidToday: paidToday,
      expenseToday: expenseToday,
      paidOrderCount: paidOrderCount,
      debtTotal: debtTotal,
      unpaidOrderCount: unpaidOrderCount,
      dailySales: dailySales,
      dailyExpenses: dailyExpenses,
      recentExpenses: recentExpenses.take(12).map(_Expense.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadRows({
    required String table,
    required String select,
    required String dateColumn,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final response = await Supabase.instance.client
          .from(table)
          .select(select)
          .gte(dateColumn, start.toIso8601String())
          .lt(dateColumn, end.toIso8601String())
          .order(dateColumn, ascending: false)
          .range(offset, offset + 999);
      final page = (response as List<dynamic>).cast<Map<String, dynamic>>();
      rows.addAll(page);
      if (page.length < 1000) return rows;
      offset += page.length;
    }
  }

  int _dayIndex(DateTime day, DateTime start) => day.difference(start).inDays;

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Future<void> _addExpense() async {
    final result = await showDialog<_ExpenseDraft>(
      context: context,
      builder: (_) => const _AddExpenseDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _savingExpense = true);
    try {
      await Supabase.instance.client.from('cafe_expenses').insert({
        'description': result.description,
        'amount': result.amount,
        'created_by': Supabase.instance.client.auth.currentUser!.id,
      });
      if (mounted) {
        setState(() => _statistics = _loadStatistics());
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense saved')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save expense: ${error.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingExpense = false);
    }
  }

  Future<void> _refresh() {
    final nextStatistics = _loadStatistics();
    setState(() => _statistics = nextStatistics);
    return nextStatistics.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Statistics'),
    ),
    floatingActionButton: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.sizeOf(context).width < 900 ? 96 : 0,
      ),
      child: FloatingActionButton.extended(
        onPressed: _savingExpense ? null : _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_Statistics>(
        future: _statistics,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 40),
                              const SizedBox(height: 14),
                              Text(
                                'Could not load statistics',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(snapshot.error.toString()),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _refresh,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
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

          final stats = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final availableWidth =
                  (constraints.maxWidth - 40).clamp(0.0, 1100.0);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StatsHeader(stats: stats),
                          const SizedBox(height: 22),
                          _buildStatisticCards(availableWidth, stats),
                          const SizedBox(height: 22),
                          if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _WeeklyChartCard(stats: stats),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _IncomeExpenseCard(stats: stats),
                            ),
                          ],
                        )
                      else ...[
                        _WeeklyChartCard(stats: stats),
                        const SizedBox(height: 16),
                        _IncomeExpenseCard(stats: stats),
                      ],
                      const SizedBox(height: 22),
                      _ExpenseList(
                        expenses: stats.recentExpenses,
                        onAddExpense: _addExpense,
                      ),
                    ],
                  ),
                ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );

  Widget _buildStatisticCards(double availableWidth, _Statistics stats) {
    final paidCard = _StatisticCard(
      label: 'PAID SALES TODAY',
      value: _money(stats.paidToday),
      detail:
          '${stats.paidOrderCount} paid ${stats.paidOrderCount == 1 ? 'order' : 'orders'}',
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF41D99A),
    );
    final expenseCard = _StatisticCard(
      label: 'EXPENSES TODAY',
      value: _money(stats.expenseToday),
      detail: 'Recorded today',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFFFFB86B),
    );
    final netCard = _StatisticCard(
      label: 'NET TODAY',
      value: _money(stats.paidToday - stats.expenseToday),
      detail: 'Paid sales minus expenses',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFF8EA7FF),
    );
    final debtCard = _StatisticCard(
      label: 'CARRYOVERS / DEBTS',
      value: _money(stats.debtTotal),
      detail:
          '${stats.unpaidOrderCount} unpaid ${stats.unpaidOrderCount == 1 ? 'order' : 'orders'}',
      icon: Icons.history_rounded,
      color: const Color(0xFFFF8E8E),
    );

    if (availableWidth >= 960) {
      return Row(
        children: [
          Expanded(child: paidCard),
          const SizedBox(width: 14),
          Expanded(child: expenseCard),
          const SizedBox(width: 14),
          Expanded(child: netCard),
          const SizedBox(width: 14),
          Expanded(child: debtCard),
        ],
      );
    }

    if (availableWidth >= 560) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: paidCard),
              const SizedBox(width: 14),
              Expanded(child: expenseCard),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: netCard),
              const SizedBox(width: 14),
              Expanded(child: debtCard),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        paidCard,
        const SizedBox(height: 14),
        expenseCard,
        const SizedBox(height: 14),
        netCard,
        const SizedBox(height: 14),
        debtCard,
      ],
    );
  }
}

String _money(double amount) => 'KES ${amount.toStringAsFixed(0)}';

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});

  final _Statistics stats;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF18352B), Color(0xFF202934)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF365346)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUSINESS OVERVIEW',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF9FCEB8),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Your numbers, at a glance',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  '${months[now.month - 1]} ${now.day}, ${now.year} · '
                  'Net today ${_money(stats.paidToday - stats.expenseToday)}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: const Color(0xFFC2C9CE)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.insights_rounded,
            size: 52,
            color: Color(0xFF62DDA4),
          ),
        ],
      ),
    );
  }
}

class _Statistics {
  const _Statistics({
    required this.paidToday,
    required this.expenseToday,
    required this.paidOrderCount,
    required this.debtTotal,
    required this.unpaidOrderCount,
    required this.dailySales,
    required this.dailyExpenses,
    required this.recentExpenses,
  });

  final double paidToday;
  final double expenseToday;
  final int paidOrderCount;
  final double debtTotal;
  final int unpaidOrderCount;
  final List<double> dailySales;
  final List<double> dailyExpenses;
  final List<_Expense> recentExpenses;

  double get weekSales => dailySales.fold(0, (sum, value) => sum + value);
  double get weekExpenses => dailyExpenses.fold(0, (sum, value) => sum + value);
}

class _Expense {
  const _Expense({
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  factory _Expense.fromJson(Map<String, dynamic> json) => _Expense(
    description: json['description'] as String,
    amount: (json['amount'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final String description;
  final double amount;
  final DateTime createdAt;
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color, letterSpacing: .6),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFFA5ADB5)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard({required this.stats});

  final _Statistics stats;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This week', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Paid sales and expenses by day',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFFA5ADB5)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 210,
            width: double.infinity,
            child: CustomPaint(
              painter: _WeeklyBarsPainter(
                sales: stats.dailySales,
                expenses: stats.dailyExpenses,
                textDirection: Directionality.of(context),
                textStyle: Theme.of(context).textTheme.labelSmall!,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _LegendDot(color: Color(0xFF41D99A), label: 'Paid sales'),
              _LegendDot(color: Color(0xFFFFB86B), label: 'Expenses'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _WeeklyBarsPainter extends CustomPainter {
  const _WeeklyBarsPainter({
    required this.sales,
    required this.expenses,
    required this.textDirection,
    required this.textStyle,
  });

  final List<double> sales;
  final List<double> expenses;
  final TextDirection textDirection;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const bottom = 25.0;
    const top = 8.0;
    final chartHeight = size.height - bottom - top;
    final maxValue = [
      ...sales,
      ...expenses,
    ].fold<double>(1, (maxValue, value) => math.max(maxValue, value));
    final gridPaint = Paint()
      ..color = const Color(0xFF343A41)
      ..strokeWidth = 1;
    final salesPaint = Paint()..color = const Color(0xFF41D99A);
    final expensePaint = Paint()..color = const Color(0xFFFFB86B);
    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
    }
    final slotWidth = (size.width - left) / 7;
    final barWidth = math.min(13.0, slotWidth * .28);
    final today = DateTime.now();
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    for (var i = 0; i < 7; i++) {
      final centerX = left + slotWidth * (i + .5);
      final salesHeight = chartHeight * sales[i] / maxValue;
      final expenseHeight = chartHeight * expenses[i] / maxValue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - barWidth - 2,
            top + chartHeight - salesHeight,
            barWidth,
            salesHeight,
          ),
          const Radius.circular(4),
        ),
        salesPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX + 2,
            top + chartHeight - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(4),
        ),
        expensePaint,
      );
      final day = weekStart.add(Duration(days: i));
      final label = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1];
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: textDirection,
      )..layout();
      painter.paint(
        canvas,
        Offset(centerX - painter.width / 2, size.height - painter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarsPainter oldDelegate) =>
      oldDelegate.sales != sales || oldDelegate.expenses != expenses;
}

class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({required this.stats});

  final _Statistics stats;

  @override
  Widget build(BuildContext context) {
    final palette = [const Color(0xFF41D99A), const Color(0xFFFFB86B)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Money flow', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Paid sales vs expenses · 7 days',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFFA5ADB5)),
            ),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 174,
                height: 174,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: [stats.weekSales, stats.weekExpenses],
                    colors: palette,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'NET',
                          style: TextStyle(
                            color: Color(0xFFA5ADB5),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          child: Text(
                            _money(stats.weekSales - stats.weekExpenses),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _LegendValue(
              color: palette[0],
              label: 'Paid sales',
              value: _money(stats.weekSales),
            ),
            const SizedBox(height: 10),
            _LegendValue(
              color: palette[1],
              label: 'Expenses',
              value: _money(stats.weekExpenses),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = const Color(0xFF343A41)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 19;
    canvas.drawArc(rect.deflate(12), 0, math.pi * 2, false, track);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i] / total;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 19
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect.deflate(12), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _LegendValue extends StatelessWidget {
  const _LegendValue({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.expenses, required this.onAddExpense});

  final List<_Expense> expenses;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent expenses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dates and times are recorded automatically.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFFA5ADB5)),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Add expense',
                onPressed: onAddExpense,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No expenses recorded this week.'),
            )
          else
            for (final expense in expenses)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt_long_outlined),
                ),
                title: Text(expense.description),
                subtitle: Text(_formatDate(expense.createdAt)),
                trailing: Text(
                  _money(expense.amount),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime dateTime) {
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
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} · '
      '$hour:$minute';
}

class _ExpenseDraft {
  const _ExpenseDraft({required this.description, required this.amount});

  final String description;
  final double amount;
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ExpenseDraft(
        description: _description.text.trim(),
        amount: double.parse(_amount.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record an expense'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _description,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What was spent?',
                hintText: 'e.g. Taxi fare, vegetables',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter what the money was spent on'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (KES)',
                prefixText: 'KES ',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter an amount greater than zero'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('The date and time will be added automatically.'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save expense')),
    ],
  );
}
