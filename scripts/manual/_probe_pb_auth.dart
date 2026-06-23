// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final base = Uri.parse(Platform.environment['PB_BASE_URL'] ?? 'https://217-114-0-201.sslip.io');
  final email = Platform.environment['PB_ADMIN_EMAIL'] ?? '';
  final pass = Platform.environment['PB_ADMIN_PASSWORD'] ?? '';
  for (final p in [
    '/api/collections/_superusers/auth-with-password',
    '/api/admins/auth-with-password',
    '/api/collections/profiles/auth-with-password',
  ]) {
    final res = await http.post(
      base.replace(path: p),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity': email, 'password': pass}),
    );
    print('$p -> ${res.statusCode} body=${res.body.length > 120 ? res.body.substring(0, 120) : res.body}');
  }
}
