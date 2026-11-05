import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // A tap that misses must fail the test, rather than letting assertions pass
  // without exercising the intended control.
  WidgetController.hitTestWarningShouldBeFatal = true;
  await testMain();
}
