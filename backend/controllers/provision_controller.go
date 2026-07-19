package controllers

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

var PendingProvisionings = struct {
	sync.RWMutex
	Devices map[string]time.Time
}{
	Devices: make(map[string]time.Time),
}

// MACConfirmEndpoint is a public endpoint called by the ESP12F panel
// once it successfully connects to the local Wi-Fi.
func MACConfirmEndpoint(c *fiber.Ctx) error {
	mac := c.Query("mac")
	tempDeviceID := c.Query("device_id")

	if mac == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Missing MAC address",
		})
	}

	mac = strings.ToUpper(mac)
	now := time.Now()

	var device models.Device
	found := false

	// First try by ID (if provided)
	if tempDeviceID != "" {
		if err := config.AppConfig.DB.First(&device, "id = ?", tempDeviceID).Error; err == nil {
			found = true
		}
	}

	// Then try by MAC
	if !found {
		if err := config.AppConfig.DB.First(&device, "mac_address = ?", mac).Error; err == nil {
			found = true
		}
	}

	if found {
		// Update existing record
		if err := config.AppConfig.DB.Model(&device).Updates(models.Device{
			MACAddress: &mac,
			IsOnline:   true,
			LastSeen:   &now,
		}).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to update device: " + err.Error(),
			})
		}
	} else if tempDeviceID != "" {
		// Store in memory so CheckProvisionStatus can see it
		PendingProvisionings.Lock()
		PendingProvisionings.Devices[tempDeviceID] = now
		PendingProvisionings.Unlock()
	}

	return c.JSON(fiber.Map{
		"success":     true,
		"mac_address": mac,
		"device_id":   tempDeviceID,
	})
}

// ─────────────────────────────────────────────────
// Generate Temporary Device UUID (pre-provisioning)
// ─────────────────────────────────────────────────

// GenerateDeviceUuid handles generating a unique ID for a new hardware device
func GenerateDeviceUuid(c *fiber.Ctx) error {
	newUUID := uuid.New().String()
	return c.JSON(fiber.Map{
		"success":   true,
		"device_id": "nt-" + newUUID[:8],
	})
}

// ─────────────────────────────────────────────────
// Validate Panel / SSID Match
// ─────────────────────────────────────────────────

type ValidatePanelInput struct {
	PanelNumber int    `json:"panel_number"` // 6, 7, or 8
	ScannedSSID string `json:"scanned_ssid"` // SSID user is connected to
}

// expectedSSID returns the correct AP SSID for a given panel number.
func expectedSSID(panelNumber int) string {
	return fmt.Sprintf("Rollin_Lift_Panel_%d", panelNumber)
}

// ValidatePanelSSID checks if the selected panel matches the connected SSID.
func ValidatePanelSSID(c *fiber.Ctx) error {
	var input ValidatePanelInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	if input.PanelNumber < 6 || input.PanelNumber > 8 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Panel number must be 6, 7, or 8",
		})
	}

	expected := expectedSSID(input.PanelNumber)
	isMatch := input.ScannedSSID == expected

	return c.JSON(fiber.Map{
		"success":       true,
		"is_valid":      isMatch,
		"expected_ssid": expected,
		"scanned_ssid":  input.ScannedSSID,
	})
}

// ─────────────────────────────────────────────────
// Get Home Network Credentials (for sending to ESP)
// ─────────────────────────────────────────────────

// GetHomeNetworkCredentials returns the stored SSID and password for a home.
func GetHomeNetworkCredentials(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	// Verify the user is a member of this home
	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	// Fetch the home record separately to get credentials
	var home models.Home
	if err := config.AppConfig.DB.First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	return c.JSON(fiber.Map{
		"success":          true,
		"network_ssid":     home.NetworkSSID,
		"network_password": home.NetworkPassword,
	})
}

// ─────────────────────────────────────────────────
// Floors & Rooms
// ─────────────────────────────────────────────────

// GetFloors returns all floors for a given home.
func GetFloors(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	var floors []models.Floor
	config.AppConfig.DB.Preload("Rooms").Where("home_id = ?", homeID).Order("order_index").Find(&floors)

	return c.JSON(fiber.Map{
		"success": true,
		"floors":  floors,
	})
}

// GetRooms returns all rooms for a given floor.
func GetRooms(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	floorID := c.Params("floorId")

	// Verify user has access to the home this floor belongs to
	var floor models.Floor
	if err := config.AppConfig.DB.First(&floor, "id = ?", floorID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Floor not found",
		})
	}

	if _, err := checkHomeAccess(config.AppConfig.DB, floor.HomeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	var rooms []models.Room
	config.AppConfig.DB.Where("floor_id = ?", floorID).Order("order_index").Find(&rooms)

	return c.JSON(fiber.Map{
		"success": true,
		"rooms":   rooms,
	})
}

// ─────────────────────────────────────────────────
// Check Provision Status (poll by device id)
// ─────────────────────────────────────────────────

// CheckProvisionStatus checks whether a newly created device is online
func CheckProvisionStatus(c *fiber.Ctx) error {
	deviceID := c.Params("id")

	// 1. Check DB first (in case app already created it or it existed before)
	var device models.Device
	err := config.AppConfig.DB.First(&device, "id = ?", deviceID).Error
	if err == nil {
		status := "offline"
		if device.IsOnline {
			status = "online"
		}
		return c.JSON(fiber.Map{
			"success":     true,
			"status":      status,
			"mac_address": device.MACAddress,
			"device_id":   device.ID,
		})
	}

	// 2. Check pending memory map (waiting for app to finish provisioning)
	PendingProvisionings.RLock()
	_, pending := PendingProvisionings.Devices[deviceID]
	PendingProvisionings.RUnlock()

	if pending {
		return c.JSON(fiber.Map{
			"success": true,
			"status":  "online",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"status":  "pending",
	})
}

// ─────────────────────────────────────────────────
// Provision Device (full onboarding save)
// ─────────────────────────────────────────────────

type ProvisionDeviceInput struct {
	DeviceID       string  `json:"device_id"`
	HomeID         string  `json:"home_id"`
	DeviceType     string  `json:"device_type"`
	Name           string  `json:"name"`
	SSIDPattern    string  `json:"ssid_pattern"`
	MACAddress     string  `json:"mac_address"`     // MAC from ESP12F
	SwitchCount    int     `json:"switch_count"`
	AssignmentType string  `json:"assignment_type"` // floor | room | site | outdoor
	FloorID        *string `json:"floor_id"`
	RoomID         *string `json:"room_id"`
}

// switchName returns a human-readable switch name for a given index.
func switchName(index int) string {
	return fmt.Sprintf("Switch %d", index)
}

// ProvisionDeviceEndpoint maps the device to its home in the DB.
// The MAC address from the ESP becomes the permanent device ID.
func ProvisionDeviceEndpoint(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var input ProvisionDeviceInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	// Validation
	if input.HomeID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "home_id is required",
		})
	}
	if input.MACAddress == "" && input.DeviceID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "mac_address or device_id is required",
		})
	}
	if input.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "device name is required",
		})
	}

	// If MAC provided, use it as the primary device ID
	finalDeviceID := input.DeviceID
	if input.MACAddress != "" {
		finalDeviceID = input.MACAddress
	}

	// Validate switch count matches device type for touch panels
	if input.DeviceType == "touch_panel" {
		if input.SwitchCount < 6 || input.SwitchCount > 8 {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"error":   "Touch panel switch count must be 6, 7, or 8",
			})
		}
	}

	// Verify home access (admin required to provision)
	if _, err := checkHomeAccess(config.AppConfig.DB, input.HomeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Admin permissions required to provision devices",
		})
	}

	// Set defaults
	assignmentType := input.AssignmentType
	if assignmentType == "" {
		assignmentType = "room"
	}

	// Begin transaction
	tx := config.AppConfig.DB.Begin()

	now := time.Now()
	mac := &input.MACAddress

	var device models.Device
	err := tx.First(&device, "id = ?", finalDeviceID).Error

	if err != nil {
		// Create new device entry
		device = models.Device{
			ID:             finalDeviceID,
			HomeID:         input.HomeID,
			DeviceType:     input.DeviceType,
			Name:           input.Name,
			SSIDPattern:    &input.SSIDPattern,
			MACAddress:     mac,
			SwitchCount:    input.SwitchCount,
			IsOnline:       true,
			LastSeen:       &now,
			AssignmentType: assignmentType,
			FloorID:        input.FloorID,
			RoomID:         input.RoomID,
		}
		if err := tx.Create(&device).Error; err != nil {
			tx.Rollback()
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to provision device: " + err.Error(),
			})
		}
	} else {
		// Re-assign existing device
		device.HomeID = input.HomeID
		device.Name = input.Name
		device.DeviceType = input.DeviceType
		device.SwitchCount = input.SwitchCount
		device.SSIDPattern = &input.SSIDPattern
		device.MACAddress = mac
		device.IsOnline = true
		device.LastSeen = &now
		device.AssignmentType = assignmentType
		device.FloorID = input.FloorID
		device.RoomID = input.RoomID

		if err := tx.Save(&device).Error; err != nil {
			tx.Rollback()
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to update provisioned device: " + err.Error(),
			})
		}
	}

	// Auto-create switch configs for touch panels
	if input.DeviceType == "touch_panel" {
		tx.Where("device_id = ?", device.ID).Delete(&models.SwitchConfig{})
		for i := 1; i <= input.SwitchCount; i++ {
			sw := models.SwitchConfig{
				DeviceID:    device.ID,
				SwitchIndex: i,
				Name:        switchName(i),
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

	// Return fully populated device
	config.AppConfig.DB.Preload("Switches").First(&device, "id = ?", device.ID)

	return c.JSON(fiber.Map{
		"success": true,
		"device":  device,
	})
}
