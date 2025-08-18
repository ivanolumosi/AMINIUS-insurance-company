import { Request, Response } from 'express';
import { ClientWithPoliciesFilterRequest, PolicyService } from '../services/policy.service';
import {
    PolicyCatalogFilterRequest,
    ClientPolicyFilterRequest,
    CreateClientPolicyRequest,
    UpdateClientPolicyRequest,
    SearchPoliciesRequest,
    GetPoliciesByStatusRequest,
    PolicyStatisticsRequest,
    ExpiringPoliciesRequest,
    PolicyRenewalRequest,
    BulkUpdatePolicyStatusRequest,
    CreatePolicyCatalogRequest,
    UpdatePolicyCatalogRequest,
    UpsertPolicyCatalogRequest,
    UpsertClientPolicyRequest,
    CreatePolicyTemplateRequest,
    UpdatePolicyTemplateRequest,
    PolicyTemplateFilterRequest,
    CreateInsuranceCompanyRequest,
    UpdateInsuranceCompanyRequest,
    CreatePolicyTypeRequest,
    UpdatePolicyTypeRequest,
    CreatePolicyCategoryRequest,
    UpdatePolicyCategoryRequest,
    GetPolicyHistoryRequest,
    GetRenewalCandidatesRequest,
    BatchExpirePoliciesRequest,
    CleanupSoftDeletedRequest,
    PolicyValidationRequest
} from '../interfaces/policy';


export class PolicyController {
    private service: PolicyService;

    constructor() {
        this.service = new PolicyService();
    }

    // Utility to merge body + query for filters
    private getRequestData(req: Request) {
        return {
            ...req.query,
            ...req.body,
            ...req.params
        };
    }

   
// Consistent response handler
    private handleResponse(res: Response, result: any, successStatus: number = 200) {
        if (result?.success === false) {
            return res.status(400).json({
                success: false,
                message: result.message,
                data: null
            });
        }
        const data = result?.data !== undefined ? result.data : result;
        const message = result?.message || 'Operation completed successfully';
        return res.status(successStatus).json({
            success: true,
            message,
            data
        });
    }

    // Consistent error handler to avoid "err is unknown"
    private handleError(res: Response, err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: message
        });
    }

    // ============================================
    // POLICY CATALOG ENDPOINTS
    // ============================================

    public async getPolicyCatalog(req: Request, res: Response) {
        try {
            const request: PolicyCatalogFilterRequest = this.getRequestData(req);
            const result = await this.service.getPolicyCatalogSafe(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }
    public async getClientsWithPolicies(req: Request, res: Response): Promise<void> {
    try {
      const request: ClientWithPoliciesFilterRequest = {
        agentId: req.query.agentId as string | undefined,
        clientId: req.query.clientId as string | undefined,
        includeInactive: req.query.includeInactive === 'true',
      };

      const result = await this.service.getClientsWithPolicies(request);
      res.json(result);
    } catch (error) {
      console.error('Error in getClientsWithPolicies:', error);
      res.status(500).json({ message: 'Failed to fetch clients with policies', error });
    }
  }
    public async createPolicyCatalogItem(req: Request, res: Response) {
        try {
            const request: CreatePolicyCatalogRequest = req.body;
            const result = await this.service.createPolicyCatalogItem(request);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async updatePolicyCatalogItem(req: Request, res: Response) {
        try {
            const request: UpdatePolicyCatalogRequest = {
                policyCatalogId: req.params.id,
                ...req.body
            };
            const result = await this.service.updatePolicyCatalogItem(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // public async deletePolicyCatalogItem(req: Request, res: Response) {
    //     try {
    //         const hardDelete = req.query.hardDelete === 'true';
    //         const result = await this.service.deletePolicyCatalogItem(req.params.id, hardDelete);
    //         return this.handleResponse(res, result);
    //     } catch (error) {
    //         return res.status(500).json({
    //             success: false,
    //             message: 'Internal server error',
    //             error: error instanceof Error ? error.message : 'Unknown error'
    //         });
    //     }
    // }

    public async upsertPolicyCatalog(req: Request, res: Response) {
        try {
            const request: UpsertPolicyCatalogRequest = req.body;
            const result = await this.service.upsertPolicyCatalog(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // CLIENT POLICY ENDPOINTS
    // ============================================

    public async getClientPolicies(req: Request, res: Response) {
        try {
            const request: ClientPolicyFilterRequest = this.getRequestData(req);
            const result = await this.service.getClientPoliciesSafe(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPolicyById(req: Request, res: Response) {
        try {
            const result = await this.service.getPolicyById(req.params.id);
            if (!result) {
                return res.status(404).json({
                    success: false,
                    message: 'Policy not found',
                    data: null
                });
            }
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async createClientPolicy(req: Request, res: Response) {
        try {
            const request: CreateClientPolicyRequest = req.body;
            const result = await this.service.createClientPolicySafe(request);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async updateClientPolicy(req: Request, res: Response) {
        try {
            const request: UpdateClientPolicyRequest = {
                policyId: req.params.id,
                ...req.body
            };
            const result = await this.service.updateClientPolicySafe(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // public async deleteClientPolicy(req: Request, res: Response) {
    //     try {
    //         const hardDelete = req.query.hardDelete === 'true';
    //         const result = await this.service.deleteClientPolicy(req.params.id, hardDelete);
    //         return this.handleResponse(res, result);
    //     } catch (error) {
    //         return res.status(500).json({
    //             success: false,
    //             message: 'Internal server error',
    //             error: error instanceof Error ? error.message : 'Unknown error'
    //         });
    //     }
    // }

    public async upsertClientPolicy(req: Request, res: Response) {
        try {
            const request: UpsertClientPolicyRequest = req.body;
            const result = await this.service.upsertClientPolicy(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // POLICY SEARCH AND FILTERING
    // ============================================

    public async searchPolicies(req: Request, res: Response) {
        try {
            const request: SearchPoliciesRequest = this.getRequestData(req);
            const result = await this.service.searchPolicies(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPoliciesByStatus(req: Request, res: Response) {
        try {
            const request: GetPoliciesByStatusRequest = this.getRequestData(req);
            const result = await this.service.getPoliciesByStatus(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // POLICY EXPIRATION AND RENEWAL
    // ============================================

    public async getExpiringPolicies(req: Request, res: Response) {
        try {
            const request: ExpiringPoliciesRequest = this.getRequestData(req);
            const result = await this.service.getExpiringPolicies(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async renewPolicy(req: Request, res: Response) {
        try {
            const request: PolicyRenewalRequest = {
                policyId: req.params.id,
                ...req.body
            };
            const result = await this.service.renewPolicy(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPolicyRenewalCandidates(req: Request, res: Response) {
        try {
            const request: GetRenewalCandidatesRequest = this.getRequestData(req);
            const result = await this.service.getPolicyRenewalCandidates(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // BULK OPERATIONS
    // ============================================

    public async bulkUpdatePolicyStatus(req: Request, res: Response) {
        try {
            const request: BulkUpdatePolicyStatusRequest = req.body;
            const result = await this.service.bulkUpdatePolicyStatus(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async bulkCreatePolicies(req: Request, res: Response) {
        try {
            const policies: CreateClientPolicyRequest[] = req.body.policies;
            const result = await this.service.bulkCreatePolicies(policies);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async bulkUpdatePolicies(req: Request, res: Response) {
        try {
            const updates: UpdateClientPolicyRequest[] = req.body.updates;
            const result = await this.service.bulkUpdatePolicies(updates);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async batchExpirePolicies(req: Request, res: Response) {
        try {
            const request: BatchExpirePoliciesRequest = req.body;
            const result = await this.service.batchExpirePolicies(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // POLICY TEMPLATES
    // ============================================

    public async getPolicyTemplates(req: Request, res: Response) {
        try {
            const request: PolicyTemplateFilterRequest = this.getRequestData(req);
            const result = await this.service.getPolicyTemplates(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async createPolicyTemplate(req: Request, res: Response) {
        try {
            const request: CreatePolicyTemplateRequest = req.body;
            const result = await this.service.createPolicyTemplate(request);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async updatePolicyTemplate(req: Request, res: Response) {
        try {
            const request: UpdatePolicyTemplateRequest = {
                templateId: req.params.id,
                ...req.body
            };
            const result = await this.service.updatePolicyTemplate(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // public async deletePolicyTemplate(req: Request, res: Response) {
    //     try {
    //         const hardDelete = req.query.hardDelete === 'true';
    //         const result = await this.service.deletePolicyTemplate(req.params.id, hardDelete);
    //         return this.handleResponse(res, result);
    //     } catch (error) {
    //         return res.status(500).json({
    //             success: false,
    //             message: 'Internal server error',
    //             error: error instanceof Error ? error.message : 'Unknown error'
    //         });
    //     }
    // }

    // ============================================
    // REFERENCE DATA MANAGEMENT
    // ============================================

    public async getInsuranceCompanies(req: Request, res: Response) {
        try {
            const isActive = req.query.isActive !== 'false';
            const result = await this.service.getInsuranceCompanies(isActive);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async createInsuranceCompany(req: Request, res: Response) {
        try {
            const request: CreateInsuranceCompanyRequest = req.body;
            const result = await this.service.createInsuranceCompany(request);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async updateInsuranceCompany(req: Request, res: Response) {
        try {
            const request: UpdateInsuranceCompanyRequest = {
                companyId: req.params.id,
                ...req.body
            };
            const result = await this.service.updateInsuranceCompany(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPolicyTypes(req: Request, res: Response) {
        try {
            const isActive = req.query.isActive !== 'false';
            const result = await this.service.getPolicyTypes(isActive);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async createPolicyType(req: Request, res: Response) {
        try {
            const request: CreatePolicyTypeRequest = req.body;
            const result = await this.service.createPolicyType(request);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async updatePolicyType(req: Request, res: Response) {
        try {
            const request: UpdatePolicyTypeRequest = {
                typeId: req.params.id,
                ...req.body
            };
            const result = await this.service.updatePolicyType(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPolicyCategories(req: Request, res: Response) {
        try {
            const isActive = req.query.isActive !== 'false';
            const result = await this.service.getPolicyCategories(isActive);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async createPolicyCategory(req: Request, res: Response) {
        try {
            const request: CreatePolicyCategoryRequest = req.body;
            const result = await this.service.createPolicyCategory(request);
            return this.handleResponse(res, result, 201);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async updatePolicyCategory(req: Request, res: Response) {
        try {
            const request: UpdatePolicyCategoryRequest = {
                categoryId: req.params.id,
                ...req.body
            };
            const result = await this.service.updatePolicyCategory(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // ANALYTICS AND REPORTING
    // ============================================

    public async getPolicyStatistics(req: Request, res: Response) {
        try {
            const request: PolicyStatisticsRequest = this.getRequestData(req);
            const result = await this.service.getPolicyStatistics(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPolicyStatisticsDetailed(req: Request, res: Response) {
        try {
            const request: PolicyStatisticsRequest = this.getRequestData(req);
            const result = await this.service.getPolicyStatisticsDetailed(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getAgentDashboardSummary(req: Request, res: Response) {
        try {
            const agentId = req.params.agentId || req.query.agentId as string;
            if (!agentId) {
                return res.status(400).json({
                    success: false,
                    message: 'Agent ID is required',
                    data: null
                });
            }
            const result = await this.service.getAgentDashboardSummary(agentId);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    public async getPolicyHistory(req: Request, res: Response) {
        try {
            const request: GetPolicyHistoryRequest = {
                clientId: req.params.clientId || req.query.clientId as string,
                includeInactive: req.query.includeInactive === 'true'
            };
            if (!request.clientId) {
                return res.status(400).json({
                    success: false,
                    message: 'Client ID is required',
                    data: null
                });
            }
            const result = await this.service.getPolicyHistory(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // VALIDATION
    // ============================================

    public async validatePolicy(req: Request, res: Response) {
        try {
            const request: PolicyValidationRequest = req.body;
            const result = await this.service.validatePolicy(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // UTILITY OPERATIONS
    // ============================================

    public async cleanupSoftDeletedRecords(req: Request, res: Response) {
        try {
            const request: CleanupSoftDeletedRequest = {
                daysOld: parseInt(req.body.daysOld) || 365,
                dryRun: req.body.dryRun !== false // Default to true for safety
            };
            const result = await this.service.cleanupSoftDeletedRecords(request);
            return this.handleResponse(res, result);
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // EXPORT OPERATIONS
    // ============================================

    public async exportPolicies(req: Request, res: Response) {
        try {
            const agentId = req.query.agentId as string;
            const format = (req.query.format as 'json' | 'csv') || 'json';
            
            const result = await this.service.exportPolicies(agentId, format);

            if (format === 'csv') {
                res.setHeader('Content-Type', 'text/csv');
                res.setHeader('Content-Disposition', 'attachment; filename="policies.csv"');
                return res.send(result);
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setHeader('Content-Disposition', 'attachment; filename="policies.json"');
                return res.json(result);
            }
        } catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Internal server error',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }

    // ============================================
    // HEALTH CHECK
    // ============================================

    public async healthCheck(req: Request, res: Response) {
        try {
            // Simple health check - you could add more comprehensive checks here
            const result = await this.service.getPolicyCategories(true);
            return res.status(200).json({
                success: true,
                message: 'Policy service is healthy',
                timestamp: new Date().toISOString(),
                status: 'OK'
            });
        } catch (error) {
            return res.status(503).json({
                success: false,
                message: 'Policy service is unhealthy',
                timestamp: new Date().toISOString(),
                status: 'ERROR',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    }
    
   

    public async deleteInsuranceCompany(req: Request, res: Response) {
        try {
            const { companyId } = req.params;
            const hardDelete = req.query.hardDelete === 'true';
            const result = await this.service.deleteInsuranceCompany(companyId, { hardDelete });
            return this.handleResponse(res, result);
        } catch (err) {
            return this.handleError(res, err);
        }
    }

    public async softDeletePolicyTemplate(req: Request, res: Response) {
        try {
            const { templateId } = req.params;
            await this.service.softDeletePolicyTemplate(templateId);
            return this.handleResponse(res, { message: 'Template soft deleted successfully' });
        } catch (err) {
            return this.handleError(res, err);
        }
    }

    public async softDeletePolicyCatalog(req: Request, res: Response) {
        try {
            const { policyCatalogId } = req.params;
            await this.service.softDeletePolicyCatalog(policyCatalogId);
            return this.handleResponse(res, { message: 'Policy catalog soft deleted successfully' });
        } catch (err) {
            return this.handleError(res, err);
        }
    }

    public async softDeletePolicyCategory(req: Request, res: Response) {
        try {
            const { categoryId } = req.params;
            await this.service.softDeletePolicyCategory(categoryId);
            return this.handleResponse(res, { message: 'Policy category soft deleted successfully' });
        } catch (err) {
            return this.handleError(res, err);
        }
    }

    public async softDeleteInsuranceCompany(req: Request, res: Response) {
        try {
            const { companyId } = req.params;
            await this.service.softDeleteInsuranceCompany(companyId);
            return this.handleResponse(res, { message: 'Insurance company soft deleted successfully' });
        } catch (err) {
            return this.handleError(res, err);
        }
    }

    public async softDeleteClientPolicy(req: Request, res: Response) {
        try {
            const { policyId } = req.params;
            await this.service.softDeleteClientPolicy(policyId);
            return this.handleResponse(res, { message: 'Client policy soft deleted successfully' });
        } catch (err) {
            return this.handleError(res, err);
        }
    }
     async softDeletePolicyType(req: Request, res: Response) {
       try {
           const result = await PolicyService.softDeletePolicyType(req.params.typeId);
           res.json(result);
       } catch (error: any) {
           res.status(500).json({ error: error.message });
       }
   }

    
// ============================================
// AUTOCOMPLETE METHODS
// ============================================
public async autocompleteInsuranceCompanies(req: Request, res: Response) {
    try {
        const { term = '' } = req.query;
        const result = await this.service.searchInsuranceCompanies(String(term));
        return this.handleResponse(res, result);
    } catch (error) {
        return this.handleError(res, error);
    }
}

public async autocompletePolicyCatalog(req: Request, res: Response) {
    try {
        const { agentId, term = '' } = req.query;
        const result = await this.service.searchPolicyCatalog(String(agentId), String(term));
        return this.handleResponse(res, result);
    } catch (error) {
        return this.handleError(res, error);
    }
}

public async autocompletePolicyCategories(req: Request, res: Response) {
    try {
        const { term = '' } = req.query;
        const result = await this.service.searchPolicyCategories(String(term));
        return this.handleResponse(res, result);
    } catch (error) {
        return this.handleError(res, error);
    }
}

public async autocompletePolicyTemplates(req: Request, res: Response) {
    try {
        const { agentId, term = '' } = req.query;
        const result = await this.service.searchPolicyTemplates(String(agentId), String(term));
        return this.handleResponse(res, result);
    } catch (error) {
        return this.handleError(res, error);
    }
}

public async autocompletePolicyTypes(req: Request, res: Response) {
    try {
        const { term = '' } = req.query;
        const result = await this.service.searchPolicyTypes(String(term));
        return this.handleResponse(res, result);
    } catch (error) {
        return this.handleError(res, error);
    }
}

public async autocompleteClientPolicies(req: Request, res: Response) {
    try {
        const { clientId, term = '' } = req.query;
        const result = await this.service.searchClientPolicies(String(clientId), String(term));
        return this.handleResponse(res, result);
    } catch (error) {
        return this.handleError(res, error);
    }
}
}