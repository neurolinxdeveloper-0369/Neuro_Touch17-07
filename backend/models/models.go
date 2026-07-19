package models

import (
	"time"
)

type User struct {
	ID           string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	Name         string    `gorm:"type:varchar(100);not null" json:"name"`
	Email        *string   `gorm:"type:varchar(255)" json:"email"`
	Phone        *string   `gorm:"type:varchar(20)" json:"phone"`
	ProfilePic   *string   `gorm:"type:text;column:profile_pic" json:"profile_pic"`
	AuthProvider string    `gorm:"type:varchar(20);not null;column:auth_provider" json:"auth_provider"`
	CreatedAt    time.Time `gorm:"type:timestamptz;not null;default:CURRENT_TIMESTAMP" json:"created_at"`
	Homes        []Home    `gorm:"many2many:home_members;joinForeignKey:UserID;joinReferences:HomeID" json:"-"`
}

type OTPVerification struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Phone     string    `gorm:"uniqueIndex;type:varchar(20);not null" json:"phone"`
	OTP       string    `gorm:"type:varchar(6);not null" json:"otp"`
	ExpiresAt time.Time `gorm:"not null" json:"expires_at"`
}

type Home struct {
	ID              string       `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	Name            string       `gorm:"not null" json:"name"`
	OwnerID         string       `gorm:"type:uuid;not null" json:"owner_id"`
	Owner           User         `gorm:"foreignKey:OwnerID" json:"-"`
	HomeType        string       `gorm:"type:varchar(20);not null;default:'flat'" json:"home_type"` // flat | villa | building | office
	FloorCount      int          `gorm:"default:0" json:"floor_count"`
	NetworkSSID     *string      `gorm:"type:varchar(100)" json:"network_ssid"`
	NetworkPassword *string      `gorm:"type:varchar(255)" json:"network_password"`
	InviteCode      *string      `gorm:"type:varchar(10);uniqueIndex" json:"invite_code"`
	Members         []HomeMember `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE" json:"members"`
	Devices         []Device     `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE" json:"-"`
	Floors          []Floor      `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE" json:"-"`
	CreatedAt       time.Time    `json:"created_at"`
	UpdatedAt       time.Time    `json:"updated_at"`
}

type HomeMember struct {
	HomeID          string    `gorm:"primaryKey;type:uuid" json:"home_id"`
	UserID          string    `gorm:"primaryKey;type:uuid" json:"user_id"`
	User            User      `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE" json:"user"`
	PermissionLevel string    `gorm:"type:varchar(20);default:'view_control'" json:"permission_level"` // full_access | view_control
	JoinedAt        time.Time `gorm:"default:now()" json:"joined_at"`
}

// Floor represents a physical floor within a multi-floor home/building.
type Floor struct {
	ID         string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	HomeID     string    `gorm:"type:uuid;not null;index" json:"home_id"`
	Name       string    `gorm:"type:varchar(100);not null" json:"name"`
	OrderIndex int       `gorm:"default:0" json:"order_index"`
	Rooms      []Room    `gorm:"foreignKey:FloorID;constraint:OnDelete:CASCADE" json:"rooms"`
	CreatedAt  time.Time `json:"created_at"`
}

// Room represents a room within a floor.
type Room struct {
	ID         string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	FloorID    string    `gorm:"type:uuid;not null;index" json:"floor_id"`
	HomeID     string    `gorm:"type:uuid;not null;index" json:"home_id"`
	Name       string    `gorm:"type:varchar(100);not null" json:"name"`
	Icon       string    `gorm:"type:varchar(50);default:'room'" json:"icon"`
	OrderIndex int       `gorm:"default:0" json:"order_index"`
	CreatedAt  time.Time `json:"created_at"`
}

type Device struct {
	ID             string         `gorm:"primaryKey;type:varchar(50)" json:"id"` // MAC address (AA:BB:CC:DD:EE:FF) or temp UUID
	HomeID         string         `gorm:"type:uuid;not null" json:"home_id"`
	DeviceType     string         `gorm:"type:varchar(30);not null" json:"device_type"` // touch_panel | ir_blaster | lift_panel | energy_meter | temp_monitor
	Name           string         `gorm:"not null" json:"name"`
	MACAddress     *string        `gorm:"type:varchar(17);uniqueIndex;column:mac_address" json:"mac_address"` // e.g. AA:BB:CC:DD:EE:FF
	SSIDPattern    *string        `gorm:"type:varchar(100)" json:"ssid_pattern"`
	FirmwareVersion *string       `gorm:"type:varchar(20)" json:"firmware_version"`
	IsOnline       bool           `gorm:"default:false" json:"is_online"`
	LastSeen       *time.Time     `json:"last_seen"`
	SwitchCount    int            `gorm:"default:1" json:"switch_count"`
	Config         string         `gorm:"type:text;default:'{}'" json:"config"` // JSON blob
	// Assignment
	AssignmentType string         `gorm:"type:varchar(20);default:'room'" json:"assignment_type"` // floor | room | site | outdoor
	FloorID        *string        `gorm:"type:uuid;index" json:"floor_id"`
	RoomID         *string        `gorm:"type:uuid;index" json:"room_id"`
	Switches       []SwitchConfig `gorm:"foreignKey:DeviceID;constraint:OnDelete:CASCADE" json:"switches"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
}

type SwitchConfig struct {
	ID           string  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	DeviceID     string  `gorm:"type:varchar(50);not null" json:"device_id"`
	SwitchIndex  int     `gorm:"not null" json:"switch_index"`
	Name         string  `gorm:"not null" json:"name"`
	Icon         string  `gorm:"type:varchar(50);default:'lightbulb'" json:"icon"`
	ShortcutType *string `gorm:"type:varchar(50)" json:"shortcut_type"`
}

type Automation struct {
	ID         string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	HomeID     string    `gorm:"type:uuid;not null" json:"home_id"`
	Name       string    `gorm:"not null" json:"name"`
	IsActive   bool      `gorm:"default:true" json:"is_active"`
	Conditions string    `gorm:"type:text;default:'[]'" json:"conditions"` // JSON string
	Actions    string    `gorm:"type:text;default:'[]'" json:"actions"`    // JSON string
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type Schedule struct {
	ID          string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	DeviceID    string    `gorm:"type:varchar(50);not null;index" json:"device_id"`
	SwitchIndex int       `gorm:"not null" json:"switch_index"`
	CronExpr    string    `gorm:"type:varchar(100);not null" json:"cron_expr"`
	Action      string    `gorm:"type:varchar(10);not null" json:"action"` // on | off
	IsActive    bool      `gorm:"default:true" json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type Telemetry struct {
	ID         uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID   string    `gorm:"type:varchar(50);not null;index" json:"device_id"`
	Metric     string    `gorm:"type:varchar(50);not null" json:"metric"` // voltage, current, power, energy, temperature, humidity...
	Value      float64   `gorm:"not null" json:"value"`
	RecordedAt time.Time `gorm:"index;default:now()" json:"recorded_at"`
}

type Notification struct {
	ID        string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	UserID    string    `gorm:"type:uuid;not null;index" json:"user_id"`
	Title     string    `gorm:"not null" json:"title"`
	Body      string    `gorm:"not null" json:"body"`
	IsRead    bool      `gorm:"default:false" json:"is_read"`
	DeviceID  *string   `gorm:"type:varchar(50)" json:"device_id"`
	CreatedAt time.Time `gorm:"default:now()" json:"created_at"`
}
