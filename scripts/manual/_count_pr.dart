// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:pocketbase/pocketbase.dart';

const _url = 'https://217-114-0-201.sslip.io';
const _email = 'Kuchenov@yandex.ru';

Future<void> main() async {
  final pw = Platform.environment['AUDIT_USER_PASSWORD'] ?? '';
  final pb = PocketBase(_url);
  await pb.collection('profiles').authWithPassword(_email, pw);
  final uid = pb.authStore.record!.id;
  final plans = await pb.collection('plans').getFullList(
        batch: 500,
        filter: 'user_id = "$uid"',
      );
  final pr = plans
      .where((p) => (p.data['title'] ?? '').toString() == 'Price Reporter Email check')
      .toList();
  print('total=${plans.length} price_reporter=${pr.length}');
}
