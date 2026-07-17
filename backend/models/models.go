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
	ID         string       `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	Name       string       `gorm:"not null"`
	OwnerID    string       `gorm:"type:uuid;not null"`
	Owner      User         `gorm:"foreignKey:OwnerID"`
	InviteCode *string      `gorm:"type:varchar(10);uniqueIndex"`
	Members    []HomeMember `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE"`
	Floors     []Floor      `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE"`
	Rooms      []Room       `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE"`
	Devices    []Device     `gorm:"foreignKey:HomeID;constraint:OnDelete:CASCADE"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type HomeMember struct {
	HomeID          string    `gorm:"primaryKey;type:uuid"`
	UserID          string    `gorm:"primaryKey;type:uuid"`
	User            User      `gorm:"foreignKey:UserID;constraint:OnDelete:CASCADE"`
	PermissionLevel string    `gorm:"type:varchar(20);default:'view_control'"` // full_access | view_control
	JoinedAt        time.Time `gorm:"default:now()"`
}

type Floor struct {
	ID         string `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	HomeID     string `gorm:"type:uuid;not null"`
	Name       string `gorm:"not null"`
	OrderIndex int    `gorm:"default:0"`
	Rooms      []Room `gorm:"foreignKey:FloorID;constraint:OnDelete:CASCADE"`
}

type Room struct {
	ID         string   `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	FloorID    string   `gorm:"type:uuid;not null"`
	HomeID     string   `gorm:"type:uuid;not null"`
	Name       string   `gorm:"not null"`
	Icon       string   `gorm:"type:varchar(50);default:'room'"`
	OrderIndex int      `gorm:"default:0"`
	Devices    []Device `gorm:"foreignKey:RoomID;constraint:OnDelete:SET NULL"`
}

type Device struct {
	ID              string         `gorm:"primaryKey;type:varchar(50)"` // MAC or specific ID
	HomeID          string         `gorm:"type:uuid;not null"`
	RoomID          *string        `gorm:"type:uuid"`
	DeviceType      string         `gorm:"type:varchar(30);not null"` // touch_panel | ir_blaster | lift_panel | energy_meter | temp_monitor
	Name            string         `gorm:"not null"`
	SSIDPattern     *string        `gorm:"type:varchar(100)"`
	FirmwareVersion *string        `gorm:"type:varchar(20)"`
	IsOnline        bool           `gorm:"default:false"`
	LastSeen        *time.Time
	SwitchCount     int            `gorm:"default:1"`
	Config          string         `gorm:"type:text;default:'{}'"` // JSON representation of config
	Switches        []SwitchConfig `gorm:"foreignKey:DeviceID;constraint:OnDelete:CASCADE"`
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

type SwitchConfig struct {
	ID           string  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	DeviceID     string  `gorm:"type:varchar(50);not null"`
	SwitchIndex  int     `gorm:"not null"`
	Name         string  `gorm:"not null"`
	Icon         string  `gorm:"type:varchar(50);default:'lightbulb'"`
	ShortcutType *string `gorm:"type:varchar(50)"`
}

type Automation struct {
	ID         string `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	HomeID     string `gorm:"type:uuid;not null"`
	Name       string `gorm:"not null"`
	IsActive   bool   `gorm:"default:true"`
	Conditions string `gorm:"type:text;default:'[]'"` // JSON string
	Actions    string `gorm:"type:text;default:'[]'"` // JSON string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type Schedule struct {
	ID          string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	DeviceID    string    `gorm:"type:varchar(50);not null;index"`
	SwitchIndex int       `gorm:"not null"`
	CronExpr    string    `gorm:"type:varchar(100);not null"`
	Action      string    `gorm:"type:varchar(10);not null"` // on | off
	IsActive    bool      `gorm:"default:true"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Telemetry struct {
	ID         uint64    `gorm:"primaryKey;autoIncrement"`
	DeviceID   string    `gorm:"type:varchar(50);not null;index"`
	Metric     string    `gorm:"type:varchar(50);not null"` // voltage, current, power, energy, temperature, humidity...
	Value      float64   `gorm:"not null"`
	RecordedAt time.Time `gorm:"index;default:now()"`
}

type Notification struct {
	ID        string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID    string    `gorm:"type:uuid;not null;index"`
	Title     string    `gorm:"not null"`
	Body      string    `gorm:"not null"`
	IsRead    bool      `gorm:"default:false"`
	DeviceID  *string   `gorm:"type:varchar(50)"`
	CreatedAt time.Time `gorm:"default:now()"`
}
