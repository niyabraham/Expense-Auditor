-- Update the get_dashboard_analytics function to handle NULL expense_date values
-- This fixes the "null value not allowed for object key" (code 22004) error

CREATE OR REPLACE FUNCTION get_dashboard_analytics()
RETURNS json
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT json_build_object(
    'total_approved_spend', COALESCE((SELECT SUM(amount) FROM claims WHERE status = 'approved'), 0),
    'approved_count', (SELECT COUNT(*) FROM claims WHERE status = 'approved'),
    'flagged_count', (SELECT COUNT(*) FROM claims WHERE status = 'flagged'),
    'rejected_count', (SELECT COUNT(*) FROM claims WHERE status = 'rejected'),
    'monthly_spend', COALESCE((
      SELECT json_object_agg(sub.m::text, sub.month_total)
      FROM (
        SELECT EXTRACT(MONTH FROM expense_date::date) as m, SUM(amount) as month_total
        FROM claims
        WHERE expense_date IS NOT NULL  -- FIX: Filter out rows with NULL dates
        GROUP BY 1
      ) sub
    ), '{}'::json)
  );
$$;
