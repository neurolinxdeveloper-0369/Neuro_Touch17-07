package config

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type Config struct {
	Port           string
	DB             *gorm.DB
	JWTSecret      string
	MqttBroker     string
	MqttPort       string
	MqttUsername   string
	MqttPassword   string
	OllamaURL      string
	OllamaModel    string
	GoogleClientID string
}

var AppConfig *Config

func LoadConfig() {
	// Ignore error as env vars might be set via Docker Compose
	_ = godotenv.Load()

	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "postgres")
	dbPass := getEnv("DB_PASSWORD", "postgres")
	dbName := getEnv("DB_NAME", "neurotouch")
	dbSSL := getEnv("DB_SSLMODE", "disable")

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		dbHost, dbUser, dbPass, dbName, dbPort, dbSSL)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	AppConfig = &Config{
		Port:           getEnv("PORT", "8080"),
		DB:             db,
		JWTSecret:      getEnv("JWT_SECRET", "super_secret_neuro_touch_key"),
		MqttBroker:     getEnv("MQTT_BROKER", "localhost"),
		MqttPort:       getEnv("MQTT_PORT", "1883"),
		MqttUsername:   getEnv("MQTT_USERNAME", ""),
		MqttPassword:   getEnv("MQTT_PASSWORD", ""),
		OllamaURL:      getEnv("OLLAMA_API_URL", "http://localhost:11434"),
		OllamaModel:    getEnv("OLLAMA_MODEL", "llama3"),
		GoogleClientID: getEnv("GOOGLE_CLIENT_ID", ""),
	}

	log.Println("Database connection established and config loaded successfully.")
}

func getEnv(key, defaultVal string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultVal
}
