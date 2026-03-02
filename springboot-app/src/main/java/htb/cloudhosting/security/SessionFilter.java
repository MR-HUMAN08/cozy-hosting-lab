package htb.cloudhosting.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

/**
 * Custom security filter that checks JSESSIONID cookies against the SessionTracker.
 * This allows session hijacking — if an attacker steals a valid JSESSIONID from
 * /actuator/sessions, they can use it to authenticate without credentials.
 */
@Component
public class SessionFilter extends OncePerRequestFilter {

    private final SessionTracker sessionTracker;

    public SessionFilter(SessionTracker sessionTracker) {
        this.sessionTracker = sessionTracker;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain)
            throws ServletException, IOException {

        // Only process if not already authenticated
        if (SecurityContextHolder.getContext().getAuthentication() == null ||
                !SecurityContextHolder.getContext().getAuthentication().isAuthenticated() ||
                "anonymousUser".equals(SecurityContextHolder.getContext().getAuthentication().getPrincipal())) {

            String jsessionId = getJSessionId(request);

            if (jsessionId != null && sessionTracker.isValidSession(jsessionId)) {
                String username = sessionTracker.getUsername(jsessionId);

                // Create authentication token for the hijacked session
                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(
                                username, null,
                                Collections.singletonList(new SimpleGrantedAuthority("ROLE_ADMIN"))
                        );

                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        }

        // Set JSESSIONID cookie if not present (mimic default Spring Boot behavior)
        String existingCookie = getJSessionId(request);
        if (existingCookie == null) {
            String newSessionId = sessionTracker.generateSessionId();
            Cookie cookie = new Cookie("JSESSIONID", newSessionId);
            cookie.setPath("/");
            cookie.setHttpOnly(true);
            response.addCookie(cookie);
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Extract JSESSIONID from request cookies.
     */
    private String getJSessionId(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            for (Cookie cookie : cookies) {
                if ("JSESSIONID".equals(cookie.getName())) {
                    return cookie.getValue();
                }
            }
        }
        return null;
    }
}
