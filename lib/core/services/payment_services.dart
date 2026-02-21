import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import '../config/supabase_config.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final Dio _dio = Dio();
  
  // IMPORTANT: Never expose your Stripe secret key in the app!
  // These should be handled by your backend/Supabase Edge Functions
  static const String _publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'YOUR_PUBLISHABLE_KEY',
  );

  Future<void> initialize() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Create a payment intent (call your backend/Supabase function)
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String bookingId,
  }) async {
    try {
      // Call Supabase Edge Function to create payment intent
      final response = await SupabaseConfig.client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': (amount * 100).toInt(), // Convert to cents
          'currency': currency,
          'booking_id': bookingId,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  /// Process payment with card
  Future<bool> processPayment({
    required String clientSecret,
    required String bookingId,
  }) async {
    try {
      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'MSpace',
          style: ThemeMode.system,
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful - update booking in database
      await SupabaseConfig.client.from('bookings').update({
        'payment_status': 'held', // Escrow: money is held
      }).eq('id', bookingId);

      return true;
    } on StripeException catch (e) {
      print('Stripe error: ${e.error.message}');
      return false;
    } catch (e) {
      print('Payment error: $e');
      return false;
    }
  }

  /// Release payment (when job is completed)
  Future<bool> releasePayment({
    required String bookingId,
    required String paymentIntentId,
  }) async {
    try {
      // Call Supabase Edge Function to release payment
      final response = await SupabaseConfig.client.functions.invoke(
        'release-payment',
        body: {
          'booking_id': bookingId,
          'payment_intent_id': paymentIntentId,
        },
      );

      if (response.status == 200) {
        // Update booking status
        await SupabaseConfig.client.from('bookings').update({
          'payment_status': 'released',
        }).eq('id', bookingId);

        return true;
      }

      return false;
    } catch (e) {
      print('Release payment error: $e');
      return false;
    }
  }

  /// Refund payment
  Future<bool> refundPayment({
    required String bookingId,
    required String paymentIntentId,
  }) async {
    try {
      // Call Supabase Edge Function to refund
      final response = await SupabaseConfig.client.functions.invoke(
        'refund-payment',
        body: {
          'booking_id': bookingId,
          'payment_intent_id': paymentIntentId,
        },
      );

      if (response.status == 200) {
        await SupabaseConfig.client.from('bookings').update({
          'payment_status': 'refunded',
        }).eq('id', bookingId);

        return true;
      }

      return false;
    } catch (e) {
      print('Refund error: $e');
      return false;
    }
  }
}