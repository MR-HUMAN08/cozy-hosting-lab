package htb.cloudhosting.scheduled;

import htb.cloudhosting.security.SessionTracker;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Simulates a real admin user (kanderson) who is actively logged in.
 * Periodically refreshes kanderson's session to keep it alive.
 *
 * In a real HTB machine, this represents a legitimate admin user
 * whose session is inadvertently exposed via the /actuator/sessions endpoint.
 */
@Component
public class FakeUser {

    private final SessionTracker sessionTracker;

    public FakeUser(SessionTracker sessionTracker) {
        this.sessionTracker = sessionTracker;
    }

    /**
     * Every 5 minutes, ensure kanderson's session exists.
     * If it was removed (e.g., by cleanup), re-create it.
     */
    @Scheduled(fixedRate = 300000) // 5 minutes
    public void maintainKandersonSession() {
        boolean hasSession = sessionTracker.getAllSessions()
                .containsValue("kanderson");

        if (!hasSession) {
            String newSession = sessionTracker.generateSessionId();
            sessionTracker.addSession(newSession, "kanderson");
            System.out.println("[*] FakeUser: Refreshed kanderson session: " + newSession);
        }
    }
}
