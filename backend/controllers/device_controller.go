package controllers

import (
	"encoding/json"
	"fmt"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// Helper to check device access via its home
func checkDeviceAccess(db *gorm.DB, deviceID, userID string, requireAdmin bool) (*models.Device, error) {
	var device models.Device
	if err := db.First(&device, "id = ?", deviceID).Error; err != nil {
		return nil, err
	}

	var member models.HomeMember
	err := db.Where("home_id = ? AND user_id = ?", device.HomeID, userID).First(&member).Error
	if err != nil {
		return nil, err
	}

	if requireAdmin && member.PermissionLevel != "full_access" {
		return nil, fmt.Errorf("administrative access required")
	}

	return &device, nil
}

// GetHomeDevices
func GetHomeDevices(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied to this home's devices",
		})
	}

	var devices []models.Device
	if err := config.AppConfig.DB.Preload("Switches").Find(&devices, "home_id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to load devices",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"devices": devices,
	})
}

// GetDevice
func GetDevice(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	device, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied or device not found",
		})
	}

	// Load switches relation
	config.AppConfig.DB.Preload("Switches").First(device, "id = ?", deviceID)

	return c.JSON(fiber.Map{
		"success": true,
		"device":  device,
	})
}

// UpdateDevice
type UpdateDeviceInput struct {
	Name   string                 `json:"name"`
	Config map[string]interface{} `json:"config"`
}

func UpdateDevice(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	device, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied. Admin rights required.",
		})
	}

	var input UpdateDeviceInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid inputs",
		})
	}

	if input.Name != "" {
		device.Name = input.Name
	}


	if len(input.Config) > 0 {
		configBytes, _ := json.Marshal(input.Config)
		device.Config = string(configBytes)
	}

	config.AppConfig.DB.Save(device)

	return c.JSON(fiber.Map{
		"success": true,
		"device":  device,
	})
}

// DeleteDevice
func DeleteDevice(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	device, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied. Admin rights required.",
		})
	}

	if err := config.AppConfig.DB.Delete(device).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to delete device",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Device deleted successfully",
	})
}

// SendCommand
type CommandInput struct {
	Feature string                 `json:"feature"` // switch, ir, lift, config
	Payload map[string]interface{} `json:"payload"`
}

// Note: MQTT publishing will be handled by packages/services imported here.
// Since Go doesn't resolve services package yet, we import it as "neurotouch/services"
func SendCommand(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	_, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied to send command to this device",
		})
	}

	var input CommandInput
	if err := c.BodyParser(&input); err != nil || input.Feature == "" || len(input.Payload) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid command structure. Feature and payload required.",
		})
	}

	// We declare a channel/hook or direct MQTT service publish.
	// We'll write to topic: neurotouch/devices/{deviceId}/command/{feature}
	topic := fmt.Sprintf("neurotouch/devices/%s/command/%s", deviceID, input.Feature)
	payloadBytes, _ := json.Marshal(input.Payload)

	// Since we import mqtt service, we publish directly via a package variable or channel
	// We'll expose a globally accessible helper in services/mqtt_service.go: MqttPublish(topic, payload)
	// We call it dynamically here.
	MqttPublish(topic, string(payloadBytes))

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Command dispatched successfully",
	})
}

// MqttPublish stub/declaration.
// In models/main.go or routing we will connect this stub to the real services.MqttClient publisher.
var MqttPublish func(topic string, payload string) = func(topic string, payload string) {
	// Fallback print
	fmt.Printf("[SIMULATED MQTT PUBLISH] Topic: %s, Payload: %s\n", topic, payload)
}

// GetSwitches
func GetSwitches(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	if _, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	var switches []models.SwitchConfig
	if err := config.AppConfig.DB.Where("device_id = ?", deviceID).Order("switch_index asc").Find(&switches).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed loading switches list",
		})
	}

	return c.JSON(fiber.Map{
		"success":  true,
		"switches": switches,
	})
}

// UpdateSwitch
type UpdateSwitchInput struct {
	Name         string  `json:"name"`
	Icon         string  `json:"icon"`
	ShortcutType *string `json:"shortcut_type"`
}

func UpdateSwitch(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")
	switchIndexStr := c.Params("index") // index of the switch on device (1-based)

	_, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied. Admin rights required.",
		})
	}

	var input UpdateSwitchInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid switch data",
		})
	}

	var sw models.SwitchConfig
	err = config.AppConfig.DB.Where("device_id = ? AND switch_index = ?", deviceID, switchIndexStr).First(&sw).Error
	if err != nil {
		// Create a switch config dynamically if it wasn't pre-initialized
		var indexVal int
		_, _ = fmt.Sscanf(switchIndexStr, "%d", &indexVal)
		sw = models.SwitchConfig{
			DeviceID:    deviceID,
			SwitchIndex: indexVal,
			Name:        "Switch " + switchIndexStr,
		}
	}

	if input.Name != "" {
		sw.Name = input.Name
	}
	if input.Icon != "" {
		sw.Icon = input.Icon
	}
	if input.ShortcutType != nil {
		if *input.ShortcutType == "" {
			sw.ShortcutType = nil
		} else {
			sw.ShortcutType = input.ShortcutType
		}
	}

	if err := config.AppConfig.DB.Save(&sw).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to update switch",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"switch":  sw,
	})
}

// GetIRProfiles
func GetIRProfiles(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")
	applianceType := c.Query("appliance_type") // ac | tv | fan

	if _, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	// This references seeds/ir_brands.json in practical terms.
	// We can load static seed list or return the matching database profiles.
	// For simplicity, return mock matrix mapping that is resolved locally or in backend config.
	var brands []string
	if applianceType == "ac" {
		brands = []string{"Daikin", "Mitsubishi", "Samsung", "LG", "Voltas", "Panasonic", "Carrier"}
	} else if applianceType == "tv" {
		brands = []string{"Sony", "Samsung", "LG", "TCL", "Xiaomi", "Panasonic", "Vizio"}
	} else {
		brands = []string{"Usha", "Havells", "Orient", "Crompton", "Luminous", "Syska"}
	}

	return c.JSON(fiber.Map{
		"success":        true,
		"appliance_type": applianceType,
		"brands":         brands,
	})
}
