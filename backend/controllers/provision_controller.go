package controllers

import (
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

// GenerateDeviceUuid handles generating a unique ID for a new hardware device
func GenerateDeviceUuid(c *fiber.Ctx) error {
	newUUID := uuid.New().String()
	return c.JSON(fiber.Map{
		"success":   true,
		"device_id": "nt-" + newUUID[:8], // Return a clean prefix + uuid snippet
	})
}

// CheckProvisionStatus checks whether a newly created device is online
func CheckProvisionStatus(c *fiber.Ctx) error {
	deviceID := c.Params("id")

	var device models.Device
	err := config.AppConfig.DB.First(&device, "id = ?", deviceID).Error
	if err != nil {
		return c.JSON(fiber.Map{
			"success": true,
			"status":  "pending", // Not added to database yet
		})
	}

	status := "offline"
	if device.IsOnline {
		status = "online"
	}

	return c.JSON(fiber.Map{
		"success": true,
		"status":  status,
	})
}

type ProvisionDeviceInput struct {
	DeviceID    string `json:"device_id"`
	HomeID      string `json:"home_id"`
	RoomID      string `json:"room_id"`
	DeviceType  string `json:"device_type"`
	Name        string `json:"name"`
	SSIDPattern string `json:"ssid_pattern"`
	SwitchCount int    `json:"switch_count"`
}

// ProvisionDeviceEndpoint maps the device to its home/room in DB
func ProvisionDeviceEndpoint(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var input ProvisionDeviceInput
	if err := c.BodyParser(&input); err != nil || input.DeviceID == "" || input.HomeID == "" || input.RoomID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Device ID, Home ID, and Room ID are required",
		})
	}

	// Verify home access
	if _, err := checkHomeAccess(config.AppConfig.DB, input.HomeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin permissions required to provision devices",
		})
	}

	// Verify room exists in this home
	var room models.Room
	if err := config.AppConfig.DB.First(&room, "id = ? AND home_id = ?", input.RoomID, input.HomeID).Error; err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Selected room does not exist in this home",
		})
	}

	// Begin Transaction to create device & default switch configurations
	tx := config.AppConfig.DB.Begin()

	var device models.Device
	err := tx.First(&device, "id = ?", input.DeviceID).Error

	now := time.Now()

	if err != nil {
		// New device entry
		device = models.Device{
			ID:          input.DeviceID,
			HomeID:      input.HomeID,
			RoomID:      &input.RoomID,
			DeviceType:  input.DeviceType,
			Name:        input.Name,
			SSIDPattern: &input.SSIDPattern,
			SwitchCount: input.SwitchCount,
			IsOnline:    true, // Set online on provision
			LastSeen:    &now,
		}

		if err := tx.Create(&device).Error; err != nil {
			tx.Rollback()
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to provision device: " + err.Error(),
			})
		}
	} else {
		// Device already existed, re-assign
		device.HomeID = input.HomeID
		device.RoomID = &input.RoomID
		device.Name = input.Name
		device.DeviceType = input.DeviceType
		device.SwitchCount = input.SwitchCount
		device.SSIDPattern = &input.SSIDPattern
		device.IsOnline = true
		device.LastSeen = &now

		if err := tx.Save(&device).Error; err != nil {
			tx.Rollback()
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to update provisioned device: " + err.Error(),
			})
		}
	}

	// Auto-create switch configs based on SwitchCount if touch panel
	if input.DeviceType == "touch_panel" {
		// Delete any existing switches to avoid duplicate indexes
		tx.Where("device_id = ?", device.ID).Delete(&models.SwitchConfig{})

		for i := 1; i <= input.SwitchCount; i++ {
			sw := models.SwitchConfig{
				DeviceID:    device.ID,
				SwitchIndex: i,
				Name:        "Switch " + string(rune(48+i)), // e.g. Switch 1
				Icon:        "lightbulb",
			}
			if err := tx.Create(&sw).Error; err != nil {
				tx.Rollback()
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
					"success": false,
					"error":   "Failed to generate default switches: " + err.Error(),
				})
			}
		}
	}

	if err := tx.Commit().Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Provision transaction commit failed",
		})
	}

	// Return populated device structure
	config.AppConfig.DB.Preload("Switches").First(&device, "id = ?", device.ID)

	return c.JSON(fiber.Map{
		"success": true,
		"device":  device,
	})
}
