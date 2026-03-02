package htb.cloudhosting.controller;

import htb.cloudhosting.security.SessionTracker;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Custom actuator-style endpoint that exposes active sessions.
 *
 * VULNERABILITY: A01:2021 Broken Access Control
 * This endpoint is accessible without authentication and reveals
 * session cookies (JSESSIONID values) mapped to usernames.
 * An attacker can steal these session IDs and hijack user sessions.
 */
@RestController
public class ActuatorSessionsController {

    private final SessionTracker sessionTracker;

    public ActuatorSessionsController(SessionTracker sessionTracker) {
        this.sessionTracker = sessionTracker;
    }

    @GetMapping("/actuator/sessions")
    public Map<String, String> getSessions() {
        return sessionTracker.getAllSessions();
    }

    @GetMapping("/actuator")
    public Map<String, Object> actuatorIndex() {
        return Map.of(
            "_links", Map.of(
                "self", Map.of("href", "/actuator", "templated", false),
                "sessions", Map.of("href", "/actuator/sessions", "templated", false),
                "health", Map.of("href", "/actuator/health", "templated", false),
                "env", Map.of("href", "/actuator/env", "templated", false),
                "mappings", Map.of("href", "/actuator/mappings", "templated", false)
            )
        );
    }

    @GetMapping("/actuator/health")
    public Map<String, String> health() {
        return Map.of("status", "UP");
    }

    @GetMapping("/actuator/env")
    public Map<String, Object> env() {
        return Map.of(
            "activeProfiles", new String[]{},
            "propertySources", new Object[]{
                Map.of("name", "server.ports",
                       "properties", Map.of("local.server.port", Map.of("value", 8080)))
            }
        );
    }

    @GetMapping("/actuator/mappings")
    public Map<String, Object> mappings() {
        return Map.of(
            "contexts", Map.of(
                "application", Map.of(
                    "mappings", Map.of(
                        "dispatcherServlets", Map.of(
                            "dispatcherServlet", new Object[]{
                                Map.of("handler", "htb.cloudhosting.controller.IndexController#index()",
                                       "predicate", "{GET [/]}"),
                                Map.of("handler", "htb.cloudhosting.controller.AdminController#admin()",
                                       "predicate", "{GET [/admin]}"),
                                Map.of("handler", "htb.cloudhosting.controller.AdminController#executessh()",
                                       "predicate", "{POST [/executessh]}"),
                                Map.of("handler", "htb.cloudhosting.controller.LoginController#login()",
                                       "predicate", "{GET [/login]}")
                            }
                        )
                    )
                )
            )
        );
    }
}
