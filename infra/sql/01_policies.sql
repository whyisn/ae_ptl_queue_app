-- 01_policies.sql
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_notes ENABLE ROW LEVEL SECURITY;

-- AE: hanya data miliknya; PTL/ADMIN: semua
CREATE POLICY requests_select ON requests
  FOR SELECT USING (ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'));
CREATE POLICY requests_insert ON requests
  FOR INSERT WITH CHECK (ae_id = auth.uid());
CREATE POLICY requests_update ON requests
  FOR UPDATE USING (ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'));
CREATE POLICY requests_delete ON requests
  FOR DELETE USING (ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'));

CREATE POLICY media_select ON request_media
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM requests r WHERE r.id = request_id
    AND (r.ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'))
  ));
CREATE POLICY media_insert ON request_media
  FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM requests r WHERE r.id = request_id AND r.ae_id = auth.uid()
  ));
CREATE POLICY media_delete ON request_media
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM requests r WHERE r.id = request_id
    AND (r.ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'))
  ));

CREATE POLICY notes_select ON request_notes
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM requests r WHERE r.id = request_id
    AND (r.ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'))
  ));
CREATE POLICY notes_insert ON request_notes
  FOR INSERT WITH CHECK ((auth.jwt() ->> 'role') IN ('PTL','ADMIN')
    OR EXISTS (SELECT 1 FROM requests r WHERE r.id = request_id AND r.ae_id = auth.uid()));
CREATE POLICY notes_delete ON request_notes
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM requests r WHERE r.id = request_id
    AND (r.ae_id = auth.uid() OR (auth.jwt() ->> 'role') IN ('PTL','ADMIN'))
  ));
