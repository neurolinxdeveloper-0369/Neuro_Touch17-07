package controllers

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"strings"
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

// Generate JWT tokens helper
func generateTokens(userID string) (string, string, error) {
	// Access Token (15 minutes)
	accessClaims := jwt.MapClaims{
		"sub": userID,
		"exp": time.Now().Add(15 * time.Minute).Unix(),
		"iat": time.Now().Unix(),
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessStr, err := accessToken.SignedString([]byte(config.AppConfig.JWTSecret))
	if err != nil {
		return "", "", err
	}

	// Refresh Token (7 days)
	refreshClaims := jwt.MapClaims{
		"sub": userID,
		"exp": time.Now().Add(7 * 24 * time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshStr, err := refreshToken.SignedString([]byte(config.AppConfig.JWTSecret))
	if err != nil {
		return "", "", err
	}

	return accessStr, refreshStr, nil
}

// Google ID token payload
type GoogleTokenInfo struct {
	Email         string `json:"email"`
	EmailVerified string `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	Aud           string `json:"aud"`
	Error         string `json:"error"`
}

type GoogleAuthInput struct {
	IdToken string `json:"id_token"`
}

// GoogleAuth handles Google token verification and login/signup
func GoogleAuth(c *fiber.Ctx) error {
	var input GoogleAuthInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	if input.IdToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "ID token is required",
		})
	}

	// Validate Google ID token via Google TokenInfo API
	resp, err := http.Get(fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?id_token=%s", url.QueryEscape(input.IdToken)))
	if err != nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to contact Google authentication service",
		})
	}
	defer resp.Body.Close()

	var tokenInfo GoogleTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to parse Google response",
		})
	}

	if tokenInfo.Error != "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   fmt.Sprintf("Invalid Google token: %s", tokenInfo.Error),
		})
	}

	// Verify audience matches our configured web/server client ID
	if config.AppConfig.GoogleClientID != "" && tokenInfo.Aud != config.AppConfig.GoogleClientID {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Token audience mismatch: not authorized for this application",
		})
	}

	if tokenInfo.Email == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Google token did not contain email",
		})
	}

	var user models.User
	dbErr := config.AppConfig.DB.Where("email = ?", tokenInfo.Email).First(&user).Error
	if dbErr != nil {
		// User does not exist, sign up
		prov := "google"
		user = models.User{
			Name:         tokenInfo.Name,
			Email:        &tokenInfo.Email,
			ProfilePic:   &tokenInfo.Picture,
			AuthProvider: prov,
		}
		if err := config.AppConfig.DB.Create(&user).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to create user in database",
			})
		}
	} else {
		// User exists, update profile pic and name if they changed
		user.Name = tokenInfo.Name
		user.ProfilePic = &tokenInfo.Picture
		user.AuthProvider = "google"
		config.AppConfig.DB.Save(&user)
	}

	access, refresh, err := generateTokens(user.ID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to generate session tokens",
		})
	}

	return c.JSON(fiber.Map{
		"success":       true,
		"access_token":  access,
		"refresh_token": refresh,
		"user":          user,
	})
}

type SendOTPInput struct {
	Phone string `json:"phone"`
}

// SendOTP generates and simulates sending an OTP
func SendOTP(c *fiber.Ctx) error {
	var input SendOTPInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	phone := strings.TrimSpace(input.Phone)
	if phone == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Phone number is required",
		})
	}

	// Generate 6-digit OTP code
	otpCode := fmt.Sprintf("%06d", rand.Intn(1000000))

	// In GORM, upsert the verification code for this phone number
	var verification models.OTPVerification
	err := config.AppConfig.DB.Where("phone = ?", phone).First(&verification).Error
	if err == nil {
		// Update existing
		verification.OTP = otpCode
		verification.ExpiresAt = time.Now().Add(5 * time.Minute)
		config.AppConfig.DB.Save(&verification)
	} else {
		// Create new
		verification = models.OTPVerification{
			Phone:     phone,
			OTP:       otpCode,
			ExpiresAt: time.Now().Add(5 * time.Minute),
		}
		config.AppConfig.DB.Create(&verification)
	}

	// Simulate sending by logging to terminal
	log.Printf("[SIMULATED OTP] Verification code for phone %s is: '%s'", phone, otpCode)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "OTP verification code sent",
	})
}

type VerifyOTPInput struct {
	Phone string `json:"phone"`
	OTP   string `json:"otp"`
	Name  string `json:"name,omitempty"`
}

// VerifyOTPLogin verifies the OTP and performs login/signup
func VerifyOTPLogin(c *fiber.Ctx) error {
	var input VerifyOTPInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request body",
		})
	}

	phone := strings.TrimSpace(input.Phone)
	otp := strings.TrimSpace(input.OTP)

	if phone == "" || otp == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Phone number and OTP code are required",
		})
	}

	var verification models.OTPVerification
	err := config.AppConfig.DB.Where("phone = ? AND otp = ?", phone, otp).First(&verification).Error
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid OTP code",
		})
	}

	if time.Now().After(verification.ExpiresAt) {
		config.AppConfig.DB.Delete(&verification)
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "OTP code has expired",
		})
	}

	// Delete verification record since it succeeded
	config.AppConfig.DB.Delete(&verification)

	var user models.User
	dbErr := config.AppConfig.DB.Where("phone = ?", phone).First(&user).Error
	if dbErr != nil {
		// New user, sign up
		name := strings.TrimSpace(input.Name)
		if name == "" {
			// Extract last 4 digits of phone for default name
			displayDigits := phone
			if len(phone) > 4 {
				displayDigits = phone[len(phone)-4:]
			}
			name = "User " + displayDigits
		}

		// Generate letter DP URL
		firstLetter := "U"
		if len(name) > 0 {
			firstLetter = string([]rune(name)[0])
		}
		profilePicURL := fmt.Sprintf("https://ui-avatars.com/api/?name=%s&background=random&color=fff&size=128", url.QueryEscape(firstLetter))

		user = models.User{
			Name:         name,
			Phone:        &phone,
			ProfilePic:   &profilePicURL,
			AuthProvider: "otp",
		}

		if err := config.AppConfig.DB.Create(&user).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"error":   "Failed to create user in database",
			})
		}
	} else {
		// User exists, update auth provider to otp if needed
		user.AuthProvider = "otp"
		config.AppConfig.DB.Save(&user)
	}

	access, refresh, err := generateTokens(user.ID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Failed to generate session tokens",
		})
	}

	return c.JSON(fiber.Map{
		"success":       true,
		"access_token":  access,
		"refresh_token": refresh,
		"user":          user,
	})
}

type RefreshTokenInput struct {
	RefreshToken string `json:"refresh_token"`
}

// RefreshToken handles token refresh
func RefreshToken(c *fiber.Ctx) error {
	var input RefreshTokenInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid request",
		})
	}

	token, err := jwt.Parse(input.RefreshToken, func(token *jwt.Token) (interface{}, error) {
		return []byte(config.AppConfig.JWTSecret), nil
	})

	if err != nil || !token.Valid {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid or expired refresh token",
		})
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "Invalid token claims",
		})
	}

	userID := claims["sub"].(string)

	var user models.User
	if err := config.AppConfig.DB.First(&user, "id = ?", userID).Error; err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"error":   "User not found",
		})
	}

	access, refresh, err := generateTokens(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"error":   "Error generating tokens",
		})
	}

	return c.JSON(fiber.Map{
		"success":       true,
		"access_token":  access,
		"refresh_token": refresh,
	})
}

func init() {
	rand.Seed(time.Now().UnixNano())
}
