import 'package:ecs_ai/core/utils/id_generator.dart';

class IdeNotification {
  IdeNotification(this.message, {this.type = 'error'});
  final String id = IdGenerator.next('notif_');
  final String message;
  final String type;
}
