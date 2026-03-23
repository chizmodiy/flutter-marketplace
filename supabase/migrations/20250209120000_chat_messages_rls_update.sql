ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can mark messages as read" ON public.chat_messages;
CREATE POLICY "Participants can mark messages as read"
ON public.chat_messages
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.chat_participants cp
    WHERE cp.chat_id = chat_messages.chat_id
    AND cp.user_id = auth.uid()
  )
  AND sender_id != auth.uid()
)
WITH CHECK (true);
