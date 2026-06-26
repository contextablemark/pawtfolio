import 'package:flutter/material.dart';
import 'package:pawtfolio/home_page.dart';
import 'package:pawtfolio/theme.dart';

class PawtfolioApp extends StatelessWidget {
  const PawtfolioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pawtfolio',
    debugShowCheckedModeBanner: false,
    theme: buildPawtfolioTheme(),
    home: const HomePage(),
  );
}
