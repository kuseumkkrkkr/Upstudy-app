import 'package:flutter/material.dart';
import 'package:s11/pages/course_pages.dart';

VoidCallback buildCourseAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(() {
      navigator.push(
        MaterialPageRoute(builder: (_) => const CourseCatalogPage()),
      );
    });
  };
}
