// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'SDR Studio';

  @override
  String get waterfall => 'ウォーターフォール';

  @override
  String get spectrum => 'スペクトラム';

  @override
  String get frequency => '周波数';

  @override
  String get mode => 'モード';

  @override
  String get gain => 'ゲイン';

  @override
  String get bandwidth => '帯域幅';

  @override
  String get favorites => 'お気に入り';

  @override
  String get history => '履歴';

  @override
  String get profiles => 'プロファイル';

  @override
  String get addFrequency => '周波数を追加';

  @override
  String get removeFrequency => '周波数を削除';

  @override
  String get saveFrequency => '周波数を保存';

  @override
  String get frequencyLibrary => '周波数ライブラリ';

  @override
  String get modeAM => 'AM';

  @override
  String get modeFM => 'FM';

  @override
  String get settings => '設定';

  @override
  String get language => '言語';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get start => '開始';

  @override
  String get stop => '停止';

  @override
  String get connectDevice => 'デバイスを接続';

  @override
  String get deviceNotFound => 'SDRデバイスが見つかりません';

  @override
  String get errorGeneric => 'エラーが発生しました';

  @override
  String get confirm => '確認';

  @override
  String get cancel => 'キャンセル';
}
