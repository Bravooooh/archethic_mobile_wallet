// @dart=2.9

// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:archethic_mobile_wallet/ui/widgets/icon_widget.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Project imports:
import 'package:archethic_mobile_wallet/appstate_container.dart';
import 'package:archethic_mobile_wallet/localization.dart';
import 'package:archethic_mobile_wallet/service_locator.dart';
import 'package:archethic_mobile_wallet/styles.dart';
import 'package:archethic_mobile_wallet/util/hapticutil.dart';
import 'package:archethic_mobile_wallet/util/sharedprefsutil.dart';

enum PinOverlayType { NEW_PIN, ENTER_PIN }

class ShakeCurve extends Curve {
  @override
  double transform(double t) {
    //t from 0.0 to 1.0
    return sin(t * 3 * pi);
  }
}

class PinScreen extends StatefulWidget {
  const PinScreen(this.type,
      {this.description = '',
      this.expectedPin = '',
      this.pinScreenBackgroundColor});

  final PinOverlayType type;
  final String expectedPin;
  final String description;
  final Color pinScreenBackgroundColor;

  @override
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  static const int MAX_ATTEMPTS = 5;

  int _pinLength = 6;
  double buttonSize = 100.0;

  String pinEnterTitle = '';
  String pinCreateTitle = '';

  // Stateful data
  List<IconData> _dotStates;
  String _pin;
  String _pinConfirmed;
  bool
      _awaitingConfirmation; // true if pin has been entered once, false if not entered once
  String _header;
  int _failedAttempts = 0;
  final List<int> _listPinNumber = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 0];

  // Invalid animation
  AnimationController _controller;
  Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    sl.get<SharedPrefsUtil>().getPinPadShuffle().then((bool value) {
      if (value) {
        _listPinNumber.shuffle();
      }
    });

    // Initialize list all empty
    if (widget.type == PinOverlayType.ENTER_PIN) {
      _header = pinEnterTitle;
      _pinLength = widget.expectedPin.length;
    } else {
      _header = pinCreateTitle;
    }
    _dotStates = List<IconData>.filled(_pinLength, FontAwesomeIcons.minus);
    _awaitingConfirmation = false;
    _pin = '';
    _pinConfirmed = '';
    // Get adjusted failed attempts
    sl.get<SharedPrefsUtil>().getLockAttempts().then((int attempts) {
      setState(() {
        _failedAttempts = attempts % MAX_ATTEMPTS;
      });
    });
    // Set animation
    _controller = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    final Animation curve =
        CurvedAnimation(parent: _controller, curve: ShakeCurve());
    _animation = Tween<double>(begin: 0.0, end: 25.0).animate(curve)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          if (widget.type == PinOverlayType.ENTER_PIN) {
            sl.get<SharedPrefsUtil>().incrementLockAttempts().then((_) {
              _failedAttempts++;
              if (_failedAttempts >= MAX_ATTEMPTS) {
                setState(() {
                  _controller.value = 0;
                });
                sl.get<SharedPrefsUtil>().updateLockDate().then((_) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      '/lock_screen_transition',
                      (Route<dynamic> route) => false);
                });
              } else {
                setState(() {
                  _pin = '';
                  _header = AppLocalization.of(context).pinInvalid;
                  _dotStates =
                      List<IconData>.filled(_pinLength, FontAwesomeIcons.minus);
                  _controller.value = 0;
                });
              }
            });
          } else {
            setState(() {
              _awaitingConfirmation = false;
              _dotStates =
                  List<IconData>.filled(_pinLength, FontAwesomeIcons.minus);
              _pin = '';
              _pinConfirmed = '';
              _header = AppLocalization.of(context).pinConfirmError;
              _controller.value = 0;
            });
          }
        }
      })
      ..addListener(() {
        setState(() {
          // the animation object’s value is the changed state
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Set next character in the pin set
  /// return true if all characters entered
  bool _setCharacter(String character) {
    if (_awaitingConfirmation) {
      setState(() {
        _pinConfirmed = _pinConfirmed + character;
      });
    } else {
      setState(() {
        _pin = _pin + character;
      });
    }
    for (int i = 0; i < _dotStates.length; i++) {
      if (_dotStates[i] == FontAwesomeIcons.minus) {
        setState(() {
          _dotStates[i] = FontAwesomeIcons.solidCircle;
        });
        break;
      }
    }
    if (_dotStates.last == FontAwesomeIcons.solidCircle) {
      return true;
    }
    return false;
  }

  void _backSpace() {
    if (_dotStates[0] != FontAwesomeIcons.minus) {
      int lastFilledIndex;
      for (int i = 0; i < _dotStates.length; i++) {
        if (_dotStates[i] == FontAwesomeIcons.solidCircle) {
          if (i == _dotStates.length ||
              _dotStates[i + 1] == FontAwesomeIcons.minus) {
            lastFilledIndex = i;
            break;
          }
        }
      }
      setState(() {
        _dotStates[lastFilledIndex] = FontAwesomeIcons.minus;
        if (_awaitingConfirmation) {
          _pinConfirmed = _pinConfirmed.substring(0, _pinConfirmed.length - 1);
        } else {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      });
    }
  }

  Widget _buildPinScreenButton(String buttonText, BuildContext context) {
    return Container(
      height: smallScreen(context) ? buttonSize - 15 : buttonSize,
      width: smallScreen(context) ? buttonSize - 15 : buttonSize,
      child: InkWell(
          borderRadius: BorderRadius.circular(200),
          highlightColor: StateContainer.of(context).curTheme.primary15,
          splashColor: StateContainer.of(context).curTheme.primary30,
          onTap: () {},
          onTapDown: (TapDownDetails details) {
            if (_controller.status == AnimationStatus.forward ||
                _controller.status == AnimationStatus.reverse) {
              return;
            }
            if (_setCharacter(buttonText)) {
              // Mild delay so they can actually see the last dot get filled
              Future<void>.delayed(const Duration(milliseconds: 50), () {
                if (widget.type == PinOverlayType.ENTER_PIN) {
                  // Pin is not what was expected
                  if (_pin != widget.expectedPin) {
                    sl.get<HapticUtil>().feedback(FeedbackType.error);
                    _controller.forward();
                  } else {
                    sl.get<SharedPrefsUtil>().resetLockAttempts().then((_) {
                      Navigator.of(context).pop(true);
                    });
                  }
                } else {
                  if (!_awaitingConfirmation) {
                    // Switch to confirm pin
                    setState(() {
                      _awaitingConfirmation = true;
                      _dotStates = List<IconData>.filled(
                          _pinLength, FontAwesomeIcons.minus);
                      _header = AppLocalization.of(context).pinConfirmTitle;
                    });
                  } else {
                    // First and second pins match
                    if (_pin == _pinConfirmed) {
                      Navigator.of(context).pop(_pin);
                    } else {
                      sl.get<HapticUtil>().feedback(FeedbackType.error);
                      _controller.forward();
                    }
                  }
                }
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                    color: StateContainer.of(context).curTheme.background40,
                    blurRadius: 15,
                    spreadRadius: -15),
              ],
            ),
            alignment: const AlignmentDirectional(0, 0),
            child: Text(
              buttonText,
              textAlign: TextAlign.center,
              style: AppStyles.textStyleSize20W700Primary(context),
            ),
          )),
    );
  }

  List<Widget> _buildPinDots() {
    final List<Widget> ret = List<Widget>.empty(growable: true);
    for (int i = 0; i < _pinLength; i++) {
      ret.add(FaIcon(_dotStates[i],
          color: StateContainer.of(context).curTheme.primary, size: 15.0));
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    if (pinEnterTitle.isEmpty) {
      setState(() {
        pinEnterTitle = AppLocalization.of(context).pinEnterTitle;
        if (widget.type == PinOverlayType.ENTER_PIN) {
          _header = pinEnterTitle;
        }
      });
    }
    if (pinCreateTitle.isEmpty) {
      setState(() {
        pinCreateTitle = AppLocalization.of(context).pinCreateTitle;
        if (widget.type == PinOverlayType.NEW_PIN) {
          _header = pinCreateTitle;
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              StateContainer.of(context).curTheme.backgroundDark,
              StateContainer.of(context).curTheme.background
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.1),
                child: Column(
                  children: <Widget>[
                    buildIconWidget(context, 'assets/icons/pin-code.png'),
                    const SizedBox(height: 30,),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      child: AutoSizeText(
                        _header,
                        style: AppStyles.textStyleSize16W400Primary(context),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        stepGranularity: 0.1,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 10),
                      child: AutoSizeText(
                        widget.description,
                        style: AppStyles.textStyleSize16W200Primary(context),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        stepGranularity: 0.1,
                      ),
                    ),
                    Container(
                      margin: EdgeInsetsDirectional.only(
                        start: MediaQuery.of(context).size.width * 0.25 +
                            _animation.value,
                        end: MediaQuery.of(context).size.width * 0.25 -
                            _animation.value,
                        top: MediaQuery.of(context).size.height * 0.02,
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _buildPinDots()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width * 0.07,
                      right: MediaQuery.of(context).size.width * 0.07,
                      bottom: smallScreen(context)
                          ? MediaQuery.of(context).size.height * 0.02
                          : MediaQuery.of(context).size.height * 0.05,
                      top: MediaQuery.of(context).size.height * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.01),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(0).toString(),
                                context),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(1).toString(),
                                context),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(2).toString(),
                                context),
                          ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.01),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(3).toString(),
                                context),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(4).toString(),
                                context),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(5).toString(),
                                context),
                          ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.01),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(6).toString(),
                                context),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(7).toString(),
                                context),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(8).toString(),
                                context),
                          ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.009),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            SizedBox(
                              height: smallScreen(context)
                                  ? buttonSize - 15
                                  : buttonSize,
                              width: smallScreen(context)
                                  ? buttonSize - 15
                                  : buttonSize,
                            ),
                            _buildPinScreenButton(
                                _listPinNumber.elementAt(9).toString(),
                                context),
                            Container(
                              height: smallScreen(context)
                                  ? buttonSize - 15
                                  : buttonSize,
                              width: smallScreen(context)
                                  ? buttonSize - 15
                                  : buttonSize,
                              child: InkWell(
                                  borderRadius: BorderRadius.circular(200),
                                  highlightColor: StateContainer.of(context)
                                      .curTheme
                                      .primary15,
                                  splashColor: StateContainer.of(context)
                                      .curTheme
                                      .primary30,
                                  onTap: () {},
                                  onTapDown: (TapDownDetails details) {
                                    _backSpace();
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                            color: StateContainer.of(context)
                                                .curTheme
                                                .background40,
                                            blurRadius: 15,
                                            spreadRadius: -15),
                                      ],
                                    ),
                                    alignment: const AlignmentDirectional(0, 0),
                                    child: FaIcon(Icons.backspace,
                                        color: StateContainer.of(context)
                                            .curTheme
                                            .primary,
                                        size: 20.0),
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
