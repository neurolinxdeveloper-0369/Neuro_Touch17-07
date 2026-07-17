package routes

import (
	"neurotouch/controllers"
	"neurotouch/middleware"

	"github.com/gofiber/fiber/v2"
)

func SetupRoutes(app *fiber.App) {
	api := app.Group("/api/v1")

	// --- Public Auth Routes ---
	auth := api.Group("/auth")
	auth.Post("/google", controllers.GoogleAuth)
	auth.Post("/otp/send", controllers.SendOTP)
	auth.Post("/otp/verify", controllers.VerifyOTPLogin)
	auth.Post("/refresh-token", controllers.RefreshToken)

	// --- Protected Routes ---
	protected := api.Group("", middleware.AuthRequired)

	// Homes Management
	protected.Get("/homes", controllers.GetHomes)
	protected.Post("/homes", controllers.CreateHome)
	protected.Get("/homes/:id", controllers.GetHome)
	protected.Put("/homes/:id", controllers.UpdateHome)
	protected.Delete("/homes/:id", controllers.DeleteHome)
	protected.Post("/homes/:id/invite", controllers.GenerateInvite)
	protected.Post("/homes/join", controllers.JoinHome)

	// Home Members
	protected.Get("/homes/:id/members", controllers.GetMembers)
	protected.Put("/homes/:id/members/:userId", controllers.UpdateMemberPermission)
	protected.Delete("/homes/:id/members/:userId", controllers.RemoveMember)

	// Floors
	protected.Get("/homes/:id/floors", controllers.GetFloors)
	protected.Post("/homes/:id/floors", controllers.CreateFloor)
	protected.Put("/homes/:id/floors/:floorId", controllers.UpdateFloor)
	protected.Delete("/homes/:id/floors/:floorId", controllers.DeleteFloor)

	// Rooms
	protected.Get("/homes/:id/rooms", controllers.GetRooms)
	protected.Post("/homes/:id/rooms", controllers.CreateRoom)
	protected.Put("/homes/:id/rooms/:roomId", controllers.UpdateRoom)
	protected.Delete("/homes/:id/rooms/:roomId", controllers.DeleteRoom)

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
	protected.Get("/provision/:id/status", controllers.CheckProvisionStatus)
	protected.Post("/provision/device", controllers.ProvisionDeviceEndpoint)

	// Telemetry
	protected.Get("/devices/:id/telemetry/latest", controllers.GetTelemetryLatest)
	protected.Get("/devices/:id/telemetry/history", controllers.GetTelemetryHistory)

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
