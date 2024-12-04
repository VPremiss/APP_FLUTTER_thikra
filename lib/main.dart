import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:is_lock_screen/is_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:overlay_pop_up/overlay_pop_up.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thikra_app/constants/colors.dart';
import 'package:thikra_app/objectbox.g.dart';

import 'models/reminder.dart';
import 'helpers/object_box.dart';

late ObjectBox objectbox;

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  FlutterForegroundTask.init(
    iosNotificationOptions: const IOSNotificationOptions(),
    androidNotificationOptions: AndroidNotificationOptions(
      onlyAlertOnce: true,
      playSound: false,
      visibility: NotificationVisibility.VISIBILITY_SECRET,
      channelId: 'dev.vpremiss.thikra_app',
      channelName: 'التذكير المستمر',
      enableVibration: false,
      priority: NotificationPriority.MIN,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(60000),
      autoRunOnBoot: true,
      allowWakeLock: true,
    ),
  );

  objectbox = await ObjectBox.create();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ذكرى',
      theme: ThemeData(
        useMaterial3: true,
        splashColor: ConstantColors.secondary,
        scaffoldBackgroundColor: ConstantColors.secondary,
        colorScheme: ColorScheme.fromSeed(seedColor: ConstantColors.primary),
        scrollbarTheme: ScrollbarThemeData(
          mainAxisMargin: 0.15,
          interactive: true,
          thumbColor: WidgetStateProperty.all(ConstantColors.primary),
          radius: null,
          thumbVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(6.5),
        ),
        fontFamily: 'ReadexPro',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
      ],
      locale: const Locale('ar'),
      home: const MainView(),
    );
  }
}

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final TextEditingController _inputController = TextEditingController();
  final int _inputMaximumCharacters = 400;
  bool _isServiceRunning = false;
  List<String> _reminders = [];
  int _frequencyInSeconds = 120; // * 2 minutes by default

  @override
  void initState() {
    super.initState();

    _loadReminders();
    _checkServiceStatus();
    _getRemindingFrequency();

    FlutterNativeSplash.remove();
  }

  Future<void> _loadSavedReminders() async {
    setState(() {
      _reminders = objectbox.reminderBox
          .getAll()
          .map(
            (e) => e.content,
          )
          .toList();
    });
  }

  Future<void> _saveRemindersToFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/reminders.json';
    final file = File(filePath);
    // debugPrint('Main isolate directory path: $filePath');

    try {
      await file.writeAsString(jsonEncode(_reminders));
      // debugPrint('reminders.json saved at $filePath with contents: $_reminders');
    } catch (e) {
      debugPrint('Error occurred while saving to [reminders.json] file: $e');
    }
  }

  Future<void> _addDefaultReminders() async {
    List<String> initialReminderAthkar = [
      'بسم الله.',
      'سبحان الله.',
      'الحمد لله.',
      'لا إله إلا الله.',
      'الله أكبر.',
      'لا حول ولا قوة إلا بالله.',
      'لا حول ولا قوة إلا بالله العلي العظيم.',
      'لا إله إلا الله، وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير.',
      'اللهمّ صلّ على محمّد.',
      'اللهمّ صلّ على محمّد، وعلى آل محمّد، كما صلّيت على إبراهيم، وعلى آل إبراهيم إنك حميد مجيد... اللهمّ بارك على محمّد، وعلى آل محمّد، كما باركت على إبراهيم، وعلى آل إبراهيم، إنك حميد مجيد.',
      'رضيت بالله ربّا، وبمحمّد رسولا، وبالإسلام دينا.',
      'أستغفر الله وأتوب إليه.',
      'أستغفر الله العلي العظيم الحيّ القيّوم وأتوب إليه.',
      'لا إله إلا الله العظيم الحليم، لا إله إلا الله رب العرش العظيم، لا إله إلا الله، رب السماوات ورب الأرض ربّ العرش الكريم.',
      'سبحان الله وبحمده، سبحان الله العظيم.',
      'يا مقلّب القلوب والأبصار، ثبّت قلبي على دينك.',
      'يا مقلّب القلوب والأبصار، ثبّت قلبي على دينك، وتب عليّ، إنّك أنت التّوّاب الرّحيم.',
      'ربّ اجعلني مقيم الصلاة ومن ذرّيّتي، ربنا وتقبّل دعاء.',
      'ربّنا اغفر لنا ولإخواننا الذين سبقونا بالإيمان، ولا تجعل في قلوبنا غلًّا للذين آمنوا، ربّنا إنك رؤوف رحيم.',
      'ربّنا آتنا في الدّنيا حسنة، وفي الآخرة حسنة، وقنا عذاب النار.',
      'اللهمّ أغننا بحلالك عن حرامك، واكفنا بفضلك عمّن سواك.',
      'سبّوحٌ قدّوس، ربّ الملائكة والرّوح.',
      'بسم الله الذي لا يضرّ مع اسمه شيء في الأرض ولا في السماء، وهو السميع العليم.',
      'أعوذ بكلمات الله التّامّات من شرّ ما خلق.',
      'قل هو الله أحد، الله الصّمد، لم يلد ولم يولد، ولم يكن له كفوًا أحد.',
      'ربّ اغفر لي.',
      'اللهمّ إنا نسألك العفو والعافية.',
      'اللهمّ إنا نسألك العفو والعافية، والمعافاة الدائمة، في الدنيا والآخرة.',
      'اللهمّ أنت ربّي، لا إله إلا أنت، خلقتني وأنا عبدك، وأنا على عهدك ووعدك ما استطعت، أعوذ بك من شر ما صنعت، أبوء لك بنعمتك عليّ، وأبوء بذنبي، فاغفر لي، فإنه لا يغفر الذنوب إلا أنت.',
    ];

    setState(() {
      for (String thikr in initialReminderAthkar) {
        final reminder = Reminder(content: thikr);

        objectbox.reminderBox.put(reminder);

        _reminders.add(thikr);
      }
    });

    await _saveRemindersToFile();
  }

  Future<void> _loadReminders() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    bool hasAdded = preferences.getBool('hasAddedDefaultReminders') ?? false;

    if (!hasAdded) {
      await _addDefaultReminders();
      await preferences.setBool('hasAddedDefaultReminders', true);
    }

    await _loadSavedReminders();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterForegroundTask.isRunningService;

    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  Future<void> _getRemindingFrequency() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    int seconds = preferences.getInt('frequencyInSeconds') ?? 120;

    setState(() {
      _frequencyInSeconds = seconds;
    });
  }

  void _reloadForegroundService() async {
    if (_isServiceRunning) {
      await _stopForegroundService();
      await _startForegroundService();
    }
  }

  Future<void> _saveFrequencyToFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/frequency.json';
    final file = File(filePath);

    try {
      await file.writeAsString(
        jsonEncode({'frequencyInSeconds': _frequencyInSeconds}),
      );
    } catch (e) {
      debugPrint('Error occurred while saving to [frequency.json] file: $e');
    }
  }

  String _secondsToReadableTime(int seconds) {
    if (seconds < 60) {
      return '$seconds ثانية';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60} دقيقة';
    } else {
      return '${seconds ~/ 3600} ساعة';
    }
  }

  void _setRemindingFrequency(int newFrequencyInSeconds) async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setInt('frequencyInSeconds', newFrequencyInSeconds);

    setState(() {
      _frequencyInSeconds = newFrequencyInSeconds;

      _reloadForegroundService();
    });

    await _saveFrequencyToFile();
  }

  void _showFrequencyDialog() {
    final List<int> options = [
      10, // * 10 seconds
      15, // * 15 seconds
      30, // * 30 seconds
      45, // * 45 seconds
      60, // * 1 minute
      120, // * 2 minutes
      180, // * 3 minutes
      300, // * 5 minutes
      600, // * 10 minutes
      900, // * 15 minutes
      1800, // * 30 minutes
      2700, // * 45 minutes
      3600, // * 1 hour
      7200, // * 2 hours
      10800, // * 3 hours
      14400, // * 4 hours
      18000, // * 5 hours
      21600, // * 6 hours
      28800, // * 8 hours
      36000, // * 10 hours
      43200, // * 12 hours
    ];
    int selectedFrequency = _frequencyInSeconds;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('مدة التكرار'),
              content: DropdownButton<int>(
                menuMaxHeight: 400,
                isExpanded: true,
                menuWidth: 100,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                value: selectedFrequency,
                items: options
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(_secondsToReadableTime(option)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedFrequency = value;
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    _setRemindingFrequency(selectedFrequency);

                    Navigator.pop(context);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> _requestPermissions() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    final bool overlayPermissionGranted = await OverlayPopUp.checkPermission();
    if (!overlayPermissionGranted) {
      await OverlayPopUp.requestPermission();
    }
  }

  Future<void> _startForegroundService() async {
    await _requestPermissions();

    FlutterForegroundTask.init(
      iosNotificationOptions: const IOSNotificationOptions(),
      androidNotificationOptions: AndroidNotificationOptions(
        onlyAlertOnce: true,
        playSound: false,
        visibility: NotificationVisibility.VISIBILITY_SECRET,
        channelId: 'dev.vpremiss.thikra_app',
        channelName: 'التذكير المستمر',
        enableVibration: false,
        priority: NotificationPriority.MIN,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'التذكير المستمر قيد العمل',
      notificationText: 'انقر للانتقال للتطبيق',
      callback: startCallback,
    );
  }

  void _toggleForegroundService() async {
    if (_isServiceRunning) {
      await _stopForegroundService();
    } else {
      await _startForegroundService();
    }

    setState(() {
      _isServiceRunning = !_isServiceRunning;
    });
  }

  void _editReminder(int index) async {
    final TextEditingController editInputController = TextEditingController(
      text: _reminders[index],
    );
    final editDialogResult = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل'),
          content: TextField(
            controller: editInputController,
            maxLength: _inputMaximumCharacters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                final updatedReminderContent = editInputController.text.trim();
                if (updatedReminderContent.isNotEmpty) {
                  Navigator.of(context).pop(updatedReminderContent);
                }
              },
              child: const Text('تعديل'),
            ),
          ],
        );
      },
    );

    if (editDialogResult != null &&
        editDialogResult.isNotEmpty &&
        editDialogResult != _reminders[index]) {
      setState(() {
        _reminders[index] = editDialogResult;

        final query = objectbox.reminderBox
            .query(Reminder_.content.equals(_reminders[index]))
            .build();
        final results = query.find();

        if (results.isNotEmpty) {
          final reminder = results.first;

          reminder.content = editDialogResult;

          objectbox.reminderBox.put(reminder);
        }
      });

      await _saveRemindersToFile();
    }
  }

  void _confirmReminderDeletion(int index) async {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف'),
        content: const Text('هل أنت متأكد من حذف هذه الذكرى ؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                final contentToRemove = _reminders[index];
                final query = objectbox.reminderBox
                    .query(Reminder_.content.equals(contentToRemove))
                    .build();
                final results = query.find();

                for (var reminder in results) {
                  objectbox.reminderBox.remove(reminder.id);
                }

                _reminders.removeAt(index);
              });

              await _saveRemindersToFile();

              Navigator.of(context).pop(true);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _addReminder() async {
    String reminderContent = _inputController.text.trim();

    reminderContent = reminderContent.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (reminderContent.isNotEmpty) {
      setState(() {
        final reminder = Reminder(content: reminderContent);

        objectbox.reminderBox.put(reminder);

        _reminders.add(reminderContent);
      });
      await _saveRemindersToFile();

      _inputController.clear();

      FocusScope.of(context).unfocus();
    } else {
      debugPrint('There is no string input to add.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ذكرى',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: ConstantColors.primary,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.75),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_history),
            color: Colors.white,
            onPressed: _showFrequencyDialog,
            tooltip: 'تعديل مدة التكرار',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: IconButton(
              tooltip: _isServiceRunning ? 'إيقاف' : 'تشغيل',
              icon: Icon(_isServiceRunning ? Icons.pause : Icons.play_arrow),
              color: Colors.white,
              onPressed: _toggleForegroundService,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/images/logo/base.png',
                width: 150,
                height: 150,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: _reminders.isEmpty
                    ? const SizedBox()
                    : Scrollbar(
                        child: ListView.builder(
                          itemCount: _reminders.length,
                          itemBuilder: (context, index) {
                            return Column(
                              children: [
                                InkWell(
                                  onTap: () => _editReminder(index),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 10,
                                      right: 15.0,
                                    ),
                                    title: Text(_reminders[index]),
                                    trailing: IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(Icons.highlight_remove),
                                      onPressed: () =>
                                          _confirmReminderDeletion(index),
                                    ),
                                  ),
                                ),
                                if (index < _reminders.length - 1)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: ConstantColors.secondary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 12.5,
                    bottom: 12.5,
                    left: 10.0,
                    right: 10.0,
                  ),
                  child: TextField(
                    controller: _inputController,
                    maxLength: _inputMaximumCharacters,
                    cursorOpacityAnimates: true,
                    maxLines: null,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      helperText: 'أذكار ، أدعية ، مواعيد ، واجبات ...',
                      labelText: 'أضف ذكرى جديدة من هنا ...',
                      suffixIcon: IconButton(
                        iconSize: 25,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _addReminder,
                        tooltip: 'إضافة',
                      ),
                      contentPadding: const EdgeInsets.only(
                        left: 10,
                        right: 10,
                        bottom: 10,
                      ),
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: ConstantColors.primary,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _addReminder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.setTaskHandler(RandomReminderTaskHandler());
}

class RandomReminderTaskHandler extends TaskHandler {
  final Random _random = Random();
  final List<String> _reminders = [];
  Timer? _overlayTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _startOverlayTimer();
  }

  Future<int> _getFrequencyInSeconds() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/frequency.json';
    final file = File(filePath);

    try {
      if (await file.exists()) {
        final contents = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(contents);

        return jsonMap['frequencyInSeconds'] ?? 120;
      } else {
        debugPrint('[frequency.json] file does not exist!');
        return 120;
      }
    } catch (e) {
      debugPrint('Error occurred while reading from [frequency.json] file: $e');
      return 120;
    }
  }

  Future<void> _reloadReminderContents() async {
    final directory = await getApplicationDocumentsDirectory();
    final String dirPath = directory.path;
    final file = File('$dirPath/reminders.json');

    // debugPrint('Reloading reminders from $dirPath');
    try {
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);

        _reminders.clear();
        _reminders.addAll(jsonList.cast<String>());
        // debugPrint('Reloaded reminders: $_reminders');
      } else {
        debugPrint('[reminders.json] file does not exist at $dirPath');
      }
    } catch (e) {
      debugPrint('Error occurred while reading [reminders.json] file: $e');
    }
  }

  void _estimateOverlaySize(String text) {
    double averageCharacterWidth = 45.0;
    double lineHeight = 200.0;
    double maximumWidth = 800.0;
    double minimumWidth = 300.0;
    double padding = 28.0;

    int maxCharsPerLine =
        ((maximumWidth - padding) / averageCharacterWidth).floor();
    int lines = (text.length / maxCharsPerLine).ceil();
    // print(numLines);

    double textWidth = lines < 3
        ? (text.length *
            averageCharacterWidth *
            (lines == 1
                ? 0.825
                : lines == 2
                    ? 0.625
                    : 0.85))
        : text.length * averageCharacterWidth;

    double overlayWidth = lines < 3
        ? textWidth.clamp(
            (lines == 1
                ? minimumWidth + padding + padding
                : lines == 2
                    ? 80
                    : 100),
            maximumWidth)
        : textWidth.clamp((minimumWidth - padding), maximumWidth);
    double overlayHeight = lines < 3
        ? ((lines *
                    (lineHeight *
                        (lines == 1
                            ? 1.2
                            : lines == 2
                                ? 0.65
                                : 1)))
                .clamp(40, 1000.0) +
            padding)
        : (lines *
                (lineHeight /
                    (lines == 3
                        ? 1.75
                        : lines == 4
                            ? 2.25
                            : lines <= 6
                                ? 2.75
                                : lines <= 11
                                    ? 3.2
                                    : lines <= 20
                                        ? 3.5
                                        : 3.75)))
            .clamp(0.0, 1000.0);

    OverlayPopUp.showOverlay(
      height: overlayHeight.toInt(),
      width: overlayWidth.toInt(),
      backgroundBehavior: OverlayFlag.focusable,
      isDraggable: true,
    );

    OverlayPopUp.sendToOverlay(text);
  }

  Future<void> _startOverlayTimer() async {
    final frequencyInSeconds = await _getFrequencyInSeconds();

    _overlayTimer = Timer.periodic(
      Duration(seconds: frequencyInSeconds),
      (timer) async {
        final bool? isLocked = await isLockScreen();

        if (isLocked == false) {
          await _reloadReminderContents();

          if (_reminders.isNotEmpty) {
            final reminder = _reminders[_random.nextInt(_reminders.length)];
            _estimateOverlaySize(reminder);
            // debugPrint('Shared reminder: $reminder');
          } else {
            debugPrint('No reminders available...');
          }
        } else {
          debugPrint('Screen is locked. Skipping overlay.');
        }
      },
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // ...
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _overlayTimer?.cancel();

    await OverlayPopUp.closeOverlay();
  }
}

@pragma("vm:entry-point")
void overlayPopUp() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      color: Colors.transparent,
      child: OverlayWidget(),
    ),
  ));
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;
  Timer? _closingTimer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController!.forward();

    OverlayPopUp.dataListener?.listen((data) {
      if (mounted) {
        _restartAnimations();
      }
    });

    _startClosingTimer();
  }

  void _restartAnimations() {
    _isClosing = false;

    _animationController!.reset();
    _animationController!.forward();

    _closingTimer?.cancel();
    _startClosingTimer();
  }

  void _startClosingTimer() {
    _closingTimer = Timer(const Duration(seconds: 5), () {
      _closeOverlay();
    });
  }

  void _closeOverlay() {
    if (!_isClosing) {
      _isClosing = true;

      _animationController!.reverse().then((value) {
        OverlayPopUp.closeOverlay();
      });
    }
  }

  @override
  void dispose() {
    _closingTimer?.cancel();
    _animationController!.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _closingTimer?.cancel();
        _closeOverlay();
      },
      child: StreamBuilder<dynamic>(
        stream: OverlayPopUp.dataListener,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            String text = snapshot.data.toString();

            return Center(
              child: FadeTransition(
                opacity: _fadeAnimation!,
                child: ScaleTransition(
                  scale: _scaleAnimation!,
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(107, 54, 89, 99),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      text,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      softWrap: text.trim().split(' ').length > 2,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16.0,
                      ),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
