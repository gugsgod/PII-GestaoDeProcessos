import 'package:dart_frog/dart_frog.dart';

import '../lib/authenticator.dart';

Handler middleware(Handler handler) {
  return handler.use(
    provider<Authenticator>(
      (_) => Authenticator(),
    ),
  );
}