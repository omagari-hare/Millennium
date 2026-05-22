import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:convert';
import 'dart:math';
import 'main.dart'; // Добавлен импорт для возврата на экран входа

// Глобальные переменные для настроек
final ValueNotifier<String> appCurrency = ValueNotifier<String>('₸');
final ValueNotifier<ThemeMode> appTheme = ValueNotifier<ThemeMode>(
  ThemeMode.light,
);
final ValueNotifier<String?> userAvatar = ValueNotifier<String?>(null);
final ValueNotifier<bool> notificationsEnabled = ValueNotifier<bool>(
  true,
); // Настройка уведомлений

// Настройка системных уведомлений через Awesome Notifications
Future<void> initNotifications() async {
  await AwesomeNotifications().initialize(
    null, // Иконка по умолчанию (из res/drawable)
    [
      NotificationChannel(
        channelKey: 'task_reminders',
        channelName: 'Напоминания о задачах',
        channelDescription: 'Уведомления для запланированных задач',
        defaultColor: Colors.black,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
    ],
  );
}

// Планирование уведомления на телефон (работает даже в фоне!)
void scheduleSystemNotification(String title, String date, String time) {
  if (!notificationsEnabled.value)
    return; // Проверяем, включены ли они в настройках

  try {
    final dateParts = date.split('.');
    final timeParts = time.split(':');
    final taskDate = DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    final difference = taskDate.difference(DateTime.now());
    if (difference.isNegative) return; // Время уже прошло

    // Запланированное уведомление на точное время
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random().nextInt(100000),
        channelKey: 'task_reminders',
        title: '⏰ Пора выполнить задачу!',
        body: title,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: taskDate.year,
        month: taskDate.month,
        day: taskDate.day,
        hour: taskDate.hour,
        minute: taskDate.minute,
        second: 0,
        allowWhileIdle: true, // Важно для срабатывания в спящем режиме
      ),
    );

    // Мгновенное подтверждение (что таймер установлен)
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: Random().nextInt(100000),
        channelKey: 'task_reminders',
        title: 'Напоминание установлено',
        body: 'Напомним о задаче "$title" в $time',
      ),
    );
  } catch (e) {
    print("Ошибка системных уведомлений: $e");
  }
}

const double EXCHANGE_RATE_USD_KZT = 480.0;

// Цветовая палитра для категорий финансов
final Map<String, Color> categoryColors = {
  'Еда': Colors.orange,
  'Транспорт': Colors.blue,
  'Развлечения': Colors.purple,
  'ЖКХ': Colors.red,
  'Подписки': Colors.teal,
  'Одежда': Colors.pink,
  'Разное': Colors.grey,
};

double convertCurrency(double amount, String fromCurrency, String toCurrency) {
  if (fromCurrency == toCurrency) return amount;
  if (fromCurrency == '\$' && toCurrency == '₸')
    return amount * EXCHANGE_RATE_USD_KZT;
  if (fromCurrency == '₸' && toCurrency == '\$')
    return amount / EXCHANGE_RATE_USD_KZT;
  return amount;
}

String formatAmount(double amount, String currency) {
  if (currency == '\$') return amount.toStringAsFixed(2);
  return amount.toStringAsFixed(0);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    initNotifications(); // Инициализация при старте
    _loadSettingsFromCloud();
  }

  Future<void> _loadSettingsFromCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();

    // Загружаем статус уведомлений из памяти телефона
    final notifs = prefs.getBool('notificationsEnabled');
    if (notifs != null) notificationsEnabled.value = notifs;

    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data['currency'] != null) appCurrency.value = data['currency'];
          if (data['theme'] != null)
            appTheme.value = data['theme'] == 'dark'
                ? ThemeMode.dark
                : ThemeMode.light;
          if (data['avatar'] != null) userAvatar.value = data['avatar'];
        }
      } catch (e) {
        print("Ошибка загрузки настроек: $e");
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showAddBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const HubTab(),
      const FinanceTab(),
      const TasksTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _screens[_selectedIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBottomSheet(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        shape: const CircleBorder(), // Делаем кнопку идеально круглой под вырез
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Theme.of(context).cardColor,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.space_dashboard_rounded, 'Хаб', 0),
              _buildNavItem(Icons.account_balance_wallet_rounded, 'Финансы', 1),
              const SizedBox(width: 40),
              _buildNavItem(Icons.check_circle_outline_rounded, 'Задачи', 2),
              _buildNavItem(Icons.person_outline_rounded, 'Профиль', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.38);
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 1: ХАБ
// ==========================================
class HubTab extends StatelessWidget {
  const HubTab({Key? key}) : super(key: key);

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Привет, ${FirebaseAuth.instance.currentUser?.displayName ?? 'Пользователь'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      'Твоя сводка',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: userAvatar,
                  builder: (context, avatarBase64, child) {
                    return CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.1),
                      backgroundImage: avatarBase64 != null
                          ? MemoryImage(base64Decode(avatarBase64))
                          : null,
                      child: avatarBase64 == null
                          ? Icon(
                              Icons.notifications_none,
                              color: Theme.of(context).colorScheme.onSurface,
                            )
                          : null,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('transactions')
                  .snapshots(),
              builder: (context, snapshot) {
                return ValueListenableBuilder<String>(
                  valueListenable: appCurrency,
                  builder: (context, currentCurrency, child) {
                    double totalIncome = 0;
                    double totalExpense = 0;

                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rawAmount = (data['amount'] as num).toDouble();
                        final docCurrency = data['currency'] ?? '₸';
                        final amount = convertCurrency(
                          rawAmount,
                          docCurrency,
                          currentCurrency,
                        );

                        if (data['type'] == 'Доход')
                          totalIncome += amount;
                        else
                          totalExpense += amount;
                      }
                    }

                    final balance = totalIncome - totalExpense;
                    double progress = totalIncome == 0
                        ? 0
                        : (totalExpense / totalIncome);
                    if (progress > 1) progress = 1;

                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : Colors.black,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Общий баланс',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${balance >= 0 ? '' : '-'}${formatAmount(balance.abs(), currentCurrency)} $currentCurrency',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Потрачено',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${formatAmount(totalExpense, currentCurrency)} $currentCurrency',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),
            Text(
              'Задачи на сегодня',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('tasks')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'На сегодня задач нет! Отдыхай 🎉',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  );
                }

                final now = DateTime.now();
                final todayStr =
                    "${now.day}.${now.month.toString().padLeft(2, '0')}.${now.year}";

                final todayDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['dueDate'] == todayStr;
                }).toList();

                if (todayDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'На сегодня задач нет! Отдыхай 🎉',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: todayDocs.map((doc) {
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    return TaskItem(
                      taskId: doc.id,
                      title: data['title'] ?? 'Без названия',
                      isDone: data['isDone'] ?? false,
                      dueDate: data['dueDate'],
                      dueTime: data['dueTime'],
                      priority: data['priority'],
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddBottomSheet(
                            editDocId: doc.id,
                            initialType: 'Задача',
                            initialData: data,
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Виджет отдельной задачи
class TaskItem extends StatelessWidget {
  final String taskId;
  final String title;
  final bool isDone;
  final String? dueDate;
  final String? dueTime;
  final String? priority;
  final VoidCallback? onTap;

  const TaskItem({
    Key? key,
    required this.taskId,
    required this.title,
    required this.isDone,
    this.dueDate,
    this.dueTime,
    this.priority,
    this.onTap,
  }) : super(key: key);

  void _toggleTask(bool? value) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(taskId)
        .update({'isDone': value});
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(taskId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (direction) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('tasks')
              .doc(taskId)
              .delete();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          leading: Checkbox(
            value: isDone,
            onChanged: _toggleTask,
            activeColor: Theme.of(context).colorScheme.primary,
            checkColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: (dueDate != null || dueTime != null || priority != null)
              ? Text(
                  '${dueDate != null ? 'До: $dueDate' : ''} ${dueTime != null ? dueTime : ''} ${dueDate != null && priority != null ? '•' : ''} ${priority != null ? priority : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 2: ФИНАНСЫ (С ДИНАМИЧНЫМ ГРАФИКОМ)
// ==========================================
class FinanceTab extends StatefulWidget {
  const FinanceTab({Key? key}) : super(key: key);

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedPeriod = 'Месяц';

  bool _isDateInPeriod(Timestamp? timestamp) {
    if (timestamp == null) return true;
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (_selectedPeriod == 'День') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } else if (_selectedPeriod == 'Неделя') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      return date.isAfter(start) || date.isAtSameMomentAs(start);
    } else if (_selectedPeriod == 'Месяц') {
      return date.year == now.year && date.month == now.month;
    } else if (_selectedPeriod == 'Год') {
      return date.year == now.year;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
              top: 24,
              right: 24,
              bottom: 16,
            ),
            child: Text(
              'Финансы',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildPeriodTab('День'),
                _buildPeriodTab('Неделя'),
                _buildPeriodTab('Месяц'),
                _buildPeriodTab('Год'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('transactions')
                .snapshots(),
            builder: (context, snapshot) {
              return ValueListenableBuilder<String>(
                valueListenable: appCurrency,
                builder: (context, currentCurrency, child) {
                  double totalExpense = 0;
                  Map<String, double> categoryTotals = {};

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['type'] == 'Расход' &&
                          _isDateInPeriod(data['createdAt'] as Timestamp?)) {
                        final rawAmount = (data['amount'] as num).toDouble();
                        final docCurrency = data['currency'] ?? '₸';
                        final category = data['category'] ?? 'Разное';

                        final convertedAmount = convertCurrency(
                          rawAmount,
                          docCurrency,
                          currentCurrency,
                        );
                        totalExpense += convertedAmount;

                        categoryTotals[category] =
                            (categoryTotals[category] ?? 0) + convertedAmount;
                      }
                    }
                  }

                  return Center(
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: DonutChartPainter(
                          context,
                          categoryTotals,
                          totalExpense,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Расходы',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${formatAmount(totalExpense, currentCurrency)} $currentCurrency',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'История операций',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('transactions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Нет транзакций',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  );
                }

                return ValueListenableBuilder<String>(
                  valueListenable: appCurrency,
                  builder: (context, currentCurrency, child) {
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _isDateInPeriod(data['createdAt'] as Timestamp?);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(
                          'Нет транзакций за этот период',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: filteredDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final isIncome = data['type'] == 'Доход';
                        final rawAmount = (data['amount'] as num).toDouble();
                        final docCurrency = data['currency'] ?? '₸';
                        final category = data['category'] ?? 'Разное';
                        final docId = doc.id;

                        final amount = convertCurrency(
                          rawAmount,
                          docCurrency,
                          currentCurrency,
                        );
                        final circleColor = isIncome
                            ? Colors.green
                            : (categoryColors[category] ?? Colors.grey);

                        return Dismissible(
                          key: Key(docId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) {
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('transactions')
                                .doc(docId)
                                .delete();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => AddBottomSheet(
                                    editDocId: docId,
                                    initialType: isIncome ? 'Доход' : 'Расход',
                                    initialData: data,
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: circleColor.withOpacity(0.1),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: circleColor,
                                ),
                              ),
                              title: Text(
                                category,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                data['date'] ?? 'Сегодня',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              trailing: Text(
                                '${isIncome ? '+' : '-'}${formatAmount(amount, currentCurrency)} $currentCurrency',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isIncome
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String text) {
    final isActive = _selectedPeriod == text;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = text),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.1),
                ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final BuildContext context;
  final Map<String, double> categoryTotals;
  final double total;

  DonutChartPainter(this.context, this.categoryTotals, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;

    paint.color = Theme.of(context).colorScheme.onSurface.withOpacity(0.1);
    canvas.drawCircle(center, radius, paint);

    if (total > 0 && categoryTotals.isNotEmpty) {
      double startAngle = -pi / 2;

      categoryTotals.forEach((category, amount) {
        final sweepAngle = (amount / total) * 2 * pi;
        paint.color = categoryColors[category] ?? Colors.grey;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        startAngle += sweepAngle;
      });
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// ВКЛАДКА 3: ЗАДАЧИ
// ==========================================
class TasksTab extends StatefulWidget {
  const TasksTab({Key? key}) : super(key: key);

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedFilter = 'Все';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
              top: 24,
              right: 24,
              bottom: 16,
            ),
            child: Text(
              'Все задачи',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTaskFilter('Все'),
                _buildTaskFilter('В процессе'),
                _buildTaskFilter('Готово'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('tasks')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Нет задач',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isDone = data['isDone'] ?? false;
                  if (_selectedFilter == 'В процессе') return !isDone;
                  if (_selectedFilter == 'Готово') return isDone;
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'Здесь пока пусто',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: filteredDocs.map((doc) {
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    return TaskItem(
                      taskId: doc.id,
                      title: data['title'] ?? 'Без названия',
                      isDone: data['isDone'] ?? false,
                      dueDate: data['dueDate'],
                      dueTime: data['dueTime'],
                      priority: data['priority'],
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddBottomSheet(
                            editDocId: doc.id,
                            initialType: 'Задача',
                            initialData: data,
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskFilter(String text) {
    final isActive = _selectedFilter == text;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = text),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ВКЛАДКА 4: ПРОФИЛЬ
// ==========================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Future<void> _pickAndSaveAvatar() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 50,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);

        userAvatar.value = base64String;

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'avatar': base64String,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print("Ошибка при выборе фото: $e");
    }
  }

  Future<void> _editName(BuildContext context, User user) async {
    final TextEditingController nameController = TextEditingController(
      text: user.displayName,
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Изменить имя',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Введите новое имя',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await user.updateDisplayName(nameController.text.trim());
                await user.reload();
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    setState(() {});
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Уведомления',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: ValueListenableBuilder<bool>(
          valueListenable: notificationsEnabled,
          builder: (context, isEnabled, child) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: Theme.of(context).colorScheme.primary,
              title: Text(
                'Разрешить напоминания',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Системные пуш-уведомления для задач',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              value: isEnabled,
              onChanged: (value) async {
                notificationsEnabled.value = value;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notificationsEnabled', value);

                if (value) {
                  AwesomeNotifications().isNotificationAllowed().then((
                    isAllowed,
                  ) {
                    if (!isAllowed) {
                      AwesomeNotifications()
                          .requestPermissionToSendNotifications();
                    }
                  });
                }
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Закрыть',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Пользователь';
    final userEmail = user?.email ?? 'Почта скрыта';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            ValueListenableBuilder<String?>(
              valueListenable: userAvatar,
              builder: (context, avatarBase64, child) {
                return GestureDetector(
                  onTap: _pickAndSaveAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage: avatarBase64 != null
                            ? MemoryImage(base64Decode(avatarBase64))
                            : null,
                        child: avatarBase64 == null
                            ? Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 40,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              userEmail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 40),

            _buildProfileMenuItem(
              context,
              Icons.person_outline,
              'Мой аккаунт',
              onTap: () {
                if (user != null) _editName(context, user);
              },
            ),
            _buildProfileMenuItem(
              context,
              Icons.notifications_none,
              'Уведомления',
              onTap: () {
                _showNotificationSettings(context);
              },
            ),

            // ТЕМНАЯ ТЕМА (ПЕРЕКЛЮЧАТЕЛЬ)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.dark_mode_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  'Тёмная тема',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: ValueListenableBuilder<ThemeMode>(
                  valueListenable: appTheme,
                  builder: (context, theme, child) {
                    return Switch(
                      value: theme == ThemeMode.dark,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) async {
                        appTheme.value = value
                            ? ThemeMode.dark
                            : ThemeMode.light;
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .set({
                                'theme': value ? 'dark' : 'light',
                              }, SetOptions(merge: true));
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // ВЫБОР ВАЛЮТЫ
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attach_money,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  'Валюта',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: ValueListenableBuilder<String>(
                  valueListenable: appCurrency,
                  builder: (context, currency, child) {
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currency,
                        dropdownColor: Theme.of(context).cardColor,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '₸',
                            child: Text(
                              'Тенге (₸)',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: '\$',
                            child: Text(
                              'Доллар (\$)',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            appCurrency.value = value;
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .set({
                                    'currency': value,
                                  }, SetOptions(merge: true));
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  // Возвращаем на экран входа и полностью очищаем историю экранов
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ==========================================
// BOTTOM SHEET (МЕНЮ ДОБАВЛЕНИЯ И РЕДАКТИРОВАНИЯ)
// ==========================================
class AddBottomSheet extends StatefulWidget {
  final String? editDocId;
  final String? initialType;
  final Map<String, dynamic>? initialData;

  const AddBottomSheet({
    Key? key,
    this.editDocId,
    this.initialType,
    this.initialData,
  }) : super(key: key);

  @override
  State<AddBottomSheet> createState() => _AddBottomSheetState();
}

class _AddBottomSheetState extends State<AddBottomSheet> {
  late String _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedDate;
  String? _selectedTime;
  DateTime? _pickedDateTime; // Сохраняем реальную дату для Firebase Timestamp
  String _selectedPriority = 'Средний';
  late String _selectedCategory;

  final List<String> _expenseCategories = [
    'Еда',
    'Транспорт',
    'Развлечения',
    'ЖКХ',
    'Подписки',
    'Одежда',
    'Разное',
  ];
  final List<String> _incomeCategories = [
    'Зарплата',
    'Перевод',
    'Кешбэк',
    'Инвестиции',
    'Разное',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? 'Расход';

    if (widget.initialData != null) {
      if (_selectedType == 'Задача') {
        _titleController.text = widget.initialData!['title'] ?? '';
        _selectedDate = widget.initialData!['dueDate'];
        _selectedTime = widget.initialData!['dueTime'];
        _selectedPriority = widget.initialData!['priority'] ?? 'Средний';
        _selectedCategory = 'Разное';
      } else {
        _amountController.text = widget.initialData!['amount'].toString();
        _selectedCategory = widget.initialData!['category'] ?? 'Разное';
        final date = widget.initialData!['date'];
        _selectedDate = date == 'Сегодня' ? null : date;
      }
    } else {
      _selectedCategory = _selectedType == 'Доход'
          ? _incomeCategories[0]
          : _expenseCategories[0];
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime;
      if (_selectedType == 'Задача') {
        pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              child: child!,
            );
          },
        );
      }

      setState(() {
        _selectedDate =
            "${pickedDate.day}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}";
        if (pickedTime != null) {
          _selectedTime =
              "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
          _pickedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        } else {
          _pickedDateTime = pickedDate;
        }
      });
    }
  }

  Future<void> _saveToDatabase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      if (_selectedType == 'Задача') {
        if (_titleController.text.isEmpty) return;
        final taskData = {
          'title': _titleController.text,
          'isDone': widget.initialData?['isDone'] ?? false,
          'dueDate': _selectedDate,
          'dueTime': _selectedTime,
          'priority': _selectedPriority,
          if (widget.editDocId == null)
            'createdAt': _pickedDateTime != null
                ? Timestamp.fromDate(_pickedDateTime!)
                : FieldValue.serverTimestamp(),
          if (widget.editDocId != null && _pickedDateTime != null)
            'createdAt': Timestamp.fromDate(_pickedDateTime!),
        };

        if (widget.editDocId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('tasks')
              .doc(widget.editDocId)
              .update(taskData);
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('tasks')
              .add(taskData);
        }

        // Запуск планировщика системного уведомления
        if (_selectedDate != null && _selectedTime != null) {
          scheduleSystemNotification(
            _titleController.text,
            _selectedDate!,
            _selectedTime!,
          );
        }
      } else {
        if (_amountController.text.isEmpty) return;
        double amount = double.parse(
          _amountController.text.replaceAll(',', '.'),
        );

        final transData = {
          'amount': amount,
          'type': _selectedType,
          'category': _selectedCategory,
          'date': _selectedDate ?? "Сегодня",
          if (widget.editDocId == null) 'currency': appCurrency.value,
          if (widget.editDocId == null)
            'createdAt': _pickedDateTime != null
                ? Timestamp.fromDate(_pickedDateTime!)
                : FieldValue.serverTimestamp(),
          if (widget.editDocId != null && _pickedDateTime != null)
            'createdAt': Timestamp.fromDate(_pickedDateTime!),
        };

        if (widget.editDocId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('transactions')
              .doc(widget.editDocId)
              .update(transData);
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('transactions')
              .add(transData);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("Ошибка при сохранении: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Расход', 'Доход', 'Задача'].map((type) {
              final isSelected = _selectedType == type;
              return GestureDetector(
                onTap: widget.editDocId != null
                    ? null
                    : () {
                        setState(() {
                          _selectedType = type;
                          _selectedCategory = type == 'Доход'
                              ? _incomeCategories[0]
                              : _expenseCategories[0];
                        });
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          if (_selectedType == 'Задача') ...[
            TextField(
              controller: _titleController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Что нужно сделать?',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.4),
                ),
                border: const UnderlineInputBorder(),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDateTime(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? '$_selectedDate ${_selectedTime ?? ''}'
                                  : 'Время и Дата',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPriority,
                        dropdownColor: Theme.of(context).cardColor,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: ['Низкий', 'Средний', 'Высокий'].map((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) =>
                            setState(() => _selectedPriority = newValue!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            ValueListenableBuilder<String>(
              valueListenable: appCurrency,
              builder: (context, currency, child) {
                return TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    prefixText: '$currency ',
                    prefixStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    border: InputBorder.none,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDateTime(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate ?? 'Сегодня',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        dropdownColor: Theme.of(context).cardColor,
                        isExpanded: true,
                        icon: Icon(
                          Icons.category_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items:
                            (_selectedType == 'Расход'
                                    ? _expenseCategories
                                    : _incomeCategories)
                                .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                        onChanged: (newValue) =>
                            setState(() => _selectedCategory = newValue!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saveToDatabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
