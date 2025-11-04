package com.systech.hrms.util;

import com.aventrix.jnanoid.jnanoid.NanoIdUtils;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.SecureRandom;

/**
 * NanoID generator for tenant IDs
 *
 * Generates URL-safe, collision-resistant unique identifiers for tenant isolation.
 *
 * Format: 12-character lowercase alphanumeric
 * Example: a3b9c8d2e1f4
 *
 * Collision Probability:
 * - 36^12 = 4.7×10^18 combinations
 * - For 1 million IDs: collision probability ≈ 0.0000001%
 * - Safe for production use
 *
 * @author Systech Team
 * @version 1.0.0
 */
@Slf4j
@Component
public class NanoIdGenerator {

    @Value("${nanoid.size:12}")
    private int size;

    @Value("${nanoid.alphabet:0123456789abcdefghijklmnopqrstuvwxyz}")
    private String alphabet;

    private final SecureRandom random = new SecureRandom();

    /**
     * Generate a unique NanoID for tenant identification
     *
     * @return 12-character lowercase alphanumeric ID (e.g., "a3b9c8d2e1f4")
     */
    public String generateTenantId() {
        char[] alphabetChars = alphabet.toCharArray();
        String tenantId = NanoIdUtils.randomNanoId(random, alphabetChars, size);
        log.debug("Generated tenant_id: {}", tenantId);
        return tenantId;
    }

    /**
     * Validate tenant ID format
     *
     * @param tenantId the tenant ID to validate
     * @return true if valid format
     */
    public boolean isValidTenantId(String tenantId) {
        if (tenantId == null || tenantId.length() != size) {
            return false;
        }

        // Check all characters are in alphabet
        for (char c : tenantId.toCharArray()) {
            if (alphabet.indexOf(c) == -1) {
                return false;
            }
        }

        return true;
    }

    /**
     * Get configured size for NanoID
     *
     * @return size of NanoID
     */
    public int getSize() {
        return size;
    }

    /**
     * Get configured alphabet for NanoID
     *
     * @return alphabet string
     */
    public String getAlphabet() {
        return alphabet;
    }
}
