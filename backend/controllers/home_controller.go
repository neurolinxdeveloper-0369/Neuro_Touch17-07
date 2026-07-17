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
		return nil, gorm.ErrRecordNotFound // Or simulated auth check
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

// CreateHome
type CreateHomeInput struct {
	Name string `json:"name"`
}

func CreateHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var input CreateHomeInput
	if err := c.BodyParser(&input); err != nil || input.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid home details",
		})
	}

	// Create transaction
	tx := config.AppConfig.DB.Begin()

	home := models.Home{
		Name:    input.Name,
		OwnerID: userID,
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

// UpdateHome
func UpdateHome(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator privileges required to edit home",
		})
	}

	var input CreateHomeInput
	if err := c.BodyParser(&input); err != nil || input.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid home name",
		})
	}

	var home models.Home
	if err := config.AppConfig.DB.First(&home, "id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Home not found",
		})
	}

	home.Name = input.Name
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
		"success": true,
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

// --- Floors Controllers ---

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
	if err := config.AppConfig.DB.Order("order_index asc").Find(&floors, "home_id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to retrieve floors",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"floors":  floors,
	})
}

type FloorInput struct {
	Name       string `json:"name"`
	OrderIndex *int   `json:"order_index,omitempty"`
}

func CreateFloor(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var input FloorInput
	if err := c.BodyParser(&input); err != nil || input.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid floor name",
		})
	}

	order := 0
	if input.OrderIndex != nil {
		order = *input.OrderIndex
	}

	floor := models.Floor{
		HomeID:     homeID,
		Name:       input.Name,
		OrderIndex: order,
	}

	if err := config.AppConfig.DB.Create(&floor).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create floor",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"floor":   floor,
	})
}

func UpdateFloor(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")
	floorID := c.Params("floorId")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var input FloorInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid parameters",
		})
	}

	var floor models.Floor
	if err := config.AppConfig.DB.First(&floor, "id = ? AND home_id = ?", floorID, homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Floor not found",
		})
	}

	if input.Name != "" {
		floor.Name = input.Name
	}
	if input.OrderIndex != nil {
		floor.OrderIndex = *input.OrderIndex
	}

	config.AppConfig.DB.Save(&floor)

	return c.JSON(fiber.Map{
		"success": true,
		"floor":   floor,
	})
}

func DeleteFloor(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")
	floorID := c.Params("floorId")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var floor models.Floor
	if err := config.AppConfig.DB.First(&floor, "id = ? AND home_id = ?", floorID, homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Floor not found",
		})
	}

	config.AppConfig.DB.Delete(&floor)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Floor deleted successfully",
	})
}

// --- Rooms Controllers ---

func GetRooms(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, false); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	var rooms []models.Room
	if err := config.AppConfig.DB.Order("order_index asc").Find(&rooms, "home_id = ?", homeID).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to retrieve rooms",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"rooms":   rooms,
	})
}

type RoomInput struct {
	FloorID    string `json:"floor_id"`
	Name       string `json:"name"`
	Icon       string `json:"icon"`
	OrderIndex *int   `json:"order_index,omitempty"`
}

func CreateRoom(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var input RoomInput
	if err := c.BodyParser(&input); err != nil || input.Name == "" || input.FloorID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Floor ID and Room name are required",
		})
	}

	// Verify floor belongs to this home
	var floor models.Floor
	if err := config.AppConfig.DB.First(&floor, "id = ? AND home_id = ?", input.FloorID, homeID).Error; err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid floor ID for this home",
		})
	}

	order := 0
	if input.OrderIndex != nil {
		order = *input.OrderIndex
	}

	iconStr := "room"
	if input.Icon != "" {
		iconStr = input.Icon
	}

	room := models.Room{
		FloorID:    input.FloorID,
		HomeID:     homeID,
		Name:       input.Name,
		Icon:       iconStr,
		OrderIndex: order,
	}

	if err := config.AppConfig.DB.Create(&room).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to create room",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"room":    room,
	})
}

func UpdateRoom(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")
	roomID := c.Params("roomId")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var input RoomInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid parameters",
		})
	}

	var room models.Room
	if err := config.AppConfig.DB.First(&room, "id = ? AND home_id = ?", roomID, homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Room not found",
		})
	}

	if input.Name != "" {
		room.Name = input.Name
	}
	if input.Icon != "" {
		room.Icon = input.Icon
	}
	if input.OrderIndex != nil {
		room.OrderIndex = *input.OrderIndex
	}

	config.AppConfig.DB.Save(&room)

	return c.JSON(fiber.Map{
		"success": true,
		"room":    room,
	})
}

func DeleteRoom(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	homeID := c.Params("id")
	roomID := c.Params("roomId")

	if _, err := checkHomeAccess(config.AppConfig.DB, homeID, userID, true); err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Administrator permissions required",
		})
	}

	var room models.Room
	if err := config.AppConfig.DB.First(&room, "id = ? AND home_id = ?", roomID, homeID).Error; err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"error":   "Room not found",
		})
	}

	config.AppConfig.DB.Delete(&room)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Room deleted successfully",
	})
}

func init() {
	rand.Seed(time.Now().UnixNano())
}
