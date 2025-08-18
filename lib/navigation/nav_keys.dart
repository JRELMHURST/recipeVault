import 'package:flutter/widgets.dart';

class NavKeys {
  NavKeys._();

  static final GlobalKey<NavigatorState> root = GlobalKey<NavigatorState>(
    debugLabel: 'rootNav',
  );

  static final GlobalKey<NavigatorState> shell = GlobalKey<NavigatorState>(
    debugLabel: 'shellNav',
  );
}
