package controllers

import (
	"time"

	"neurotouch/config"
	"neurotouch/models"

	"github.com/gofiber/fiber/v2"
)

// GetTelemetryLatest
func GetTelemetryLatest(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")

	_, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	// Fetch latest telemetry for each unique metric of this device
	var metrics []string
	config.AppConfig.DB.Model(&models.Telemetry{}).
		Where("device_id = ?", deviceID).
		Distinct("metric").
		Pluck("metric", &metrics)

	latestMap := make(map[string]models.Telemetry)
	for _, m := range metrics {
		var point models.Telemetry
		err := config.AppConfig.DB.
			Where("device_id = ? AND metric = ?", deviceID, m).
			Order("recorded_at desc").
			First(&point).Error
		if err == nil {
			latestMap[m] = point
		}
	}

	return c.JSON(fiber.Map{
		"success":   true,
		"telemetry": latestMap,
	})
}

// GetTelemetryHistory
func GetTelemetryHistory(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	deviceID := c.Params("id")
	metric := c.Query("metric")
	resolution := c.Query("resolution", "raw") // raw | hourly | daily

	if metric == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"error":   "Metric parameter is required",
		})
	}

	_, err := checkDeviceAccess(config.AppConfig.DB, deviceID, userID, false)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"error":   "Access denied",
		})
	}

	// Parse timestamps
	fromTime := time.Now().Add(-24 * time.Hour) // Default last 24h
	toTime := time.Now()

	if fromStr := c.Query("from"); fromStr != "" {
		if t, err := time.Parse(time.RFC3339, fromStr); err == nil {
			fromTime = t
		}
	}
	if toStr := c.Query("to"); toStr != "" {
		if t, err := time.Parse(time.RFC3339, toStr); err == nil {
			toTime = t
		}
	}

	type HistoryPoint struct {
		Timestamp time.Time `json:"timestamp"`
		Value     float64   `json:"value"`
		AvgValue  *float64  `json:"avg_value,omitempty"`
		MinValue  *float64  `json:"min_value,omitempty"`
		MaxValue  *float64  `json:"max_value,omitempty"`
	}

	var dataPoints []HistoryPoint

	if resolution == "hourly" {
		// Group by hour
		query := `SELECT date_trunc('hour', recorded_at) as timestamp, 
		                 avg(value) as value, 
		                 avg(value) as avg_value, 
		                 min(value) as min_value, 
		                 max(value) as max_value 
		          FROM telemetry 
		          WHERE device_id = ? AND metric = ? AND recorded_at BETWEEN ? AND ? 
		          GROUP BY timestamp 
		          ORDER BY timestamp ASC`
		rows, err := config.AppConfig.DB.Raw(query, deviceID, metric, fromTime, toTime).Rows()
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var p HistoryPoint
				var avg, min, max float64
				if err := rows.Scan(&p.Timestamp, &p.Value, &avg, &min, &max); err == nil {
					p.AvgValue = &avg
					p.MinValue = &min
					p.MaxValue = &max
					dataPoints = append(dataPoints, p)
				}
			}
		}
	} else if resolution == "daily" {
		// Group by day
		query := `SELECT date_trunc('day', recorded_at) as timestamp, 
		                 avg(value) as value, 
		                 avg(value) as avg_value, 
		                 min(value) as min_value, 
		                 max(value) as max_value 
		          FROM telemetry 
		          WHERE device_id = ? AND metric = ? AND recorded_at BETWEEN ? AND ? 
		          GROUP BY timestamp 
		          ORDER BY timestamp ASC`
		rows, err := config.AppConfig.DB.Raw(query, deviceID, metric, fromTime, toTime).Rows()
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var p HistoryPoint
				var avg, min, max float64
				if err := rows.Scan(&p.Timestamp, &p.Value, &avg, &min, &max); err == nil {
					p.AvgValue = &avg
					p.MinValue = &min
					p.MaxValue = &max
					dataPoints = append(dataPoints, p)
				}
			}
		}
	} else {
		// Raw points
		var rawPoints []models.Telemetry
		err := config.AppConfig.DB.
			Where("device_id = ? AND metric = ? AND recorded_at BETWEEN ? AND ?", deviceID, metric, fromTime, toTime).
			Order("recorded_at asc").
			Limit(1000). // Cap at 1000 raw points for performance
			Find(&rawPoints).Error
		if err == nil {
			for _, rp := range rawPoints {
				dataPoints = append(dataPoints, HistoryPoint{
					Timestamp: rp.RecordedAt,
					Value:     rp.Value,
				})
			}
		}
	}

	return c.JSON(fiber.Map{
		"success": true,
		"history": fiber.Map{
			"device_id":   deviceID,
			"metric":      metric,
			"data_points": dataPoints,
		},
	})
}
