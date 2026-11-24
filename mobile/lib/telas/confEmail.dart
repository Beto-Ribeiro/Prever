import 'dart:async';
import 'package:flutter/foundation.dart';
import 'exportador_import.dart';

class ConfEmail extends StatefulWidget {
  final Function(int) onChangePage;
  final String? email;
  final String? senha;
  final Future<bool> Function(String email, String senha)? onVerificarSessao;
  final Future<void> Function(String email, String redirectTo)? onReenviarEmail;

  const ConfEmail({
    super.key,
    required this.title,
    required this.email,
    required this.senha,
    required this.onChangePage,
    this.onVerificarSessao,
    this.onReenviarEmail,
  });

  final String title;

  @override
  State<ConfEmail> createState() => _confEmail_state();
}

class _confEmail_state extends State<ConfEmail> {
  bool _verificando = false;
  bool _reenviando = false;
  int _segundosCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _iniciarCooldown([int segundos = 60]) {
    _cooldownTimer?.cancel();
    setState(() {
      _segundosCooldown = segundos;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosCooldown <= 1) {
        timer.cancel();
        setState(() {
          _segundosCooldown = 0;
        });
      } else {
        setState(() {
          _segundosCooldown -= 1;
        });
      }
    });
  }

  Future<void> reenviarConfirmacao() async {
    final email = widget.email?.trim() ?? '';
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'E-mail não informado. Volte para a tela de cadastro e tente novamente.',
            ),
          ),
        );
      }
      return;
    }

    if (_reenviando || _segundosCooldown > 0) return;

    setState(() {
      _reenviando = true;
    });

    try {
      final redirectTo = kIsWeb
          ? Uri.base.origin
          : 'com.prever.app://login-callback';
      if (widget.onReenviarEmail != null) {
        await widget.onReenviarEmail!(email, redirectTo);
      } else {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: redirectTo,
        );
      }

      if (!mounted) return;
      _iniciarCooldown(60);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Novo e-mail de confirmação enviado! Verifique sua caixa de entrada e spam.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      final texto = msg.contains('rate limit') || e.statusCode == '429'
          ? 'Aguarde alguns instantes antes de solicitar um novo e-mail.'
          : 'Não foi possível reenviar o e-mail: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(texto)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível reenviar o e-mail de confirmação. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reenviando = false;
        });
      }
    }
  }

  Future<void> verificarConfirmacao() async {
    // IMPORTANTE: Nunca registrar credenciais em logs de produção.
    debugPrint('Verificando confirmação de e-mail...');
    if (widget.email == null ||
        widget.email!.trim().isEmpty ||
        widget.senha == null ||
        widget.senha!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro: e-mail ou senha não foram recebidos. Tente entrar pela tela de login.',
            ),
          ),
        );
      }
      return;
    }

    if (_verificando) return;

    setState(() {
      _verificando = true;
    });

    try {
      bool sessaoIniciada;
      if (widget.onVerificarSessao != null) {
        sessaoIniciada = await widget.onVerificarSessao!(
          widget.email!.trim(),
          widget.senha!,
        );
      } else {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: widget.email!.trim(),
          password: widget.senha!,
        );
        sessaoIniciada = response.session != null;
      }

      if (!mounted) return;

      if (sessaoIniciada) {
        widget.onChangePage(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível iniciar a sessão. Tente novamente.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      debugPrint('AuthException na confirmação de e-mail: ${e.statusCode}');
      String mensagem;
      final lower = e.message.toLowerCase();
      if (lower.contains('email not confirmed') ||
          lower.contains('email não confirmado')) {
        mensagem =
            'E-mail ainda não confirmado. Verifique sua caixa de entrada e spam.';
      } else if (lower.contains('invalid login credentials') ||
          lower.contains('invalid')) {
        mensagem = 'Credenciais inválidas. Tente entrar pela tela de login.';
      } else if (lower.contains('rate limit') || e.statusCode == '429') {
        mensagem =
            'Muitas tentativas seguidas. Aguarde alguns instantes e tente novamente.';
      } else {
        mensagem = 'Erro: ${e.message}';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    } catch (_) {
      debugPrint('Erro genérico na confirmação de e-mail');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro inesperado. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _verificando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailMascarado = widget.email?.trim() ?? '';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: AbstractBackgroundPainter(
                primaryColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                secondaryColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.3),
                tertiaryColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: SvgPicture.asset(
                          'gfx/svg/Image/Prever_logo.svg',
                          semanticsLabel: 'Logo Prever',
                          height: 60,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(25, 28, 25, 32),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Confirme seu e-mail de cadastro\npara prosseguir',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0B1426),
                              ),
                            ),
                            if (emailMascarado.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Enviamos um link para $emailMascarado',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton(
                              key: const Key('botao_ja_confirmei'),
                              onPressed: _verificando
                                  ? null
                                  : verificarConfirmacao,
                              child: _verificando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Já confirmei!'),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              key: const Key('botao_reenviar_confirmacao'),
                              onPressed: (_reenviando || _segundosCooldown > 0)
                                  ? null
                                  : reenviarConfirmacao,
                              child: _reenviando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _segundosCooldown > 0
                                          ? 'Reenviar e-mail (${_segundosCooldown}s)'
                                          : 'Reenviar e-mail de confirmação',
                                    ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                widget.onChangePage(8);
                              },
                              child: const Text(
                                'Ir para Login',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: Colors.blueGrey,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
