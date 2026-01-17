-- Create sessions table
CREATE TABLE public.sessions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  last_accessed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create session_data table to store conversation state
CREATE TABLE public.session_data (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  user_input TEXT,
  property_type TEXT,
  photos JSONB DEFAULT '[]'::jsonb,
  media JSONB DEFAULT '[]'::jsonb,
  generated_description TEXT,
  chat_messages JSONB DEFAULT '[]'::jsonb,
  photo_analyses JSONB DEFAULT '[]'::jsonb,
  property_story TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_data ENABLE ROW LEVEL SECURITY;

-- Create policies for sessions
CREATE POLICY "Users can view their own sessions" 
ON public.sessions 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own sessions" 
ON public.sessions 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own sessions" 
ON public.sessions 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own sessions" 
ON public.sessions 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create policies for session_data
CREATE POLICY "Users can view their own session data" 
ON public.session_data 
FOR SELECT 
USING (EXISTS (
  SELECT 1 FROM public.sessions 
  WHERE sessions.id = session_data.session_id 
  AND sessions.user_id = auth.uid()
));

CREATE POLICY "Users can create their own session data" 
ON public.session_data 
FOR INSERT 
WITH CHECK (EXISTS (
  SELECT 1 FROM public.sessions 
  WHERE sessions.id = session_data.session_id 
  AND sessions.user_id = auth.uid()
));

CREATE POLICY "Users can update their own session data" 
ON public.session_data 
FOR UPDATE 
USING (EXISTS (
  SELECT 1 FROM public.sessions 
  WHERE sessions.id = session_data.session_id 
  AND sessions.user_id = auth.uid()
));

CREATE POLICY "Users can delete their own session data" 
ON public.session_data 
FOR DELETE 
USING (EXISTS (
  SELECT 1 FROM public.sessions 
  WHERE sessions.id = session_data.session_id 
  AND sessions.user_id = auth.uid()
));

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to update last_accessed_at
CREATE OR REPLACE FUNCTION public.update_last_accessed_at()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.sessions 
  SET last_accessed_at = now() 
  WHERE id = NEW.session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_sessions_updated_at
  BEFORE UPDATE ON public.sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_session_data_updated_at
  BEFORE UPDATE ON public.session_data
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Update last_accessed_at when session_data is accessed
CREATE TRIGGER update_session_last_accessed
  AFTER INSERT OR UPDATE ON public.session_data
  FOR EACH ROW
  EXECUTE FUNCTION public.update_last_accessed_at();