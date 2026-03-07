import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

Future<bool> _hasInternetAccess() async {
  // `dart:io` DNS lookups are not supported on web and report false negatives.
  if (kIsWeb) return true;

  try {
    final result = await InternetAddress.lookup('example.com')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

bool _hasNetworkTransport(dynamic result) {
  if (result is ConnectivityResult) {
    return result != ConnectivityResult.none;
  }
  if (result is List<ConnectivityResult>) {
    return result.any((r) => r != ConnectivityResult.none);
  }
  return false;
}

Future<bool> _resolveOnlineStatus(Connectivity connectivity) async {
  final result = await connectivity.checkConnectivity();
  if (!_hasNetworkTransport(result)) {
    return false;
  }
  if (kIsWeb) return true;
  return _hasInternetAccess();
}

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  final controller = StreamController<bool>.broadcast();

  Future<void> emitStatus() async {
    final isOnline = await _resolveOnlineStatus(connectivity);
    if (!controller.isClosed) {
      controller.add(isOnline);
    }
  }

  emitStatus();

  final sub = connectivity.onConnectivityChanged.listen((_) {
    emitStatus();
  });

  final timer = Timer.periodic(const Duration(seconds: 5), (_) {
    emitStatus();
  });

  ref.onDispose(() {
    sub.cancel();
    timer.cancel();
    controller.close();
  });

  return controller.stream.distinct();
});
