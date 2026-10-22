-- Run on a disposable Supabase database after applying migrations. Rolls back.
begin;
insert into auth.users(id, email) values
 ('00000000-0000-4000-8000-000000000001','orbit-test-a@example.invalid'),
 ('00000000-0000-4000-8000-000000000002','orbit-test-b@example.invalid');
insert into public.learning_events(user_id,id,kind,occurred_at,day,data) values
 ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000010','complete',now(),current_date,'{"session":"b","lesson":"a1-01"}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$ begin
  if (select count(*) from public.learning_events) <> 0 then raise exception 'RLS leaked another user'; end if;
end $$;
insert into public.learning_events(user_id,id,kind,occurred_at,day,data) values
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011','complete',now(),current_date,'{"session":"a","lesson":"a1-01"}');
do $$ begin
  if (select count(*) from public.learning_events) <> 1 then raise exception 'Own event not readable'; end if;
  begin
    insert into public.learning_events(user_id,id,kind,occurred_at,day,data) values
    ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000012','complete',now(),current_date,'{"session":"x","lesson":"a1-01"}');
    raise exception 'Cross-user insert allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.learning_events set data='{"session":"forged","lesson":"a1-02"}';
    raise exception 'Immutable events were mutable';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set local role anon;
do $$ begin
  begin
    perform count(*) from public.learning_events;
    raise exception 'Anonymous access allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
delete from auth.users where id='00000000-0000-4000-8000-000000000001';
do $$ begin
  if exists(select 1 from public.learning_events where user_id='00000000-0000-4000-8000-000000000001') then raise exception 'Cascade deletion failed'; end if;
end $$;
rollback;
