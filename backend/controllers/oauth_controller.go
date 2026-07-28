package controllers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
)

// Generate a random string for auth codes and tokens
func generateRandomHex(n int) string {
	bytes := make([]byte, n)
	if _, err := rand.Read(bytes); err != nil {
		return ""
	}
	return hex.EncodeToString(bytes)
}

// RenderAuthorizePage serves the HTML page for Alexa Account Linking
func RenderAuthorizePage(c *fiber.Ctx) error {
	state := c.Query("state")
	redirectURI := c.Query("redirect_uri")
	clientID := c.Query("client_id")

	if redirectURI == "" {
		return c.Status(fiber.StatusBadRequest).SendString("Missing redirect_uri")
	}

	html := fmt.Sprintf(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Link Neuro Touch with Alexa</title>
    <script src="https://accounts.google.com/gsi/client" async defer></script>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #111844; color: white; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background-color: #1e265c; padding: 30px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); width: 100%%; max-width: 400px; text-align: center; }
        input { width: 100%%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; box-sizing: border-box; background-color: #2a336d; color: white; }
        button { width: 100%%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; background-color: #4CAF50; color: white; font-weight: bold; cursor: pointer; font-size: 16px; }
        button:hover { background-color: #45a049; }
        .hidden { display: none; }
        .error { color: #ff5252; font-size: 14px; margin-bottom: 10px; }
    </style>
</head>
<body>
    <div class="card" id="step1">
        <h2>Neuro Touch Alexa Link</h2>
        <p>Enter your phone number to receive an OTP</p>
        <div id="error1" class="error hidden"></div>
        <input type="text" id="phone" placeholder="Phone Number (e.g. 1234567890)">
        <button onclick="sendOTP()">Send OTP</button>

        <div style="margin: 20px 0; color: #aaa;">OR</div>

        <div id="g_id_onload"
             data-client_id="%s"
             data-context="signin"
             data-ux_mode="popup"
             data-callback="handleGoogleLogin"
             data-auto_prompt="false">
        </div>
        <div class="g_id_signin"
             data-type="standard"
             data-shape="rectangular"
             data-theme="outline"
             data-text="signin_with"
             data-size="large"
             data-logo_alignment="left"
             style="display: flex; justify-content: center;">
        </div>
    </div>

    <div class="card hidden" id="step2">
        <h2>Verify OTP</h2>
        <p>Enter the code sent to your phone</p>
        <div id="error2" class="error hidden"></div>
        <input type="text" id="otp" placeholder="6-digit OTP">
        <button onclick="verifyAndLink()">Verify & Link Account</button>
    </div>

    <script>
        const state = "%s";
        const redirectUri = "%s";
        const clientId = "%s";

        async function sendOTP() {
            const phone = document.getElementById('phone').value;
            try {
                const res = await fetch('/api/v1/auth/otp/send', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({phone: phone})
                });
                const data = await res.json();
                if(data.success) {
                    document.getElementById('step1').classList.add('hidden');
                    document.getElementById('step2').classList.remove('hidden');
                    document.getElementById('error1').classList.add('hidden');
                } else {
                    const err = document.getElementById('error1');
                    err.innerText = data.error || "Failed to send OTP";
                    err.classList.remove('hidden');
                }
            } catch (e) {
                console.error(e);
            }
        }

        async function verifyAndLink() {
            const phone = document.getElementById('phone').value;
            const otp = document.getElementById('otp').value;
            try {
                const res = await fetch('/api/v1/oauth/authorize', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({phone, otp, state, redirect_uri: redirectUri, client_id: clientId})
                });
                const data = await res.json();
                if(data.success) {
                    window.location.href = data.redirect_url;
                } else {
                    const err = document.getElementById('error2');
                    err.innerText = data.error || "Invalid OTP";
                    err.classList.remove('hidden');
                }
            } catch (e) {
                console.error(e);
            }
        }

        async function handleGoogleLogin(response) {
            try {
                const res = await fetch('/api/v1/oauth/authorize', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({id_token: response.credential, state, redirect_uri: redirectUri, client_id: clientId})
                });
                const data = await res.json();
                if(data.success) {
                    window.location.href = data.redirect_url;
                } else {
                    const err = document.getElementById('error1');
                    err.innerText = data.error || "Google login failed";
                    err.classList.remove('hidden');
                }
            } catch (e) {
                console.error(e);
            }
        }
    </script>
</body>
</html>
`, config.AppConfig.GoogleClientID, state, redirectURI, clientID)

	c.Set("Content-Type", "text/html")
	return c.SendString(html)
}

type AuthorizeSubmitInput struct {
	Phone       string `json:"phone"`
	OTP         string `json:"otp"`
	IdToken     string `json:"id_token"`
	State       string `json:"state"`
	RedirectURI string `json:"redirect_uri"`
	ClientID    string `json:"client_id"`
}

// AuthorizeSubmit verifies the OTP and generates the authorization code
func AuthorizeSubmit(c *fiber.Ctx) error {
	var input AuthorizeSubmitInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Invalid request"})
	}

	var user models.User

	if input.IdToken != "" {
		// Handle Google Sign-In
		resp, err := http.Get(fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?id_token=%s", url.QueryEscape(input.IdToken)))
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Failed to contact Google"})
		}
		defer resp.Body.Close()

		var tokenInfo GoogleTokenInfo
		if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil || tokenInfo.Error != "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Invalid Google token"})
		}

		if err := config.AppConfig.DB.Where("email = ?", tokenInfo.Email).First(&user).Error; err != nil {
			// Create user if not exists
			user = models.User{Name: tokenInfo.Name, Email: &tokenInfo.Email, AuthProvider: "google"}
			config.AppConfig.DB.Create(&user)
		}
	} else {
		// Handle Phone OTP
		phone := strings.TrimSpace(input.Phone)
		otp := strings.TrimSpace(input.OTP)

		var verification models.OTPVerification
		err := config.AppConfig.DB.Where("phone = ? AND otp = ?", phone, otp).First(&verification).Error
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Invalid OTP code"})
		}

		if time.Now().After(verification.ExpiresAt) {
			config.AppConfig.DB.Delete(&verification)
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "OTP has expired"})
		}
		config.AppConfig.DB.Delete(&verification)

		if err := config.AppConfig.DB.Where("phone = ?", phone).First(&user).Error; err != nil {
			user = models.User{Name: "User " + phone, Phone: &phone, AuthProvider: "otp"}
			config.AppConfig.DB.Create(&user)
		}
	}

	// Generate Authorization Code
	authCode := generateRandomHex(32)

	oauthToken := models.OAuthToken{
		UserID:            user.ID,
		AuthorizationCode: authCode,
		ExpiresAt:         time.Now().Add(10 * time.Minute),
	}
	
	if err := config.AppConfig.DB.Create(&oauthToken).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to create token"})
	}

	redirectURL := fmt.Sprintf("%s?state=%s&code=%s", input.RedirectURI, url.QueryEscape(input.State), authCode)
	return c.JSON(fiber.Map{"success": true, "redirect_url": redirectURL})
}

// Token handles Alexa exchanging the auth code for access and refresh tokens
func Token(c *fiber.Ctx) error {
	grantType := c.FormValue("grant_type")

	if grantType == "authorization_code" {
		code := c.FormValue("code")
		
		var oauthToken models.OAuthToken
		if err := config.AppConfig.DB.Where("authorization_code = ?", code).First(&oauthToken).Error; err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_grant"})
		}

		if time.Now().After(oauthToken.ExpiresAt) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_grant", "error_description": "Code expired"})
		}

		// Generate Access and Refresh tokens
		oauthToken.AccessToken = generateRandomHex(64)
		oauthToken.RefreshToken = generateRandomHex(64)
		oauthToken.AuthorizationCode = "" // Burn the code
		oauthToken.ExpiresAt = time.Now().Add(30 * 24 * time.Hour) // 30 days
		config.AppConfig.DB.Save(&oauthToken)

		return c.JSON(fiber.Map{
			"access_token":  oauthToken.AccessToken,
			"token_type":    "Bearer",
			"expires_in":    2592000, // 30 days in seconds
			"refresh_token": oauthToken.RefreshToken,
		})
	} else if grantType == "refresh_token" {
		refreshToken := c.FormValue("refresh_token")
		
		var oauthToken models.OAuthToken
		if err := config.AppConfig.DB.Where("refresh_token = ?", refreshToken).First(&oauthToken).Error; err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_grant"})
		}

		// Rotate Access Token
		oauthToken.AccessToken = generateRandomHex(64)
		config.AppConfig.DB.Save(&oauthToken)

		return c.JSON(fiber.Map{
			"access_token":  oauthToken.AccessToken,
			"token_type":    "Bearer",
			"expires_in":    2592000,
			"refresh_token": oauthToken.RefreshToken, // Optional: return same or new refresh token
		})
	}

	return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "unsupported_grant_type"})
}
