/// A lightweight, locally-saved reference to an account that signed in on
/// this device (the Meta/Facebook-style account switcher).
///
/// Deliberately contains NO secrets — no password, no auth token. Only
/// enough profile info to render the switcher row: uid, email, display name
/// and avatar URL. Stored on-device only (cleared with app data/uninstall).
class SavedAccount {
  const SavedAccount({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.lastLoginAt,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? lastLoginAt;

  String get displayLabel {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return email;
  }

  /// First letter used for the avatar fallback.
  String get initial {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name.substring(0, 1).toUpperCase();
    final local = email.split('@').first.trim();
    return (local.isNotEmpty ? local[0] : '?').toUpperCase();
  }

  /// Masked identifier for display, e.g. `m•••@gmail.com`.
  String get maskedEmail {
    final at = email.lastIndexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at);
    final maskedLocal = '${local[0]}${'•' * (local.length - 1)}';
    return '$maskedLocal$domain';
  }

  SavedAccount copyWith({DateTime? lastLoginAt}) {
    return SavedAccount(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'lastLoginAt': lastLoginAt?.toIso8601String(),
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    final lastLogin = json['lastLoginAt'] as String?;
    return SavedAccount(
      uid: (json['uid'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      lastLoginAt: lastLogin != null && lastLogin.isNotEmpty
          ? DateTime.tryParse(lastLogin)
          : null,
    );
  }
}