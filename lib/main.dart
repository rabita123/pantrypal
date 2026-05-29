import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:pantrypal/app.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:pantrypal/shared/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await setupDependencies();
  await NotificationService.instance.init();

  final rcApiKey =
      Platform.isIOS ? 'appl_vldzueYBTHHQdGdeSsRyRKpEvJN' : 'goog_XXXXXXXXXX';
  await Purchases.configure(PurchasesConfiguration(rcApiKey));

  runApp(const PantryPalApp());
}
