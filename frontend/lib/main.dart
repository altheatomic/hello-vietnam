import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_mobile.dart';
import 'app/deep_link_state.dart';
import 'core/config/env.dart';
import 'core/data/reference_data_cache_repository.dart';
import 'core/language/app_language.dart';
import 'core/storage/local_storage.dart' as app_storage;
import 'features/forum/data/forum_store.dart';
import 'features/planner/data/trip_store.dart';
import 'features/personalization/data/travel_preferences_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  await app_storage.LocalStorage.instance.initialize();
  await AppLanguageController.instance.initialize();
  await TravelPreferencesRepository.instance.initialize();
  await ReferenceDataCacheRepository.instance.initialize();
  await TripStore.instance.init();
  await ForumStore.instance.init();
  await initDeepLinks();
  await ReferenceDataCacheRepository.instance.refreshStaleInBackground();

  runApp(const MobileApp());
}
