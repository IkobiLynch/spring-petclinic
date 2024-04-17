# Build application using gradle

# Use gradles jdk running on ubuntu jammy jellyfish as base image
FROM gradle:8.7.0-jdk-jammy as build

# Copy source code and change user to prevent permisison issues.
COPY --chown=gradle:gradle . /home/gradle/src 
WORKDIR /home/gradle/src 

# Run Gradle Build with wrapper 
RUN ./gradlew build --no-daemon

# Run application 

# Use OpenJDK as base image
FROM openjdk:17-jdk-alpine

# Copy the jar file from your host to your current location (/app) in the container
COPY --from=build --chown=gradle:gradle /home/gradle/src/build/libs/*.jar /app/spring-app.jar

# Set the working directory in the container
WORKDIR /app

# Expose PORT
EXPOSE 8080

# Command to run the application
ENTRYPOINT ["java", "-jar", "spring-app.jar"]

