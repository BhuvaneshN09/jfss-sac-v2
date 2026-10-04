-- Cap the event-photo bucket (created without file_size_limit) and any other
-- uncapped buckets so a client bypass cannot fill the project.

update storage.buckets
set
  file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'club-event-photos';

update storage.buckets
set file_size_limit = 10485760
where coalesce(file_size_limit, 0) = 0;
