package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"neurotouch/config"
	"neurotouch/controllers"
	"neurotouch/models"
)

type OllamaMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type OllamaRequest struct {
	Model    string          `json:"model"`
	Messages []OllamaMessage `json:"messages"`
	Stream   bool            `json:"stream"`
}

type OllamaResponse struct {
	Message struct {
		Content string `json:"content"`
	} `json:"message"`
}

func InitAIChat() {
	// Link the controller stub to our local Ollama function
	controllers.GetAIChatResponse = func(homeID string, message string, history []map[string]interface{}) (string, error) {
		return getOllamaChatResponse(homeID, message, history)
	}
}

func getOllamaChatResponse(homeID string, message string, history []map[string]interface{}) (string, error) {
	db := config.AppConfig.DB

	// --- 1. Fetch Database Context ---
	var home models.Home
	if err := db.Preload("Floors.Rooms.Devices.Switches").First(&home, "id = ?", homeID).Error; err != nil {
		return "", fmt.Errorf("home not found in database: %v", err)
	}

	// Structure a clean JSON description of the smart home setup
	type DeviceCtx struct {
		ID         string   `json:"id"`
		Name       string   `json:"name"`
		Type       string   `json:"type"`
		IsOnline   bool     `json:"is_online"`
		Switches   []string `json:"switches,omitempty"`
	}

	type RoomCtx struct {
		Name    string      `json:"name"`
		Devices []DeviceCtx `json:"devices"`
	}

	type FloorCtx struct {
		Name  string    `json:"name"`
		Rooms []RoomCtx `json:"rooms"`
	}

	var homeLayout []FloorCtx

	for _, f := range home.Floors {
		floorCtx := FloorCtx{Name: f.Name}
		for _, r := range f.Rooms {
			roomCtx := RoomCtx{Name: r.Name}
			for _, d := range r.Devices {
				devCtx := DeviceCtx{
					ID:       d.ID,
					Name:     d.Name,
					Type:     d.DeviceType,
					IsOnline: d.IsOnline,
				}
				for _, sw := range d.Switches {
					devCtx.Switches = append(devCtx.Switches, fmt.Sprintf("Switch %d: %s", sw.SwitchIndex, sw.Name))
				}
				roomCtx.Devices = append(roomCtx.Devices, devCtx)
			}
			floorCtx.Rooms = append(floorCtx.Rooms, roomCtx)
		}
		homeLayout = append(homeLayout, floorCtx)
	}

	layoutJSON, _ := json.MarshalIndent(homeLayout, "", "  ")

	// --- 2. Build Ollama System Prompt ---
	systemPrompt := fmt.Sprintf(`You are "Neuro Touch AI Assistant", a smart home concierge. You help control the user's automated home.
Here is the live configuration of the user's home layout and device states:

%s

Guidelines:
1. Always be polite, concise, and helpful.
2. If asked to turn a switch on/off, refer to the device ID, name, and switch index. Say: "I'll do that right away" and indicate the details.
3. Be aware of offline devices. If a device is offline, mention that it seems offline.
4. Keep replies formatting clean using markdown.`, string(layoutJSON))

	// --- 3. Build Message List ---
	var messages []OllamaMessage

	// Add system context
	messages = append(messages, OllamaMessage{
		Role:    "system",
		Content: systemPrompt,
	})

	// Add chat history
	for _, h := range history {
		role, _ := h["role"].(string)
		content, _ := h["content"].(string)
		if role != "" && content != "" {
			messages = append(messages, OllamaMessage{
				Role:    role,
				Content: content,
			})
		}
	}

	// Add new message
	messages = append(messages, OllamaMessage{
		Role:    "user",
		Content: message,
	})

	// --- 4. Call Ollama HTTP API ---
	reqBody := OllamaRequest{
		Model:    config.AppConfig.OllamaModel,
		Messages: messages,
		Stream:   false,
	}

	jsonBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to encode request: %v", err)
	}

	apiURL := fmt.Sprintf("%s/api/chat", config.AppConfig.OllamaURL)
	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(jsonBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create http request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("ollama server unreachable: %v", err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed reading response: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ollama returned error status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var ollamaResp OllamaResponse
	if err := json.Unmarshal(bodyBytes, &ollamaResp); err != nil {
		return "", fmt.Errorf("failed parsing response json: %v", err)
	}

	reply := ollamaResp.Message.Content
	if reply == "" {
		reply = "I'm sorry, I couldn't generate a response."
	}

	return reply, nil
}
