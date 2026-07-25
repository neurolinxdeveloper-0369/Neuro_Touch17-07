package main

import (
	"fmt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Device struct {
	ID             string  `gorm:"primaryKey;type:varchar(50)" json:"id"`
	HomeID         string  `gorm:"type:uuid;not null;index" json:"home_id"`
	DeviceType     string  `gorm:"type:varchar(50);not null" json:"device_type"`
	Name           string  `gorm:"type:varchar(100);not null" json:"name"`
	MACAddress     *string `gorm:"type:varchar(17);uniqueIndex;column:mac_address" json:"mac_address"`
}

func main() {
	dsn := "host=129.121.120.144 user=postgres password=Neuro@123456 dbname=neurotouch_iot port=5432 sslmode=disable TimeZone=UTC"
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		fmt.Println("Error connecting:", err)
		return
	}

	var devices []Device
	db.Find(&devices)
	fmt.Printf("Found %d devices\n", len(devices))
	for _, d := range devices {
        mac := "none"
        if d.MACAddress != nil {
            mac = *d.MACAddress
        }
		fmt.Printf("Device: %s (Type: %s, HomeID: %s, MAC: %s)\n", d.Name, d.DeviceType, d.HomeID, mac)
	}
}
