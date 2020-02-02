-- Your SQL goes here
CREATE TYPE EntryType AS ENUM ('work', 'training', 'school');

ALTER TABLE entries ADD new_type EntryType NOT NULL DEFAULT 'work';

UPDATE entries set new_type = 'work' WHERE entry_type = 'Betriebliche Tätigkeit';
UPDATE entries set new_type = 'training' WHERE entry_type = 'Schulung';
UPDATE entries set new_type = 'school' WHERE entry_type = 'Berufsschule';

ALTER TABLE entries DROP COLUMN entry_type;
ALTER TABLE entries RENAME COLUMN new_type to entry_type;

