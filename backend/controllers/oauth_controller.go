package controllers

import (
	"crypto/rand"
	"crypto/sha256"
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

// hashToken creates a SHA-256 hash of the token for secure storage
func hashToken(token string) string {
	hasher := sha256.New()
	hasher.Write([]byte(token))
	return hex.EncodeToString(hasher.Sum(nil))
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
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #111844; color: white; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background-color: #1e265c; padding: 30px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); width: 100%%; max-width: 400px; text-align: center; }
        input { width: 100%%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; box-sizing: border-box; background-color: #2a336d; color: white; }
        button { width: 100%%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; background-color: #4CAF50; color: white; font-weight: bold; cursor: pointer; font-size: 16px; }
        button:hover { background-color: #45a049; }
        .hidden { display: none; }
        .error { color: #ff5252; font-size: 14px; margin-bottom: 10px; }
        .loading { font-size: 18px; color: #4CAF50; }
    </style>
</head>
<body>
    <div class="card hidden" id="loadingState">
        <h2>Linking Account...</h2>
        <p class="loading">Please wait while we verify your Google login.</p>
    </div>

    <div class="card" id="step1">
        <h2>Neuro Touch Alexa Link</h2>
        <p>Enter your phone number to receive an OTP</p>
        <div id="error1" class="error hidden"></div>
        <input type="text" id="phone" placeholder="Phone Number (e.g. 1234567890)">
        <button onclick="sendOTP()">Send OTP</button>

        <div style="margin: 20px 0; color: #aaa;">OR</div>

        <button onclick="loginWithGoogle()" style="background-color: #4285F4; display: flex; align-items: center; justify-content: center;">
            <svg style="width:18px;height:18px;margin-right:10px;" viewBox="0 0 24 24"><path fill="#fff" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/><path fill="#fff" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="#fff" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="#fff" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>
            Sign in with Google
        </button>
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
        const googleClientId = "%s";

        window.onload = function() {
            if (window.location.hash.includes("id_token=")) {
                const hashParams = new URLSearchParams(window.location.hash.substring(1));
                const idToken = hashParams.get("id_token");
                const customStateEncoded = hashParams.get("state");
                
                if (idToken && customStateEncoded) {
                    try {
                        const customState = JSON.parse(atob(customStateEncoded));
                        document.getElementById('step1').classList.add('hidden');
                        document.getElementById('loadingState').classList.remove('hidden');
                        
                        fetch('/api/v1/oauth/authorize', {
                            method: 'POST',
                            headers: {'Content-Type': 'application/json'},
                            body: JSON.stringify({
                                id_token: idToken, 
                                state: customState.state, 
                                redirect_uri: customState.redirect_uri, 
                                client_id: customState.client_id
                            })
                        })
                        .then(res => res.json())
                        .then(data => {
                            if(data.success) {
                                window.location.href = data.redirect_url;
                            } else {
                                document.getElementById('loadingState').classList.add('hidden');
                                document.getElementById('step1').classList.remove('hidden');
                                const err = document.getElementById('error1');
                                err.innerText = data.error || "Google login failed on backend";
                                err.classList.remove('hidden');
                                window.history.pushState("", document.title, window.location.pathname + window.location.search);
                            }
                        });
                    } catch(e) {
                        console.error(e);
                    }
                }
            }
        };

        function loginWithGoogle() {
            const myRedirectUri = window.location.origin + window.location.pathname;
            const customState = btoa(JSON.stringify({ state: state, redirect_uri: redirectUri, client_id: clientId }));
            const url = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${googleClientId}&redirect_uri=${encodeURIComponent(myRedirectUri)}&response_type=id_token&scope=email%20profile&state=${customState}&nonce=12345`;
            window.location.href = url;
        }

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
    </script>
</body>
</html>
`, state, redirectURI, clientID, config.AppConfig.GoogleClientID)

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

		if phone == "1234567890" && otp == "123456" {
			// Backdoor for Amazon Certification Testing
			// Log them into the main testing account
			if err := config.AppConfig.DB.Where("phone = ?", phone).First(&user).Error; err != nil {
				user = models.User{Name: "Amazon Tester", Phone: &phone, AuthProvider: "otp"}
				config.AppConfig.DB.Create(&user)
			}
		} else {
			// Normal OTP Verification
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
	}

	// Generate Authorization Code
	authCode := generateRandomHex(32)
	accessToken := generateRandomHex(32)
	refreshToken := generateRandomHex(32)

	oauthToken := models.OAuthToken{
		UserID:            user.ID,
		AuthorizationCode: hashToken(authCode),
		AccessToken:       hashToken(accessToken),
		RefreshToken:      hashToken(refreshToken),
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
		hashedCode := hashToken(code)
		
		var oauthToken models.OAuthToken
		// Backwards compatibility for existing plaintext codes during transition
		if err := config.AppConfig.DB.Where("authorization_code = ? OR authorization_code = ?", hashedCode, code).First(&oauthToken).Error; err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_grant"})
		}

		if time.Now().After(oauthToken.ExpiresAt) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_grant", "error_description": "Code expired"})
		}

		// Generate Access and Refresh tokens
		newAccess := generateRandomHex(64)
		newRefresh := generateRandomHex(64)
		
		oauthToken.AccessToken = hashToken(newAccess)
		oauthToken.RefreshToken = hashToken(newRefresh)
		oauthToken.AuthorizationCode = "" // Burn the code
		oauthToken.ExpiresAt = time.Now().Add(30 * 24 * time.Hour) // 30 days
		config.AppConfig.DB.Save(&oauthToken)

		return c.JSON(fiber.Map{
			"access_token":  newAccess,
			"token_type":    "Bearer",
			"expires_in":    2592000, // 30 days in seconds
			"refresh_token": newRefresh,
		})
	} else if grantType == "refresh_token" {
		refreshToken := c.FormValue("refresh_token")
		hashedRefresh := hashToken(refreshToken)
		
		var oauthToken models.OAuthToken
		// Backwards compatibility for existing plaintext refresh tokens
		if err := config.AppConfig.DB.Where("refresh_token = ? OR refresh_token = ?", hashedRefresh, refreshToken).First(&oauthToken).Error; err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid_grant"})
		}

		// Rotate Access Token
		newAccess := generateRandomHex(64)
		oauthToken.AccessToken = hashToken(newAccess)
		// Upgrade refresh token to hash if it was plaintext
		oauthToken.RefreshToken = hashedRefresh
		config.AppConfig.DB.Save(&oauthToken)

		return c.JSON(fiber.Map{
			"access_token":  newAccess,
			"token_type":    "Bearer",
			"expires_in":    2592000,
			"refresh_token": refreshToken, // Return same refresh token
		})
	}

	return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "unsupported_grant_type"})
}
