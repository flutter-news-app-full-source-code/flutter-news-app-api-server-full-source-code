import 'package:json_annotation/json_annotation.dart';

/// The server environment that the notification is from.
@JsonEnum(fieldRename: FieldRename.pascal)
enum AppleEnvironment {
  /// The sandbox environment.
  sandbox,

  /// The production environment.
  production,
}
