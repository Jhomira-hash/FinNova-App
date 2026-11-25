import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  List _budgets = [];
  Map _spentByCategory = {};
  Map _limitByCategory = {};
  Map _categoryNames = {};
  double _totalMonthlyExpense = 0.0;
  List _dailyExpenses = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  @override
  void initState() {
    super.initState();
    _fetchAnalysisData();
  }

  // Semaforización: Verde (<50%), Amarillo (50%-84%), Rojo (>=85%)
  Color _getTrafficLightColor(double percentage) {
    if (percentage >= 0.85) {
      return const Color(0xFFEF4444); // Rojo
    } else if (percentage >= 0.50) {
      return const Color(0xFFF59E0B); // Amarillo
    } else {
      return const Color(0xFF10B981); // Verde
    }
  }

  Future<void> _fetchAnalysisData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final budgetsResponse = await Supabase.instance.client
          .from('presupuestos')
          .select('id, categoria_id, monto_limite, categorias(id, nombre)')
          .eq('user_id', user.id);

      final txResponse = await Supabase.instance.client
          .from('transacciones')
          .select('categoria_id, monto, fecha, tipo, categorias(nombre)')
          .eq('user_id', user.id)
          .eq('tipo', 'gasto');

      final now = DateTime.now();
      final Map spentMap = {};
      final Map limitMap = {};
      final Map namesMap = {};
      final List daysSum = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      double totalExpense = 0.0;

      for (var b in budgetsResponse) {
        final catId = b['categoria_id'];
        if (catId != null) {
          limitMap[catId] = (b['monto_limite'] as num).toDouble();
          if (b['categorias'] != null) {
            namesMap[catId] = b['categorias']['nombre'];
          }
        }
      }

      for (var tx in txResponse) {
        final fechaTx = DateTime.tryParse(tx['fecha'].toString());
        if (fechaTx != null &&
            fechaTx.month == now.month &&
            fechaTx.year == now.year) {
          final double monto = (tx['monto'] as num).toDouble();
          final catId = tx['categoria_id'];

          totalExpense += monto;

          if (catId != null) {
            spentMap[catId] = (spentMap[catId] ?? 0.0) + monto;
            if (tx['categorias'] != null) {
              namesMap[catId] = tx['categorias']['nombre'];
            }
          }

          final int dayIndex = fechaTx.weekday - 1;
          if (dayIndex >= 0 && dayIndex < 7) {
            daysSum[dayIndex] += monto;
          }
        }
      }

      if (mounted) {
        setState(() {
          _budgets = List.from(budgetsResponse);
          _spentByCategory = spentMap;
          _limitByCategory = limitMap;
          _categoryNames = namesMap;
          _totalMonthlyExpense = totalExpense;
          _dailyExpenses = daysSum;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar análisis: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCurrentMonthAbbrev() {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return months[DateTime.now().month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final List sortedEntries = _spentByCategory.entries.toList()
      ..sort((a, b) => (b.value as double).compareTo(a.value as double));

    double maxDaily = 10.0;
    for (var val in _dailyExpenses) {
      if (val > maxDaily) maxDaily = val;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Análisis mensual',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF104070)),
            onPressed: _fetchAnalysisData,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchAnalysisData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MINI DASHBOARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distribución de Gastos',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '-S/ ${_totalMonthlyExpense.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_totalMonthlyExpense <= 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Aún no tienes gastos este mes para graficar.',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: Stack(
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 32,
                                    sections: List.generate(
                                      sortedEntries.length,
                                          (i) {
                                        final entry = sortedEntries[i];
                                        final double spent =
                                        entry.value as double;
                                        final double limit =
                                        (_limitByCategory[entry.key] ??
                                            spent)
                                            .toDouble();
                                        final double usagePct = limit > 0
                                            ? (spent / limit)
                                            : 0.0;
                                        final color =
                                        _getTrafficLightColor(
                                            usagePct);

                                        return PieChartSectionData(
                                          color: color,
                                          value: spent,
                                          showTitle: false,
                                          radius: 16,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '${_getCurrentMonthAbbrev()}\n100%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: List.generate(
                                sortedEntries.length,
                                    (i) {
                                  final entry = sortedEntries[i];
                                  final catName =
                                      _categoryNames[entry.key] ??
                                          'Otros';
                                  final double spent =
                                  entry.value as double;
                                  final double limit =
                                  (_limitByCategory[entry.key] ??
                                      spent)
                                      .toDouble();
                                  final double usagePct = limit > 0
                                      ? (spent / limit)
                                      : 0.0;
                                  final int sharePct =
                                  ((spent / _totalMonthlyExpense) *
                                      100)
                                      .round();
                                  final color =
                                  _getTrafficLightColor(usagePct);

                                  return Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 6),
                                    child: _buildLegendItem(
                                        '$catName ($sharePct%)', color),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Gráfico de Barras por días
                    SizedBox(
                      height: 100,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxDaily * 1.2,
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles:
                                SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles:
                                SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles:
                                SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const days = [
                                    'L', 'M', 'M', 'J', 'V', 'S', 'D'
                                  ];
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < days.length) {
                                    return Text(days[value.toInt()],
                                        style: const TextStyle(
                                            fontSize: 12));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: List.generate(7, (index) {
                            final double dayVal =
                            (_dailyExpenses[index] as num).toDouble();
                            final double ratio =
                            maxDaily > 0 ? (dayVal / maxDaily) : 0.0;
                            final Color barColor = dayVal > 0
                                ? _getTrafficLightColor(ratio)
                                : Colors.grey.shade300;
                            return _makeBarGroup(
                              index,
                              dayVal > 0 ? dayVal : 0.2,
                              barColor,
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECCIÓN: PRESUPUESTOS ACTUALES CON SEMAFORIZACIÓN
              const Text(
                'Presupuestos actuales:',
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (_budgets.isEmpty)
                const Text('No hay presupuestos registrados.')
              else
                ..._budgets.map((b) {
                  final categoryName =
                      b['categorias']?['nombre'] ?? 'Categoría';
                  final catId = b['categoria_id'];
                  final limit = (b['monto_limite'] as num).toDouble();
                  final double spent =
                  (_spentByCategory[catId] ?? 0.0).toDouble();
                  final double percentage =
                  limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                  final double remaining = limit - spent;
                  final Color statusColor =
                  _getTrafficLightColor(percentage);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(categoryName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                                'S/ ${spent.toStringAsFixed(0)} / S/ ${limit.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: percentage >= 0.85
                                        ? statusColor
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey.shade200,
                            color: statusColor,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(percentage * 100).toInt()}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: statusColor)),
                            Text(
                                'Restan S/ ${remaining.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}