# update_subscriptions_by_day.sql

## Overview
This script updates the `subscriptions_by_day` table with aggregated daily subscription data, ensuring unique entries and updating existing ones to maintain data integrity.

## Features
- Adds a unique constraint to prevent duplicate entries.
- Aggregates subscription data by status, metro area, and UTM parameters.
- Handles conflicts by updating existing records.
