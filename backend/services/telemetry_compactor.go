package services

import (
	"log"
	"time"

	"neurotouch/config"
	"neurotouch/models"
)

func StartTelemetryCompactor() {
	// Execute compaction immediately on boot
	compactOldTelemetry()

	// Ticker running compaction every 6 hours
	ticker := time.NewTicker(6 * time.Hour)
	go func() {
		for range ticker.C {
			compactOldTelemetry()
		}
	}()
}

func compactOldTelemetry() {
	log.Println("Starting background telemetry compaction job...")
	db := config.AppConfig.DB

	// 1. Hourly Compaction: rows older than 24h
	twentyFourHoursAgo := time.Now().Add(-24 * time.Hour)

	type TempAgg struct {
		DeviceID   string
		Metric     string
		HourStamp  time.Time
		AvgValue   float64
		MinValue   float64
		MaxValue   float64
	}

	var hourlyAggs []TempAgg
	queryHourly := `SELECT device_id, metric, date_trunc('hour', recorded_at) as hour_stamp,
	                       avg(value) as avg_value, min(value) as min_value, max(value) as max_value
	                FROM telemetry
	                WHERE recorded_at < ?
	                GROUP BY device_id, metric, hour_stamp`

	err := db.Raw(queryHourly, twentyFourHoursAgo).Scan(&hourlyAggs).Error
	if err != nil {
		log.Printf("Telemetry compaction: error aggregating hourly stats: %v", err)
		return
	}

	if len(hourlyAggs) > 0 {
		tx := db.Begin()
		// Delete compacted raw points
		if err := tx.Where("recorded_at < ?", twentyFourHoursAgo).Delete(&models.Telemetry{}).Error; err != nil {
			tx.Rollback()
			log.Printf("Telemetry compaction: failed to clean old raw points: %v", err)
			return
		}

		// Re-insert compacted stats as telemetry points matching the timestamp
		// To distinguish compacted points, we can store their averages or insert them back.
		// Since our history query aggregates on-the-fly, inserting the average value back is standard.
		for _, agg := range hourlyAggs {
			points := models.Telemetry{
				DeviceID:   agg.DeviceID,
				Metric:     agg.Metric,
				Value:      agg.AvgValue,
				RecordedAt: agg.HourStamp,
			}
			if err := tx.Create(&points).Error; err != nil {
				tx.Rollback()
				log.Printf("Telemetry compaction: error creating aggregated point: %v", err)
				return
			}
		}

		if err := tx.Commit().Error; err != nil {
			log.Printf("Telemetry compaction: transaction commit failed: %v", err)
			return
		}
		log.Printf("Telemetry compaction: compacted %d hourly metrics successfully", len(hourlyAggs))
	}
}
