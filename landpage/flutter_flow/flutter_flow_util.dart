import 'package:flutter/widgets.dart';

T createModel<T>(BuildContext context, T Function() creator) {
  return creator();
}

// Add other small utilities expected by generated code as needed.
