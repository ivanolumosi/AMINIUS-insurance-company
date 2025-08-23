import cron from "node-cron";
import emailService from "./../nodemailer/emailservice";  // your EmailService file
import { poolPromise } from "../../db";    
import * as sql from "mssql";

// ========================
// Utility Functions
// ========================

// Fetch all active agents
async function getAllActiveAgents() {
  const pool = await poolPromise;
  const result = await pool.request()
    .query(`SELECT AgentId, Email, FirstName, LastName FROM Agent WHERE IsActive = 1`);
  return result.recordset;
}

// Fetch today's appointments for an agent
async function getTodayAppointments(agentId: string) {
  const pool = await poolPromise;
  const result = await pool.request()
    .input("AgentId", sql.UniqueIdentifier, agentId)
    .execute("sp_GetTodayAppointments");

  return result.recordset;
}

// Combine appointment date + time and convert to Nairobi time
function formatAppointmentTime(appointmentDateStr: string, startTimeStr: string) {
  if (!appointmentDateStr || !startTimeStr) return "Invalid Date";

  const appointmentDate = new Date(appointmentDateStr);
  const startTime = new Date(startTimeStr); // from DB, usually 1970-01-01Txx:xx:xxZ

  // Merge date + UTC time
  const combined = new Date(
    appointmentDate.getFullYear(),
    appointmentDate.getMonth(),
    appointmentDate.getDate(),
    startTime.getUTCHours(),
    startTime.getUTCMinutes(),
    startTime.getUTCSeconds()
  );

  return combined.toLocaleTimeString("en-KE", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "Africa/Nairobi",
  });
}

// Send email to a single agent with their appointments
async function sendAgentAppointments(agent: any) {
  const appointments = await getTodayAppointments(agent.AgentId);

  if (!appointments || appointments.length === 0) {
    console.log(`📭 No appointments for ${agent.Email} today.`);
    return;
  }

  const appointmentList = appointments.map((a: any) => {
    const clientName = a.ClientName || a.clientName || "Unknown Client";
    const appointmentTime = formatAppointmentTime(a.AppointmentDate, a.StartTime);
    return `<li>${clientName} at ${appointmentTime}</li>`;
  }).join("");

  const htmlContent = `
    <h3>Today's Appointments</h3>
    <ul>${appointmentList}</ul>
  `;

  try {
    await emailService.sendMail(
      agent.Email,
      "Your Appointments for Today",
      "Please see your appointments below.",
      htmlContent
    );
    console.log(`✅ Appointment email sent to ${agent.Email}`);
  } catch (error) {
    console.error(`❌ Failed to send email to ${agent.Email}:`, error);
  }
}

// ========================
// Cron Jobs
// ========================

// 12:05 AM Nairobi time
cron.schedule(
  "5 0 * * *",
  async () => {
    console.log("⏰ Running 12:05 AM appointment email job...");
    const agents = await getAllActiveAgents();
    for (const agent of agents) {
      await sendAgentAppointments(agent);
    }
  },
  { timezone: "Africa/Nairobi" }
);

// 8:00 AM Nairobi time
cron.schedule(
  "0 8 * * *",
  async () => {
    console.log("⏰ Running 8:00 AM appointment email job...");
    const agents = await getAllActiveAgents();
    for (const agent of agents) {
      await sendAgentAppointments(agent);
    }
  },
  { timezone: "Africa/Nairobi" }
);

// ========================
// Optional: Test Cron (every minute)
// ========================
// cron.schedule("* * * * *", async () => {
// //   console.log("🔔 Running test cron...");
// //   const agents = await getAllActiveAgents();
// //   for (const agent of agents) {
// //     await sendAgentAppointments(agent);
// //   }
// // });

