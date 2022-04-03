// Dart imports:
// ignore_for_file: always_specify_types

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:aeuniverse/util/service_locator.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:aeuniverse/appstate_container.dart';
import 'package:aeuniverse/model/available_themes.dart';
import 'package:aeuniverse/ui/util/settings_list_item.dart';
import 'package:aeuniverse/ui/util/styles.dart';
import 'package:aeuniverse/ui/util/ui_util.dart';
import 'package:aeuniverse/ui/views/pin_screen.dart';
import 'package:aeuniverse/ui/views/settings/backupseed_sheet.dart';
import 'package:aeuniverse/ui/views/settings/nodes_widget.dart';
import 'package:aeuniverse/ui/views/settings/yubikey_params_widget.dart';
import 'package:aeuniverse/ui/views/yubikey_screen.dart';
import 'package:aeuniverse/ui/widgets/components/dialog.dart';
import 'package:aeuniverse/ui/widgets/components/icon_widget.dart';
import 'package:aeuniverse/ui/widgets/components/sheet_util.dart';
import 'package:aeuniverse/util/preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:core/localization.dart';
import 'package:core/model/authentication_method.dart';
import 'package:core/model/available_currency.dart';
import 'package:core/model/available_networks.dart';
import 'package:core/model/available_language.dart';
import 'package:core/model/data/appdb.dart';
import 'package:core/model/device_lock_timeout.dart';
import 'package:core/model/device_unlock_option.dart';
import 'package:core/util/biometrics_util.dart';
import 'package:core/util/get_it_instance.dart';
import 'package:core/util/haptic_util.dart';
import 'package:core/util/vault.dart';
import 'package:core_ui/util/case_converter.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/svg.dart';

class SettingsSheetUniverse extends StatefulWidget {
  const SettingsSheetUniverse({Key? key}) : super(key: key);

  @override
  _SettingsSheetUniverseState createState() => _SettingsSheetUniverseState();
}

class _SettingsSheetUniverseState extends State<SettingsSheetUniverse>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _securityController;
  Animation<Offset>? _securityOffsetFloat;
  AnimationController? _nodesController;
  Animation<Offset>? _nodesOffsetFloat;
  AnimationController? _aboutController;
  Animation<Offset>? _aboutOffsetFloat;
  AnimationController? _yubikeyParamsController;
  Animation<Offset>? _yubikeyParamsOffsetFloat;

  String versionString = '';

  bool _hasBiometrics = false;
  AuthenticationMethod _curAuthMethod = AuthenticationMethod(AuthMethod.pin);
  UnlockSetting _curUnlockSetting = UnlockSetting(UnlockOption.no);
  LockTimeoutSetting _curTimeoutSetting =
      LockTimeoutSetting(LockTimeoutOption.one);
  ThemeSetting _curThemeSetting = ThemeSetting(ThemeOptions.dark);
  NetworksSetting _curNetworksSetting =
      NetworksSetting(AvailableNetworks.AETestNet);

  bool? _securityOpen;
  bool? _aboutOpen;
  bool? _nodesOpen;
  bool? _yubikeyParamsOpen;

  bool _pinPadShuffleActive = false;

  bool notNull(Object? o) => o != null;

  @override
  void initState() {
    super.initState();
    _nodesOpen = false;
    _securityOpen = false;
    _aboutOpen = false;
    _yubikeyParamsOpen = false;

    // Determine if they have face or fingerprint enrolled, if not hide the setting
    sl.get<BiometricUtil>().hasBiometrics().then((bool hasBiometrics) {
      setState(() {
        _hasBiometrics = hasBiometrics;
      });
    });
    Preferences.getInstance().then((Preferences _preferences) {
      setState(() {
        _pinPadShuffleActive = _preferences.getPinPadShuffle();
        _curAuthMethod = _preferences.getAuthMethod();
        _curUnlockSetting = _preferences.getLock()
            ? UnlockSetting(UnlockOption.yes)
            : UnlockSetting(UnlockOption.no);
        _curThemeSetting = _preferences.getTheme();
        _curNetworksSetting = _preferences.getNetwork();
        _curTimeoutSetting = _preferences.getLockTimeout();
      });
    });

    _securityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _aboutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _nodesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _yubikeyParamsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _securityOffsetFloat =
        Tween<Offset>(begin: const Offset(1.1, 0), end: const Offset(0, 0))
            .animate(_securityController!);
    _aboutOffsetFloat =
        Tween<Offset>(begin: const Offset(1.1, 0), end: const Offset(0, 0))
            .animate(_aboutController!);
    _nodesOffsetFloat =
        Tween<Offset>(begin: const Offset(1.1, 0), end: const Offset(0, 0))
            .animate(_nodesController!);
    _yubikeyParamsOffsetFloat =
        Tween<Offset>(begin: const Offset(1.1, 0), end: const Offset(0, 0))
            .animate(_yubikeyParamsController!);
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        versionString =
            AppLocalization.of(context)!.version + ' ${packageInfo.version}';
      });
    });
  }

  @override
  void dispose() {
    _securityController!.dispose();
    _aboutController!.dispose();
    _nodesController!.dispose();
    _yubikeyParamsController!.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        super.didChangeAppLifecycleState(state);
        break;
      case AppLifecycleState.resumed:
        super.didChangeAppLifecycleState(state);
        break;
      default:
        super.didChangeAppLifecycleState(state);
        break;
    }
  }

  Future<void> _authMethodDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    switch (await showDialog<AuthMethod>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(
              AppLocalization.of(context)!.authMethod,
              style: AppStyles.textStyleSize20W700Primary(context),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                side: BorderSide(
                    color: StateContainer.of(context).curTheme.primary45!)),
            children: <Widget>[
              if (_hasBiometrics)
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, AuthMethod.biometrics);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(
                          AppLocalization.of(context)!.biometricsMethod,
                          style: _curAuthMethod.getIndex() ==
                                  AuthenticationMethod(AuthMethod.biometrics)
                                      .method
                                      .index
                              ? AppStyles.textStyleSize16W600ChoiceOption(
                                  context)
                              : AppStyles.textStyleSize16W600Primary(context),
                        ),
                        const SizedBox(width: 20),
                        if (_curAuthMethod.getIndex() ==
                            AuthenticationMethod(AuthMethod.biometrics)
                                .method
                                .index)
                          FaIcon(
                            FontAwesomeIcons.check,
                            color: StateContainer.of(context)
                                .curTheme
                                .choiceOption,
                            size: 16,
                          )
                      ],
                    ),
                  ),
                ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, AuthMethod.pin);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        AppLocalization.of(context)!.pinMethod,
                        style: _curAuthMethod.getIndex() ==
                                AuthenticationMethod(AuthMethod.pin)
                                    .method
                                    .index
                            ? AppStyles.textStyleSize16W600ChoiceOption(context)
                            : AppStyles.textStyleSize16W600Primary(context),
                      ),
                      const SizedBox(width: 20),
                      if (_curAuthMethod.getIndex() ==
                          AuthenticationMethod(AuthMethod.pin).method.index)
                        FaIcon(
                          FontAwesomeIcons.check,
                          color:
                              StateContainer.of(context).curTheme.choiceOption,
                          size: 16,
                        )
                    ],
                  ),
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, AuthMethod.yubikeyWithYubicloud);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        AppLocalization.of(context)!.yubikeyWithYubiCloudMethod,
                        style: _curAuthMethod.getIndex() ==
                                AuthenticationMethod(
                                        AuthMethod.yubikeyWithYubicloud)
                                    .method
                                    .index
                            ? AppStyles.textStyleSize16W600ChoiceOption(context)
                            : AppStyles.textStyleSize16W600Primary(context),
                      ),
                      const SizedBox(width: 20),
                      if (_curAuthMethod.getIndex() ==
                          AuthenticationMethod(AuthMethod.yubikeyWithYubicloud)
                              .method
                              .index)
                        FaIcon(
                          FontAwesomeIcons.check,
                          color:
                              StateContainer.of(context).curTheme.choiceOption,
                          size: 16,
                        )
                    ],
                  ),
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, AuthMethod.ledger);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        AppLocalization.of(context)!.ledgerMethod,
                        style: _curAuthMethod.getIndex() ==
                                AuthenticationMethod(AuthMethod.ledger)
                                    .method
                                    .index
                            ? AppStyles.textStyleSize16W600ChoiceOption(context)
                            : AppStyles.textStyleSize16W600Primary(context),
                      ),
                      const SizedBox(width: 20),
                      if (_curAuthMethod.getIndex() ==
                          AuthenticationMethod(AuthMethod.ledger).method.index)
                        FaIcon(
                          FontAwesomeIcons.check,
                          color:
                              StateContainer.of(context).curTheme.choiceOption,
                          size: 16,
                        )
                    ],
                  ),
                ),
              ),
            ],
          );
        })) {
      case AuthMethod.pin:
        _preferences.setAuthMethod(AuthenticationMethod(AuthMethod.pin));
        setState(() {
          _curAuthMethod = AuthenticationMethod(AuthMethod.pin);
        });
        break;
      case AuthMethod.biometrics:
        _preferences.setAuthMethod(AuthenticationMethod(AuthMethod.biometrics));
        setState(() {
          _curAuthMethod = AuthenticationMethod(AuthMethod.biometrics);
        });

        break;
      case AuthMethod.yubikeyWithYubicloud:
        _preferences.setAuthMethod(
            AuthenticationMethod(AuthMethod.yubikeyWithYubicloud));
        setState(() {
          _curAuthMethod =
              AuthenticationMethod(AuthMethod.yubikeyWithYubicloud);
        });

        break;

      case AuthMethod.ledger:
        _preferences.setAuthMethod(AuthenticationMethod(AuthMethod.ledger));
        setState(() {
          _curAuthMethod = AuthenticationMethod(AuthMethod.ledger);
        });

        break;
      default:
        _preferences.setAuthMethod(AuthenticationMethod(AuthMethod.pin));
        setState(() {
          _curAuthMethod = AuthenticationMethod(AuthMethod.pin);
        });
        break;
    }
  }

  Future<void> _lockDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    switch (await showDialog<UnlockOption>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(
              AppLocalization.of(context)!.lockAppSetting,
              style: AppStyles.textStyleSize20W700Primary(context),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                side: BorderSide(
                    color: StateContainer.of(context).curTheme.primary45!)),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, UnlockOption.no);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        AppLocalization.of(context)!.no,
                        style: _curUnlockSetting.setting.index ==
                                UnlockSetting(UnlockOption.no).getIndex()
                            ? AppStyles.textStyleSize16W600ChoiceOption(context)
                            : AppStyles.textStyleSize16W600Primary(context),
                      ),
                      const SizedBox(width: 20),
                      if (_curUnlockSetting.setting.index ==
                          UnlockSetting(UnlockOption.no).getIndex())
                        FaIcon(
                          FontAwesomeIcons.check,
                          color:
                              StateContainer.of(context).curTheme.choiceOption,
                          size: 16,
                        )
                    ],
                  ),
                ),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, UnlockOption.yes);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        AppLocalization.of(context)!.yes,
                        style: _curUnlockSetting.setting.index ==
                                UnlockSetting(UnlockOption.yes).getIndex()
                            ? AppStyles.textStyleSize16W600ChoiceOption(context)
                            : AppStyles.textStyleSize16W600Primary(context),
                      ),
                      const SizedBox(width: 20),
                      if (_curUnlockSetting.setting.index ==
                          UnlockSetting(UnlockOption.yes).getIndex())
                        FaIcon(
                          FontAwesomeIcons.check,
                          color:
                              StateContainer.of(context).curTheme.choiceOption,
                          size: 16,
                        )
                    ],
                  ),
                ),
              ),
            ],
          );
        })) {
      case UnlockOption.yes:
        _preferences.setLock(true);
        setState(() {
          _curUnlockSetting = UnlockSetting(UnlockOption.yes);
        });
        break;
      case UnlockOption.no:
        _preferences.setLock(false);
        setState(() {
          _curUnlockSetting = UnlockSetting(UnlockOption.no);
        });
        break;
      default:
        _preferences.setLock(false);
        setState(() {
          _curUnlockSetting = UnlockSetting(UnlockOption.no);
        });
        break;
    }
  }

  List<Widget> _buildCurrencyOptions() {
    final List<Widget> ret = List<Widget>.empty(growable: true);
    for (AvailableCurrencyEnum value in AvailableCurrencyEnum.values) {
      ret.add(SimpleDialogOption(
        onPressed: () {
          Navigator.pop(context, value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: Image.asset(
                  'packages/aeuniverse/assets/icons/currency/${AvailableCurrency(value).getIso4217Code().toLowerCase()}.png',
                  width: 30,
                  height: 20,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(AvailableCurrency(value).getDisplayName(context),
                  style: StateContainer.of(context)
                              .curCurrency
                              .getDisplayName(context) ==
                          AvailableCurrency(value).getDisplayName(context)
                      ? AppStyles.textStyleSize14W600ChoiceOption(context)
                      : AppStyles.textStyleSize14W600Primary(context)),
              if (AvailableCurrency(value).getIso4217Code() == 'EUR' ||
                  AvailableCurrency(value).getIso4217Code() == 'USD')
                const SizedBox(
                  width: 10,
                ),
              if (AvailableCurrency(value).getIso4217Code() == 'EUR' ||
                  AvailableCurrency(value).getIso4217Code() == 'USD')
                buildIconWidget(
                  context,
                  'packages/aeuniverse/assets/icons/oracle.png',
                  25,
                  25,
                  color: StateContainer.of(context)
                              .curCurrency
                              .getDisplayName(context) ==
                          AvailableCurrency(value).getDisplayName(context)
                      ? StateContainer.of(context).curTheme.choiceOption
                      : StateContainer.of(context).curTheme.primary,
                ),
              const SizedBox(width: 20),
              if (StateContainer.of(context)
                      .curCurrency
                      .getDisplayName(context) ==
                  AvailableCurrency(value).getDisplayName(context))
                FaIcon(
                  FontAwesomeIcons.check,
                  color: StateContainer.of(context).curTheme.choiceOption,
                  size: 16,
                )
            ],
          ),
        ),
      ));
    }
    return ret;
  }

  Future<void> _currencyDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    final AvailableCurrencyEnum? selection =
        await showDialog<AvailableCurrencyEnum>(
            context: context,
            builder: (BuildContext context) {
              return SimpleDialog(
                title: Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalization.of(context)!.currency,
                          style: AppStyles.textStyleSize20W700Primary(context),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Row(
                          children: [
                            buildIconWidget(
                              context,
                              'packages/aeuniverse/assets/icons/oracle.png',
                              20,
                              20,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: AutoSizeText(
                                AppLocalization.of(context)!.currencyOracleInfo,
                                style: AppStyles.textStyleSize12W100Primary(
                                    context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )),
                shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                    side: BorderSide(
                        color: StateContainer.of(context).curTheme.primary45!)),
                children: _buildCurrencyOptions(),
              );
            });
    if (selection != null) {
      _preferences.setCurrency(AvailableCurrency(selection));
      if (StateContainer.of(context).curCurrency.currency != selection) {
        setState(() {
          StateContainer.of(context).curCurrency = AvailableCurrency(selection);
          StateContainer.of(context)
              .updateCurrency(AvailableCurrency(selection));
        });
      }
    }
  }

  List<Widget> _buildLanguageOptions() {
    final List<Widget> ret = List<Widget>.empty(growable: true);
    for (AvailableLanguage value in AvailableLanguage.values) {
      ret.add(SimpleDialogOption(
        onPressed: () {
          Navigator.pop(context, value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: LanguageSetting(value).getLocaleString().toLowerCase() ==
                        'default'
                    ? const SizedBox(
                        width: 30,
                        height: 20,
                      )
                    : Image.asset(
                        'packages/aeuniverse/assets/icons/country/${LanguageSetting(value).getLocaleString().toLowerCase()}.png',
                        width: 30,
                        height: 20,
                      ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(LanguageSetting(value).getDisplayName(context),
                  style: StateContainer.of(context)
                              .curLanguage
                              .getDisplayName(context) ==
                          LanguageSetting(value).getDisplayName(context)
                      ? AppStyles.textStyleSize16W600ChoiceOption(context)
                      : AppStyles.textStyleSize16W600Primary(context)),
              const SizedBox(width: 20),
              if (StateContainer.of(context)
                      .curLanguage
                      .getDisplayName(context) ==
                  LanguageSetting(value).getDisplayName(context))
                FaIcon(
                  FontAwesomeIcons.check,
                  color: StateContainer.of(context).curTheme.choiceOption,
                  size: 16,
                )
              else
                const SizedBox(),
            ],
          ),
        ),
      ));
    }

    return ret;
  }

  Future<void> _languageDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    final AvailableLanguage? selection = await showDialog<AvailableLanguage>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                AppLocalization.of(context)!.language,
                style: AppStyles.textStyleSize20W700Primary(context),
              ),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                side: BorderSide(
                    color: StateContainer.of(context).curTheme.primary45!)),
            children: _buildLanguageOptions(),
          );
        });
    if (selection != null) {
      _preferences.setLanguage(LanguageSetting(selection));
      if (StateContainer.of(context).curLanguage.language != selection) {
        setState(() {
          StateContainer.of(context).updateLanguage(LanguageSetting(selection));
        });
      }
    }
  }

  List<Widget> _buildLockTimeoutOptions() {
    final List<Widget> ret = List<Widget>.empty(growable: true);
    for (LockTimeoutOption value in LockTimeoutOption.values) {
      ret.add(SimpleDialogOption(
        onPressed: () {
          Navigator.pop(context, value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: <Widget>[
              Text(LockTimeoutSetting(value).getDisplayName(context),
                  style: _curUnlockSetting.getDisplayName(context) ==
                          LockTimeoutSetting(value).getDisplayName(context)
                      ? AppStyles.textStyleSize16W600ChoiceOption(context)
                      : AppStyles.textStyleSize16W600Primary(context)),
              const SizedBox(width: 20),
              if (_curUnlockSetting.getDisplayName(context) ==
                  LockTimeoutSetting(value).getDisplayName(context))
                FaIcon(
                  FontAwesomeIcons.check,
                  color: StateContainer.of(context).curTheme.choiceOption,
                  size: 16,
                )
              else
                const SizedBox(),
            ],
          ),
        ),
      ));
    }

    return ret;
  }

  Future<void> _lockTimeoutDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    final LockTimeoutOption? selection = await showDialog<LockTimeoutOption>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                AppLocalization.of(context)!.autoLockHeader,
                style: AppStyles.textStyleSize20W700Primary(context),
              ),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                side: BorderSide(
                    color: StateContainer.of(context).curTheme.primary45!)),
            children: _buildLockTimeoutOptions(),
          );
        });
    if (selection != null) {
      if (_curTimeoutSetting.setting != selection) {
        _preferences.setLockTimeout(LockTimeoutSetting(selection));
        setState(() {
          _curTimeoutSetting = LockTimeoutSetting(selection);
        });
      }
    }
  }

  List<Widget> _buildThemeOptions() {
    final List<Widget> ret = List<Widget>.empty(growable: true);
    for (var value in ThemeOptions.values) {
      ret.add(SimpleDialogOption(
        onPressed: () {
          Navigator.pop(context, value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: <Widget>[
              Text(ThemeSetting(value).getDisplayName(context),
                  style: StateContainer.of(context).curTheme.displayName ==
                          ThemeSetting(value).getDisplayName(context)
                      ? AppStyles.textStyleSize16W600ChoiceOption(context)
                      : AppStyles.textStyleSize16W600Primary(context)),
              const SizedBox(width: 20),
              if (StateContainer.of(context).curTheme.displayName ==
                  ThemeSetting(value).getDisplayName(context))
                FaIcon(
                  FontAwesomeIcons.check,
                  color: StateContainer.of(context).curTheme.choiceOption,
                  size: 16,
                )
              else
                const SizedBox(),
            ],
          ),
        ),
      ));
    }
    return ret;
  }

  Future<void> _themeDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    final ThemeOptions? selection = await showDialog<ThemeOptions>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                AppLocalization.of(context)!.themeHeader,
                style: AppStyles.textStyleSize20W700Primary(context),
              ),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                side: BorderSide(
                    color: StateContainer.of(context).curTheme.primary45!)),
            children: _buildThemeOptions(),
          );
        });
    if (selection != null) {
      if (_curThemeSetting != ThemeSetting(selection)) {
        _preferences.setTheme(ThemeSetting(selection));
        setState(() {
          StateContainer.of(context).updateTheme(ThemeSetting(selection));
          _curThemeSetting = ThemeSetting(selection);
        });
      }
    }
  }

  List<Widget> _buildNetworkOptions() {
    final List<Widget> ret = List<Widget>.empty(growable: true);
    for (AvailableNetworks value in AvailableNetworks.values) {
      ret.add(SimpleDialogOption(
        onPressed: () {
          if (value == AvailableNetworks.AEMainNet) {
            UIUtil.showSnackbar(
                'Soon...',
                context,
                StateContainer.of(context).curTheme.primary!,
                StateContainer.of(context).curTheme.overlay80!);
          } else {
            Navigator.pop(context, value);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: <Widget>[
              ClipRRect(
                child: NetworksSetting(value).network.index ==
                        AvailableNetworks.AETestNet.index
                    ? SvgPicture.asset(
                        'packages/core_ui/assets/themes/dark/logo_alone.svg',
                        color: Colors.green,
                        height: 15,
                      )
                    : NetworksSetting(value).network.index ==
                            AvailableNetworks.AEDevNet.index
                        ? SvgPicture.asset(
                            'packages/core_ui/assets/themes/dark/logo_alone.svg',
                            color: Colors.orange,
                            height: 15,
                          )
                        : SvgPicture.asset(
                            'packages/core_ui/assets/themes/dark/logo_alone.svg',
                            height: 15,
                          ),
              ),
              const SizedBox(
                width: 10,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(NetworksSetting(value).getDisplayName(context),
                      style: StateContainer.of(context)
                                  .curNetwork
                                  .getDisplayName(context) ==
                              NetworksSetting(value).getDisplayName(context)
                          ? AppStyles.textStyleSize16W600ChoiceOption(context)
                          : AppStyles.textStyleSize16W600Primary(context)),
                  Text(NetworksSetting(value).getLink(),
                      style: AppStyles.textStyleSize12W100Primary(context)),
                ],
              ),
              const SizedBox(width: 20),
              if (StateContainer.of(context)
                      .curNetwork
                      .getDisplayName(context) ==
                  NetworksSetting(value).getDisplayName(context))
                FaIcon(
                  FontAwesomeIcons.check,
                  color: StateContainer.of(context).curTheme.choiceOption,
                  size: 16,
                )
              else
                const SizedBox(),
            ],
          ),
        ),
      ));
    }

    return ret;
  }

  Future<void> _networkDialog() async {
    final Preferences _preferences = await Preferences.getInstance();
    final AvailableNetworks? selection = await showDialog<AvailableNetworks>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Text(
                AppLocalization.of(context)!.networksHeader,
                style: AppStyles.textStyleSize20W700Primary(context),
              ),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                side: BorderSide(
                    color: StateContainer.of(context).curTheme.primary45!)),
            children: _buildNetworkOptions(),
          );
        });
    if (selection != null) {
      if (StateContainer.of(context).curNetwork.network != selection) {
        _preferences.setNetwork(NetworksSetting(selection));
        setState(() {
          _curNetworksSetting = NetworksSetting(selection);
          StateContainer.of(context).curNetwork = _curNetworksSetting;
        });
        setupServiceLocator();
        await StateContainer.of(context)
            .requestUpdate(account: StateContainer.of(context).selectedAccount);
      }
    }
  }

  Future<bool> _onBackButtonPressed() async {
    if (_securityOpen!) {
      setState(() {
        _securityOpen = false;
      });
      _securityController!.reverse();
      return false;
    } else if (_aboutOpen!) {
      setState(() {
        _aboutOpen = false;
      });
      _aboutController!.reverse();
      return false;
    } else if (_nodesOpen!) {
      setState(() {
        _nodesOpen = false;
      });
      _nodesController!.reverse();
      return false;
    } else if (_yubikeyParamsOpen!) {
      setState(() {
        _yubikeyParamsOpen = false;
      });
      _yubikeyParamsController!.reverse();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackButtonPressed,
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            Container(
              color: StateContainer.of(context).curTheme.backgroundDark,
              constraints: const BoxConstraints.expand(),
            ),
            buildMainSettings(context),
            SlideTransition(
                position: _securityOffsetFloat!,
                child: buildSecurityMenu(context)),
            SlideTransition(
                position: _aboutOffsetFloat!, child: buildAboutMenu(context)),
            SlideTransition(
                position: _nodesOffsetFloat!,
                child: NodesList(_nodesController!, _nodesOpen!)),
            SlideTransition(
                position: _yubikeyParamsOffsetFloat!,
                child: YubikeyParams(
                    _yubikeyParamsController!, _yubikeyParamsOpen!)),
          ],
        ),
      ),
    );
  }

  Widget buildMainSettings(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: StateContainer.of(context).curTheme.backgroundDark,
          border: Border(
            right: BorderSide(
                color: StateContainer.of(context).curTheme.primary30!,
                width: 1),
          )),
      child: SafeArea(
        minimum: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 30,
        ),
        child: Column(
          children: <Widget>[
            // Settings items
            Expanded(
                child: Stack(
              children: <Widget>[
                ListView(
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsetsDirectional.only(
                          start: 30.0, top: 10.0, bottom: 10.0),
                      child: Text(AppLocalization.of(context)!.informations,
                          style: AppStyles.textStyleSize20W700Primary(context)),
                    ),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSingleLineWithInfos(
                        context,
                        AppLocalization.of(context)!.nodesHeader,
                        AppLocalization.of(context)!.nodesHeaderDesc,
                        icon: 'packages/aeuniverse/assets/icons/nodes.png',
                        iconColor: StateContainer.of(context)
                            .curTheme
                            .iconDrawerColor!, onPressed: () {
                      setState(() {
                        _nodesOpen = true;
                      });
                      _nodesController!.forward();
                    }),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSingleLineWithInfos(
                        context,
                        AppLocalization.of(context)!.aeWebsiteLinkHeader,
                        AppLocalization.of(context)!.aeWebsiteLinkDesc,
                        icon:
                            'packages/aeuniverse/assets/icons/world-wide-web.png',
                        iconColor: StateContainer.of(context)
                            .curTheme
                            .iconDrawerColor!, onPressed: () async {
                      UIUtil.showWebview(context, 'https://www.archethic.net',
                          AppLocalization.of(context)!.aeWebsiteLinkHeader);
                    }),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSingleLineWithInfos(
                        context,
                        AppLocalization.of(context)!.labLinkHeader,
                        AppLocalization.of(context)!.labLinkDesc,
                        icon: 'packages/aeuniverse/assets/icons/microscope.png',
                        iconColor: StateContainer.of(context)
                            .curTheme
                            .iconDrawerColor!, onPressed: () async {
                      UIUtil.showWebview(
                          context,
                          'https://www.archethic.net/lab.html',
                          AppLocalization.of(context)!.labLinkHeader);
                    }),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSingleLine(
                        context,
                        AppLocalization.of(context)!.aboutHeader,
                        'packages/aeuniverse/assets/icons/help.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        onPressed: () {
                      setState(() {
                        _aboutOpen = true;
                      });
                      _aboutController!.forward();
                    }),
                    Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15),
                    Container(
                      margin: const EdgeInsetsDirectional.only(
                          start: 30.0, top: 20.0, bottom: 10.0),
                      child: Text(AppLocalization.of(context)!.preferences,
                          style: AppStyles.textStyleSize20W700Primary(context)),
                    ),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemWithDefaultValueWithInfos(
                        context,
                        AppLocalization.of(context)!.changeCurrencyHeader,
                        AppLocalization.of(context)!
                            .changeCurrencyDesc
                            .replaceAll(
                                '%1',
                                StateContainer.of(context)
                                    .curNetwork
                                    .getNetworkCryptoCurrencyLabel()),
                        StateContainer.of(context).curCurrency,
                        'packages/aeuniverse/assets/icons/money-currency.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        _currencyDialog),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemWithDefaultValue(
                        context,
                        AppLocalization.of(context)!.language,
                        StateContainer.of(context).curLanguage,
                        'packages/aeuniverse/assets/icons/languages.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        _languageDialog),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemWithDefaultValue(
                        context,
                        AppLocalization.of(context)!.themeHeader,
                        _curThemeSetting,
                        'packages/aeuniverse/assets/icons/themes.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        _themeDialog),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemWithDefaultValue(
                        context,
                        AppLocalization.of(context)!.networksHeader,
                        _curNetworksSetting,
                        'packages/aeuniverse/assets/icons/url.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        _networkDialog),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSingleLine(
                        context,
                        AppLocalization.of(context)!.securityHeader,
                        'packages/aeuniverse/assets/icons/encrypted.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        onPressed: () {
                      setState(() {
                        _securityOpen = true;
                      });
                      _securityController!.forward();
                    }),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSingleLine(
                        context,
                        AppLocalization.of(context)!.logout,
                        'packages/aeuniverse/assets/icons/logout.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        onPressed: () {
                      AppDialogs.showConfirmDialog(
                          context,
                          CaseChange.toUpperCase(
                              AppLocalization.of(context)!.warning,
                              context,
                              StateContainer.of(context)
                                  .curLanguage
                                  .getLocaleString()),
                          AppLocalization.of(context)!.logoutDetail,
                          AppLocalization.of(context)!
                              .logoutAction
                              .toUpperCase(), () {
                        // Show another confirm dialog
                        AppDialogs.showConfirmDialog(
                            context,
                            AppLocalization.of(context)!.logoutAreYouSure,
                            AppLocalization.of(context)!.logoutReassurance,
                            CaseChange.toUpperCase(
                                AppLocalization.of(context)!.yes,
                                context,
                                StateContainer.of(context)
                                    .curLanguage
                                    .getLocaleString()), () {
                          // Delete all data
                          sl.get<DBHelper>().dropAll();
                          Vault.getInstance().then((Vault _vault) {
                            _vault.deleteAll();
                          });
                          Preferences.getInstance()
                              .then((Preferences _preferences) {
                            _preferences.deleteAll();
                            StateContainer.of(context).logOut();
                            Navigator.of(context).pushNamedAndRemoveUntil(
                                '/', (Route<dynamic> route) => false);
                          });
                        });
                      });
                    }),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    const SizedBox(height: 30),
                  ].where(notNull).toList(),
                ),
                //List Top Gradient End
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 20.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          StateContainer.of(context).curTheme.backgroundDark!,
                          StateContainer.of(context).curTheme.backgroundDark00!
                        ],
                        begin: const AlignmentDirectional(0.5, -1.0),
                        end: const AlignmentDirectional(0.5, 1.0),
                      ),
                    ),
                  ),
                ), //List Top Gradient End
                //List Bottom Gradient
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 30.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          StateContainer.of(context).curTheme.backgroundDark00!,
                          StateContainer.of(context).curTheme.backgroundDark!
                        ],
                        begin: const AlignmentDirectional(0.5, -1),
                        end: const AlignmentDirectional(0.5, 0.5),
                      ),
                    ),
                  ),
                ), //List Bottom Gradient End
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget buildSecurityMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StateContainer.of(context).curTheme.backgroundDark,
        border: Border(
          right: BorderSide(
              color: StateContainer.of(context).curTheme.primary30!, width: 1),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: StateContainer.of(context).curTheme.overlay30!,
              offset: const Offset(-5, 0),
              blurRadius: 20),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.only(
          top: 60,
        ),
        child: Column(
          children: <Widget>[
            // Back button and Security Text
            Container(
              margin: const EdgeInsets.only(bottom: 10.0, top: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      //Back button
                      Container(
                        height: 40,
                        width: 40,
                        margin: const EdgeInsets.only(right: 10, left: 10),
                        child: TextButton(
                            onPressed: () {
                              setState(() {
                                _securityOpen = false;
                              });
                              _securityController!.reverse();
                            },
                            child: FaIcon(FontAwesomeIcons.chevronLeft,
                                color:
                                    StateContainer.of(context).curTheme.primary,
                                size: 24)),
                      ),
                      //Security Header Text
                      Text(
                        AppLocalization.of(context)!.securityHeader,
                        style: AppStyles.textStyleSize20W700Primary(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
                child: Stack(
              children: <Widget>[
                ListView(
                  padding: const EdgeInsets.only(top: 15.0),
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsetsDirectional.only(
                          start: 30.0, bottom: 10),
                      child: Text(AppLocalization.of(context)!.preferences,
                          style: AppStyles.textStyleSize20W700Primary(context)),
                    ),
                    // Authentication Method
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemWithDefaultValue(
                        context,
                        AppLocalization.of(context)!.authMethod,
                        _curAuthMethod,
                        'packages/aeuniverse/assets/icons/authentLaunch.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        _authMethodDialog),
                    // Authenticate on Launch

                    Column(children: <Widget>[
                      Divider(
                          height: 2,
                          color: StateContainer.of(context).curTheme.primary15),
                      AppSettings.buildSettingsListItemWithDefaultValue(
                          context,
                          AppLocalization.of(context)!.lockAppSetting,
                          _curUnlockSetting,
                          'packages/aeuniverse/assets/icons/authentication.png',
                          StateContainer.of(context).curTheme.iconDrawerColor!,
                          _lockDialog),
                    ]),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    // Authentication Timer
                    AppSettings.buildSettingsListItemWithDefaultValue(
                      context,
                      AppLocalization.of(context)!.autoLockHeader,
                      _curTimeoutSetting,
                      'packages/aeuniverse/assets/icons/autoLock.png',
                      StateContainer.of(context).curTheme.iconDrawerColor!,
                      _lockTimeoutDialog,
                      disabled: _curUnlockSetting.setting == UnlockOption.no,
                    ),
                    Column(children: <Widget>[
                      Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15,
                      ),
                      AppSettings.buildSettingsListItemSingleLine(
                          context,
                          AppLocalization.of(context)!.backupSecretPhrase,
                          'packages/aeuniverse/assets/icons/key-word.png',
                          StateContainer.of(context).curTheme.iconDrawerColor!,
                          onPressed: () async {
                        final Preferences _preferences =
                            await Preferences.getInstance();
                        final AuthenticationMethod authMethod =
                            _preferences.getAuthMethod();
                        final bool hasBiometrics =
                            await sl.get<BiometricUtil>().hasBiometrics();

                        if (authMethod.method == AuthMethod.biometrics &&
                            hasBiometrics) {
                          try {
                            final bool authenticated = await sl
                                .get<BiometricUtil>()
                                .authenticateWithBiometrics(
                                    context,
                                    AppLocalization.of(context)!
                                        .fingerprintSeedBackup);
                            if (authenticated) {
                              sl
                                  .get<HapticUtil>()
                                  .feedback(FeedbackType.success);
                              StateContainer.of(context)
                                  .getSeed()
                                  .then((String seed) {
                                Sheets.showAppHeightNineSheet(
                                    context: context,
                                    widget: AppSeedBackupSheet(seed));
                              });
                            }
                          } catch (e) {
                            await authenticateWithPin();
                          }
                        } else {
                          if (authMethod.method ==
                              AuthMethod.yubikeyWithYubicloud) {
                            return authenticateWithYubikey();
                          } else {
                            await authenticateWithPin();
                          }
                        }
                      }),
                    ]),
                    Divider(
                      height: 2,
                      color: StateContainer.of(context).curTheme.primary15,
                    ),
                    AppSettings.buildSettingsListItemSwitch(
                        context,
                        AppLocalization.of(context)!.pinPadShuffle,
                        'packages/aeuniverse/assets/icons/shuffle.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        _pinPadShuffleActive,
                        onChanged: (bool _isSwitched) async {
                      final Preferences _preferences =
                          await Preferences.getInstance();
                      setState(() {
                        _pinPadShuffleActive = _isSwitched;
                        _isSwitched
                            ? _preferences.setPinPadShuffle(true)
                            : _preferences.setPinPadShuffle(false);
                      });
                    }),
                    Column(children: <Widget>[
                      Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15,
                      ),
                      AppSettings.buildSettingsListItemSingleLineWithInfos(
                          context,
                          AppLocalization.of(context)!.yubikeyParamsHeader,
                          AppLocalization.of(context)!.yubikeyParamsDesc,
                          icon:
                              'packages/aeuniverse/assets/icons/digital-key.png',
                          iconColor: StateContainer.of(context)
                              .curTheme
                              .iconDrawerColor!, onPressed: () {
                        setState(() {
                          _yubikeyParamsOpen = true;
                        });
                        _yubikeyParamsController!.forward();
                      }),
                    ]),
                    Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15),
                  ].where(notNull).toList(),
                ),
                //List Top Gradient End
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 20.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          StateContainer.of(context).curTheme.backgroundDark!,
                          StateContainer.of(context).curTheme.backgroundDark00!
                        ],
                        begin: const AlignmentDirectional(0.5, -1.0),
                        end: const AlignmentDirectional(0.5, 1.0),
                      ),
                    ),
                  ),
                ), //List Top Gradient End
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget buildAboutMenu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
              color: StateContainer.of(context).curTheme.primary30!, width: 1),
        ),
        color: StateContainer.of(context).curTheme.backgroundDark,
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: StateContainer.of(context).curTheme.overlay30!,
              offset: const Offset(-5, 0),
              blurRadius: 20),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.only(
          top: 60,
        ),
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 10.0, top: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    height: 40,
                    width: 40,
                    margin: const EdgeInsets.only(right: 10, left: 10),
                    child: TextButton(
                        onPressed: () {
                          setState(() {
                            _aboutOpen = false;
                          });
                          _aboutController!.reverse();
                        },
                        child: FaIcon(FontAwesomeIcons.chevronLeft,
                            color: StateContainer.of(context).curTheme.primary,
                            size: 24)),
                  ),
                  Expanded(
                    child: AutoSizeText(
                      AppLocalization.of(context)!.aboutHeader,
                      style: AppStyles.textStyleSize20W700Primary(context),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
                child: Stack(
              children: <Widget>[
                ListView(
                  padding: const EdgeInsets.only(top: 15.0),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Text(versionString,
                              style: AppStyles.textStyleSize14W100Primary(
                                  context)),
                        ],
                      ),
                    ),
                    Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15),
                    AppSettings.buildSettingsListItemSingleLine(
                        context,
                        AppLocalization.of(context)!
                            .aboutGeneralTermsAndConditions,
                        'packages/aeuniverse/assets/icons/terms-and-conditions.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        onPressed: () async {
                      UIUtil.showWebview(
                          context,
                          'https://archethic.net',
                          AppLocalization.of(context)!
                              .aboutGeneralTermsAndConditions);
                    }),
                    Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15),
                    AppSettings.buildSettingsListItemSingleLine(
                        context,
                        AppLocalization.of(context)!.aboutWalletServiceTerms,
                        'packages/aeuniverse/assets/icons/walletServiceTerms.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        onPressed: () async {
                      UIUtil.showWebview(context, 'https://archethic.net',
                          AppLocalization.of(context)!.aboutWalletServiceTerms);
                    }),
                    Divider(
                        height: 2,
                        color: StateContainer.of(context).curTheme.primary15),
                    AppSettings.buildSettingsListItemSingleLine(
                        context,
                        AppLocalization.of(context)!.aboutPrivacyPolicy,
                        'packages/aeuniverse/assets/icons/privacyPolicy.png',
                        StateContainer.of(context).curTheme.iconDrawerColor!,
                        onPressed: () async {
                      UIUtil.showWebview(context, 'https://archethic.net',
                          AppLocalization.of(context)!.aboutPrivacyPolicy);
                    }),
                  ].where(notNull).toList(),
                ),
                //List Top Gradient End
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 20.0,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          StateContainer.of(context).curTheme.backgroundDark!,
                          StateContainer.of(context).curTheme.backgroundDark00!
                        ],
                        begin: const AlignmentDirectional(0.5, -1.0),
                        end: const AlignmentDirectional(0.5, 1.0),
                      ),
                    ),
                  ),
                ), //List Top Gradient End
              ],
            )),
          ],
        ),
      ),
    );
  }

  Future<void> authenticateWithYubikey() async {
    // Yubikey Authentication
    final bool auth = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) {
      return const YubikeyScreen();
    })) as bool;
    if (auth) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      StateContainer.of(context).getSeed().then((String seed) {
        Sheets.showAppHeightNineSheet(
            context: context, widget: AppSeedBackupSheet(seed));
      });
    }
  }

  Future<void> authenticateWithPin() async {
    // PIN Authentication
    final Vault _vault = await Vault.getInstance();
    final String? expectedPin = _vault.getPin();
    final bool auth = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) {
      return PinScreen(
        PinOverlayType.enterPin,
        expectedPin: expectedPin!,
        description: AppLocalization.of(context)!.pinSecretPhraseBackup,
      );
    })) as bool;
    if (auth) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      StateContainer.of(context).getSeed().then((String seed) {
        Sheets.showAppHeightNineSheet(
            context: context, widget: AppSeedBackupSheet(seed));
      });
    }
  }
}
