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

    // Basic validation
    if (!firstName || !lastName || !email || !phone || !passwordHash) {
      return res.status(400).json({ 
        error: "Missing required fields",
        Message: "First name, last name, email, phone, and password are required" 
      });
    }

    // 🔄 Updated to pass object instead of individual parameters
    const result = await agentService.upsertAgent({
      agentId: agentId || null,
      firstName,
      lastName,
      email,
      phone,
      passwordHash,
      avatar
    });

    res.json(result); // Returns { agentId: string }
    
  } catch (err: any) {
    console.error("Error upserting agent:", err);
    
    // Return structured error response that matches your frontend expectations
    if (err.message === 'Email already exists') {
      return res.status(409).json({ 
        error: "Email already exists",
        Message: "An account with this email address already exists" 
      });
    }
    
    res.status(500).json({ 
      error: "Failed to upsert agent",
      Message: err.message || "An unexpected error occurred while updating the profile"
    });
  }
};

export const getAgentProfile = async (req: Request, res: Response) => {
  try {
    const agent = await agentService.getAgent(req.params.agentId);
    if (!agent) return res.status(404).json({ error: "Agent not found" });
    res.json(agent);
  } catch (err: any) {
    console.error("❌ Error getting agent profile:", err);
    res.status(500).json({ 
      error: "Failed to get agent",
      Message: err.message || "Failed to retrieve agent profile"
    });
  }
};

export const updateAgentSettings = async (req: Request, res: Response) => {
  try {
    const result = await agentService.updateAgentSettings(req.params.agentId, req.body);
    res.json(result); // Returns { message: string }
  } catch (err: any) {
    console.error("❌ Error updating agent settings:", err);
    res.status(500).json({ 
      error: "Failed to update settings",
      Message: err.message || "Failed to update agent settings"
    });
  }
};

export const authenticateAgent = async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    const agent = await agentService.authenticateAgent(email);
    if (!agent) return res.status(404).json({ error: "Agent not found" });
    res.json(agent);
  } catch (err: any) {
    console.error("❌ Error authenticating agent:", err);
    res.status(500).json({ 
      error: "Failed to authenticate",
      Message: err.message || "Authentication failed"
    });
  }
};

export const loginAgent = async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    
    // 🔄 Updated to pass object instead of individual parameters
    const result = await agentService.loginAgent({ email, password });
    res.json(result);
  } catch (err: any) {
    console.error("❌ Error logging in:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Login failed due to server error"
    });
  }
};

export const registerAgent = async (req: Request, res: Response) => {
  try {
    // Basic validation
    const { FirstName, LastName, Email, Phone, PasswordHash } = req.body;
    
    if (!FirstName || !LastName || !Email || !Phone || !PasswordHash) {
      return res.status(400).json({
        Success: false,
        Message: "Missing required fields: FirstName, LastName, Email, Phone, and PasswordHash are required",
        AgentId: undefined
      });
    }

    const result = await agentService.registerAgent(req.body);
    
    if (result.Success) {
      res.status(201).json(result); // 201 Created for successful registration
    } else {
      // Return 409 for conflicts (like email exists), 400 for other failures
      const statusCode = result.Message.includes('already exists') ? 409 : 400;
      res.status(statusCode).json(result);
    }
    
  } catch (err: any) {
    console.error("Error registering agent:", err);
    
    res.status(500).json({
      Success: false,
      Message: err.message || "Registration failed due to server error",
      AgentId: undefined
    });
  }
};

export const changeAgentPassword = async (req: Request, res: Response) => {
  try {
    const { oldPasswordHash, newPasswordHash } = req.body;
    
    // 🔄 Updated to pass object instead of individual parameters
    const result = await agentService.changePassword(
      req.params.agentId,
      { oldPasswordHash, newPasswordHash }
    );
    res.json(result);
  } catch (err: any) {
    console.error("❌ Error changing password:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to change password"
    });
  }
};

export const requestPasswordReset = async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    
    // 🔄 Updated to pass object instead of just email string
    const result = await agentService.requestPasswordReset({ email });
    res.json(result);
  } catch (err: any) {
    console.error("❌ Error requesting password reset:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to request password reset"
    });
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
  } catch (err: any) {
    console.error("❌ Error resetting password:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to reset password"
    });
  }
};

export const sendTemporaryPassword = async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    const result = await agentService.sendTemporaryPassword(email);
    res.json(result);
  } catch (err: any) {
    console.error("❌ Error sending temporary password:", err);
    res.status(500).json({ 
      Success: false,
      Message: err.message || "Failed to send temporary password"
    });
  }
};

export const getInsuranceCompanies = async (_req: Request, res: Response) => {
  try {
    const companies = await agentService.getInsuranceCompanies();
    res.json(companies);
  } catch (err: any) {
    console.error("❌ Error getting insurance companies:", err);
    res.status(500).json({ 
      error: "Failed to get insurance companies",
      Message: err.message || "Failed to retrieve insurance companies"
    });
  }
};

export const getPolicyTypes = async (_req: Request, res: Response) => {
  try {
    const types = await agentService.getPolicyTypes();
    res.json(types);
  } catch (err: any) {
    console.error("❌ Error getting policy types:", err);
    res.status(500).json({ 
      error: "Failed to get policy types",
      Message: err.message || "Failed to retrieve policy types"
    });
  }
};

export const getNavbarBadgeCounts = async (req: Request, res: Response) => {
  try {
    const { agentId } = req.params;
    const counts = await agentService.getNavbarBadgeCounts(agentId);
    res.json(counts);
  } catch (err: any) {
    console.error("❌ Error getting navbar badge counts:", err);
    res.status(500).json({ 
      error: "Failed to get navbar badge counts",
      Message: err.message || "Failed to retrieve badge counts"
    });
  }
};