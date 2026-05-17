import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/admin_app.dart';
import 'core/config/env.dart';
import 'core/data/reference_data_cache_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  await ReferenceDataCacheRepository.instance.initialize();
  await ReferenceDataCacheRepository.instance.refreshStaleInBackground();

  runApp(const AdminApp());
}
