import 'package:flutter/material.dart';
import 'package:s11/features/textbook/ui/pages/book_page.dart';

VoidCallback buildBookAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(
      // ignore: use_build_context_synchronously
      () => showBookLibraryModal(context: navigator.context),
    );
  };
}
