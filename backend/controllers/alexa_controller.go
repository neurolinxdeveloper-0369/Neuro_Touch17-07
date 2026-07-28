package controllers

import (
	"encoding/json"
	"fmt"
	"strings"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type AlexaDirective struct {
	Directive struct {
		Header struct {
			Namespace      string `json:"namespace"`
			Name           string `json:"name"`
			PayloadVersion string `json:"payloadVersion"`
			MessageId      string `json:"messageId"`
			CorrelationToken string `json:"correlationToken,omitempty"`
		} `json:"header"`
		Endpoint struct {
			Scope struct {
				Type  string `json:"type"`
				Token string `json:"token"`
			} `json:"scope"`
			EndpointId string `json:"endpointId"`
		} `json:"endpoint,omitempty"`
		Payload json.RawMessage `json:"payload"`
	} `json:"directive"`
}

// AlexaEndpoint handles incoming directives from AWS Lambda
func AlexaEndpoint(c *fiber.Ctx) error {
	var req AlexaDirective
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid directive format"})
	}

	namespace := req.Directive.Header.Namespace
	name := req.Directive.Header.Name
	
	// For Discovery, token is in payload.scope. For others, it's in endpoint.scope
	var token string
	if namespace == "Alexa.Discovery" {
		var payload struct {
			Scope struct {
				Token string `json:"token"`
			} `json:"scope"`
		}
		json.Unmarshal(req.Directive.Payload, &payload)
		token = payload.Scope.Token
	} else {
		token = req.Directive.Endpoint.Scope.Token
	}

	// Verify Token
	var oauthToken models.OAuthToken
	if err := config.AppConfig.DB.Preload("User").Where("access_token = ?", token).First(&oauthToken).Error; err != nil {
		// Return Alexa ErrorResponse InvalidAuthorizationCredential
		return c.JSON(createAlexaError(req.Directive.Header.CorrelationToken, req.Directive.Endpoint.EndpointId, "INVALID_AUTHORIZATION_CREDENTIAL", "Invalid token"))
	}

	user := oauthToken.User

	switch namespace {
	case "Alexa.Discovery":
		if name == "Discover" {
			return handleDiscovery(c, user, req.Directive.Header.MessageId)
		}
	case "Alexa.PowerController":
		if name == "TurnOn" || name == "TurnOff" {
			return handlePowerControl(c, req, user, name == "TurnOn")
		}
	}

	// Fallback error
	return c.JSON(createAlexaError(req.Directive.Header.CorrelationToken, req.Directive.Endpoint.EndpointId, "INVALID_DIRECTIVE", "Unsupported directive"))
}

func handleDiscovery(c *fiber.Ctx, user models.User, messageId string) error {
	var devices []models.Device
	
	// Get all devices owned by user's homes
	// Since user.Homes is many-to-many, we fetch user's homes first
	config.AppConfig.DB.Preload("Homes.Devices.Switches").First(&user)

	var endpoints []map[string]interface{}

	for _, home := range user.Homes {
		for _, device := range home.Devices {
			for _, sw := range device.Switches {
				endpoint := map[string]interface{}{
					"endpointId":        fmt.Sprintf("%s_%d", device.ID, sw.SwitchIndex),
					"manufacturerName":  "Neuro Touch",
					"description":       "Smart Switch by Neuro Touch",
					"friendlyName":      sw.Name,
					"displayCategories": []string{"SWITCH"},
					"cookie": map[string]string{
						"mac": device.ID, // Or MAC
					},
					"capabilities": []map[string]interface{}{
						{
							"type":      "AlexaInterface",
							"interface": "Alexa.PowerController",
							"version":   "3",
							"properties": map[string]interface{}{
								"supported": []map[string]string{{"name": "powerState"}},
								"proactivelyReported": true,
								"retrievable":         true,
							},
						},
						{
							"type":      "AlexaInterface",
							"interface": "Alexa",
							"version":   "3",
						},
					},
				}
				endpoints = append(endpoints, endpoint)
			}
		}
	}

	response := map[string]interface{}{
		"event": map[string]interface{}{
			"header": map[string]string{
				"namespace":      "Alexa.Discovery",
				"name":           "Discover.Response",
				"payloadVersion": "3",
				"messageId":      uuid.NewString(),
			},
			"payload": map[string]interface{}{
				"endpoints": endpoints,
			},
		},
	}

	return c.JSON(response)
}

func handlePowerControl(c *fiber.Ctx, req AlexaDirective, user models.User, turnOn bool) error {
	endpointId := req.Directive.Endpoint.EndpointId
	correlationToken := req.Directive.Header.CorrelationToken

	// endpointId is format "deviceID_switchIndex"
	parts := strings.Split(endpointId, "_")
	if len(parts) != 2 {
		return c.JSON(createAlexaError(correlationToken, endpointId, "NO_SUCH_ENDPOINT", "Invalid endpoint ID"))
	}
	deviceId := parts[0]
	// switchIndex := parts[1] // if needed to validate

	// Publish MQTT Command
	topic := fmt.Sprintf("neurotouch/devices/%s/command/switch", deviceId)
	
	// Assuming state is sent as boolean
	payload := map[string]interface{}{
		"switch_index": parts[1],
		"state": turnOn,
	}
	
	payloadBytes, _ := json.Marshal(payload)
	MqttPublish(topic, string(payloadBytes))

	// Respond with state report
	powerState := "OFF"
	if turnOn {
		powerState = "ON"
	}

	response := map[string]interface{}{
		"context": map[string]interface{}{
			"properties": []map[string]interface{}{
				{
					"namespace":                 "Alexa.PowerController",
					"name":                      "powerState",
					"value":                     powerState,
					"timeOfSample":              "2023-01-01T00:00:00Z", // Should use ISO8601 current time
					"uncertaintyInMilliseconds": 0,
				},
			},
		},
		"event": map[string]interface{}{
			"header": map[string]string{
				"namespace":        "Alexa",
				"name":             "Response",
				"payloadVersion":   "3",
				"messageId":        uuid.NewString(),
				"correlationToken": correlationToken,
			},
			"endpoint": map[string]string{
				"endpointId": endpointId,
			},
			"payload": map[string]interface{}{},
		},
	}

	return c.JSON(response)
}

func createAlexaError(correlationToken, endpointId, errType, errMessage string) map[string]interface{} {
	return map[string]interface{}{
		"event": map[string]interface{}{
			"header": map[string]string{
				"namespace":        "Alexa",
				"name":             "ErrorResponse",
				"payloadVersion":   "3",
				"messageId":        uuid.NewString(),
				"correlationToken": correlationToken,
			},
			"endpoint": map[string]string{
				"endpointId": endpointId,
			},
			"payload": map[string]string{
				"type":    errType,
				"message": errMessage,
			},
		},
	}
}
