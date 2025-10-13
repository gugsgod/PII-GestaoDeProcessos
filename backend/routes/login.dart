import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) {
  final request = context.request;
  // TODO: implement route handler
  return Response(body: 'Essa é a rota de login');
}
