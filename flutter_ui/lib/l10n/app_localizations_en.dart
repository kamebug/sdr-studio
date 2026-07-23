// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SDR Studio';

  @override
  String get waterfall => 'Waterfall';

  @override
  String get spectrum => 'Spectrum';

  @override
  String get frequency => 'Frequency';

  @override
  String get mode => 'Mode';

  @override
  String get gain => 'Gain';

  @override
  String get bandwidth => 'Bandwidth';

  @override
  String get favorites => 'Favorites';

  @override
  String get history => 'History';

  @override
  String get profiles => 'Profiles';

  @override
  String get addFrequency => 'Add frequency';

  @override
  String get removeFrequency => 'Remove frequency';

  @override
  String get saveFrequency => 'Save frequency';

  @override
  String get frequencyLibrary => 'Frequency library';

  @override
  String get modeAM => 'AM';

  @override
  String get modeFM => 'FM';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get connectDevice => 'Connect device';

  @override
  String get deviceNotFound => 'No SDR device found';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';
}
