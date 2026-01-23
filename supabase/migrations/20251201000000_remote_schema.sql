


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."apply_templates"("p_listing_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_listing_type_id uuid;
    v_owned_by uuid;
BEGIN
    -- Get the listing's type and owner
    SELECT listing_type_id, owned_by
    INTO v_listing_type_id, v_owned_by
    FROM public.listings
    WHERE id = p_listing_id;

    IF v_listing_type_id IS NULL THEN
        RAISE EXCEPTION 'Listing not found or has no type';
    END IF;

    -- Generate activities using the same core function
    PERFORM public.fn_generate_activities_for_listing(
        p_listing_id,
        v_listing_type_id,
        v_owned_by
    );
END;
$$;


ALTER FUNCTION "public"."apply_templates"("p_listing_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."broadcast_table_changes"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    payload JSONB;
    origin_user UUID;
BEGIN
    -- Get the user who initiated this change (will be NULL for anon/service role)
    origin_user := auth.uid();

    -- Build payload matching BroadcastChangePayload structure
    IF TG_OP = 'DELETE' THEN
        payload := jsonb_build_object(
            'table', TG_TABLE_NAME,
            'type', TG_OP,
            'record', NULL,
            'old_record', to_jsonb(OLD) || jsonb_build_object(
                '_origin_user_id', origin_user,
                '_event_version', 1
            )
        );
    ELSIF TG_OP = 'INSERT' THEN
        payload := jsonb_build_object(
            'table', TG_TABLE_NAME,
            'type', TG_OP,
            'record', to_jsonb(NEW) || jsonb_build_object(
                '_origin_user_id', origin_user,
                '_event_version', 1
            ),
            'old_record', NULL
        );
    ELSE -- UPDATE
        payload := jsonb_build_object(
            'table', TG_TABLE_NAME,
            'type', TG_OP,
            'record', to_jsonb(NEW) || jsonb_build_object(
                '_origin_user_id', origin_user,
                '_event_version', 1
            ),
            'old_record', to_jsonb(OLD)
        );
    END IF;

    -- Use realtime.send() with private=false for public channel
    -- This works without real Supabase authentication
    PERFORM realtime.send(
        payload,           -- JSONB payload
        TG_OP,             -- event name (INSERT/UPDATE/DELETE)  
        'dispatch:broadcast',  -- topic
        false              -- private = false (public channel)
    );

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."broadcast_table_changes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_version_compat"("p_platform" "text", "p_client_version" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_record app_compat%ROWTYPE;
    v_client_raw INTEGER[];
    v_min_raw INTEGER[];
    v_client_parts INTEGER[];
    v_min_parts INTEGER[];
    v_compatible BOOLEAN := TRUE;
BEGIN
    SELECT * INTO v_record FROM app_compat WHERE platform = p_platform;
    IF NOT FOUND THEN
        RETURN json_build_object('compatible', TRUE, 'min_version', NULL, 'current_version', NULL, 'force_update', FALSE, 'message', 'No compatibility record found');
    END IF;

    -- Parse version strings to arrays
    v_client_raw := string_to_array(p_client_version, '.')::INTEGER[];
    v_min_raw := string_to_array(v_record.min_version, '.')::INTEGER[];

    -- Pad with zeros for missing minor/patch (handles "1" or "1.0" gracefully)
    v_client_parts := ARRAY[
        COALESCE(v_client_raw[1], 0),
        COALESCE(v_client_raw[2], 0),
        COALESCE(v_client_raw[3], 0)
    ];
    v_min_parts := ARRAY[
        COALESCE(v_min_raw[1], 0),
        COALESCE(v_min_raw[2], 0),
        COALESCE(v_min_raw[3], 0)
    ];

    -- Compare major.minor.patch
    IF v_client_parts[1] < v_min_parts[1] THEN
        v_compatible := FALSE;
    ELSIF v_client_parts[1] = v_min_parts[1] THEN
        IF v_client_parts[2] < v_min_parts[2] THEN
            v_compatible := FALSE;
        ELSIF v_client_parts[2] = v_min_parts[2] THEN
            IF v_client_parts[3] < v_min_parts[3] THEN
                v_compatible := FALSE;
            END IF;
        END IF;
    END IF;

    RETURN json_build_object(
        'compatible', v_compatible,
        'min_version', v_record.min_version,
        'current_version', v_record.current_version,
        'force_update', v_record.force_update AND NOT v_compatible,
        'migration_required', v_record.migration_required,
        'message', CASE
            WHEN NOT v_compatible AND v_record.force_update THEN 'Update required. Please update to continue.'
            WHEN NOT v_compatible THEN 'Update available. Please update for the best experience.'
            ELSE 'App is up to date.'
        END
    );
END;
$$;


ALTER FUNCTION "public"."check_version_compat"("p_platform" "text", "p_client_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_generate_activities_for_listing"("p_listing_id" "uuid", "p_listing_type_id" "uuid", "p_declared_by" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.activities (
        id,
        title,
        description,
        status,
        declared_by,
        listing,
        audiences,
        source_template_id,
        created_via,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid(),
        at.title,
        at.description,
        'open',
        p_declared_by,
        p_listing_id,
        at.audiences,
        at.id,
        'dispatch',
        now(),
        now()
    FROM public.activity_templates at
    WHERE at.listing_type_id = p_listing_type_id
      AND NOT at.is_archived
    ON CONFLICT DO NOTHING;
END;
$$;


ALTER FUNCTION "public"."fn_generate_activities_for_listing"("p_listing_id" "uuid", "p_listing_type_id" "uuid", "p_declared_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_intake_queue_batch"("batch_size" integer DEFAULT 5) RETURNS TABLE("id" "uuid", "envelope" "jsonb", "message_type" "text", "created_at" timestamp with time zone, "retry_count" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    iq.id,
    iq.envelope,
    iq.message_type,
    iq.created_at,
    iq.retry_count
  FROM intake_queue iq
  WHERE iq.processed_at IS NULL
  ORDER BY iq.created_at ASC
  LIMIT batch_size
  FOR UPDATE SKIP LOCKED;
END;
$$;


ALTER FUNCTION "public"."get_intake_queue_batch"("batch_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Try to find an existing profile by email (Shadow Profile Claim)
  update public.users
  set auth_id = new.id,
      id = new.id, -- ENSURE ID matches Auth ID during claim
      updated_at = now()
  where email = new.email;

  -- If found, we are done.
  if found then
    return new;
  end if;

  -- If NOT found, create a new profile
  insert into public.users (id, auth_id, email, name, user_type)
  values (
    new.id, -- CRITICAL: ID must match Auth ID
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    'admin'
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM users
    WHERE id = auth.uid()
    AND user_type = 'admin'
  );
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_app_admin"() RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$ SELECT EXISTS ( SELECT 1 FROM users WHERE auth_id = auth.uid() AND user_type IN ('admin', 'marketing', 'operator') ); $$;


ALTER FUNCTION "public"."is_app_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_realtor"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE auth_id = auth.uid()
      AND user_type = 'realtor'
  )
$$;


ALTER FUNCTION "public"."is_realtor"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_intake_queue_processed"("queue_id" "uuid", "error_msg" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE intake_queue
  SET 
    processed_at = NOW(),
    error_message = error_msg
  WHERE id = queue_id;
END;
$$;


ALTER FUNCTION "public"."mark_intake_queue_processed"("queue_id" "uuid", "error_msg" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_generate_activities_for_listing"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    PERFORM public.fn_generate_activities_for_listing(
        NEW.id,
        NEW.listing_type_id,
        NEW.owned_by -- Use listing owner as declarer
    );
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_generate_activities_for_listing"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "due_date" timestamp with time zone,
    "status" "text" DEFAULT 'open'::"text",
    "duration_minutes" integer,
    "declared_by" "uuid" NOT NULL,
    "listing" "uuid",
    "created_via" "text" DEFAULT 'dispatch'::"text",
    "source_slack_messages" "jsonb",
    "completed_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone,
    "audiences" "text"[] DEFAULT ARRAY['admin'::"text", 'marketing'::"text"] NOT NULL,
    "source_template_id" "uuid"
);

ALTER TABLE ONLY "public"."activities" REPLICA IDENTITY FULL;


ALTER TABLE "public"."activities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activity_assignees" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "activity_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "assigned_by" "uuid" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."activity_assignees" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activity_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "listing_type_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text" NOT NULL,
    "audiences" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "default_assignee_id" "uuid",
    "position" integer DEFAULT 0 NOT NULL,
    "is_archived" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "check_audiences_valid" CHECK (("audiences" <@ ARRAY['admin'::"text", 'marketing'::"text"]))
);


ALTER TABLE "public"."activity_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."agent_tasks" (
    "task_id" "text" NOT NULL,
    "realtor_id" "text",
    "task_key" "text",
    "name" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'OPEN'::"text",
    "task_category" "text",
    "priority" integer DEFAULT 0,
    "due_date" "date",
    "inputs" "jsonb" DEFAULT '{}'::"jsonb",
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."agent_tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_compat" (
    "platform" "text" NOT NULL,
    "min_version" "text" NOT NULL,
    "current_version" "text" NOT NULL,
    "migration_required" boolean DEFAULT false,
    "force_update" boolean DEFAULT false,
    "deprecated_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."app_compat" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."channels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."channels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."classifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "text",
    "user_id" "text",
    "channel_id" "text",
    "message_ts" "text",
    "message" "text",
    "classification" "jsonb" NOT NULL,
    "message_type" "text",
    "group_key" "text",
    "task_key" "text",
    "assignee_hint" "text",
    "due_date" "date",
    "confidence" double precision,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."classifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intake_events" (
    "event_id" "text" NOT NULL,
    "processed_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."intake_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."intake_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "envelope" "jsonb" NOT NULL,
    "message_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "processed_at" timestamp with time zone,
    "retry_count" integer DEFAULT 0,
    "error_message" "text"
);


ALTER TABLE "public"."intake_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."listing_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    "is_archived" boolean DEFAULT false NOT NULL,
    "owned_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "color_hex" "text"
);


ALTER TABLE "public"."listing_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."listings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "address" "text" NOT NULL,
    "city" "text" DEFAULT ''::"text",
    "province" "text" DEFAULT ''::"text",
    "postal_code" "text" DEFAULT ''::"text",
    "country" "text" DEFAULT 'Canada'::"text",
    "price" numeric(12,2),
    "mls_number" "text",
    "listing_type" "text" DEFAULT 'sale'::"text",
    "status" "text" DEFAULT 'draft'::"text",
    "owned_by" "uuid" NOT NULL,
    "created_via" "text" DEFAULT 'dispatch'::"text",
    "source_slack_messages" "jsonb",
    "activated_at" timestamp with time zone,
    "pending_at" timestamp with time zone,
    "closed_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone,
    "due_date" timestamp with time zone,
    "listing_type_id" "uuid" NOT NULL,
    "stage" "text" DEFAULT 'pending'::"text" NOT NULL,
    "property_id" "uuid",
    "real_dirt" "text",
    CONSTRAINT "listing_stage_check" CHECK (("stage" = ANY (ARRAY['pending'::"text", 'working_on'::"text", 'live'::"text", 'sold'::"text", 're_list'::"text", 'done'::"text"])))
);

ALTER TABLE ONLY "public"."listings" REPLICA IDENTITY FULL;


ALTER TABLE "public"."listings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "content" "text" NOT NULL,
    "channel_id" "uuid",
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "content" "text" NOT NULL,
    "parent_type" "text" NOT NULL,
    "parent_id" "uuid" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "edited_at" timestamp with time zone,
    "edited_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "deleted_at" timestamp with time zone,
    "deleted_by" "uuid",
    CONSTRAINT "notes_deleted_fields_check" CHECK (((("deleted_at" IS NULL) AND ("deleted_by" IS NULL)) OR (("deleted_at" IS NOT NULL) AND ("deleted_by" IS NOT NULL)))),
    CONSTRAINT "notes_parent_type_check" CHECK (("parent_type" = ANY (ARRAY['listing'::"text", 'task'::"text", 'activity'::"text"])))
);

ALTER TABLE ONLY "public"."notes" REPLICA IDENTITY FULL;


ALTER TABLE "public"."notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."properties" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "address" "text" NOT NULL,
    "unit" "text",
    "city" "text",
    "province" "text",
    "postal_code" "text",
    "country" "text" DEFAULT 'Canada'::"text",
    "property_type" "text" DEFAULT 'residential'::"text" NOT NULL,
    "owned_by" "uuid" NOT NULL,
    "created_via" "text" DEFAULT 'dispatch'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "synced_at" timestamp with time zone,
    CONSTRAINT "property_type_check" CHECK (("property_type" = ANY (ARRAY['residential'::"text", 'commercial'::"text", 'land'::"text", 'multi_family'::"text", 'condo'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."properties" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."realtors" (
    "realtor_id" "text" NOT NULL,
    "slack_user_id" "text",
    "name" "text",
    "email" "text",
    "status" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."realtors" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."status_changes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "parent_type" "text" NOT NULL,
    "parent_id" "uuid" NOT NULL,
    "old_status" "text",
    "new_status" "text" NOT NULL,
    "changed_by" "uuid" NOT NULL,
    "reason" "text",
    "changed_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone
);


ALTER TABLE "public"."status_changes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subtasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "completed" boolean DEFAULT false,
    "parent_type" "text" NOT NULL,
    "parent_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone
);


ALTER TABLE "public"."subtasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sync_metadata" (
    "user_id" "uuid" NOT NULL,
    "last_sync_tasks" timestamp with time zone DEFAULT "now"(),
    "last_sync_activities" timestamp with time zone DEFAULT "now"(),
    "last_sync_listings" timestamp with time zone DEFAULT "now"(),
    "last_sync_notes" timestamp with time zone DEFAULT "now"(),
    "last_sync_subtasks" timestamp with time zone DEFAULT "now"(),
    "last_sync_status_changes" timestamp with time zone DEFAULT "now"(),
    "last_sync_claim_events" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."sync_metadata" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_assignees" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "assigned_by" "uuid" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."task_assignees" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "due_date" timestamp with time zone,
    "status" "text" DEFAULT 'open'::"text",
    "declared_by" "uuid" NOT NULL,
    "listing" "uuid",
    "created_via" "text" DEFAULT 'dispatch'::"text",
    "source_slack_messages" "jsonb",
    "completed_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone,
    "audiences" "text"[] DEFAULT ARRAY['admin'::"text", 'marketing'::"text"] NOT NULL
);

ALTER TABLE ONLY "public"."tasks" REPLICA IDENTITY FULL;


ALTER TABLE "public"."tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "avatar_url" "text",
    "user_type" "text" DEFAULT 'admin'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "auth_id" "uuid",
    "avatar_path" "text",
    "avatar_hash" "text"
);

ALTER TABLE ONLY "public"."users" REPLICA IDENTITY FULL;


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."avatar_hash" IS 'SHA256 hash of the normalized avatar image';



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activity_assignees"
    ADD CONSTRAINT "activity_assignees_activity_id_user_id_key" UNIQUE ("activity_id", "user_id");



ALTER TABLE ONLY "public"."activity_assignees"
    ADD CONSTRAINT "activity_assignees_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activity_templates"
    ADD CONSTRAINT "activity_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."agent_tasks"
    ADD CONSTRAINT "agent_tasks_pkey" PRIMARY KEY ("task_id");



ALTER TABLE ONLY "public"."app_compat"
    ADD CONSTRAINT "app_compat_pkey" PRIMARY KEY ("platform");



ALTER TABLE ONLY "public"."channels"
    ADD CONSTRAINT "channels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."channels"
    ADD CONSTRAINT "channels_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."classifications"
    ADD CONSTRAINT "classifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intake_events"
    ADD CONSTRAINT "intake_events_pkey" PRIMARY KEY ("event_id");



ALTER TABLE ONLY "public"."intake_queue"
    ADD CONSTRAINT "intake_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."listing_types"
    ADD CONSTRAINT "listing_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."listings"
    ADD CONSTRAINT "listings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "properties_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."realtors"
    ADD CONSTRAINT "realtors_pkey" PRIMARY KEY ("realtor_id");



ALTER TABLE ONLY "public"."realtors"
    ADD CONSTRAINT "realtors_slack_user_id_key" UNIQUE ("slack_user_id");



ALTER TABLE ONLY "public"."status_changes"
    ADD CONSTRAINT "status_changes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subtasks"
    ADD CONSTRAINT "subtasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sync_metadata"
    ADD CONSTRAINT "sync_metadata_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_task_id_user_id_key" UNIQUE ("task_id", "user_id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_activities_audiences" ON "public"."activities" USING "gin" ("audiences");



CREATE INDEX "idx_activities_declared_by" ON "public"."activities" USING "btree" ("declared_by");



CREATE INDEX "idx_activities_due_date" ON "public"."activities" USING "btree" ("due_date");



CREATE UNIQUE INDEX "idx_activities_idempotent_template" ON "public"."activities" USING "btree" ("listing", "source_template_id") WHERE ("source_template_id" IS NOT NULL);



CREATE INDEX "idx_activities_listing" ON "public"."activities" USING "btree" ("listing");



CREATE INDEX "idx_activities_status" ON "public"."activities" USING "btree" ("status");



CREATE INDEX "idx_activities_updated_at" ON "public"."activities" USING "btree" ("updated_at");



CREATE INDEX "idx_activity_assignees_activity" ON "public"."activity_assignees" USING "btree" ("activity_id");



CREATE INDEX "idx_activity_assignees_user" ON "public"."activity_assignees" USING "btree" ("user_id");



CREATE INDEX "idx_agent_tasks_deleted_at" ON "public"."agent_tasks" USING "btree" ("deleted_at") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_agent_tasks_realtor_id" ON "public"."agent_tasks" USING "btree" ("realtor_id");



CREATE INDEX "idx_agent_tasks_status" ON "public"."agent_tasks" USING "btree" ("status");



CREATE INDEX "idx_agent_tasks_task_key" ON "public"."agent_tasks" USING "btree" ("task_key");



CREATE INDEX "idx_classifications_channel_id" ON "public"."classifications" USING "btree" ("channel_id");



CREATE INDEX "idx_classifications_created_at" ON "public"."classifications" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_classifications_event_id" ON "public"."classifications" USING "btree" ("event_id");



CREATE INDEX "idx_classifications_message_type" ON "public"."classifications" USING "btree" ("message_type");



CREATE INDEX "idx_classifications_user_id" ON "public"."classifications" USING "btree" ("user_id");



CREATE INDEX "idx_intake_events_processed_at" ON "public"."intake_events" USING "btree" ("processed_at" DESC);



CREATE INDEX "idx_intake_queue_created_at" ON "public"."intake_queue" USING "btree" ("created_at");



CREATE INDEX "idx_intake_queue_message_type" ON "public"."intake_queue" USING "btree" ("message_type");



CREATE INDEX "idx_intake_queue_processed_at" ON "public"."intake_queue" USING "btree" ("processed_at") WHERE ("processed_at" IS NULL);



CREATE UNIQUE INDEX "idx_listing_types_global_name_unique" ON "public"."listing_types" USING "btree" ("lower"("name")) WHERE ("owned_by" IS NULL);



CREATE UNIQUE INDEX "idx_listing_types_scoped_name_unique" ON "public"."listing_types" USING "btree" ("owned_by", "lower"("name")) WHERE ("owned_by" IS NOT NULL);



CREATE INDEX "idx_listings_due_date" ON "public"."listings" USING "btree" ("due_date");



CREATE INDEX "idx_listings_owned_by" ON "public"."listings" USING "btree" ("owned_by");



CREATE INDEX "idx_listings_property_id" ON "public"."listings" USING "btree" ("property_id");



CREATE INDEX "idx_listings_stage" ON "public"."listings" USING "btree" ("stage");



CREATE INDEX "idx_listings_status" ON "public"."listings" USING "btree" ("status");



CREATE INDEX "idx_listings_updated_at" ON "public"."listings" USING "btree" ("updated_at");



CREATE INDEX "idx_notes_created_at" ON "public"."notes" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_notes_created_by" ON "public"."notes" USING "btree" ("created_by");



CREATE INDEX "idx_notes_parent" ON "public"."notes" USING "btree" ("parent_type", "parent_id");



CREATE INDEX "idx_notes_updated_at" ON "public"."notes" USING "btree" ("updated_at");



CREATE UNIQUE INDEX "idx_properties_dedupe" ON "public"."properties" USING "btree" ("owned_by", "lower"("address"), COALESCE("unit", ''::"text"), "lower"(COALESCE("postal_code", ''::"text"))) WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_properties_owned_by" ON "public"."properties" USING "btree" ("owned_by");



CREATE INDEX "idx_properties_updated_at" ON "public"."properties" USING "btree" ("updated_at");



CREATE INDEX "idx_realtors_slack_user_id" ON "public"."realtors" USING "btree" ("slack_user_id");



CREATE INDEX "idx_realtors_status" ON "public"."realtors" USING "btree" ("status");



CREATE INDEX "idx_status_changes_changed_at" ON "public"."status_changes" USING "btree" ("changed_at" DESC);



CREATE INDEX "idx_status_changes_parent" ON "public"."status_changes" USING "btree" ("parent_type", "parent_id");



CREATE INDEX "idx_subtasks_parent" ON "public"."subtasks" USING "btree" ("parent_type", "parent_id");



CREATE INDEX "idx_task_assignees_task" ON "public"."task_assignees" USING "btree" ("task_id");



CREATE INDEX "idx_task_assignees_user" ON "public"."task_assignees" USING "btree" ("user_id");



CREATE INDEX "idx_tasks_audiences" ON "public"."tasks" USING "gin" ("audiences");



CREATE INDEX "idx_tasks_declared_by" ON "public"."tasks" USING "btree" ("declared_by");



CREATE INDEX "idx_tasks_due_date" ON "public"."tasks" USING "btree" ("due_date");



CREATE INDEX "idx_tasks_listing" ON "public"."tasks" USING "btree" ("listing");



CREATE INDEX "idx_tasks_status" ON "public"."tasks" USING "btree" ("status");



CREATE INDEX "idx_tasks_updated_at" ON "public"."tasks" USING "btree" ("updated_at");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_user_type" ON "public"."users" USING "btree" ("user_type");



CREATE INDEX "notes_deleted_idx" ON "public"."notes" USING "btree" ("deleted_at");



CREATE INDEX "notes_parent_idx" ON "public"."notes" USING "btree" ("parent_type", "parent_id");



CREATE INDEX "users_auth_id_idx" ON "public"."users" USING "btree" ("auth_id");



CREATE INDEX "users_email_idx" ON "public"."users" USING "btree" ("email");



CREATE OR REPLACE TRIGGER "broadcast_activities_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."activities" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_table_changes"();



CREATE OR REPLACE TRIGGER "broadcast_listings_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."listings" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_table_changes"();



CREATE OR REPLACE TRIGGER "broadcast_notes_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."notes" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_table_changes"();



CREATE OR REPLACE TRIGGER "broadcast_properties_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."properties" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_table_changes"();



CREATE OR REPLACE TRIGGER "broadcast_tasks_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_table_changes"();



CREATE OR REPLACE TRIGGER "broadcast_users_changes" AFTER INSERT OR DELETE OR UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."broadcast_table_changes"();



CREATE OR REPLACE TRIGGER "on_listing_created" AFTER INSERT ON "public"."listings" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_generate_activities_for_listing"();



CREATE OR REPLACE TRIGGER "update_activities_updated_at" BEFORE UPDATE ON "public"."activities" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_app_compat_updated_at" BEFORE UPDATE ON "public"."app_compat" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_listings_updated_at" BEFORE UPDATE ON "public"."listings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_notes_updated_at" BEFORE UPDATE ON "public"."notes" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_properties_updated_at" BEFORE UPDATE ON "public"."properties" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_sync_metadata_updated_at" BEFORE UPDATE ON "public"."sync_metadata" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_tasks_updated_at" BEFORE UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_declared_by_fkey" FOREIGN KEY ("declared_by") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_listing_fkey" FOREIGN KEY ("listing") REFERENCES "public"."listings"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_source_template_id_fkey" FOREIGN KEY ("source_template_id") REFERENCES "public"."activity_templates"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."activity_assignees"
    ADD CONSTRAINT "activity_assignees_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "public"."activities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."activity_assignees"
    ADD CONSTRAINT "activity_assignees_assigned_by_fkey" FOREIGN KEY ("assigned_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."activity_assignees"
    ADD CONSTRAINT "activity_assignees_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."activity_templates"
    ADD CONSTRAINT "activity_templates_default_assignee_id_fkey" FOREIGN KEY ("default_assignee_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."activity_templates"
    ADD CONSTRAINT "activity_templates_listing_type_id_fkey" FOREIGN KEY ("listing_type_id") REFERENCES "public"."listing_types"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."listing_types"
    ADD CONSTRAINT "listing_types_owned_by_fkey" FOREIGN KEY ("owned_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."listings"
    ADD CONSTRAINT "listings_listing_type_fk" FOREIGN KEY ("listing_type_id") REFERENCES "public"."listing_types"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."listings"
    ADD CONSTRAINT "listings_owned_by_fkey" FOREIGN KEY ("owned_by") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."listings"
    ADD CONSTRAINT "listings_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_channel_id_fkey" FOREIGN KEY ("channel_id") REFERENCES "public"."channels"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."notes"
    ADD CONSTRAINT "notes_edited_by_fkey" FOREIGN KEY ("edited_by") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "properties_owned_by_fkey" FOREIGN KEY ("owned_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."status_changes"
    ADD CONSTRAINT "status_changes_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."sync_metadata"
    ADD CONSTRAINT "sync_metadata_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_assigned_by_fkey" FOREIGN KEY ("assigned_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_declared_by_fkey" FOREIGN KEY ("declared_by") REFERENCES "public"."users"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_listing_fkey" FOREIGN KEY ("listing") REFERENCES "public"."listings"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_auth_id_fkey" FOREIGN KEY ("auth_id") REFERENCES "auth"."users"("id");



CREATE POLICY "Allow insert messages" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow read channels" ON "public"."channels" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow read messages" ON "public"."messages" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow read users" ON "public"."users" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Anon activity access" ON "public"."activities" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Anon listing access" ON "public"."listings" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Anon status_change access" ON "public"."status_changes" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Anon subtask access" ON "public"."subtasks" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Anon sync_metadata access" ON "public"."sync_metadata" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Anon task access" ON "public"."tasks" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Anon users can read all users" ON "public"."users" FOR SELECT TO "anon" USING (true);



CREATE POLICY "Enable all access for authenticated users" ON "public"."activities" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable all access for authenticated users" ON "public"."listings" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Enable all access for authenticated users" ON "public"."tasks" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Service role can access all" ON "public"."agent_tasks" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can access all" ON "public"."classifications" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can access all" ON "public"."intake_events" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can access all" ON "public"."intake_queue" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role can access all" ON "public"."realtors" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Staff can access everything" ON "public"."users" TO "authenticated" USING ("public"."is_app_admin"());



CREATE POLICY "Users can access own profile" ON "public"."users" USING (("auth_id" = "auth"."uid"()));



CREATE POLICY "Users can read all users" ON "public"."users" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE TO "authenticated" USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."activities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."activity_assignees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_assignees_delete" ON "public"."activity_assignees" FOR DELETE USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."activities" "a"
  WHERE (("a"."id" = "activity_assignees"."activity_id") AND (("a"."declared_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."listings" "l"
          WHERE (("l"."id" = "a"."listing") AND ("l"."owned_by" = "auth"."uid"()))))))))));



CREATE POLICY "activity_assignees_insert" ON "public"."activity_assignees" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."activities" "a"
  WHERE (("a"."id" = "activity_assignees"."activity_id") AND (("a"."declared_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."listings" "l"
          WHERE (("l"."id" = "a"."listing") AND ("l"."owned_by" = "auth"."uid"())))))))));



CREATE POLICY "activity_assignees_select" ON "public"."activity_assignees" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."activities" "a"
  WHERE (("a"."id" = "activity_assignees"."activity_id") AND (("a"."declared_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."listings" "l"
          WHERE (("l"."id" = "a"."listing") AND ("l"."owned_by" = "auth"."uid"()))))))))));



CREATE POLICY "activity_select" ON "public"."activities" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."activity_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."agent_tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_compat" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "app_compat_admin_write" ON "public"."app_compat" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "app_compat_read" ON "public"."app_compat" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "at_delete" ON "public"."activity_templates" FOR DELETE TO "authenticated" USING (("public"."is_realtor"() AND (EXISTS ( SELECT 1
   FROM "public"."listing_types" "lt"
  WHERE (("lt"."id" = "activity_templates"."listing_type_id") AND ("lt"."owned_by" = "auth"."uid"()))))));



CREATE POLICY "at_insert" ON "public"."activity_templates" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_realtor"() AND (EXISTS ( SELECT 1
   FROM "public"."listing_types" "lt"
  WHERE (("lt"."id" = "activity_templates"."listing_type_id") AND ("lt"."owned_by" = "auth"."uid"()))))));



CREATE POLICY "at_select" ON "public"."activity_templates" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."listing_types" "lt"
  WHERE (("lt"."id" = "activity_templates"."listing_type_id") AND ("lt"."owned_by" = "auth"."uid"())))) OR "public"."is_app_admin"()));



CREATE POLICY "at_update" ON "public"."activity_templates" FOR UPDATE TO "authenticated" USING (("public"."is_realtor"() AND (EXISTS ( SELECT 1
   FROM "public"."listing_types" "lt"
  WHERE (("lt"."id" = "activity_templates"."listing_type_id") AND ("lt"."owned_by" = "auth"."uid"())))))) WITH CHECK (("public"."is_realtor"() AND (EXISTS ( SELECT 1
   FROM "public"."listing_types" "lt"
  WHERE (("lt"."id" = "activity_templates"."listing_type_id") AND ("lt"."owned_by" = "auth"."uid"()))))));



ALTER TABLE "public"."channels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."classifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."intake_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."intake_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "listing_select" ON "public"."listings" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."listing_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."listings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "lt_delete" ON "public"."listing_types" FOR DELETE TO "authenticated" USING (("public"."is_realtor"() AND ("owned_by" = "auth"."uid"())));



CREATE POLICY "lt_insert" ON "public"."listing_types" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_realtor"() AND ("owned_by" = "auth"."uid"())));



CREATE POLICY "lt_select" ON "public"."listing_types" FOR SELECT TO "authenticated" USING ((("owned_by" = "auth"."uid"()) OR "public"."is_app_admin"()));



CREATE POLICY "lt_update" ON "public"."listing_types" FOR UPDATE TO "authenticated" USING (("public"."is_realtor"() AND ("owned_by" = "auth"."uid"()))) WITH CHECK (("public"."is_realtor"() AND ("owned_by" = "auth"."uid"())));



ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "note_edit" ON "public"."notes" FOR UPDATE TO "authenticated" USING ((("created_by" = "auth"."uid"()) AND ("deleted_at" IS NULL))) WITH CHECK ((("created_by" = "auth"."uid"()) AND ("deleted_at" IS NULL)));



CREATE POLICY "note_insert" ON "public"."notes" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = "auth"."uid"()) AND ((("parent_type" = 'listing'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."listings" "l"
  WHERE (("l"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR (("parent_type" = 'task'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."listings" "l" ON (("l"."id" = "t"."listing")))
  WHERE (("t"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR (("parent_type" = 'activity'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."activities" "a"
     JOIN "public"."listings" "l" ON (("l"."id" = "a"."listing")))
  WHERE (("a"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR "public"."is_app_admin"())));



CREATE POLICY "note_select" ON "public"."notes" FOR SELECT TO "authenticated" USING ((((("parent_type" = 'listing'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."listings" "l"
  WHERE (("l"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR (("parent_type" = 'task'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."listings" "l" ON (("l"."id" = "t"."listing")))
  WHERE (("t"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR (("parent_type" = 'activity'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."activities" "a"
     JOIN "public"."listings" "l" ON (("l"."id" = "a"."listing")))
  WHERE (("a"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR "public"."is_app_admin"()) AND (("deleted_at" IS NULL) OR (("deleted_by" = "auth"."uid"()) AND ("deleted_at" > ("now"() - '00:10:00'::interval))) OR "public"."is_app_admin"())));



CREATE POLICY "note_soft_delete" ON "public"."notes" FOR UPDATE TO "authenticated" USING ((("deleted_at" IS NULL) AND ((("parent_type" = 'listing'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."listings" "l"
  WHERE (("l"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR (("parent_type" = 'task'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."listings" "l" ON (("l"."id" = "t"."listing")))
  WHERE (("t"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR (("parent_type" = 'activity'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."activities" "a"
     JOIN "public"."listings" "l" ON (("l"."id" = "a"."listing")))
  WHERE (("a"."id" = "notes"."parent_id") AND ("l"."owned_by" = "auth"."uid"()))))) OR "public"."is_app_admin"()))) WITH CHECK ((("deleted_at" IS NOT NULL) AND ("deleted_by" = "auth"."uid"())));



CREATE POLICY "note_undo" ON "public"."notes" FOR UPDATE TO "authenticated" USING ((("deleted_by" = "auth"."uid"()) AND ("deleted_at" > ("now"() - '00:10:00'::interval)))) WITH CHECK ((("deleted_at" IS NULL) AND ("deleted_by" IS NULL)));



ALTER TABLE "public"."notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."properties" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "properties_delete" ON "public"."properties" FOR DELETE TO "authenticated" USING (("public"."is_app_admin"() OR ("owned_by" = "auth"."uid"())));



CREATE POLICY "properties_insert" ON "public"."properties" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_app_admin"() OR ("owned_by" = "auth"."uid"())));



CREATE POLICY "properties_select" ON "public"."properties" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "properties_update" ON "public"."properties" FOR UPDATE TO "authenticated" USING (("public"."is_app_admin"() OR ("owned_by" = "auth"."uid"()))) WITH CHECK (("public"."is_app_admin"() OR ("owned_by" = "auth"."uid"())));



ALTER TABLE "public"."realtors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "status_change_access" ON "public"."status_changes" TO "authenticated" USING (((("parent_type" = 'task'::"text") AND ("parent_id" IN ( SELECT "tasks"."id"
   FROM "public"."tasks"))) OR (("parent_type" = 'activity'::"text") AND ("parent_id" IN ( SELECT "activities"."id"
   FROM "public"."activities"))) OR (("parent_type" = 'listing'::"text") AND ("parent_id" IN ( SELECT "listings"."id"
   FROM "public"."listings")))));



ALTER TABLE "public"."status_changes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "subtask_access" ON "public"."subtasks" TO "authenticated" USING (((("parent_type" = 'task'::"text") AND ("parent_id" IN ( SELECT "tasks"."id"
   FROM "public"."tasks"))) OR (("parent_type" = 'activity'::"text") AND ("parent_id" IN ( SELECT "activities"."id"
   FROM "public"."activities")))));



ALTER TABLE "public"."subtasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sync_metadata" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sync_metadata_access" ON "public"."sync_metadata" TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."task_assignees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "task_assignees_delete" ON "public"."task_assignees" FOR DELETE USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_assignees"."task_id") AND (("t"."declared_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."listings" "l"
          WHERE (("l"."id" = "t"."listing") AND ("l"."owned_by" = "auth"."uid"()))))))))));



CREATE POLICY "task_assignees_insert" ON "public"."task_assignees" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_assignees"."task_id") AND (("t"."declared_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."listings" "l"
          WHERE (("l"."id" = "t"."listing") AND ("l"."owned_by" = "auth"."uid"())))))))));



CREATE POLICY "task_assignees_select" ON "public"."task_assignees" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_assignees"."task_id") AND (("t"."declared_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM "public"."listings" "l"
          WHERE (("l"."id" = "t"."listing") AND ("l"."owned_by" = "auth"."uid"()))))))))));



CREATE POLICY "task_select" ON "public"."tasks" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_templates"("p_listing_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."apply_templates"("p_listing_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_templates"("p_listing_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."broadcast_table_changes"() TO "anon";
GRANT ALL ON FUNCTION "public"."broadcast_table_changes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."broadcast_table_changes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_version_compat"("p_platform" "text", "p_client_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_version_compat"("p_platform" "text", "p_client_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_version_compat"("p_platform" "text", "p_client_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_generate_activities_for_listing"("p_listing_id" "uuid", "p_listing_type_id" "uuid", "p_declared_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."fn_generate_activities_for_listing"("p_listing_id" "uuid", "p_listing_type_id" "uuid", "p_declared_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_generate_activities_for_listing"("p_listing_id" "uuid", "p_listing_type_id" "uuid", "p_declared_by" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_intake_queue_batch"("batch_size" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_intake_queue_batch"("batch_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_intake_queue_batch"("batch_size" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_app_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_app_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_app_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_realtor"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_realtor"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_realtor"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_intake_queue_processed"("queue_id" "uuid", "error_msg" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_intake_queue_processed"("queue_id" "uuid", "error_msg" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_intake_queue_processed"("queue_id" "uuid", "error_msg" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_generate_activities_for_listing"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_generate_activities_for_listing"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_generate_activities_for_listing"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON TABLE "public"."activities" TO "anon";
GRANT ALL ON TABLE "public"."activities" TO "authenticated";
GRANT ALL ON TABLE "public"."activities" TO "service_role";



GRANT ALL ON TABLE "public"."activity_assignees" TO "anon";
GRANT ALL ON TABLE "public"."activity_assignees" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_assignees" TO "service_role";



GRANT ALL ON TABLE "public"."activity_templates" TO "anon";
GRANT ALL ON TABLE "public"."activity_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_templates" TO "service_role";



GRANT ALL ON TABLE "public"."agent_tasks" TO "anon";
GRANT ALL ON TABLE "public"."agent_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."agent_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."app_compat" TO "anon";
GRANT ALL ON TABLE "public"."app_compat" TO "authenticated";
GRANT ALL ON TABLE "public"."app_compat" TO "service_role";



GRANT ALL ON TABLE "public"."channels" TO "anon";
GRANT ALL ON TABLE "public"."channels" TO "authenticated";
GRANT ALL ON TABLE "public"."channels" TO "service_role";



GRANT ALL ON TABLE "public"."classifications" TO "anon";
GRANT ALL ON TABLE "public"."classifications" TO "authenticated";
GRANT ALL ON TABLE "public"."classifications" TO "service_role";



GRANT ALL ON TABLE "public"."intake_events" TO "anon";
GRANT ALL ON TABLE "public"."intake_events" TO "authenticated";
GRANT ALL ON TABLE "public"."intake_events" TO "service_role";



GRANT ALL ON TABLE "public"."intake_queue" TO "anon";
GRANT ALL ON TABLE "public"."intake_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."intake_queue" TO "service_role";



GRANT ALL ON TABLE "public"."listing_types" TO "anon";
GRANT ALL ON TABLE "public"."listing_types" TO "authenticated";
GRANT ALL ON TABLE "public"."listing_types" TO "service_role";



GRANT ALL ON TABLE "public"."listings" TO "anon";
GRANT ALL ON TABLE "public"."listings" TO "authenticated";
GRANT ALL ON TABLE "public"."listings" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."notes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."notes" TO "authenticated";
GRANT ALL ON TABLE "public"."notes" TO "service_role";



GRANT UPDATE("content") ON TABLE "public"."notes" TO "authenticated";



GRANT UPDATE("edited_at") ON TABLE "public"."notes" TO "authenticated";



GRANT UPDATE("edited_by") ON TABLE "public"."notes" TO "authenticated";



GRANT UPDATE("synced_at") ON TABLE "public"."notes" TO "authenticated";



GRANT UPDATE("updated_at") ON TABLE "public"."notes" TO "authenticated";



GRANT UPDATE("deleted_at") ON TABLE "public"."notes" TO "authenticated";



GRANT UPDATE("deleted_by") ON TABLE "public"."notes" TO "authenticated";



GRANT ALL ON TABLE "public"."properties" TO "anon";
GRANT ALL ON TABLE "public"."properties" TO "authenticated";
GRANT ALL ON TABLE "public"."properties" TO "service_role";



GRANT ALL ON TABLE "public"."realtors" TO "anon";
GRANT ALL ON TABLE "public"."realtors" TO "authenticated";
GRANT ALL ON TABLE "public"."realtors" TO "service_role";



GRANT ALL ON TABLE "public"."status_changes" TO "anon";
GRANT ALL ON TABLE "public"."status_changes" TO "authenticated";
GRANT ALL ON TABLE "public"."status_changes" TO "service_role";



GRANT ALL ON TABLE "public"."subtasks" TO "anon";
GRANT ALL ON TABLE "public"."subtasks" TO "authenticated";
GRANT ALL ON TABLE "public"."subtasks" TO "service_role";



GRANT ALL ON TABLE "public"."sync_metadata" TO "anon";
GRANT ALL ON TABLE "public"."sync_metadata" TO "authenticated";
GRANT ALL ON TABLE "public"."sync_metadata" TO "service_role";



GRANT ALL ON TABLE "public"."task_assignees" TO "anon";
GRANT ALL ON TABLE "public"."task_assignees" TO "authenticated";
GRANT ALL ON TABLE "public"."task_assignees" TO "service_role";



GRANT ALL ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







