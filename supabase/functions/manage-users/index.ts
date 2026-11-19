// Supabase Edge Function: manage-users
// Creates and manages student / staff logins. Runs with the service-role key,
// so it checks the caller's role itself before doing anything.
//
// Deploy:  supabase functions deploy manage-users
// Secret:  supabase secrets set STUDENT_EMAIL_DOMAIN=students.gssunguwansarki.app
//          (must match studentEmailDomain in lib/config.dart)
//
// Actions (POST JSON body):
//   { action: "create_student", full_name, admission_no, class_name?, gender?, pin? }
//   { action: "bulk_create_students", students: [{ full_name, admission_no, class_name?, gender? }] }
//   { action: "reset_pin", user_id, pin? }
//   { action: "set_active", user_id, active }
//   { action: "create_staff", full_name, email, password, role: "counsellor"|"admin", phone? }   (admin only)

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const DOMAIN = Deno.env.get("STUDENT_EMAIL_DOMAIN") ?? "students.gssunguwansarki.app";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** "GSS/2024/015" -> "gss-2024-015" ; must match AuthService.studentEmail in Flutter */
function normaliseAdmission(no: string) {
  return no.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function studentEmail(admissionNo: string) {
  return `${normaliseAdmission(admissionNo)}@${DOMAIN}`;
}

function randomPin() {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

function validPin(pin: string) {
  return /^[0-9]{6}$/.test(pin);
}

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function createStudent(s: {
  full_name: string;
  admission_no: string;
  class_name?: string;
  gender?: string;
  pin?: string;
}) {
  const fullName = (s.full_name ?? "").trim();
  const admissionNo = (s.admission_no ?? "").trim().toUpperCase();
  if (fullName.length < 3) throw new Error("Full name is too short");
  if (!normaliseAdmission(admissionNo)) throw new Error("Admission number is required");
  const pin = s.pin && s.pin.length ? s.pin : randomPin();
  if (!validPin(pin)) throw new Error("PIN must be exactly 6 digits");
  const gender = s.gender === "male" || s.gender === "female" ? s.gender : null;

  const { data, error } = await admin.auth.admin.createUser({
    email: studentEmail(admissionNo),
    password: pin,
    email_confirm: true,
    user_metadata: { full_name: fullName, admission_no: admissionNo },
  });
  if (error) {
    if (/already/i.test(error.message)) {
      throw new Error(`Admission number ${admissionNo} already has an account`);
    }
    throw error;
  }

  const { error: pErr } = await admin.from("profiles").insert({
    id: data.user!.id,
    role: "student",
    full_name: fullName,
    admission_no: admissionNo,
    class_name: s.class_name?.trim() || null,
    gender,
  });
  if (pErr) {
    await admin.auth.admin.deleteUser(data.user!.id); // roll back
    throw pErr;
  }
  return { user_id: data.user!.id, full_name: fullName, admission_no: admissionNo, pin };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  // Who is calling?
  const authHeader = req.headers.get("Authorization") ?? "";
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: u } = await caller.auth.getUser();
  if (!u?.user) return json({ error: "Please log in again" }, 401);

  const { data: me } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("id", u.user.id)
    .single();
  const isAdmin = me?.is_active && me.role === "admin";
  const isStaff = me?.is_active && (me.role === "admin" || me.role === "counsellor");
  if (!isStaff) return json({ error: "Only counsellors can manage accounts" }, 403);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  try {
    switch (body.action) {
      case "create_student": {
        return json(await createStudent(body as any));
      }

      case "bulk_create_students": {
        const list = Array.isArray(body.students) ? body.students.slice(0, 300) : [];
        const created: unknown[] = [];
        const failed: unknown[] = [];
        for (const s of list) {
          try {
            created.push(await createStudent({ ...s, pin: undefined }));
          } catch (e) {
            failed.push({ admission_no: s?.admission_no, full_name: s?.full_name, error: (e as Error).message });
          }
        }
        return json({ created, failed });
      }

      case "reset_pin": {
        const { data: target } = await admin
          .from("profiles").select("role").eq("id", body.user_id).single();
        if (!target) return json({ error: "User not found" }, 404);
        if (target.role !== "student") return json({ error: "Only student PINs can be reset here" }, 403);
        const pin = body.pin && String(body.pin).length ? String(body.pin) : randomPin();
        if (!validPin(pin)) return json({ error: "PIN must be exactly 6 digits" }, 400);
        const { error } = await admin.auth.admin.updateUserById(body.user_id, { password: pin });
        if (error) throw error;
        return json({ user_id: body.user_id, pin });
      }

      case "set_active": {
        const { data: target } = await admin
          .from("profiles").select("role").eq("id", body.user_id).single();
        if (!target) return json({ error: "User not found" }, 404);
        if (target.role !== "student" && !isAdmin) {
          return json({ error: "Only the admin can disable staff accounts" }, 403);
        }
        if (body.user_id === u.user.id) return json({ error: "You cannot disable yourself" }, 400);
        const active = !!body.active;
        const { error } = await admin.auth.admin.updateUserById(body.user_id, {
          ban_duration: active ? "none" : "876000h",
        });
        if (error) throw error;
        await admin.from("profiles").update({ is_active: active }).eq("id", body.user_id);
        return json({ user_id: body.user_id, active });
      }

      case "create_staff": {
        if (!isAdmin) return json({ error: "Only the admin can add staff" }, 403);
        const role = body.role === "admin" ? "admin" : "counsellor";
        const email = String(body.email ?? "").trim().toLowerCase();
        const password = String(body.password ?? "");
        const fullName = String(body.full_name ?? "").trim();
        if (!email.includes("@")) return json({ error: "Valid email required" }, 400);
        if (password.length < 8) return json({ error: "Password must be at least 8 characters" }, 400);
        if (fullName.length < 3) return json({ error: "Full name is too short" }, 400);

        const { data, error } = await admin.auth.admin.createUser({
          email, password, email_confirm: true, user_metadata: { full_name: fullName },
        });
        if (error) throw error;
        const { error: pErr } = await admin.from("profiles").insert({
          id: data.user!.id, role, full_name: fullName, phone: body.phone ?? null,
        });
        if (pErr) {
          await admin.auth.admin.deleteUser(data.user!.id);
          throw pErr;
        }
        return json({ user_id: data.user!.id, email, role });
      }

      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (e) {
    return json({ error: (e as Error).message ?? String(e) }, 400);
  }
});
