import 'package:thikra_app/models/reminder.dart';
import 'package:thikra_app/objectbox.g.dart';

class ObjectBox {
  late final Store store;
  late final Box<Reminder> reminderBox;

  ObjectBox._create(this.store) {
    reminderBox = Box<Reminder>(store);
  }

  static Future<ObjectBox> create() async {
    final store = await openStore();
    return ObjectBox._create(store);
  }
}
