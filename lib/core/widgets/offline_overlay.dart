import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';

class OfflineOverlay extends ConsumerWidget {
  final Widget child;

  const OfflineOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(isOnlineStreamProvider);
    final isOnline = onlineAsync.value;

    if (isOnline == true) return child;

    final theme = Theme.of(context);
    final title = onlineAsync.isLoading
        ? 'Checking internet connection...'
        : 'You are offline';
    final subtitle = onlineAsync.isLoading
        ? 'Please wait while we verify your connection.'
        : 'Connect to the internet to continue.';
    final showRetry = !onlineAsync.isLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        onlineAsync.isLoading ? Icons.wifi_tethering : Icons.wifi_off,
                        size: 48,
                        color: onlineAsync.isLoading
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (showRetry) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref.refresh(isOnlineStreamProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
