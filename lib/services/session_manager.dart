import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan & membaca session login user via shared_preferences.
///
/// Yang disimpan cukup data non-sensitif untuk mengenali user yang sedang
/// login (id, username, nama, role) — bukan password.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _kUserId = 'session_user_id';
  static const _kUsername = 'session_username';
  static const _kNamaLengkap = 'session_nama_lengkap';
  static const _kRole = 'session_role';

  Future<void> saveSession({
    required int userId,
    required String username,
    required String namaLengkap,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kUsername, username);
    await prefs.setString(_kNamaLengkap, namaLengkap);
    await prefs.setString(_kRole, role);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kUserId);
  }

  Future<SessionUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    if (id == null) return null;
    return SessionUser(
      id: id,
      username: prefs.getString(_kUsername) ?? '',
      namaLengkap: prefs.getString(_kNamaLengkap) ?? '',
      role: prefs.getString(_kRole) ?? '',
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kUsername);
    await prefs.remove(_kNamaLengkap);
    await prefs.remove(_kRole);
  }
}

/// Data user yang sedang login (dari session).
class SessionUser {
  final int id;
  final String username;
  final String namaLengkap;
  final String role;

  const SessionUser({
    required this.id,
    required this.username,
    required this.namaLengkap,
    required this.role,
  });
}
