class TacticalNode {
  final String shortName;
  final String longName;
  final String hexId;
  final String hardware;
  final String role;
  final double batteryLevel;
  final double voltage;
  final double? snr;
  final int? rssi;
  final String lastHeard;
  final bool isLocal; // Is this OUR node (olive green) or an ALLY (dark green)?

  TacticalNode({
    required this.shortName,
    required this.longName,
    required this.hexId,
    required this.hardware,
    required this.role,
    required this.batteryLevel,
    required this.voltage,
    this.snr,
    this.rssi,
    required this.lastHeard,
    required this.isLocal,
  });
}