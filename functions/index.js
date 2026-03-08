const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteUserAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Vous devez être connecté.");
  }

  const callerUid = request.auth.uid;
  const callerEmail = request.auth.token.email || "";
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
  const isAdmin =
    callerEmail === "lehsainiimadeddinelouei@gmail.com" ||
    (callerDoc.exists && callerDoc.data().role === "admin");

  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Accès réservé à l'administrateur.");
  }

  const uidToDelete = request.data.uid;
  if (!uidToDelete) {
    throw new HttpsError("invalid-argument", "UID manquant.");
  }

  try {
    await admin.auth().deleteUser(uidToDelete);
    return { success: true };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return { success: true };
    }
    throw new HttpsError("internal", error.message);
  }
});
