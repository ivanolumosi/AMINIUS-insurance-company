import { Request, Response } from 'express';
import { PolicyService } from '../services/policy.service';

export class PolicyController {
    private service: PolicyService;

    constructor() {
        this.service = new PolicyService();
    }

    // Policy Catalog
    public async getPolicyCatalog(req: Request, res: Response) {
        try {
            const result = await this.service.getPolicyCatalog(req.body);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async createPolicyCatalogItem(req: Request, res: Response) {
        try {
            const id = await this.service.createPolicyCatalogItem(req.body);
            res.status(201).json({ policyCatalogId: id });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async updatePolicyCatalogItem(req: Request, res: Response) {
        try {
            const rows = await this.service.updatePolicyCatalogItem(req.body);
            res.json({ rowsAffected: rows });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async deletePolicyCatalogItem(req: Request, res: Response) {
        try {
            const rows = await this.service.deletePolicyCatalogItem(req.params.policyCatalogId, req.params.agentId);
            res.json({ rowsAffected: rows });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async upsertPolicyCatalog(req: Request, res: Response) {
        try {
            const id = await this.service.upsertPolicyCatalog(req.body);
            res.status(200).json({ policyCatalogId: id });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    // Client Policies
    public async getClientPolicies(req: Request, res: Response) {
        try {
            const result = await this.service.getClientPolicies(req.body);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async createClientPolicy(req: Request, res: Response) {
        try {
            const id = await this.service.createClientPolicy(req.body);
            res.status(201).json({ policyId: id });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async updateClientPolicy(req: Request, res: Response) {
        try {
            const rows = await this.service.updateClientPolicy(req.body);
            res.json({ rowsAffected: rows });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async upsertClientPolicy(req: Request, res: Response) {
        try {
            const id = await this.service.upsertClientPolicy(req.body);
            res.status(200).json({ policyId: id });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async getExpiringPolicies(req: Request, res: Response) {
        try {
            const result = await this.service.getExpiringPolicies(req.body);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async getPolicyStatistics(req: Request, res: Response) {
        try {
            const stats = await this.service.getPolicyStatistics(req.params.agentId);
            res.json(stats);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    // Templates
    public async getPolicyTemplates(req: Request, res: Response) {
        try {
            const result = await this.service.getPolicyTemplates(req.body);
            res.json(result);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async createPolicyTemplate(req: Request, res: Response) {
        try {
            const id = await this.service.createPolicyTemplate(req.body);
            res.status(201).json({ templateId: id });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async deletePolicyTemplate(req: Request, res: Response) {
        try {
            const rows = await this.service.deletePolicyTemplate(req.params.templateId, req.params.agentId);
            res.json({ rowsAffected: rows });
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    // Reference Data
    public async getInsuranceCompanies(req: Request, res: Response) {
        try {
            const companies = await this.service.getInsuranceCompanies();
            res.json(companies);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async getPolicyTypes(req: Request, res: Response) {
        try {
            const types = await this.service.getPolicyTypes();
            res.json(types);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }

    public async getPolicyCategories(req: Request, res: Response) {
        try {
            const categories = await this.service.getPolicyCategories();
            res.json(categories);
        } catch (error: any) {
            res.status(500).json({ error: error.message });
        }
    }
}
