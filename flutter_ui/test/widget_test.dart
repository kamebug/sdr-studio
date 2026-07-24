// Teste mínimo de smoke test — confirma que o app inicializa e mostra
// pelo menos um MaterialApp na árvore de widgets, sem travar.
//
// O template padrão do "flutter create" referenciava uma classe "MyApp"
// que nunca existiu neste projeto (o widget raiz real é SdrStudioApp,
// em lib/main.dart) — esse era o erro que o "flutter analyze" apontava.
//
// Um teste mais completo (testando o carregamento do core Rust via FFI,
// navegação entre telas, etc.) fica para quando a integração com
// hardware estiver mais madura — FFI e plugins nativos (SoLoud) tornam
// testes de widget completos mais trabalhosos de configurar em CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sdr_studio/main.dart';

void main() {
  testWidgets('SdrStudioApp builds without throwing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const SdrStudioApp(initialLocale: Locale('en')),
    );

    // Não avança o tempo suficiente para o carregamento do core Rust
    // (FFI) ou do motor de áudio serem exercitados aqui — só confirma
    // que a árvore de widgets inicial monta sem exceção.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
