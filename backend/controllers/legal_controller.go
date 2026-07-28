package controllers

import "github.com/gofiber/fiber/v2"

func PrivacyPolicy(c *fiber.Ctx) error {
	c.Set("Content-Type", "text/html")
	html := `
<!DOCTYPE html>
<html>
<head>
    <title>Privacy Policy - Neuro Touch</title>
    <style>body { font-family: sans-serif; padding: 40px; max-width: 800px; margin: 0 auto; }</style>
</head>
<body>
    <h1>Privacy Policy for Neuro Touch</h1>
    <p>Last updated: July 2026</p>
    <p>Your privacy is important to us. This privacy policy explains how Neuro Touch collects, uses, and protects your data.</p>
    <h2>Data Collection</h2>
    <p>We collect basic account information (such as your phone number or email) to link your smart home devices to the Alexa service.</p>
    <h2>Data Usage</h2>
    <p>Your data is used strictly for authenticating and operating your smart home devices. We do not sell or share your data with third parties.</p>
    <h2>Contact Us</h2>
    <p>If you have any questions, please contact us at support@neurolinx.in.</p>
</body>
</html>
`
	return c.SendString(html)
}
