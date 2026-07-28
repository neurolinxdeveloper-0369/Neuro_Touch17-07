package models

import (
	"time"
)

type OAuthToken struct {
	ID                uint      `gorm:"primaryKey" json:"id"`
	UserID            string    `gorm:"type:uuid;not null;index" json:"user_id"`
	AuthorizationCode string    `gorm:"uniqueIndex" json:"authorization_code"`
	AccessToken       string    `gorm:"uniqueIndex" json:"access_token"`
	RefreshToken      string    `gorm:"uniqueIndex" json:"refresh_token"`
	ExpiresAt         time.Time `json:"expires_at"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`

	User              User      `gorm:"foreignKey:UserID" json:"-"`
}
