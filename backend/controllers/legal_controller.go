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

func TermsOfUse(c *fiber.Ctx) error {
	c.Set("Content-Type", "text/html")
	html := `
<!DOCTYPE html>
<html>
<head>
    <title>Terms of Use - Neuro Touch</title>
    <style>body { font-family: sans-serif; padding: 40px; max-width: 800px; margin: 0 auto; }</style>
</head>
<body>
    <h1>Terms of Use for Neuro Touch</h1>
    <p>Last updated: July 2026</p>
    <p>Welcome to Neuro Touch. By using our smart home devices, Alexa skill, and mobile application, you agree to these terms.</p>
    <h2>Acceptable Use</h2>
    <p>You agree to use the Neuro Touch services only for lawful purposes and in accordance with these Terms of Use. You are responsible for all activity that occurs under your account.</p>
    <h2>Service Availability</h2>
    <p>We strive to provide 99.9% uptime, but we do not guarantee that the service will be uninterrupted or error-free. Neuro Touch is not responsible for any damages resulting from service downtime.</p>
    <h2>Changes to Terms</h2>
    <p>We reserve the right to modify these terms at any time. Continued use of the service constitutes acceptance of any changes.</p>
    <h2>Contact</h2>
    <p>If you have any questions about these Terms, please contact us at support@neurolinx.in.</p>
</body>
</html>
`
	return c.SendString(html)
}
