# Open the database
sqlite3 /home/ianm/Development/ShadowWhisper/features.db

# Check if features 91-175 are duplicates of 1-90
SELECT id, name FROM features WHERE id > 90 LIMIT 10;

# If they're duplicates, delete them:
DELETE FROM features WHERE id > 90;

# Verify the count
SELECT COUNT(*) FROM features;

# Exit
.quit

