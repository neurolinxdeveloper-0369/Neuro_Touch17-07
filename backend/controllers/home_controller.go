package controllers

import (
	"math/rand"
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// Helper to check access permissions on a home
func checkHomeAccess(db *gorm.DB, homeID, userID string, requireFullAccess bool) (*models.HomeMember, error) {
	var member models.HomeMember
	err := db.Where("home_id = ? AND user_id = ?", homeID, userID).First(&member).Error
	if err != nil {
		return nil, err
	}
	if requireFullAccess && member.PermissionLevel != "full_access" {
		return nil, gorm.ErrRecordNotFound
	}
	return &member, nil
}

// GetHomes
func GetHomes(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var members []models.HomeMember
	if err := config.AppConfig.DB.Where("user_id = ?", userID).Find(&members).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Database error checking user's homes",
		})
	}

	var homeIDs []string
	for _, m := range members {
		homeIDs = append(homeIDs, m.HomeID)
	}

	var homes []models.Home
	if len(homeIDs) > 0 {
		if err := config.AppConfig.DB.Preload("Members.User").Preload("Owner").Where("id IN ?", homeIDs).Find(&homes).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Database error preloading homes",
			})
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"homes":   homes,
	})
}

// CreateHome — accepts name, home_type, floor_count, network_ssid, network_password
type CreateHomeInput struct {
	Name            string  `json:"name"`
	HomeType        string  `json:"home_type"`         // flat | villa | building | office
	FloorCount      int     `json:"floor_count"`       // 0 for flat, user-entered for others
	NetworkSSID     *string `json:"network_ssid"`      // optional Wi-Fi SSID
	NetworkPassword *string `json:"network_password"`  // optional Wi-Fi password
}

func CreateHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var input CreateHomeInput
	if err := c.BodyParser(&input); err != nil || input.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Home name is required",
		})
	}

	// Validate home type
	validTypes := map[string]bool{"flat": true, "villa": true, "building": true, "office": true}
	if input.HomeType == "" {
		input.HomeType = "flat"
	}
	if !validTypes[input.HomeType] {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid home_type. Must be one of: flat, villa, building, office",
		})
	}

	// Flat type has no floors
	if input.HomeType == "flat" {
		input.FloorCount = 0
	}
	if input.FloorCount < 0 {
		input.FloorCount = 0
	}

	// Create transaction
	tx := config.AppConfig.DB.Begin()

	home := models.Home{
		Name:            input.Name,
		OwnerID:         userID,
		HomeType:        input.HomeType,
		FloorCount:      input.FloorCount,
		NetworkSSID:     input.NetworkSSID,
		NetworkPassword: input.NetworkPassword,
	}

	if err := tx.Create(&home).Error; err != nil {
		tx.Rollback()
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create home",
		})
	}

	member := models.HomeMember{
		HomeID:          home.ID,
		UserID:          userID,
		PermissionLevel: "full_access", // Owners get full access
	}

	if err := tx.Create(&member).Error; err != nil {
		tx.Rollback()
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create home owner mapping",
		})
	}

	if err := tx.Commit().Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Transaction commit failed",
		})
	}

	// Preload to return fully populated object
	config.AppConfig.DB.Preload("Members.User").Preload("Owner").First(&home, "id = ?", home.ID)

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"home":    home,
	})
}

// GetHome
func GetHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied to this home",
		})
	}

	var home models.Home
	if err := config.AppConfig.DB.Preload("Members.User").Preload("Owner").First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"home":    home,
	})
}

// UpdateHome — update name and/or network details
type UpdateHomeInput struct {
	Name            string  `json:"name"`
	NetworkSSID     *string `json:"network_ssid"`
	NetworkPassword *string `json:"network_password"`
}

func UpdateHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator privileges required to edit home",
		})
	}

	var input UpdateHomeInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid input",
		})
	}

	var home models.Home
	if err := config.AppConfig.DB.First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	if input.Name != "" {
		home.Name = input.Name
	}
	if input.NetworkSSID != nil {
		home.NetworkSSID = input.NetworkSSID
	}
	if input.NetworkPassword != nil {
		home.NetworkPassword = input.NetworkPassword
	}

	config.AppConfig.DB.Save(&home)

	return c.JSON(fiber.Map{
		"success": true,
		"home":    home,
	})
}

// DeleteHome
func DeleteHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	var home models.Home
	if err := config.AppConfig.DB.First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	if home.OwnerID != userID {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Only the home owner can delete it",
		})
	}

	if err := config.AppConfig.DB.Delete(&home).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to delete home",
		})
	}

	return c.JSON(fiber.Map{
		"success":  true,
		"message": "Home deleted successfully",
	})
}

// GenerateInvite
func GenerateInvite(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required to invite members",
		})
	}

	var home models.Home
	if err := config.AppConfig.DB.First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	// Generate clean random 6-character code (alphanumeric uppercase)
	const charset = "ABCDEFGHJKLMNOPQRSTUVWXYZ23456789"
	b := make([]byte, 6)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	code := string(b)

	home.InviteCode = &code
	config.AppConfig.DB.Save(&home)

	return c.JSON(fiber.Map{
		"success":     true,
		"invite_code": code,
	})
}

// JoinHome
type JoinHomeInput struct {
	Code string `json:"code"`
}

func JoinHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var input JoinHomeInput
	if err := c.BodyParser(&input); err != nil || input.Code == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invite code required",
		})
	}

	var home models.Home
	if err := config.AppConfig.DB.Where("invite_code = ?", input.Code).First(&home).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid invite code",
		})
	}

	// Verify not already member
	var existing models.HomeMember
	err := config.AppConfig.DB.Where("home_id = ? AND user_id = ?", home.ID, userID).First(&existing).Error
	if err == nil {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{
			"success": false,
			"error":   "You are already a member of this home",
		})
	}

	// Join with standard control rights
	member := models.HomeMember{
		HomeID:          home.ID,
		UserID:          userID,
		PermissionLevel: "view_control",
	}

	if err := config.AppConfig.DB.Create(&member).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to join home",
		})
	}

	// Preload full home details
	config.AppConfig.DB.Preload("Members.User").Preload("Owner").First(&home, "id = ?", home.ID)

	return c.JSON(fiber.Map{
		"success": true,
		"home":    home,
	})
}

// Members Management
func GetMembers(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied to home members",
		})
	}

	var members []models.HomeMember
	if err := config.AppConfig.DB.Preload("User").Where("home_id = ?", homeID).Find(&members).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Error loading members",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"members": members,
	})
}

type UpdateMemberInput struct {
	PermissionLevel string `json:"permission_level"`
}

func UpdateMemberPermission(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")
	targetUserID := c.Params("userId")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var input UpdateMemberInput
	if err := c.BodyParser(&input); err != nil || (input.PermissionLevel != "full_access" && input.PermissionLevel != "view_control") {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid permission level (use full_access or view_control)",
		})
	}

	var member models.HomeMember
	if err := config.AppConfig.DB.Where("home_id = ? AND user_id = ?", homeID, targetUserID).First(&member).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Member mapping not found",
		})
	}

	member.PermissionLevel = input.PermissionLevel
	config.AppConfig.DB.Save(&member)

	// Preload full member data to return
	config.AppConfig.DB.Preload("User").First(&member, "home_id = ? AND user_id = ?", homeID, targetUserID)

	return c.JSON(fiber.Map{
		"success": true,
		"member":  member,
	})
}

func RemoveMember(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")
	targetUserID := c.Params("userId")

	var home models.Home
	if err := config.AppConfig.DB.First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	// Owner can remove anyone, regular user can only remove themselves
	if home.OwnerID != userID && userID != targetUserID {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied. You cannot remove this member.",
		})
	}

	if home.OwnerID == targetUserID {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "The owner cannot be removed. Transfer ownership or delete home.",
		})
	}

	var member models.HomeMember
	if err := config.AppConfig.DB.Where("home_id = ? AND user_id = ?", homeID, targetUserID).First(&member).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Member mapping not found",
		})
	}

	config.AppConfig.DB.Delete(&member)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Member removed successfully",
	})
}

func init() {
	rand.Seed(time.Now().UnixNano())
}
