package org.qtproject.example.vexa;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.security.KeyStore;
import java.util.Arrays;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

// Seals small secrets (the database key, the application access record) with an AES-256 key that never leaves
// Android Keystore. Inputs and outputs are Base64 text so the C++ side needs no JNI array handling.
public final class SecretVault {
    private static final String PROVIDER = "AndroidKeyStore";
    private static final String ALIAS = "vexa-local-vault-v1";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int TAG_BITS = 128;
    private static final int IV_BYTES = 12;

    private SecretVault() {}

    public static boolean available() {
        try {
            KeyStore store = KeyStore.getInstance(PROVIDER);
            store.load(null);
            return true;
        } catch (Exception error) {
            return false;
        }
    }

    // Returns Base64 of IV followed by the ciphertext. The IV is random for every call.
    public static String seal(String plainBase64) throws Exception {
        byte[] plain = Base64.decode(plainBase64, Base64.NO_WRAP);
        try {
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, key(true));
            byte[] body = cipher.doFinal(plain);
            byte[] iv = cipher.getIV();
            byte[] sealed = new byte[iv.length + body.length];
            System.arraycopy(iv, 0, sealed, 0, iv.length);
            System.arraycopy(body, 0, sealed, iv.length, body.length);
            return Base64.encodeToString(sealed, Base64.NO_WRAP);
        } finally {
            Arrays.fill(plain, (byte) 0);
        }
    }

    public static String open(String sealedBase64) throws Exception {
        byte[] sealed = Base64.decode(sealedBase64, Base64.NO_WRAP);
        if (sealed.length <= IV_BYTES) {
            throw new IllegalArgumentException("Vault record is too short");
        }
        Cipher cipher = Cipher.getInstance(TRANSFORMATION);
        cipher.init(Cipher.DECRYPT_MODE, key(false), new GCMParameterSpec(TAG_BITS, sealed, 0, IV_BYTES));
        byte[] plain = cipher.doFinal(sealed, IV_BYTES, sealed.length - IV_BYTES);
        try {
            return Base64.encodeToString(plain, Base64.NO_WRAP);
        } finally {
            Arrays.fill(plain, (byte) 0);
        }
    }

    private static SecretKey key(boolean create) throws Exception {
        KeyStore store = KeyStore.getInstance(PROVIDER);
        store.load(null);
        if (!store.containsAlias(ALIAS)) {
            if (!create) {
                throw new IllegalStateException("Vault key is missing");
            }
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, PROVIDER);
            generator.init(new KeyGenParameterSpec.Builder(ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build());
            generator.generateKey();
        }
        return (SecretKey) store.getKey(ALIAS, null);
    }
}
