class AthenaKinematicStatus {
  AthenaKinematicStatus({
    required this.homed,
    required this.offset,
    required this.position,
    required this.timestamp,
  });

  final bool homed;
  final double offset;
  final double position;
  final int timestamp;

  factory AthenaKinematicStatus.fromJson(Map<String, dynamic> json) {
    return AthenaKinematicStatus(
      homed: json['homed'] == true,
      offset:
          (json['offset'] is num) ? (json['offset'] as num).toDouble() : 0.0,
      position: (json['position'] is num)
          ? (json['position'] as num).toDouble()
          : 0.0,
      timestamp: (json['timestamp'] is int)
          ? (json['timestamp'] as int)
          : (json['timestamp'] is num)
              ? (json['timestamp'] as num).toInt()
              : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'homed': homed,
        'offset': offset,
        'position': position,
        'timestamp': timestamp,
      };
}
