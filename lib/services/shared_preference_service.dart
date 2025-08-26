import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BambooSharedPreference extends GetxService {
  static BambooSharedPreference get to => Get.find();
  late final SharedPreferences _prefs;

  // Initialize the service
  Future<BambooSharedPreference> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  // Add any shared preference methods you need here
  // For example:
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);
  
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);
  
  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
}
