import { createClient } from 'npm:@supabase/supabase-js@2';

// The service role exists ONLY in the Edge Function environment.
// No request parameter may select the account to delete.
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 });
  const url = Deno.env.get('SUPABASE_URL')!;
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error } = await caller.auth.getUser(authorization.slice(7));
  if (error || !user) return new Response('Unauthorized', { status: 401 });
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id);
  if (deletionError) return new Response('Deletion failed', { status: 500 });
  return Response.json({ deleted: true });
});
