M openjdk:8-jdk-alpine

# Workdir
WORKDIR /app

# Copy application files
COPY app.jar /app/app.jar
COPY application.properties /app/application.properties

# Expose application port
EXPOSE 8080

# Start application
CMD ["java", "-jar", "app.jar"]

