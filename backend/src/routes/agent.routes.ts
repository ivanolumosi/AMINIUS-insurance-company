import { Router } from "express";
import {
  upsertAgentProfile,
  getAgentProfile,
  updateAgentSettings,
  authenticateAgent,
  loginAgent,
  registerAgent,
  changeAgentPassword,
  requestPasswordReset,
  resetAgentPassword,
  getInsuranceCompanies,
  getPolicyTypes
} from "../controllers/agent.controller";

const router = Router();

// Agent profile
router.post("/agent", upsertAgentProfile);
router.get("/agent/:agentId", getAgentProfile);

// Settings
router.put("/agent/:agentId/settings", updateAgentSettings);

// Authentication
router.post("/agent/authenticate", authenticateAgent);
router.post("/agent/login", loginAgent);

// Registration
router.post("/agent/register", registerAgent);

// Password management
router.post("/agent/:agentId/change-password", changeAgentPassword);
router.post("/agent/password-reset/request", requestPasswordReset);
router.post("/agent/:agentId/password-reset", resetAgentPassword);

// Data lookups
router.get("/insurance-companies", getInsuranceCompanies);
router.get("/policy-types", getPolicyTypes);

export default router;
