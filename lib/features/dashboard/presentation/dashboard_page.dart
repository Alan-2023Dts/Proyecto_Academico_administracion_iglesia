import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../announcements/presentation/announcements_page.dart';
import '../../attendance/presentation/attendance_page.dart';
import '../../events/presentation/events_page.dart';
import '../../finance/presentation/finance_page.dart';
import '../../members/presentation/members_page.dart';
import '../../ministries/presentation/ministries_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  Future<void> _signOut() => Supabase.instance.client.auth.signOut();

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OverviewTab(),
      const MembersPage(),
      const EventsPage(),
      const _MoreModulesTab(
        title: 'Más módulos',
        icon: Icons.grid_view_outlined,
      ),
    ];

    final destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Inicio'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: Text('Miembros'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.event_outlined),
        selectedIcon: Icon(Icons.event),
        label: Text('Eventos'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view),
        label: Text('Más'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iglesia'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 800;
          final content = IndexedStack(index: _currentIndex, children: pages);
          if (!isTablet) return content;
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                labelType: NavigationRailLabelType.all,
                destinations: destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Miembros',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: 'Eventos',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: 'Más',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _repository = DashboardRepository(Supabase.instance.client);
  late Future<DashboardMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _repository.load();
  }

  void _refresh() {
    final future = _repository.load();
    setState(() {
      _metricsFuture = future;
    });
  }

  Future<void> _refreshAndWait() async {
    _refresh();
    await _metricsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DashboardError(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }
        final metrics = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refreshAndWait,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Resumen de hoy',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Una vista rápida de la actividad de tu iglesia.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 560 ? 4 : 2;
                  final cardWidth =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Miembros activos',
                          value: '${metrics.activeMembers}',
                          icon: Icons.groups_outlined,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Próximos eventos',
                          value: '${metrics.upcomingEvents}',
                          icon: Icons.event_available_outlined,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Asistencias del mes',
                          value: '${metrics.attendanceThisMonth}',
                          icon: Icons.fact_check_outlined,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Ministerios activos',
                          value: '${metrics.activeMinistries}',
                          icon: Icons.volunteer_activism_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (metrics.canViewFinance) ...[
                const SizedBox(height: 12),
                _FinancialSummaryCard(amount: metrics.currentMonthIncome),
              ],
              const SizedBox(height: 24),
              _AttendanceChart(data: metrics.attendanceTrend),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Los indicadores se actualizan desde Supabase. '
                    'Usa el gesto de refrescar para consultar los últimos datos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final double amount;

  const _FinancialSummaryCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: const Text('Ingresos registrados este mes'),
        subtitle: Text(
          NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(amount),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  final List<MonthlyAttendance> data;

  const _AttendanceChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxValue = data.fold<double>(
      1,
      (max, item) => item.count > max ? item.count.toDouble() : max,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asistencia de los últimos 6 meses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxValue + 1,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            DateFormat('MMM', 'es').format(data[index].month),
                            style: Theme.of(context).textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < data.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: data[index].count.toDouble(),
                            color: color,
                            width: 18,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el dashboard',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreModulesTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const _MoreModulesTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Accede a las herramientas de gestión de tu comunidad.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendancePage()),
                );
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Control de asistencia'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MinistriesPage()),
                );
              },
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Ministerios'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinancePage()),
                );
              },
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Finanzas'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
                );
              },
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Comunicados'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsPage()),
                );
              },
              icon: const Icon(Icons.description_outlined),
              label: const Text('Reportes PDF'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configuración institucional'),
            ),
          ],
        ),
      ),
    );
  }
}
