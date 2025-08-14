import { Request, Response } from "express";
import { AgentService } from "../services/agent.service";

const agentService = new AgentService();

export const upsertAgentProfile = async (req: Request, res: Response) => {
  try {
    const {
      agentId,
      firstName,
      lastName,
      email,
      phone,
      passwordHash,
      avatar
    } = req.body;
    const newAgentId = await agentService.upsertAgent(
      agentId || null,
      firstName,
      lastName,
      email,
      phone,
      passwordHash,
      avatar
    );
    res.json({ agentId: newAgentId });
  } catch (err) {
    res.status(500).json({ error: "Failed to upsert agent" });
  }
};

export const getAgentProfile = async (req: Request, res: Response) => {
  try {
    const agent = await agentService.getAgent(req.params.agentId);
    if (!agent) return res.status(404).json({ error: "Agent not found" });
    res.json(agent);
  } catch (err) {
    res.status(500).json({ error: "Failed to get agent" });
  }
};

export const updateAgentSettings = async (req: Request, res: Response) => {
  try {
    await agentService.updateAgentSettings(req.params.agentId, req.body);
    res.json({ message: "Settings updated successfully" });
  } catch (err) {
    res.status(500).json({ error: "Failed to update settings" });
  }
};

export const authenticateAgent = async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    const agent = await agentService.authenticateAgent(email);
    if (!agent) return res.status(404).json({ error: "Agent not found" });
    res.json(agent);
  } catch (err) {
    res.status(500).json({ error: "Failed to authenticate" });
  }
};

export const loginAgent = async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    const result = await agentService.loginAgent(email, password);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Login failed" });
  }
};

export const registerAgent = async (req: Request, res: Response) => {
  try {
    const result = await agentService.registerAgent(req.body);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Registration failed" });
  }
};

export const changeAgentPassword = async (req: Request, res: Response) => {
  try {
    const { oldPasswordHash, newPasswordHash } = req.body;
    const result = await agentService.changePassword(
      req.params.agentId,
      oldPasswordHash,
      newPasswordHash
    );
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Failed to change password" });
  }
};

export const requestPasswordReset = async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    const result = await agentService.requestPasswordReset(email);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Failed to request password reset" });
  }
};

export const resetAgentPassword = async (req: Request, res: Response) => {
  try {
    const { newPasswordHash } = req.body;
    const result = await agentService.resetPassword(
      req.params.agentId,
      newPasswordHash
    );
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Failed to reset password" });
  }
};

export const getInsuranceCompanies = async (_req: Request, res: Response) => {
  try {
    const companies = await agentService.getInsuranceCompanies();
    res.json(companies);
  } catch (err) {
    res.status(500).json({ error: "Failed to get insurance companies" });
  }
};

export const getPolicyTypes = async (_req: Request, res: Response) => {
  try {
    const types = await agentService.getPolicyTypes();
    res.json(types);
  } catch (err) {
    res.status(500).json({ error: "Failed to get policy types" });
  }
};
export const getNavbarBadgeCounts = async (req: Request, res: Response) => {
  try {
    const { agentId } = req.params;
    const counts = await agentService.getNavbarBadgeCounts(agentId);
    res.json(counts);
  } catch (err) {
    console.error("Error getting navbar badge counts:", err);
    res.status(500).json({ error: "Failed to get navbar badge counts" });
  }
};
