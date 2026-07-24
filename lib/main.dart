import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaosu/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化SharedPreferences
  await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      child: XiaoSuApp(),
    ),
  );
}
