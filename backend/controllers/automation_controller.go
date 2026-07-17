package controllers

import (
	"encoding/json"
	"fmt"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
)

// GetAutomations
func GetAutomations(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	var automations []models.Automation
	if err := config.AppConfig.DB.Find(&automations, "home_id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed loading automations list",
		})
	}

	return c.JSON(fiber.Map{
		"success":     true,
		"automations": automations,
	})
}

// CreateAutomation
type AutomationInput struct {
	Name       string        `json:"name"`
	Conditions []interface{} `json:"conditions"`
	Actions    []interface{} `json:"actions"`
}

func CreateAutomation(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin privileges required to create scenes",
		})
	}

	var input AutomationInput
	if err := c.BodyParser(&input); err != nil || input.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Scene name, conditions, and actions are required",
		})
	}

	condBytes, _ := json.Marshal(input.Conditions)
	actBytes, _ := json.Marshal(input.Actions)

	automation := models.Automation{
		HomeID:     homeID,
		Name:       input.Name,
		Conditions: string(condBytes),
		Actions:    string(actBytes),
		IsActive:   true,
	}

	if err := config.AppConfig.DB.Create(&automation).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create automation",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success":    true,
		"automation": automation,
	})
}

// UpdateAutomation
func UpdateAutomation(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	id := c.Params("id")

	var automation models.Automation
	if err := config.AppConfig.DB.First(&automation, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Automation scene not found",
		})
	}

	if _, err := checkHomeAccess(config.AppConfig.DB, automation.HomeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin privileges required",
		})
	}

	var input AutomationInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid configuration input",
		})
	}

	if input.Name != "" {
		automation.Name = input.Name
	}
	if len(input.Conditions) > 0 {
		condBytes, _ := json.Marshal(input.Conditions)
		automation.Conditions = string(condBytes)
	}
	if len(input.Actions) > 0 {
		actBytes, _ := json.Marshal(input.Actions)
		automation.Actions = string(actBytes)
	}

	config.AppConfig.DB.Save(&automation)

	return c.JSON(fiber.Map{
		"success":    true,
		"automation": automation,
	})
}

// DeleteAutomation
func DeleteAutomation(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	id := c.Params("id")

	var automation models.Automation
	if err := config.AppConfig.DB.First(&automation, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Scene not found",
		})
	}

	if _, err := checkHomeAccess(config.AppConfig.DB, automation.HomeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin privileges required",
		})
	}

	config.AppConfig.DB.Delete(&automation)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Automation scene deleted successfully",
	})
}

// ToggleAutomation
func ToggleAutomation(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	id := c.Params("id")

	var automation models.Automation
	if err := config.AppConfig.DB.First(&automation, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Scene not found",
		})
	}

	if _, err := checkHomeAccess(config.AppConfig.DB, automation.HomeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	automation.IsActive = !automation.IsActive
	config.AppConfig.DB.Save(&automation)

	return c.JSON(fiber.Map{
		"success":    true,
		"automation": automation,
	})
}

// --- Schedules Controllers ---

func GetSchedules(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	_, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	var schedules []models.Schedule
	if err := config.AppConfig.DB.Find(&schedules, "device_id = ?", deviceID).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to load schedules",
		})
	}

	return c.JSON(fiber.Map{
		"success":   true,
		"schedules": schedules,
	})
}

type ScheduleInput struct {
	SwitchIndex int    `json:"switch_index"`
	CronExpr    string `json:"cron_expr"`
	Action      string `json:"action"` // on | off
	IsActive    *bool  `json:"is_active,omitempty"`
}

func CreateSchedule(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	_, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin permissions required to set schedules",
		})
	}

	var input ScheduleInput
	if err := c.BodyParser(&input); err != nil || input.CronExpr == "" || (input.Action != "on" && input.Action != "off") {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Switch index, cron pattern, and action (on/off) are required",
		})
	}

	active := true
	if input.IsActive != nil {
		active = *input.IsActive
	}

	schedule := models.Schedule{
		DeviceID:    deviceID,
		SwitchIndex: input.SwitchIndex,
		CronExpr:    input.CronExpr,
		Action:      input.Action,
		IsActive:    active,
	}

	if err := config.AppConfig.DB.Create(&schedule).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create schedule",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success":  true,
		"schedule": schedule,
	})
}

func UpdateSchedule(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	id := c.Params("id")

	var schedule models.Schedule
	if err := config.AppConfig.DB.First(&schedule, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Schedule not found",
		})
	}

	_, err := checkDeviceAccess(config.AppConfig.DB, schedule.DeviceID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin permissions required",
		})
	}

	var input ScheduleInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid input params",
		})
	}

	if input.CronExpr != "" {
		schedule.CronExpr = input.CronExpr
	}
	if input.Action == "on" || input.Action == "off" {
		schedule.Action = input.Action
	}
	if input.IsActive != nil {
		schedule.IsActive = *input.IsActive
	}
	if input.SwitchIndex > 0 {
		schedule.SwitchIndex = input.SwitchIndex
	}

	config.AppConfig.DB.Save(&schedule)

	return c.JSON(fiber.Map{
		"success":  true,
		"schedule": schedule,
	})
}

func DeleteSchedule(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	id := c.Params("id")

	var schedule models.Schedule
	if err := config.AppConfig.DB.First(&schedule, "id = ?", id).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Schedule not found",
		})
	}

	_, err := checkDeviceAccess(config.AppConfig.DB, schedule.DeviceID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin permissions required",
		})
	}

	config.AppConfig.DB.Delete(&schedule)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Schedule deleted successfully",
	})
}

// --- Notifications Controllers ---

func GetNotifications(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var notifications []models.Notification
	if err := config.AppConfig.DB.Order("created_at desc").Find(&notifications, "user_id = ?", userID).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed loading notifications",
		})
	}

	return c.JSON(fiber.Map{
		"success":       true,
		"notifications": notifications,
	})
}

func MarkNotificationRead(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	id := c.Params("id")

	var notification models.Notification
	if err := config.AppConfig.DB.First(&notification, "id = ? AND user_id = ?", id, userID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Notification not found",
		})
	}

	notification.IsRead = true
	config.AppConfig.DB.Save(&notification)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Notification marked as read",
	})
}

// --- AI Chat Controller ---

type AIChatInput struct {
	HomeID  string                   `json:"home_id"`
	Message string                   `json:"message"`
	History []map[string]interface{} `json:"history"`
}

var GetAIChatResponse func(homeID string, message string, history []map[string]interface{}) (string, error) = func(homeID string, message string, history []map[string]interface{}) (string, error) {
	return "AI chat service not initialized. Query was: " + message, nil
}

func AIChat(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var input AIChatInput
	if err := c.BodyParser(&input); err != nil || input.Message == "" || input.HomeID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Home ID and user message are required",
		})
	}

	// Verify user belongs to the home they want to query about
	if _, err := checkHomeAccess(config.AppConfig.DB, input.HomeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied. You do not belong to this home.",
		})
	}

	// Execute Ollama local model with home context
	reply, err := GetAIChatResponse(input.HomeID, input.Message, input.History)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   fmt.Sprintf("AI service error: %v", err),
		})
	}

	return c.JSON(fiber.Map{
		"success":  true,
		"response": reply,
	})
}
