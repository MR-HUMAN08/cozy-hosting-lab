package htb.cloudhosting.controller;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class AdminController {

    @GetMapping("/admin")
    public String admin(Model model, Authentication authentication,
                        @RequestParam(required = false) String error) {
        model.addAttribute("username", authentication.getName());
        if (error != null) {
            model.addAttribute("ssh_status", "error");
            model.addAttribute("ssh_message", error);
        }
        return "admin";
    }

    /**
     * VULNERABLE ENDPOINT: Command Injection
     *
     * The username parameter is concatenated directly into a shell command
     * without sanitization. Spaces are blocked, but semicolons and other
     * special characters pass through, enabling OS command injection.
     *
     * Attack vector: username parameter
     * Example payload: ;{sleep,10};
     * Reverse shell: ;echo${IFS}"BASE64_PAYLOAD"|base64${IFS}-d|bash;
     */
    @PostMapping("/executessh")
    public String executeSsh(@RequestParam String host,
                              @RequestParam String username,
                              Authentication authentication) {

        // Input validation — blocks spaces but NOT semicolons or other shell metacharacters
        if (host == null || host.isEmpty()) {
            return "redirect:/admin?error=" + encode("Host field is required!");
        }

        if (username == null || username.isEmpty()) {
            return "redirect:/admin?error=" + encode("Username field is required!");
        }

        if (host.contains(" ")) {
            return "redirect:/admin?error=" + encode("Hostname can't contain whitespaces!");
        }

        if (username.contains(" ")) {
            return "redirect:/admin?error=" + encode("Username can't contain whitespaces!");
        }

        // ╔═══════════════════════════════════════════════════════════════╗
        // ║  VULNERABLE: OS Command Injection                            ║
        // ║  Username is concatenated directly into a bash command.      ║
        // ║  ProcessBuilder with /bin/bash -c executes the full string.  ║
        // ╚═══════════════════════════════════════════════════════════════╝
        String cmd = "ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no "
                     + username + "@" + host;

        String errorOutput;
        try {
            ProcessBuilder pb = new ProcessBuilder("/bin/bash", "-c", cmd);
            pb.redirectErrorStream(true);
            Process process = pb.start();

            // Capture the actual SSH command output (stdout + stderr merged)
            StringBuilder output = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (output.length() > 0) {
                        output.append("\n");
                    }
                    output.append(line);
                }
            }

            // Wait with timeout so reverse shells don't hang the web server
            boolean finished = process.waitFor(15, TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
            }

            errorOutput = output.toString().trim();
        } catch (IOException ioe) {
            errorOutput = ioe.getMessage() != null ? ioe.getMessage() : "I/O error occurred";
        } catch (InterruptedException ie) {
            errorOutput = "Process was interrupted";
            Thread.currentThread().interrupt();
        }

        // If no output was captured, use a generic message
        if (errorOutput.isEmpty()) {
            errorOutput = "ssh: Could not resolve hostname " + host + ": Name or service not known";
        }

        return "redirect:/admin?error=" + encode(errorOutput);
    }

    /**
     * URL-encode a string for use in a redirect query parameter.
     */
    private String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
