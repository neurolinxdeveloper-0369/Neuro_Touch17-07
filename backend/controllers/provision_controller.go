package controllers

import (
	"fmt"
	"strings"
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

// MACConfirmEndpoint is a public endpoint called by the ESP12F panel
// once it successfully connects to the local Wi-Fi.
func MACConfirmEndpoint(c *fiber.Ctx) error {
	mac := c.Query("mac")
	tempDeviceID := c.Query("device_id")

	if mac == "" || tempDeviceID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Missing MAC address or device_id",
		})
	}

	mac = strings.ToUpper(mac)
	now := time.Now()

	// 1. Authenticate via ProvisioningSession
	var session models.ProvisioningSession
	if err := config.AppConfig.DB.First(&session, "device_id = ?", tempDeviceID).Error; err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Unauthorized or invalid device_id",
		})
	}

	// 2. Mark session as confirmed
	session.MACAddress = &mac
	session.IsConfirmed = true
	config.AppConfig.DB.Save(&session)

	// 3. Upsert device — update if exists, create placeholder if not
	var device models.Device
	if err := config.AppConfig.DB.First(&device, "id = ? OR mac_address = ?", tempDeviceID, mac).Error; err == nil {
		// Device already exists — clear any stale MAC collision then update
		config.AppConfig.DB.Model(&models.Device{}).
			Where("mac_address = ? AND id != ?", mac, device.ID).
			Update("mac_address", nil)

		config.AppConfig.DB.Model(&device).Updates(models.Device{
			MACAddress: &mac,
			IsOnline:   true,
			LastSeen:   &now,
		})
	} else {
		// Device does NOT exist yet — create a placeholder row so the app
		// can detect it online and then call ProvisionDeviceEndpoint to fill
		// in home, name, device_type etc.
		// Clear any stale record that may hold this MAC on a different ID.
		config.AppConfig.DB.Model(&models.Device{}).
			Where("mac_address = ?", mac).
			Update("mac_address", nil)

		placeholder := models.Device{
			ID:             tempDeviceID,
			HomeID:         "",           // Will be set by ProvisionDeviceEndpoint
			DeviceType:     "energy_meter",
			Name:           "Unprovisioned Device",
			MACAddress:     &mac,
			IsOnline:       true,
			LastSeen:       &now,
			AssignmentType: "room",
		}
		config.AppConfig.DB.Create(&placeholder)
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
	deviceID := "nt-" + newUUID[:8]

	session := models.ProvisioningSession{
		DeviceID: deviceID,
	}
	if err := config.AppConfig.DB.Create(&session).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to initialize provisioning session",
		})
	}

	return c.JSON(fiber.Map{
		"success":   true,
		"device_id": deviceID,
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
	return fmt.Sprintf("Neuro_Lift_Panel_%d", panelNumber)
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

	// 2. Check ProvisioningSession
	var session models.ProvisioningSession
	if err := config.AppConfig.DB.First(&session, "device_id = ?", deviceID).Error; err == nil {
		if session.IsConfirmed {
			return c.JSON(fiber.Map{
				"success":     true,
				"status":      "online",
				"mac_address": session.MACAddress,
				"device_id":   deviceID,
			})
		}
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
			"error":   "Invalid request body: " + err.Error(),
		})
	}

	// Validation
	if input.HomeID == "" {
		fmt.Println("ProvisionDeviceEndpoint 400: home_id is required")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "home_id is required",
		})
	}
	if input.MACAddress == "" && input.DeviceID == "" {
		fmt.Println("ProvisionDeviceEndpoint 400: mac_address or device_id is required")
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "mac_address or device_id is required",
		})
	}
	if input.Name == "" {
		fmt.Println("ProvisionDeviceEndpoint 400: device name is required")
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

	// Validate switch count is reasonable
	if input.SwitchCount < 0 || input.SwitchCount > 64 {
		fmt.Printf("ProvisionDeviceEndpoint 400: invalid switch count: %d\n", input.SwitchCount)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Switch count must be between 0 and 64",
		})
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
	query := tx.Where("id = ?", finalDeviceID)
	if input.MACAddress != "" {
		query = query.Or("mac_address = ?", input.MACAddress)
	}
	err := query.First(&device).Error

	if err != nil {
			// Create new device entry
		homeID := input.HomeID
		device = models.Device{
			ID:             finalDeviceID,
			HomeID:         &homeID,
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
		homeID2 := input.HomeID
		device.HomeID = &homeID2
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

	// Auto-create switch configs for devices with switches
	if input.SwitchCount > 0 {
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

	// Auto-create gas motor config for gas_control devices
	if input.DeviceType == "gas_control" {
		var motorCount int64
		tx.Model(&models.GasMotor{}).Where("device_id = ?", device.ID).Count(&motorCount)
		if motorCount == 0 {
			gm := models.GasMotor{
				DeviceID: device.ID,
				MotorID:  1,
				State:    "off",
			}
			if err := tx.Create(&gm).Error; err != nil {
				tx.Rollback()
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
					"success": false,
					"error":   "Failed to generate default gas motor: " + err.Error(),
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
