/// An explicitly shared chat position, never a live device-location feed.
class SharedLocation {
  final String messageId;
  final double latitude;
  final double longitude;
  final DateTime sharedAt;

  const SharedLocation({
    required this.messageId,
    required this.latitude,
    required this.longitude,
    required this.sharedAt,
  });
}
