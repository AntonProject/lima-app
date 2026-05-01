import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppNotificationItem {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String kind;

  const InAppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.kind = 'generic',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead,
    'kind': kind,
  };

  factory InAppNotificationItem.fromMap(Map<String, dynamic> map) {
    return InAppNotificationItem(
      id: (map['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      title: '${map['title'] ?? ''}',
      body: '${map['body'] ?? ''}',
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}') ?? DateTime.now(),
      isRead: map['is_read'] == true || map['is_read'] == 1,
      kind: '${map['kind'] ?? 'generic'}',
    );
  }

  InAppNotificationItem copyWith({
    bool? isRead,
  }) {
    return InAppNotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      kind: kind,
    );
  }
}

class InAppNotificationsService {
  static const String _storageKey = 'in_app_notifications_v1';
  static const int _maxItems = 100;

  Future<List<InAppNotificationItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = decoded
          .whereType<Map>()
          .map((e) => InAppNotificationItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      debugPrint('InAppNotificationsService.getAll decode error: $e');
      return const [];
    }
  }

  Future<void> add({
    required String title,
    required String body,
    String kind = 'generic',
  }) async {
    final list = await getAll();
    final next = [
      InAppNotificationItem(
        id: DateTime.now().microsecondsSinceEpoch,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        isRead: false,
        kind: kind,
      ),
      ...list,
    ];
    if (next.length > _maxItems) {
      next.removeRange(_maxItems, next.length);
    }
    await _save(next);
  }

  Future<void> markRead(int id) async {
    final list = await getAll();
    final next = list
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    await _save(next);
  }

  Future<void> _save(List<InAppNotificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
  }
}

