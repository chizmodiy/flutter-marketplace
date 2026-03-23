// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Hello from Functions!")

Deno.serve(async (req) => {
  console.log('Edge Function: verify-pin invoked.'); // Added log
  if (req.method !== 'POST') {
    console.log('Edge Function: Method Not Allowed'); // Added log
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 405,
    });
  }

  const { pin, userId } = await req.json();
  console.log(`Edge Function: Received pin: [${pin ? 'present' : 'missing'}] for userId: ${userId}`); // Added log

  if (!pin || !userId) {
    console.log('Edge Function: Missing PIN or User ID'); // Added log
    return new Response(JSON.stringify({ error: 'Missing PIN or User ID' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    });
  }

  console.log('Edge Function: Creating Supabase Admin client.'); // Added log
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    console.log(`Edge Function: Attempting to get user by ID: ${userId}`); // Added log
    const { data: user, error: userError } = await supabaseAdmin.auth.admin.getUserById(userId);
    console.log(`Edge Function: User lookup result - user: ${user ? 'found' : 'not found'}, error: ${userError?.message}`); // Added log

    if (userError || !user || (!user.user.phone && !user.user.email)) {
      console.error('User lookup error or missing identifier:', userError || 'No identifier');
      return new Response(JSON.stringify({ verified: false, message: 'User not found or missing identifier.' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 404,
      });
    }

    let identifier: string | undefined;
    if (user.user.phone) {
      identifier = user.user.phone;
    } else if (user.user.email) {
      identifier = user.user.email;
    }
    console.log(`Edge Function: Determined identifier: ${identifier}`); // Added log

    if (!identifier) {
      console.log('Edge Function: User has no phone or email set.'); // Added log
      return new Response(JSON.stringify({ verified: false, message: 'User has no phone or email set.' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    console.log(`Edge Function: Attempting signInWithPassword for identifier: ${identifier}`); // Added log
    const { data: signInData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
      [identifier.includes('@') ? 'email' : 'phone']: identifier,
      password: pin,
    });
    console.log(`Edge Function: signInWithPassword result - session: ${signInData?.session ? 'present' : 'missing'}, error: ${signInError?.message}`); // Added log

    if (signInError) {
      console.error('Sign-in failed for PIN verification:', signInError.message);
      if (signInError.message.includes('Invalid login credentials')) {
        console.log('Edge Function: Invalid login credentials detected.'); // Added log
        return new Response(JSON.stringify({ verified: false, message: 'Invalid PIN.' }), {
          headers: { 'Content-Type': 'application/json' },
          status: 401, // Unauthorized
        });
      }
      return new Response(JSON.stringify({ verified: false, message: signInError.message }), {
        headers: { 'Content-Type': 'application/json' },
        status: 401,
      });
    }

    // If sign-in was successful, immediately sign out the admin client to prevent session takeover
    if (signInData.session) {
      console.log('Edge Function: PIN verified successfully. Signing out admin client.'); // Added log
      await supabaseAdmin.auth.signOut();
    }
    
    console.log('Edge Function: Returning successful verification response.'); // Added log
    return new Response(JSON.stringify({ verified: true, message: 'PIN verified successfully.' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error('Unexpected error in Edge Function:', error.message);
    return new Response(JSON.stringify({ verified: false, message: 'Internal server error.' }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/verify-pin' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
