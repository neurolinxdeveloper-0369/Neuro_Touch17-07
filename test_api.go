package main
import (
    "fmt"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "encoding/json"
)

type Device struct {
	ID             string  `gorm:"primaryKey;type:varchar(50)" json:"id"`
	HomeID         string  `gorm:"type:uuid;not null;index" json:"home_id"`
	DeviceType     string  `gorm:"type:varchar(50);not null" json:"device_type"`
	Name           string  `gorm:"type:varchar(100);not null" json:"name"`
	MACAddress     *string `gorm:"type:varchar(17);uniqueIndex;column:mac_address" json:"mac_address"`
    Switches       []SwitchConfig `gorm:"foreignKey:DeviceID" json:"switches"`
}

type SwitchConfig struct {
	ID           string  `gorm:"primaryKey;type:uuid" json:"id"`
	DeviceID     string  `gorm:"type:varchar(50);not null" json:"device_id"`
	SwitchIndex  int     `gorm:"not null" json:"switch_index"`
	Name         string  `gorm:"not null" json:"name"`
	Icon         string  `gorm:"type:varchar(50)" json:"icon"`
}

func main() {
    dsn := "host=129.121.120.144 user=postgres password=Neuro@123456 dbname=neurotouch_iot port=5432 sslmode=disable TimeZone=UTC"
	db, _ := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    var devices []Device
    db.Preload("Switches").Find(&devices, "home_id = ?", "fee9736d-e5d9-4193-a90b-11e508c0651e")
    b, _ := json.MarshalIndent(devices, "", "  ")
    fmt.Println(string(b))
}
