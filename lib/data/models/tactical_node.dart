class TacticalNode {
  final String shortName;
  final String longName;
  final String hexId;
  final String hardware;
  final String role;
  final double batteryLevel;
  final double voltage;
  final double snr;
  final int? rssi;   
  final int lastHeardUnix; 
  final String lastHeardText;
  final bool isLocal;

  TacticalNode({
    required this.shortName,
    required this.longName,
    required this.hexId,
    required this.hardware,
    required this.role,
    required this.batteryLevel,
    required this.voltage,
    required this.snr,
    this.rssi,
    required this.lastHeardUnix,
    required this.lastHeardText,
    required this.isLocal,
  });

  // 👉 THIS IS THE MISSING METHOD THAT SOLVES THE 9 ERRORS
  TacticalNode copyWith({
    String? shortName, 
    String? longName, 
    String? hardware, 
    String? role,
    double? batteryLevel, 
    double? voltage, 
    double? snr, 
    int? rssi,
    int? lastHeardUnix, 
    String? lastHeardText, 
    bool? isLocal,
  }) {
    return TacticalNode(
      shortName: shortName ?? this.shortName,
      longName: longName ?? this.longName,
      hexId: this.hexId, // Hex ID never changes, so it doesn't need to be passed
      hardware: hardware ?? this.hardware,
      role: role ?? this.role,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      voltage: voltage ?? this.voltage,
      snr: snr ?? this.snr,
      rssi: rssi ?? this.rssi,
      lastHeardUnix: lastHeardUnix ?? this.lastHeardUnix,
      lastHeardText: lastHeardText ?? this.lastHeardText,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}