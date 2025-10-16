import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlot {
  final String slotId;
  final String providerId;
  final DateTime date;
  final String startTime; // Format: "09:00"
  final String endTime; // Format: "10:00"
  final bool isAvailable;
  final String? bookingId; // If booked, this will have the booking ID
  final double? price;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeSlot({
    required this.slotId,
    required this.providerId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    this.bookingId,
    this.price,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TimeSlot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TimeSlot(
      slotId: doc.id,
      providerId: data['providerId'] ?? '',
      date: data['date'] is Timestamp 
          ? (data['date'] as Timestamp).toDate()
          : DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      bookingId: data['bookingId'],
      price: data['price']?.toDouble(),
      notes: data['notes'],
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(data['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory TimeSlot.fromMap(Map<String, dynamic> data, {String? id}) {
    return TimeSlot(
      slotId: id ?? data['slotId'] ?? '',
      providerId: data['providerId'] ?? '',
      date: data['date'] is Timestamp 
          ? (data['date'] as Timestamp).toDate()
          : DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      bookingId: data['bookingId'],
      price: data['price']?.toDouble(),
      notes: data['notes'],
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: data['updatedAt'] is Timestamp 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(data['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
      'bookingId': bookingId,
      'price': price,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TimeSlot copyWith({
    String? slotId,
    String? providerId,
    DateTime? date,
    String? startTime,
    String? endTime,
    bool? isAvailable,
    String? bookingId,
    double? price,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeSlot(
      slotId: slotId ?? this.slotId,
      providerId: providerId ?? this.providerId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAvailable: isAvailable ?? this.isAvailable,
      bookingId: bookingId ?? this.bookingId,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Utility methods
  String get formattedTime {
    return '$startTime - $endTime';
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  Duration get duration {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    return end.difference(start);
  }

  DateTime get startDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      _parseTime(startTime).hour,
      _parseTime(startTime).minute,
    );
  }

  DateTime get endDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      _parseTime(endTime).hour,
      _parseTime(endTime).minute,
    );
  }

  bool get isBooked => bookingId != null;
  bool get isFree => isAvailable && !isBooked;

  bool overlapsWith(TimeSlot other) {
    return startDateTime.isBefore(other.endDateTime) &&
           endDateTime.isAfter(other.startDateTime);
  }

  bool isOnSameDay(DateTime checkDate) {
    return date.year == checkDate.year &&
           date.month == checkDate.month &&
           date.day == checkDate.day;
  }

  bool isInPast() {
    return endDateTime.isBefore(DateTime.now());
  }

  bool isToday() {
    final now = DateTime.now();
    return isOnSameDay(now);
  }

  bool isTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isOnSameDay(tomorrow);
  }

  String get relativeTime {
    if (isToday()) {
      return 'Today at $startTime';
    } else if (isTomorrow()) {
      return 'Tomorrow at $startTime';
    } else {
      return '$formattedDate at $startTime';
    }
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  String toString() {
    return 'TimeSlot($formattedDate $formattedTime - ${isAvailable ? "Available" : "Unavailable"})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeSlot &&
        other.slotId == slotId &&
        other.providerId == providerId &&
        other.date == date &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return slotId.hashCode ^
        providerId.hashCode ^
        date.hashCode ^
        startTime.hashCode ^
        endTime.hashCode;
  }
}












