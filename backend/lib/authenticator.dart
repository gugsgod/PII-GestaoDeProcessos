
import 'package:backend/user.dart';

class Authenticator {
  static const _users = {
    'gugs': User(
      id: '1',
      name: 'gugs',
      password: '123',
    ),
    'jack': User(
      id: '2',
      name: 'Jack',
      password: '321',
    ),
  };

  static const _passwords = {
    // ⚠️ Never store user's password in plain text, these values are in plain text
    // just for the sake of the tutorial.
    'gugs': '123',
    'jack': '321',
  };

  User? findByUsernameAndPassword({
    required String username,
    required String password,
  }) {
    final user = _users[username];

    if (user != null && _passwords[username] == password) {
      return user;
    }

    return null;
  }
}