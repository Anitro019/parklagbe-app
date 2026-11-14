import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.10.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };
    return entities[char];
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication is required." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ??
    "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Supabase function credentials are not configured.");
    return jsonResponse({ error: "Notification service is not configured." }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser(authorization.slice("Bearer ".length));
  if (authError || !user) {
    return jsonResponse({ error: "Authentication is required." }, 401);
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "A valid JSON body is required." }, 400);
  }
  if (
    typeof payload !== "object" || payload === null ||
    !("complaintId" in payload) ||
    typeof payload.complaintId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      .test(payload.complaintId)
  ) {
    return jsonResponse({ error: "A valid complaint ID is required." }, 400);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: complaint, error: complaintError } = await adminClient
    .from("complaints")
    .select("reporter_id, subject, description, booking_id, spot_id")
    .eq("id", payload.complaintId)
    .eq("reporter_id", user.id)
    .maybeSingle();

  if (complaintError) {
    console.error("Could not verify report ownership:", complaintError.message);
    return jsonResponse({ error: "Could not verify the submitted report." }, 500);
  }
  if (!complaint) {
    return jsonResponse({ error: "Report not found for this account." }, 404);
  }

  const smtpHost = Deno.env.get("SMTP_HOST")?.trim() ?? "";
  const smtpPort = Number.parseInt(Deno.env.get("SMTP_PORT")?.trim() ?? "465");
  const smtpEmail = Deno.env.get("SMTP_EMAIL")?.trim() ?? "";
  const smtpPassword = Deno.env.get("SMTP_PASSWORD")?.trim() ?? "";
  const adminEmail = Deno.env.get("ADMIN_EMAIL")?.trim() ?? "";
  const senderName = Deno.env.get("SMTP_SENDER_NAME")?.trim() ||
    "ParkLagbee Support";

  if (!smtpHost || !smtpEmail || !smtpPassword || !adminEmail) {
    console.error("SMTP notification secrets are not fully configured.");
    return jsonResponse({ error: "Notification service is not configured." }, 500);
  }
  if (smtpPort !== 465) {
    console.error("Supabase Edge Functions require SMTP port 465 for Gmail.");
    return jsonResponse({ error: "SMTP must be configured to use port 465." }, 500);
  }

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("full_name")
    .eq("id", user.id)
    .maybeSingle();
  if (profileError) {
    console.error("Could not load report author profile:", profileError.message);
    return jsonResponse({ error: "Could not load report author details." }, 500);
  }

  const subjectMatch = /^\[([^\]]+)\]\s*/.exec(complaint.subject);
  const category = subjectMatch?.[1] ?? "General Inquiry";
  const subject = subjectMatch
    ? complaint.subject.slice(subjectMatch[0].length)
    : complaint.subject;
  const reporterName = profile?.full_name?.trim() || "ParkLagbee User";
  const reporterEmail = user.email ?? "Not provided";

  const escape = escapeHtml;
  const html = `
    <div style="font-family: Arial, sans-serif; padding: 20px; background-color: #0F172A; color: #FFFFFF; border-radius: 10px;">
      <h2 style="color: #00F0FF; margin-top: 0;">New ParkLagbee Support Report</h2>
      <hr style="border-color: #00E676; margin-bottom: 20px;" />
      <p><strong>Reporter Name:</strong> ${escape(reporterName)}</p>
      <p><strong>Reporter Email:</strong> ${escape(reporterEmail)}</p>
      <p><strong>Issue Category:</strong> ${escape(category)}</p>
      <p><strong>Subject:</strong> ${escape(subject)}</p>
      <div style="background-color: #1E293B; padding: 15px; border-radius: 8px; margin-top: 15px;">
        <h4 style="color: #00F0FF; margin-top: 0;">Detailed Description:</h4>
        <p style="white-space: pre-wrap;">${escape(complaint.description)}</p>
      </div>
      ${
    complaint.booking_id
      ? `<p>Booking ID: ${escape(complaint.booking_id)}</p>`
      : ""
  }
      ${complaint.spot_id ? `<p>Spot ID: ${escape(complaint.spot_id)}</p>` : ""}
    </div>
  `;
  const text = [
    "New ParkLagbee Support Report",
    `Reporter Name: ${reporterName}`,
    `Reporter Email: ${reporterEmail}`,
    `Issue Category: ${category}`,
    `Subject: ${subject}`,
    "",
    complaint.description,
    complaint.booking_id ? `Booking ID: ${complaint.booking_id}` : "",
    complaint.spot_id ? `Spot ID: ${complaint.spot_id}` : "",
  ].filter(Boolean).join("\n");

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: true,
    auth: { user: smtpEmail, pass: smtpPassword },
    connectionTimeout: 15_000,
    greetingTimeout: 15_000,
    socketTimeout: 30_000,
  });

  try {
    await transporter.sendMail({
      from: { name: senderName, address: smtpEmail },
      to: adminEmail,
      replyTo: user.email,
      subject: `[ParkLagbee Report] ${category}: ${subject}`,
      text,
      html,
    });
  } catch (error) {
    console.error(
      "SMTP report notification failed:",
      error instanceof Error ? error.message : "Unknown SMTP error",
    );
    return jsonResponse({ error: "The support email could not be sent." }, 502);
  }

  return jsonResponse({ ok: true });
});
