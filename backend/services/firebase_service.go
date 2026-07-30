package services

import (
	"context"
	"fmt"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

var fcmClient *messaging.Client

// InitFirebase initializes the Firebase Admin SDK using a service account JSON file.
func InitFirebase() error {
	ctx := context.Background()
	// Change this path if your serviceAccountKey.json is located elsewhere.
	opt := option.WithCredentialsFile("serviceAccountKey.json")
	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		return fmt.Errorf("error initializing firebase app: %v", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return fmt.Errorf("error getting Messaging client: %v", err)
	}

	fcmClient = client
	log.Println("Firebase Admin SDK initialized successfully")
	return nil
}

// SendCriticalAlarm triggers the FCM data message to wake up the app and ring.
func SendCriticalAlarm(token string, deviceID string, roomName string, currentTemp float64) error {
	if fcmClient == nil {
		return fmt.Errorf("firebase messaging client not initialized")
	}

	msg := &messaging.Message{
		Token: token,
		Data: map[string]string{
			"is_alarm":    "true",
			"device_id":   deviceID,
			"room_name":   roomName,
			"temperature": fmt.Sprintf("%.2f", currentTemp),
		},
		Android: &messaging.AndroidConfig{
			Priority: "high", // Required to wake up device
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					ContentAvailable: true,
				},
			},
			Headers: map[string]string{
				"apns-priority": "10", // High priority
			},
		},
	}

	response, err := fcmClient.Send(context.Background(), msg)
	if err != nil {
		return err
	}
	log.Printf("Successfully sent critical alarm message: %s\n", response)
	return nil
}
