import 'package:objectbox/objectbox.dart';

@Entity()
class Reminder {
  @Id()
  int id = 0;

  String content;

  Reminder({required this.content});
}
