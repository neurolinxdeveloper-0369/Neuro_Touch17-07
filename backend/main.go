package main

import (
	"log"

	"neurotouch/config"
	"neurotouch/models"
	"neurotouch/routes"
	"neurotouch/services"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func main() {
	log.Println("Starting Neuro Touch Backend Engine...")

	// 1. Load Configurations & Database connection
	config.LoadConfig()

	// 2. Automigrate Database Schema
	log.Println("Migrating database schemas...")
	err := config.AppConfig.DB.AutoMigrate(
		&models.OTPVerification{},
		&models.Home{},
		&models.HomeMember{},
		&models.Floor{},
		&models.Room{},
		&models.Device{},
		&models.SwitchConfig{},
		&models.Automation{},
		&models.Schedule{},
		&models.Telemetry{},
		&models.Notification{},
	)
	if err != nil {
		log.Fatalf("Failed database migration: %v", err)
	}
	log.Println("Database migration completed successfully.")

	// 3. Initialize Services
	log.Println("Initializing core background services...")
	services.InitMqtt()
	services.InitAIChat()
	services.StartTelemetryCompactor()

	// 4. Create Fiber Web Application
	app := fiber.New(fiber.Config{
		AppName: "Neuro Touch Smart Home IoT API",
	})

	// 5. Mount Global Middlewares
	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, PATCH, OPTIONS",
	}))

	// 6. Set Up API Routes
	routes.SetupRoutes(app)

	// 7. Start listening on Port
	bindAddr := ":" + config.AppConfig.Port
	log.Printf("REST API server listening on http://localhost%s", bindAddr)
	if err := app.Listen(bindAddr); err != nil {
		log.Fatalf("API server crashed: %v", err)
	}
}
