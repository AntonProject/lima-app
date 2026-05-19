import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _savedLoginKey = 'saved_login';
  static const _rememberLoginKey = 'remember_login';

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _rememberMe = prefs.getBool(_rememberLoginKey) ?? true;
    if (_rememberMe) {
      _usernameCtrl.text = prefs.getString(_savedLoginKey) ?? '';
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final prefs = ref.read(sharedPreferencesProvider);
      if (_rememberMe) {
        await prefs.setString(_savedLoginKey, _usernameCtrl.text.trim());
        await prefs.setBool(_rememberLoginKey, true);
      } else {
        await prefs.remove(_savedLoginKey);
        await prefs.setBool(_rememberLoginKey, false);
      }
      ref
          .read(authProvider.notifier)
          .login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final localeCode = ref.watch(appLocaleCodeProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final canSubmit =
        _usernameCtrl.text.trim().isNotEmpty &&
        _passwordCtrl.text.isNotEmpty &&
        !isLoading;
    final mq = MediaQuery.of(context);
    final isKeyboardOpen = mq.viewInsets.bottom > 0;
    final minHeight =
        mq.size.height -
        mq.padding.top -
        mq.padding.bottom -
        mq.viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _LoginBackground(),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minHeight > 0 ? minHeight : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/logo.png',
                                  width: 36,
                                  height: 36,
                                ),
                                Text(
                                  'LIMA',
                                  style: GoogleFonts.figtree(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: localeCode,
                                  borderRadius: BorderRadius.circular(12),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'ru',
                                      child: Text('RU'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'en',
                                      child: Text('EN'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'uz_latn',
                                      child: Text('UZ'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'uz_cyrl',
                                      child: Text('ЎЗ'),
                                    ),
                                  ],
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    await ref
                                        .read(appLocaleProvider.notifier)
                                        .setLocale(v);
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.l10n.t('login'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  context.l10n.t('loginLabel'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _usernameCtrl,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.t('enterLogin'),
                                    isDense: true,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? context.l10n.t('enterLogin')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.l10n.t('password'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) => setState(() {}),
                                  onFieldSubmitted: (_) {
                                    if (canSubmit) _submit();
                                  },
                                  decoration: InputDecoration(
                                    hintText: context.l10n.t('password'),
                                    isDense: true,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? context.l10n.t('enterPassword')
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.t('rememberMe'),
                                      style: GoogleFonts.manrope(
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (auth.errorMessage != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      auth.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: AppColors.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed: canSubmit ? _submit : null,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      46,
                                    ),
                                    backgroundColor: AppColors.primary,
                                    disabledBackgroundColor: const Color(
                                      0xFFC8D3F2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          context.l10n.t('login'),
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: AppColors.divider),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.t('techSupportTitle'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+998 90 020 22 25',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isKeyboardOpen) ...[
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '© LIMA NEO TECHNO, 2026',
                            style: GoogleFonts.manrope(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F59E6), Color(0xFF0B3EB8), Color(0xFF082F98)],
        ),
      ),
      child: CustomPaint(
        painter: _WavePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white.withValues(alpha: 0.16);

    for (int i = 0; i < 18; i++) {
      final path = Path();
      final yBase = size.height * 0.08 + i * (size.height * 0.055);
      path.moveTo(0, yBase);
      for (double x = 0; x <= size.width; x += 8) {
        final y =
            yBase +
            math.sin((x / size.width) * math.pi * 2 + i * 0.35) *
                (10 + (i % 4) * 4);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
