package routes

import (
	"neurotouch/controllers"
	"neurotouch/middleware"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"
)

func SetupRoutes(app *fiber.App) {
	api := app.Group("/api/v1")

	// --- Alexa & OAuth 2.0 Account Linking Routes ---
	api.Get("/oauth/authorize", controllers.RenderAuthorizePage)
	api.Post("/oauth/authorize", controllers.AuthorizeSubmit)
	api.Post("/oauth/token", controllers.Token)
	api.Post("/alexa/directive", controllers.AlexaEndpoint)

	// --- Legal Routes ---
	api.Get("/privacy", controllers.PrivacyPolicy)
	api.Get("/terms", controllers.TermsOfUse)

	// --- Public Auth Routes ---
	auth := api.Group("/auth")
	auth.Post("/google", controllers.GoogleAuth)

	// Rate limiter for OTP endpoints
	otpLimiter := limiter.New(limiter.Config{
		Max:        5,
		Expiration: 1 * time.Minute,
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"success": false,
				"error":   "Too many requests, please try again later.",
			})
		},
	})

	auth.Post("/otp/send", otpLimiter, controllers.SendOTP)
	auth.Post("/otp/verify", otpLimiter, controllers.VerifyOTPLogin)
	auth.Post("/refresh-token", controllers.RefreshToken)

	// --- Public Device Provisioning Callback (called by ESP12F hardware, no JWT) ---
	api.Get("/provision/mac-confirm", controllers.MACConfirmEndpoint)

	// --- Protected Routes ---
	protected := api.Group("", middleware.AuthRequired)

	// Homes Management
	protected.Get("/homes", controllers.GetHomes)
	protected.Post("/homes", controllers.CreateHome)
	protected.Get("/homes/:id", controllers.GetHome)
	protected.Put("/homes/:id", controllers.UpdateHome)
	protected.Delete("/homes/:id", controllers.DeleteHome)
	protected.Post("/homes/:id/invite", controllers.GenerateInvite)

	// Rate limiter for Join Home
	joinLimiter := limiter.New(limiter.Config{
		Max:        5,
		Expiration: 1 * time.Minute,
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"success": false,
				"error":   "Too many requests, please try again later.",
			})
		},
	})
	protected.Post("/homes/join", joinLimiter, controllers.JoinHome)

	// Home Members
	protected.Get("/homes/:id/members", controllers.GetMembers)
	protected.Put("/homes/:id/members/:userId", controllers.UpdateMemberPermission)
	protected.Delete("/homes/:id/members/:userId", controllers.RemoveMember)

	// Home Network Credentials (for ESP provisioning)
	protected.Get("/homes/:id/network-credentials", controllers.GetHomeNetworkCredentials)

	// Floors & Rooms
	protected.Get("/homes/:id/floors", controllers.GetFloors)
	protected.Get("/floors/:floorId/rooms", controllers.GetRooms)

	// Devices
	protected.Get("/homes/:id/devices", controllers.GetHomeDevices)
	protected.Get("/devices/:id", controllers.GetDevice)
	protected.Put("/devices/:id", controllers.UpdateDevice)
	protected.Delete("/devices/:id", controllers.DeleteDevice)
	protected.Post("/devices/:id/command", controllers.SendCommand)
	protected.Get("/devices/:id/switches", controllers.GetSwitches)
	protected.Put("/devices/:id/switches/:index", controllers.UpdateSwitch)
	protected.Get("/devices/:id/ir-profiles", controllers.GetIRProfiles)

	// Provisioning Endpoints
	protected.Post("/provision/generate-uuid", controllers.GenerateDeviceUuid)
	protected.Post("/provision/validate-panel", controllers.ValidatePanelSSID)
	protected.Get("/provision/:id/status", controllers.CheckProvisionStatus)
	protected.Post("/provision/device", controllers.ProvisionDeviceEndpoint)

	// Telemetry
	protected.Get("/devices/:id/telemetry/latest", controllers.GetTelemetryLatest)
	protected.Get("/devices/:id/telemetry/history", controllers.GetTelemetryHistory)
	protected.Get("/devices/:id/energy/history", controllers.GetEnergyHistory)

	// Automations (Scenes)
	protected.Get("/homes/:id/automations", controllers.GetAutomations)
	protected.Post("/homes/:id/automations", controllers.CreateAutomation)
	protected.Put("/automations/:id", controllers.UpdateAutomation)
	protected.Delete("/automations/:id", controllers.DeleteAutomation)
	protected.Post("/automations/:id/toggle", controllers.ToggleAutomation)

	// Schedules
	protected.Get("/devices/:id/schedules", controllers.GetSchedules)
	protected.Post("/devices/:id/schedules", controllers.CreateSchedule)
	protected.Put("/schedules/:id", controllers.UpdateSchedule)
	protected.Delete("/schedules/:id", controllers.DeleteSchedule)

	// Notifications
	protected.Get("/notifications", controllers.GetNotifications)
	protected.Patch("/notifications/:id", controllers.MarkNotificationRead)

	// AI Assistant Chat
	protected.Post("/ai/chat", controllers.AIChat)
}
