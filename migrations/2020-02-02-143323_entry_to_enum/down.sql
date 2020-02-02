-- This file should undo anything in `up.sql`
ALTER TABLE entries ADD new_type text NOT NULL DEFAULT '';

UPDATE entries set new_type = 'Betriebliche Tätigkeit' WHERE entry_type = 'work';
UPDATE entries set new_type = 'Schulung' WHERE entry_type = 'training';
UPDATE entries set new_type = 'Berufsschule' WHERE entry_type = 'school';

ALTER TABLE entries DROP COLUMN entry_type;
ALTER TABLE entries RENAME COLUMN new_type to entry_type;
DROP TYPE EntryType;
