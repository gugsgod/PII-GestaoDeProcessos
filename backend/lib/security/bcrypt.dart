import 'package:bcrypt/bcrypt.dart';

String hashPassword(String plain) {
  return BCrypt.hashpw(plain, BCrypt.gensalt());
}

bool verifyPassword(String plain, String hashed) {
  return BCrypt.checkpw(plain, hashed);
}
