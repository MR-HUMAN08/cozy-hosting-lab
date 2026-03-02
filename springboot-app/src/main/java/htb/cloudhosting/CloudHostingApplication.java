package htb.cloudhosting;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class CloudHostingApplication {

    public static void main(String[] args) {
        SpringApplication.run(CloudHostingApplication.class, args);
    }
}
