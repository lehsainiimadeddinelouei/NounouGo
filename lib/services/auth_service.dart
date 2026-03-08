import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Utilisateur courant ──
  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────
  // CRÉER UN COMPTE
  // ─────────────────────────────────────────────
  static Future<AuthResult> register({
    required String prenom,
    required String nom,
    required String email,
    required String password,
    required String phone,
    required String role,
    List<String> ageGroups = const [],
  }) async {
    try {
      // 0. Vérifier si l'email est dans deleted_accounts (banni par l'admin)
      final emailLower = email.trim().toLowerCase();
      final deletedSnap = await _db
          .collection('deleted_accounts')
          .where('email', isEqualTo: emailLower)
          .limit(1)
          .get();
      if (deletedSnap.docs.isNotEmpty) {
        return AuthResult(
          success: false,
          message: "Ce compte a été supprimé. Contactez le support pour plus d'informations.",
        );
      }

      // 1. Créer le compte Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;

      // 2. Mettre à jour le displayName
      await user.updateDisplayName('$prenom $nom');

      // 3. Envoyer l'email de vérification
      await user.sendEmailVerification();

      // 4. Sauvegarder le profil dans Firestore
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'prenom': prenom.trim(),
        'nom': nom.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': role,
        'ageGroups': ageGroups,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'profileComplete': false,
      });

      return AuthResult(success: true, message: 'Compte créé avec succès ! Vérifiez votre email.');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _authErrorMessage(e.code));
    } catch (e) {
      return AuthResult(success: false, message: 'Une erreur est survenue. Réessayez.');
    }
  }

  // ─────────────────────────────────────────────
  // CONNEXION
  // ─────────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(success: true, message: 'Connexion réussie !');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _authErrorMessage(e.code));
    } catch (e) {
      return AuthResult(success: false, message: 'Une erreur est survenue. Réessayez.');
    }
  }

  // ─────────────────────────────────────────────
  // MOT DE PASSE OUBLIÉ
  // ─────────────────────────────────────────────
  static Future<AuthResult> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult(success: true, message: 'Email de réinitialisation envoyé !');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: _authErrorMessage(e.code));
    } catch (e) {
      return AuthResult(success: false, message: 'Une erreur est survenue. Réessayez.');
    }
  }

  // ─────────────────────────────────────────────
  // DÉCONNEXION
  // ─────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────
  // MESSAGES D'ERREUR EN FRANÇAIS
  // ─────────────────────────────────────────────
  static String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Cette adresse email est déjà utilisée.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Mot de passe trop faible (min. 6 caractères).';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion.';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      default:
        return 'Erreur : $code';
    }
  }
}

// ── Résultat d'une opération Auth ──
class AuthResult {
  final bool success;
  final String message;
  const AuthResult({required this.success, required this.message});
}