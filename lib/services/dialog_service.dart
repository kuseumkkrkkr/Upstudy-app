import 'package:flutter/material.dart';
import '../dialogs/buildbox_widget.dart';

class DialogService {
  static void openDialog(BuildContext context, {String title = '설정 창'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(0),
          child: BuildboxWidget(title: title),
        );
      },
    );
  }
}
