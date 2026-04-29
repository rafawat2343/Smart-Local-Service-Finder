import 'package:shared_preferences/shared_preferences.dart';

class NotificationsReadService {
  static String _key(String userId) => 'read_feedback_ids_$userId';

  static Future<Set<String>> getReadIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(userId))?.toSet() ?? <String>{};
  }

  static Future<void> markRead(String userId, String reportId) async {
    if (reportId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key(userId))?.toSet() ?? <String>{};
    if (current.add(reportId)) {
      await prefs.setStringList(_key(userId), current.toList());
    }
  }

  static Future<int> countUnread(
    String userId,
    List<Map<String, dynamic>> feedbackReports,
  ) async {
    final read = await getReadIds(userId);
    return feedbackReports
        .where((r) => !read.contains((r['id'] ?? '').toString()))
        .length;
  }
}
