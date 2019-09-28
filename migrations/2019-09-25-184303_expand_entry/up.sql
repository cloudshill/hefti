ALTER TABLE entry
  ADD COLUMN logdate DATE NOT NULL DEFAULT 'epoch',
  ADD COLUMN entry_type text NOT NULL DEFAULT 'epoch';
-- Your SQL goes here
