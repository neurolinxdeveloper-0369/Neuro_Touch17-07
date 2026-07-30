package services

import (
	"log"
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/robfig/cron/v3"
	"gorm.io/gorm/clause"
)

// InitEnergyAggregator starts the background cron jobs for energy processing.
func InitEnergyAggregator() {
	c := cron.New()

	// Run every day at 23:59:00 to calculate daily energy usage
	c.AddFunc("59 23 * * *", calculateDailyEnergy)

	// Run every day at 02:00:00 to cleanup records older than 90 days (3 months)
	c.AddFunc("0 2 * * *", cleanupOldEnergyRecords)

	c.Start()
	log.Println("Energy Aggregator cron jobs started")
}

func calculateDailyEnergy() {
	log.Println("[CRON] Starting calculateDailyEnergy job...")
	db := config.AppConfig.DB
	now := time.Now()
	todayStr := now.Format("2006-01-02")
	dateToday, _ := time.Parse("2006-01-02", todayStr)

	// Find all energy meters
	var meters []models.Device
	db.Where("device_type IN ?", []string{"energy_meter", "three_phase_meter"}).Find(&meters)

	for _, meter := range meters {
		// Get latest energy telemetry for today to use as EndEnergy
		var latestEnergy models.EnergyReading
		err := db.Where("device_id = ? AND recorded_at >= ?", meter.ID, dateToday).
			Order("recorded_at desc").First(&latestEnergy).Error
		
		if err != nil {
			continue // No energy telemetry recorded today for this device
		}
		
		endEnergy := latestEnergy.TotalEnergy

		// Find yesterday's record to get StartEnergy
		var yesterdayRecord models.DailyEnergyRecord
		yesterday := dateToday.AddDate(0, 0, -1)
		err = db.Where("device_id = ? AND date = ?", meter.ID, yesterday).First(&yesterdayRecord).Error
		
		startEnergy := 0.0
		if err == nil {
			startEnergy = yesterdayRecord.EndEnergy
		} else {
			// If no yesterday record, get the first telemetry of today
			var firstEnergy models.EnergyReading
			db.Where("device_id = ? AND recorded_at >= ?", meter.ID, dateToday).
				Order("recorded_at asc").First(&firstEnergy)
			startEnergy = firstEnergy.TotalEnergy
		}

		unitsConsumed := endEnergy - startEnergy
		if unitsConsumed < 0 {
			unitsConsumed = 0 // In case device reset internally
		}

		// Calculate average power factor for today
		// We average Pf1, Pf2, Pf3 if it's 3-phase, or just Pf1 if 1-phase.
		var avgPf float64
		var readings []models.EnergyReading
		db.Where("device_id = ? AND recorded_at >= ?", meter.ID, dateToday).Find(&readings)
		if len(readings) > 0 {
			var sumPf float64
			for _, r := range readings {
				if r.Pf2 > 0 || r.Pf3 > 0 {
					sumPf += (r.Pf1 + r.Pf2 + r.Pf3) / 3
				} else {
					sumPf += r.Pf1
				}
			}
			avgPf = sumPf / float64(len(readings))
		}

		// Upsert daily record — update if same device+date already exists
		record := models.DailyEnergyRecord{
			DeviceID:       meter.ID,
			Date:           dateToday,
			StartEnergy:    startEnergy,
			EndEnergy:      endEnergy,
			UnitsConsumed:  unitsConsumed,
			AvgPowerFactor: avgPf,
		}

		db.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "device_id"}, {Name: "date"}},
			DoUpdates: clause.AssignmentColumns([]string{"end_energy", "units_consumed", "avg_power_factor"}),
		}).Create(&record)
	}
	log.Println("[CRON] calculateDailyEnergy job completed.")
}

func cleanupOldEnergyRecords() {
	log.Println("[CRON] Starting cleanupOldEnergyRecords job...")
	db := config.AppConfig.DB
	ninetyDaysAgo := time.Now().AddDate(0, 0, -90)
	
	result := db.Where("date < ?", ninetyDaysAgo).Delete(&models.DailyEnergyRecord{})
	log.Printf("[CRON] Deleted %d energy records older than 90 days.", result.RowsAffected)
}
