/// Single-salon installation: the only account allowed to bootstrap the shop.
///
/// Keep this value in sync with the `OWNER_EMAIL` literal in
/// `firestore.rules`; the rules are the authoritative gate.
const String kOwnerEmail = 'mohammad93zza@gmail.com';

bool isOwnerEmail(String? email) =>
    email != null && email.trim().toLowerCase() == kOwnerEmail;
