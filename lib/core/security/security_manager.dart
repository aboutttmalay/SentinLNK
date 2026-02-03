import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart'; // Add this for SHA-256
import 'dart:convert';
import 'dart:typed_data';

class SecurityManager {
  // 1. THE PASSPHRASE
  // We can now use ANY length string, because SHA-256 will fix it to 32 bytes.
  static const _passphrase = 'ProjectSentinel_TopSecretKey_2024'; 

  // 2. KEY DERIVATION (Matches Spec 3.2)
  // Converts the passphrase into a perfect 256-bit (32-byte) key using SHA-256.
  static enc.Key _getDerivedKey() {
    var bytes = utf8.encode(_passphrase);
    var digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  // 3. ENCRYPT (Text -> Secret Bytes)
  // Matches Spec 4.1
  static Uint8List encryptMessage(String plainText) {
    final iv = enc.IV.fromLength(16); // Random 16-byte IV
    final key = _getDerivedKey();     // Get the SHA-256 Key
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combine IV + CipherText (Prepend IV Architecture)
    return Uint8List.fromList(iv.bytes + encrypted.bytes);
  }

  // 4. DECRYPT (Secret Bytes -> Text)
  // Matches Spec 4.2
  static String decryptMessage(Uint8List receivedData) {
    try {
      final key = _getDerivedKey();
      
      // Extraction
      final iv = enc.IV(receivedData.sublist(0, 16));
      final cipherBytes = enc.Encrypted(receivedData.sublist(16));

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      
      return encrypter.decrypt(cipherBytes, iv: iv);
    } catch (e) {
      return "[Decryption Failed]";
    }
  }
}