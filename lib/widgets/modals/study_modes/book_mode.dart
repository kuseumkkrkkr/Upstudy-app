import 'package:flutter/material.dart';
import 'package:s11/book_page.dart';

VoidCallback buildBookAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(() => showBookLibraryModal(context: navigator.context));
  };
}
