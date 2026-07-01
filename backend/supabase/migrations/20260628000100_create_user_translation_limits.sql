-- Migration to track AI translation limits for premium users

CREATE TABLE public.user_translation_limits (
  user_id uuid REFERENCES auth.users(id) PRIMARY KEY,
  last_request_time timestamp with time zone DEFAULT now(),
  requests_this_minute integer DEFAULT 1,
  requests_today integer DEFAULT 1,
  last_reset_date date DEFAULT current_date
);

ALTER TABLE public.user_translation_limits ENABLE ROW LEVEL SECURITY;

-- Allow read/write only for the service role (used by Edge Functions)
CREATE POLICY "Service role can manage translation limits" 
ON public.user_translation_limits 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);
