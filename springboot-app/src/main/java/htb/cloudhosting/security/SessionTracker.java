package htb.cloudhosting.security;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Tracks active user sessions.
 * Maps JSESSIONID cookie values to usernames.
 * Pre-seeds a session for 'kanderson' on startup to simulate an active admin.
 */
@Component
public class SessionTracker {

    private final ConcurrentHashMap<String, String> sessions = new ConcurrentHashMap<>();

    @PostConstruct
    public void init() {
        // Pre-seed kanderson's session (simulates an active admin session)
        String kandersonSessionId = generateSessionId();
        sessions.put(kandersonSessionId, "kanderson");
        System.out.println("[*] kanderson session: " + kandersonSessionId);
    }

    /**
     * Generate a session ID that looks like a standard JSESSIONID (32-char uppercase hex).
     */
    public String generateSessionId() {
        return UUID.randomUUID().toString().replace("-", "").toUpperCase();
    }

    /**
     * Register a new session.
     */
    public void addSession(String sessionId, String username) {
        sessions.put(sessionId, username);
    }

    /**
     * Remove a session.
     */
    public void removeSession(String sessionId) {
        sessions.remove(sessionId);
    }

    /**
     * Look up a username by session ID.
     */
    public String getUsername(String sessionId) {
        return sessions.get(sessionId);
    }

    /**
     * Check if a session ID exists.
     */
    public boolean isValidSession(String sessionId) {
        return sessions.containsKey(sessionId);
    }

    /**
     * Get all active sessions (exposed via /actuator/sessions).
     */
    public Map<String, String> getAllSessions() {
        return new ConcurrentHashMap<>(sessions);
    }
}
