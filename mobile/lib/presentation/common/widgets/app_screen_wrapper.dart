import 'package:flutter/material.dart';
import '../../../core/utils/extensions.dart';

class AppScreenWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool useSafeArea;
  final bool scrollable;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const AppScreenWrapper({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.useSafeArea = true,
    this.scrollable = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: child,
      );
    }

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(
                title!,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: actions,
            )
          : null,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
