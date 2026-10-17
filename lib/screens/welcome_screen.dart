import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../main.dart';
import 'account_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.api});
  final ApiService api;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF07182C), Color(0xFF0C3B62), Color(0xFF102C49)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _MetroLinesPainter())),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0868E8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.accessible_forward,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Text(
                      'AcessaMetrô',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .35),
                    ),
                  ),
                  child: const Icon(
                    Icons.accessible_forward,
                    size: 51,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AcessaMetrô',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 280,
                  child: Text(
                    'Informação real para um transporte mais acessível.',
                    style: TextStyle(
                      color: Color(0xFFD6E6F2),
                      fontSize: 18,
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => _openLogin(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF0868E8),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Entrar ou criar conta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => AppShell(api: api)),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFBDD3E5)),
                  ),
                  child: const Text('Explorar sem conta'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _openLogin(BuildContext context) async {
    final loggedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LoginScreen(api: api)));
    if (loggedIn == true && context.mounted) {
      await Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => AppShell(api: api)));
    }
  }
}

class _MetroLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF8BC5E8).withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final stationPaint = Paint()
      ..color = const Color(0xFFB8E8D2).withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = 0; index < 6; index++) {
      final path = Path()
        ..moveTo(size.width * .52, -30 + index * 15)
        ..lineTo(size.width * .52, size.height * .3)
        ..lineTo(size.width * .22, size.height * .49)
        ..lineTo(size.width * .22, size.height + 30);
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(
        Offset(size.width * .52, size.height * (.18 + index * .08)),
        5,
        stationPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
