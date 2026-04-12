import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reliefnet/themes/theme_provider.dart';

class AppBarComponent extends StatelessWidget implements PreferredSizeWidget {
  const AppBarComponent({
    super.key,
    required this.appBarText,
  });

  final String appBarText;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return AppBar(
      title: Text(appBarText,style: TextStyle(fontSize: 20),),
      actions: [
        IconButton(
          onPressed: () => themeProvider.toggleTheme(),
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
      ],
    );
  }
}