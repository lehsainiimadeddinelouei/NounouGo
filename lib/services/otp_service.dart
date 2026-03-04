import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Gmail config ──
  static const String _gmailUser = 'lehsainiimadeddinelouei@gmail.com';
  static const String _gmailAppPassword = 'neahxgedyyetclzw';

  // ── Générer un code OTP à 6 chiffres ──
  static String _generateCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  // ── Envoyer OTP via Gmail SMTP ──
  static Future<bool> _sendEmailOtp({
    required String toEmail,
    required String code,
  }) async {
    try {
      final smtpServer = gmail(_gmailUser, _gmailAppPassword);

      final message = Message()
        ..from = Address(_gmailUser, 'NounouGo')
        ..recipients.add(toEmail)
        ..subject = 'NounouGo - Votre code de vérification'
        ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #FFF5F7; border-radius: 16px;">
            <h2 style="color: #2D3561; text-align: center;">🔐 Code de vérification</h2>
            <p style="color: #ADB5BD; text-align: center;">Votre code NounouGo est :</p>
            <div style="background: white; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
              <span style="font-size: 42px; font-weight: 800; letter-spacing: 12px; color: #E8748A;">$code</span>
            </div>
            <p style="color: #ADB5BD; text-align: center; font-size: 13px;">⏱ Ce code expire dans <strong>10 minutes</strong></p>
            <p style="color: #ADB5BD; text-align: center; font-size: 12px;">Ne partagez ce code avec personne.</p>
            <hr style="border: none; border-top: 1px solid #FFD6DF; margin: 24px 0;">
            <p style="color: #ADB5BD; text-align: center; font-size: 12px;">L'équipe NounouGo 💝</p>
          </div>
        ''';

      final sendReport = await send(message, smtpServer);
      print('Email envoyé : ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      print('Mailer erreur: ${e.message}');
      for (var p in e.problems) {
        print('Problème: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      print('Erreur email: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Envoyer OTP via numéro de téléphone
  // ─────────────────────────────────────────────
  static Future<OtpResult> sendOtpByPhone({required String phone}) async {
    try {
      final query = await _db
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return OtpResult(
          success: false,
          message: 'Aucun compte trouvé avec ce numéro.',
        );
      }

      final userDoc = query.docs.first;
      final email = userDoc['email'] as String;
      final uid = userDoc['uid'] as String;

      return await _sendAndStoreOtp(uid: uid, email: email);
    } catch (e) {
      return OtpResult(success: false, message: 'Erreur : $e');
    }
  }

  // ─────────────────────────────────────────────
  // Envoyer OTP via email directement
  // ─────────────────────────────────────────────
  static Future<OtpResult> sendOtpByEmail({required String email}) async {
    try {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return OtpResult(
          success: false,
          message: 'Aucun compte trouvé avec cet email.',
        );
      }

      final userDoc = query.docs.first;
      final uid = userDoc['uid'] as String;

      return await _sendAndStoreOtp(uid: uid, email: email.trim());
    } catch (e) {
      return OtpResult(success: false, message: 'Erreur : $e');
    }
  }

  // ─────────────────────────────────────────────
  // Générer + stocker + envoyer le code OTP
  // ─────────────────────────────────────────────
  static Future<OtpResult> _sendAndStoreOtp({
    required String uid,
    required String email,
  }) async {
    final code = _generateCode();
    final expiry = DateTime.now().add(const Duration(minutes: 10));

    // Stocker dans Firestore
    await _db.collection('otp_codes').doc(uid).set({
      'code': code,
      'email': email,
      'expiresAt': Timestamp.fromDate(expiry),
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Envoyer via Gmail SMTP
    final sent = await _sendEmailOtp(toEmail: email, code: code);

    if (!sent) {
      return OtpResult(
        success: true,
        message: 'Code généré (email non envoyé).',
        email: _maskEmail(email),
        uid: uid,
        devCode: code, // affiché dans l'app si email échoue
      );
    }

    return OtpResult(
      success: true,
      message: 'Code envoyé à votre email !',
      email: _maskEmail(email),
      uid: uid,
    );
  }

  // ─────────────────────────────────────────────
  // Vérifier le code OTP
  // ─────────────────────────────────────────────
  static Future<OtpResult> verifyOtp({
    required String uid,
    required String code,
  }) async {
    try {
      final doc = await _db.collection('otp_codes').doc(uid).get();

      if (!doc.exists) return OtpResult(success: false, message: 'Code invalide.');

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final used = data['used'] as bool;

      if (used) return OtpResult(success: false, message: 'Code déjà utilisé.');
      if (DateTime.now().isAfter(expiresAt))
        return OtpResult(success: false, message: 'Code expiré. Demandez-en un nouveau.');
      if (storedCode != code.trim())
        return OtpResult(success: false, message: 'Code incorrect.');

      await _db.collection('otp_codes').doc(uid).update({'used': true});
      return OtpResult(success: true, message: 'Code vérifié !', uid: uid);
    } catch (e) {
      return OtpResult(success: false, message: 'Erreur : $e');
    }
  }

  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '$name***@$domain';
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }
}

class OtpResult {
  final bool success;
  final String message;
  final String? email;
  final String? uid;
  final String? devCode;

  const OtpResult({
    required this.success,
    required this.message,
    this.email,
    this.uid,
    this.devCode,
  });
}
