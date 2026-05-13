import 'package:get_it/get_it.dart';
import '../api/deezer_api_client.dart';
import '../../data/services/audio_handler.dart';
import '../../data/services/ai_dj_service.dart';
import '../../data/services/local_db_service.dart';
import '../utils/secure_storage.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  // Storage
  getIt.registerSingleton<SecureStorage>(SecureStorage());

  // Local DB (SQLite for favorites + downloads)
  getIt.registerSingleton<LocalDbService>(LocalDbService());

  // API client (needs token injection after OAuth)
  getIt.registerSingleton<DeezerApiClient>(DeezerApiClient());

  // AI DJ
  getIt.registerSingleton<AiDjService>(AiDjService(getIt<SecureStorage>()));
  await getIt<AiDjService>().init();
}