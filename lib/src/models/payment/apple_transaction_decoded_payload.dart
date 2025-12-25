import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'apple_transaction_decoded_payload.g.dart';

/// {@template apple_transaction_decoded_payload}
/// Represents the decoded payload of a `signedTransactionInfo` JWS from Apple.
/// {@endtemplate}
@immutable
@JsonSerializable(explicitToJson: true, includeIfNull: true, checked: true)
class AppleTransactionDecodedPayload extends Equatable {
  /// {@macro apple_transaction_decoded_payload}
  const AppleTransactionDecodedPayload({
    required this.originalTransactionId,
    required this.transactionId,
    required this.productId,
    required this.purchaseDate,
    required this.originalPurchaseDate,
    required this.expiresDate,
    required this.type,
    required this.inAppOwnershipType,
  });

  /// Creates an [AppleTransactionDecodedPayload] from JSON data.
  factory AppleTransactionDecodedPayload.fromJson(Map<String, dynamic> json) =>
      _$AppleTransactionDecodedPayloadFromJson(json);

  /// The original transaction identifier of a purchase.
  final String originalTransactionId;

  /// The unique identifier for a transaction.
  final String transactionId;

  /// The product identifier of the in-app purchase.
  final String productId;

  /// The time of the charge.
  @JsonKey(fromJson: _dateTimeFromMilliseconds, toJson: _dateTimeToMilliseconds)
  final DateTime purchaseDate;

  /// The time of the original charge.
  @JsonKey(fromJson: _dateTimeFromMilliseconds, toJson: _dateTimeToMilliseconds)
  final DateTime originalPurchaseDate;

  /// The expiration date for the subscription.
  @JsonKey(fromJson: _dateTimeFromMilliseconds, toJson: _dateTimeToMilliseconds)
  final DateTime expiresDate;

  /// The type of the in-app purchase.
  final String type;

  /// The ownership type for an in-app purchase.
  final String inAppOwnershipType;

  /// Converts this instance to JSON data.
  Map<String, dynamic> toJson() => _$AppleTransactionDecodedPayloadToJson(this);

  @override
  List<Object?> get props => [
    originalTransactionId,
    transactionId,
    productId,
    purchaseDate,
    originalPurchaseDate,
    expiresDate,
    type,
    inAppOwnershipType,
  ];
}

DateTime _dateTimeFromMilliseconds(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms);

int _dateTimeToMilliseconds(DateTime dt) => dt.millisecondsSinceEpoch;
