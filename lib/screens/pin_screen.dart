import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/pin_service.dart';

import '../theme/app_colors.dart';

class PinScreen extends StatefulWidget {

  final String uid;

  final bool isSetup;

  final VoidCallback onUnlocked;

  const PinScreen({

    super.key,

    required this.uid,

    required this.isSetup,

    required this.onUnlocked,

  });

  @override

  State<PinScreen> createState() => _PinScreenState();

}

class _PinScreenState extends State<PinScreen> {

  String _pin = '';

  String? _firstPin;

  String? _message;

  bool _busy = false;

  Future<void> _digit(String value) async {

    if (_busy || _pin.length >= 4) return;

    setState(() {

      _pin += value;

      _message = null;

    });

    if (_pin.length != 4) return;

    final candidate = _pin;

    setState(() => _busy = true);

    try {

      if (widget.isSetup || _resetMode) {

        if (_firstPin == null) {

          setState(() {

            _firstPin = candidate;

            _pin = '';

          });

        } else if (_firstPin != candidate) {

          setState(() {

            _firstPin = null;

            _pin = '';

            _message = 'PINs did not match. Try again.';

          });

        } else {

          await PinService.instance.setPin(widget.uid, candidate);

          if (mounted) widget.onUnlocked();

        }

      } else {

        final lock = await PinService.instance.remainingLock(widget.uid);

        if (lock != null) {

          if (mounted)

            setState(() {

              _pin = '';

              _message = 'Too many attempts. Try again in 5 minutes.';

            });

        } else if (await PinService.instance.verifyPin(widget.uid, candidate)) {

          if (mounted) widget.onUnlocked();

        } else {

          final after = await PinService.instance.remainingLock(widget.uid);

          if (mounted)

            setState(() {

              _pin = '';

              _message = after == null

                  ? 'Incorrect PIN. Try again.'

                  : 'Too many attempts. Try again in 5 minutes.';

            });

        }

      }

    } catch (_) {

      if (mounted)

        setState(() {

          _pin = '';

          _message = 'PIN storage error. Please try again.';

        });

    } finally {

      if (mounted) setState(() => _busy = false);

    }

  }

  Future<void> _forgotPin() async {

    final password = await showDialog<String>(

      context: context,

      builder: (dialogContext) {

        String enteredPassword = '';

        return AlertDialog(

          title: const Text('Reset PIN'),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('Enter your account password to reset your PIN.'),

              const SizedBox(height: 12),

              TextField(

                obscureText: true,

                autofocus: true,

                onChanged: (value) {

                  enteredPassword = value;

                },

                decoration: const InputDecoration(

                  labelText: 'Account password',

                ),

              ),

            ],

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.of(dialogContext).pop();

              },

              child: const Text('Cancel'),

            ),

            TextButton(

              onPressed: () {

                Navigator.of(dialogContext).pop(enteredPassword);

              },

              child: const Text('Verify'),

            ),

          ],

        );

      },

    );

    if (!mounted || password == null || password.isEmpty) {

      return;

    }

    setState(() {

      _busy = true;

      _message = null;

    });

    try {

      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.uid != widget.uid || user.email == null) {

        if (mounted) {

          setState(() {

            _message = 'Please sign in again.';

          });

        }

        return;

      }

      await user.reauthenticateWithCredential(

        EmailAuthProvider.credential(email: user.email!, password: password),

      );

      if (!mounted) return;

      // Switch to PIN setup mode.

      // Keep the old PIN until the new PIN is saved successfully.

      setState(() {

        _firstPin = null;

        _pin = '';

        _resetMode = true;

        _message = null;

      });

    } on FirebaseAuthException catch (e) {

      if (mounted) {

        setState(() {

          _message =

              e.code == 'wrong-password' || e.code == 'invalid-credential'

              ? 'Incorrect password. Please try again.'

              : 'Password verification failed. Please try again.';

        });

      }

    } catch (_) {

      if (mounted) {

        setState(() {

          _message = 'Unable to reset PIN. Please try again.';

        });

      }

    } finally {

      if (mounted) {

        setState(() {

          _busy = false;

        });

      }

    }

  }

  bool _resetMode = false;

  @override

  Widget build(BuildContext context) {

    final setup = widget.isSetup || _resetMode;

    return Scaffold(

      backgroundColor: AppColors.background,

      body: SafeArea(

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(28),

            child: ConstrainedBox(

              constraints: const BoxConstraints(maxWidth: 360),

              child: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(

                    Icons.health_and_safety_rounded,

                    color: AppColors.primary,

                    size: 64,

                  ),

                  const SizedBox(height: 14),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Medi',
                          style: TextStyle(color: AppColors.primary),
                        ),
                        TextSpan(
                          text: 'KIN',
                          style: TextStyle(
                            color: AppColors.coral,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(

                    setup

                        ? (_firstPin == null

                              ? 'Create your 4-digit PIN'

                              : 'Confirm your PIN')

                        : 'Welcome back',

                    textAlign: TextAlign.center,

                    style: const TextStyle(

                      fontSize: 24,

                      fontWeight: FontWeight.bold,

                      color: AppColors.darkText,

                    ),

                  ),

                  const SizedBox(height: 12),

                  Text(

                    setup

                        ? 'Use this PIN to unlock MediKIN on this device.'

                        : 'Enter your 4-digit PIN to unlock MediKIN.',

                    textAlign: TextAlign.center,

                    style: const TextStyle(color: AppColors.secondaryText),

                  ),

                  const SizedBox(height: 30),

                  Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: List.generate(

                      4,

                      (i) => Container(

                        margin: const EdgeInsets.symmetric(horizontal: 10),

                        width: 17,

                        height: 17,

                        decoration: BoxDecoration(

                          shape: BoxShape.circle,

                          color: i < _pin.length

                              ? AppColors.primary

                              : Colors.transparent,

                          border: Border.all(

                            color: AppColors.primary,

                            width: 2,

                          ),

                        ),

                      ),

                    ),

                  ),

                  const SizedBox(height: 18),

                  if (_message != null)

                    Text(

                      _message!,

                      textAlign: TextAlign.center,

                      style: const TextStyle(color: AppColors.error),

                    ),

                  const SizedBox(height: 20),

                  for (final row in [

                    ['1', '2', '3'],

                    ['4', '5', '6'],

                    ['7', '8', '9'],

                    ['', '0', '⌫'],

                  ])

                    Row(

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: row

                          .map(

                            (value) => SizedBox(

                              width: 88,

                              height: 70,

                              child: value.isEmpty

                                  ? const SizedBox.shrink()

                                  : TextButton(

                                      onPressed: _busy

                                          ? null

                                          : () {

                                              if (value == '⌫') {

                                                if (_pin.isNotEmpty)

                                                  setState(

                                                    () => _pin = _pin.substring(

                                                      0,

                                                      _pin.length - 1,

                                                    ),

                                                  );

                                              } else {

                                                _digit(value);

                                              }

                                            },

                                      child: Text(

                                        value,

                                        style: const TextStyle(

                                          fontSize: 26,

                                          color: AppColors.darkText,

                                        ),

                                      ),

                                    ),

                            ),

                          )

                          .toList(),

                    ),

                  if (!setup)

                    TextButton(

                      onPressed: _busy ? null : _forgotPin,

                      child: const Text('Forgot PIN?'),

                    ),

                  if (setup)

                    TextButton(

                      onPressed: _busy

                          ? null

                          : () async {

                              await PinService.instance.clearForUser(

                                widget.uid,

                              );

                              await FirebaseAuth.instance.signOut();

                            },

                      child: const Text('Use another account'),

                    ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

}
