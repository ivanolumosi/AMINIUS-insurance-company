import { Request, Response } from "express";
import { ClientWithPoliciesFilterRequest, PolicyService } from "../services/policy.service";
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
    PolicyValidationRequest,
    DeletePolicyCatalogRequest,
} from "../interfaces/policy";

const policyService = new PolicyService();

// Utility to merge body + query for filters
const getRequestData = (req: Request) => {
    return {
        ...req.query,
        ...req.body,
        ...req.params
    };
};

// ============================================
// HEALTH CHECK
// ============================================

export const healthCheck = async (req: Request, res: Response) => {
    try {
        // Simple health check using available method
        const result = await policyService.getPolicyCategories(true);
        res.status(200).json({
            success: true,
            message: "Policy service is healthy",
            timestamp: new Date().toISOString(),
            status: "OK"
        });
    } catch (error) {
        console.error("Policy service health check failed:", error);
        res.status(503).json({
            success: false,
            message: "Policy service is unhealthy",
            timestamp: new Date().toISOString(),
            status: "ERROR",
            error: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// POLICY CATALOG ENDPOINTS
// ============================================

export const getPolicyCatalog = async (req: Request, res: Response) => {
    try {
        const request: PolicyCatalogFilterRequest = getRequestData(req);
        const result = await policyService.getPolicyCatalog(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy catalog:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy catalog",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};
export const getClientsWithPolicies = async (req: Request, res: Response): Promise<void> => {
  try {
    const { agentId, clientId, includeInactive } = req.query;
             
    const request: ClientWithPoliciesFilterRequest = {
      agentId: agentId as string,
      clientId: clientId as string,
      includeInactive: includeInactive === 'true'
    };
             
    // Get the flattened data
    const data = await policyService.getClientsWithPolicies(request);
             
    // Return the flattened array directly
    res.status(200).json(data);
         
  } catch (error) {
    console.error('Error in getClientsWithPolicies controller:', error);
             
    const errorMessage = error instanceof Error ? error.message : 'Failed to get clients with policies';
    res.status(500).json({ 
      error: errorMessage,
      message: 'Internal server error'
    });
  }
};
export const createPolicyCatalogItem = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyCatalogRequest = req.body;
        const result = await policyService.createPolicyCatalogItem(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("Error creating policy catalog item:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to create policy catalog item",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const updatePolicyCatalogItem = async (req: Request, res: Response) => {
    try {
        const request: UpdatePolicyCatalogRequest = {
            policyCatalogId: req.params.id,
            ...req.body
        };
        const result = await policyService.updatePolicyCatalogItem(request);
        res.json(result);
    } catch (error) {
        console.error("Error updating policy catalog item:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to update policy catalog item",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const upsertPolicyCatalog = async (req: Request, res: Response) => {
    try {
        const request: UpsertPolicyCatalogRequest = req.body;
        const result = await policyService.upsertPolicyCatalog(request);
        res.json(result);
    } catch (error) {
        console.error("Error upserting policy catalog:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to upsert policy catalog", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const deletePolicyCatalogItem = async (req: Request, res: Response) => {
    try {
        const request: DeletePolicyCatalogRequest = {
            policyCatalogId: req.params.policyCatalogId,
            agentId: req.body.agentId || req.query.agentId as string
        };

        if (!request.agentId) {
            return res.status(400).json({ 
                success: false,
                error: "Agent ID is required for deletion" 
            });
        }
        
        const result = await policyService.deletePolicyCatalogItem(
            request.policyCatalogId, 
            request.agentId
        );
        res.json(result);
    } catch (error) {
        console.error("Error deleting policy catalog item:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to delete policy catalog item",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const softDeletePolicyCatalog = async (req: Request, res: Response) => {
    try {
        const { policyCatalogId } = req.params;
        const result = await policyService.softDeletePolicyCatalog(policyCatalogId);
        res.json(result);
    } catch (error) {
        console.error("Error soft deleting policy catalog:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to soft delete policy catalog",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// CLIENT POLICY ENDPOINTS
// ============================================

export const getClientPolicies = async (req: Request, res: Response) => {
    try {
        const request: ClientPolicyFilterRequest = getRequestData(req);
        const result = await policyService.getClientPoliciesSafe(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting client policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get client policies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPolicyById = async (req: Request, res: Response) => {
    try {
        const result = await policyService.getPolicyById(req.params.id);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy by ID:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const createClientPolicy = async (req: Request, res: Response) => {
    try {
        const request: CreateClientPolicyRequest = req.body;
        const result = await policyService.createClientPolicySafe(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("Error creating client policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to create client policy",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const updateClientPolicy = async (req: Request, res: Response) => {
    try {
        const request: UpdateClientPolicyRequest = {
            policyId: req.params.id,
            ...req.body
        };
        const result = await policyService.updateClientPolicySafe(request);
        res.json(result);
    } catch (error) {
        console.error("Error updating client policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to update client policy",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const upsertClientPolicy = async (req: Request, res: Response) => {
    try {
        const request: UpsertClientPolicyRequest = req.body;
        const result = await policyService.upsertClientPolicy(request);
        res.json(result);
    } catch (error) {
        console.error("Error upserting client policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to upsert client policy", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const deleteClientPolicy = async (req: Request, res: Response) => {
    try {
        const { policyId } = req.params;
        const hardDelete = req.query.hardDelete === 'true';
        const result = await policyService.deleteClientPolicy(policyId, hardDelete);
        res.json(result);
    } catch (error) {
        console.error("Error deleting client policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to delete client policy", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const softDeleteClientPolicy = async (req: Request, res: Response) => {
    try {
        const { policyId } = req.params;
        const result = await policyService.softDeleteClientPolicy(policyId);
        res.json(result);
    } catch (error) {
        console.error("Error soft deleting client policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to soft delete client policy",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// POLICY SEARCH AND FILTERING
// ============================================

export const searchPolicies = async (req: Request, res: Response) => {
    try {
        const request: SearchPoliciesRequest = getRequestData(req);
        const result = await policyService.searchPolicies(request);
        res.json(result);
    } catch (error) {
        console.error("Error searching policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to search policies", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPoliciesByStatus = async (req: Request, res: Response) => {
    try {
        const request: GetPoliciesByStatusRequest = getRequestData(req);
        const result = await policyService.getPoliciesByStatus(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting policies by status:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policies by status", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// POLICY EXPIRATION AND RENEWAL
// ============================================

export const getExpiringPolicies = async (req: Request, res: Response) => {
    try {
        const request: ExpiringPoliciesRequest = getRequestData(req);
        const result = await policyService.getExpiringPolicies(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting expiring policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get expiring policies", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const renewPolicy = async (req: Request, res: Response) => {
    try {
        const request: PolicyRenewalRequest = {
            policyId: req.params.id,
            ...req.body
        };
        const result = await policyService.renewPolicy(request);
        res.json(result);
    } catch (error) {
        console.error("Error renewing policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to renew policy", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPolicyRenewalCandidates = async (req: Request, res: Response) => {
    try {
        const request: GetRenewalCandidatesRequest = getRequestData(req);
        const result = await policyService.getPolicyRenewalCandidates(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy renewal candidates:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy renewal candidates",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// BULK OPERATIONS
// ============================================

export const bulkUpdatePolicyStatus = async (req: Request, res: Response) => {
    try {
        const request: BulkUpdatePolicyStatusRequest = req.body;
        const result = await policyService.bulkUpdatePolicyStatus(request);
        res.json(result);
    } catch (error) {
        console.error("Error bulk updating policy status:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to bulk update policy status", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const bulkCreatePolicies = async (req: Request, res: Response) => {
    try {
        const policies: CreateClientPolicyRequest[] = req.body.policies;
        
        const results = [];
        let successCount = 0;
        let errorCount = 0;
        const errors: string[] = [];

        for (const policy of policies) {
            try {
                const result = await policyService.createClientPolicySafe(policy);
                results.push(result);
                if (result.success) successCount++;
                else errorCount++;
            } catch (error) {
                errorCount++;
                errors.push(error instanceof Error ? error.message : 'Unknown error');
            }
        }
        
        res.status(201).json({ 
            success: errorCount === 0,
            data: {
                results,
                successCount,
                errorCount,
                errors: errors.length > 0 ? errors : undefined
            },
            message: `Bulk creation completed: ${successCount} successful, ${errorCount} failed`
        });
    } catch (error) {
        console.error("Error bulk creating policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to bulk create policies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const bulkUpdatePolicies = async (req: Request, res: Response) => {
    try {
        const updates: UpdateClientPolicyRequest[] = req.body.updates;
        
        const results = [];
        let successCount = 0;
        let errorCount = 0;
        const errors: string[] = [];

        for (const update of updates) {
            try {
                const result = await policyService.updateClientPolicySafe(update);
                results.push(result);
                if (result.success) successCount++;
                else errorCount++;
            } catch (error) {
                errorCount++;
                errors.push(error instanceof Error ? error.message : 'Unknown error');
            }
        }
        
        res.json({ 
            success: errorCount === 0,
            data: {
                results,
                successCount,
                errorCount,
                errors: errors.length > 0 ? errors : undefined
            },
            message: `Bulk update completed: ${successCount} successful, ${errorCount} failed`
        });
    } catch (error) {
        console.error("Error bulk updating policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to bulk update policies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const batchExpirePolicies = async (req: Request, res: Response) => {
    try {
        const request: BatchExpirePoliciesRequest = req.body;
        const result = await policyService.batchExpirePolicies(request);
        res.json(result);
    } catch (error) {
        console.error("Error batch expiring policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to batch expire policies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// POLICY TEMPLATES
// ============================================

export const getPolicyTemplates = async (req: Request, res: Response) => {
    try {
        const request: PolicyTemplateFilterRequest = getRequestData(req);
        const result = await policyService.getPolicyTemplates(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy templates:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy templates",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const createPolicyTemplate = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyTemplateRequest = req.body;
        const result = await policyService.createPolicyTemplate(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("Error creating policy template:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to create policy template",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const updatePolicyTemplate = async (req: Request, res: Response) => {
    try {
        const request: UpdatePolicyTemplateRequest = {
            templateId: req.params.id,
            ...req.body
        };
        const result = await policyService.updatePolicyTemplate(request);
        res.json(result);
    } catch (error) {
        console.error("Error updating policy template:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to update policy template",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const deletePolicyTemplate = async (req: Request, res: Response) => {
    try {
        const { templateId } = req.params;
        const hardDelete = req.query.hardDelete === 'true';
        const result = await policyService.deletePolicyTemplate(templateId, hardDelete);
        res.json(result);
    } catch (error) {
        console.error("Error deleting policy template:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to delete policy template",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const softDeletePolicyTemplate = async (req: Request, res: Response) => {
    try {
        const { templateId } = req.params;
        const result = await policyService.softDeletePolicyTemplate(templateId);
        res.json(result);
    } catch (error) {
        console.error("Error soft deleting policy template:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to soft delete policy template",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// REFERENCE DATA MANAGEMENT
// ============================================

export const getInsuranceCompanies = async (req: Request, res: Response) => {
    try {
        const isActive = req.query.isActive !== 'false';
        const result = await policyService.getInsuranceCompanies(isActive);
        res.json(result);
    } catch (error) {
        console.error("Error getting insurance companies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get insurance companies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const createInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const request: CreateInsuranceCompanyRequest = req.body;
        const result = await policyService.createInsuranceCompany(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("Error creating insurance company:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to create insurance company",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const updateInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const request: UpdateInsuranceCompanyRequest = {
            companyId: req.params.id,
            ...req.body
        };
        const result = await policyService.updateInsuranceCompany(request);
        res.json(result);
    } catch (error) {
        console.error("Error updating insurance company:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to update insurance company",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const deleteInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        const result = await policyService.softDeleteInsuranceCompany(companyId);
        res.json(result);
    } catch (error) {
        console.error("Error deleting insurance company:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to delete insurance company",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const softDeleteInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        const result = await policyService.softDeleteInsuranceCompany(companyId);
        res.json(result);
    } catch (error) {
        console.error("Error soft deleting insurance company:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to soft delete insurance company",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPolicyTypes = async (req: Request, res: Response) => {
    try {
        const isActive = req.query.isActive !== 'false';
        const result = await policyService.getPolicyTypes(isActive);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy types:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy types",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const createPolicyType = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyTypeRequest = req.body;
        const result = await policyService.createPolicyType(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("Error creating policy type:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to create policy type",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const updatePolicyType = async (req: Request, res: Response) => {
    try {
        const request: UpdatePolicyTypeRequest = {
            typeId: req.params.id,
            ...req.body
        };
        const result = await policyService.updatePolicyType(request);
        res.json(result);
    } catch (error) {
        console.error("Error updating policy type:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to update policy type",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const softDeletePolicyType = async (req: Request, res: Response) => {
    try {
        const { typeId } = req.params;
        const result = await policyService.softDeletePolicyType(typeId);
        res.json(result);
    } catch (error) {
        console.error("Error soft deleting policy type:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to soft delete policy type",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPolicyCategories = async (req: Request, res: Response) => {
    try {
        const isActive = req.query.isActive !== 'false';
        const result = await policyService.getPolicyCategories(isActive);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy categories:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy categories",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const createPolicyCategory = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyCategoryRequest = req.body;
        const result = await policyService.createPolicyCategory(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("Error creating policy category:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to create policy category",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const updatePolicyCategory = async (req: Request, res: Response) => {
    try {
        const request: UpdatePolicyCategoryRequest = {
            categoryId: req.params.id,
            ...req.body
        };
        const result = await policyService.updatePolicyCategory(request);
        res.json(result);
    } catch (error) {
        console.error("Error updating policy category:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to update policy category",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const softDeletePolicyCategory = async (req: Request, res: Response) => {
    try {
        const { categoryId } = req.params;
        const result = await policyService.softDeletePolicyCategory(categoryId);
        res.json(result);
    } catch (error) {
        console.error("Error soft deleting policy category:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to soft delete policy category",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// AUTOCOMPLETE ENDPOINTS - NOW IMPLEMENTED
// ============================================

export const autocompleteInsuranceCompanies = async (req: Request, res: Response) => {
    try {
        const searchTerm = req.query.q as string;
        const result = await policyService.searchInsuranceCompanies(searchTerm);
        res.json(result);
    } catch (error) {
        console.error("Error autocompleting insurance companies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to autocomplete insurance companies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const autocompletePolicyCatalog = async (req: Request, res: Response) => {
    try {
        const searchTerm = req.query.q as string;
        const agentId = req.query.agentId as string;
        const result = await policyService.searchPolicyCatalog(searchTerm, agentId);
        res.json(result);
    } catch (error) {
        console.error("Error autocompleting policy catalog:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to autocomplete policy catalog",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const autocompletePolicyCategories = async (req: Request, res: Response) => {
    try {
        const searchTerm = req.query.q as string;
        const result = await policyService.searchPolicyCategories(searchTerm);
        res.json(result);
    } catch (error) {
        console.error("Error autocompleting policy categories:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to autocomplete policy categories",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const autocompletePolicyTemplates = async (req: Request, res: Response) => {
    try {
        const searchTerm = req.query.q as string;
        const agentId = req.query.agentId as string;
        const result = await policyService.searchPolicyTemplates(searchTerm, agentId);
        res.json(result);
    } catch (error) {
        console.error("Error autocompleting policy templates:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to autocomplete policy templates",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const autocompletePolicyTypes = async (req: Request, res: Response) => {
    try {
        const searchTerm = req.query.q as string;
        const result = await policyService.searchPolicyTypes(searchTerm);
        res.json(result);
    } catch (error) {
        console.error("Error autocompleting policy types:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to autocomplete policy types",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const autocompleteClientPolicies = async (req: Request, res: Response) => {
    try {
        const searchTerm = req.query.q as string;
        const agentId = req.query.agentId as string;
        const clientId = req.query.clientId as string;
        const result = await policyService.searchClientPolicies(searchTerm, agentId, clientId);
        res.json(result);
    } catch (error) {
        console.error("Error autocompleting client policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to autocomplete client policies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// ANALYTICS AND REPORTING
// ============================================

export const getPolicyStatistics = async (req: Request, res: Response) => {
    try {
        const request: PolicyStatisticsRequest = getRequestData(req);
        const result = await policyService.getPolicyStatistics(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy statistics:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy statistics", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPolicyStatisticsDetailed = async (req: Request, res: Response) => {
    try {
        const request: PolicyStatisticsRequest = getRequestData(req);
        const result = await policyService.getPolicyStatisticsDetailed(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting detailed policy statistics:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get detailed policy statistics", 
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getAgentDashboardSummary = async (req: Request, res: Response) => {
    try {
        const agentId = req.params.agentId || req.query.agentId as string;
        if (!agentId) {
            return res.status(400).json({ 
                success: false,
                error: "Agent ID is required" 
            });
        }
        const result = await policyService.getAgentDashboardSummary(agentId);
        res.json(result);
    } catch (error) {
        console.error("Error getting agent dashboard summary:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get agent dashboard summary",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const getPolicyHistory = async (req: Request, res: Response) => {
    try {
        const request: GetPolicyHistoryRequest = {
            clientId: req.params.clientId || req.query.clientId as string,
            includeInactive: req.query.includeInactive === 'true'
        };
        if (!request.clientId) {
            return res.status(400).json({ 
                success: false,
                error: "Client ID is required" 
            });
        }
        const result = await policyService.getPolicyHistory(request);
        res.json(result);
    } catch (error) {
        console.error("Error getting policy history:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to get policy history",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// VALIDATION
// ============================================

export const validatePolicy = async (req: Request, res: Response) => {
    try {
        const request: PolicyValidationRequest = req.body;
        const result = await policyService.validatePolicy(request);
        res.json(result);
    } catch (error) {
        console.error("Error validating policy:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to validate policy",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

export const validatePolicyData = async (req: Request, res: Response) => {
    try {
        const { policyName, policyType, companyId, startDate, endDate } = req.body;
        const result = await policyService.validatePolicyData(
            policyName, 
            policyType, 
            companyId, 
            startDate ? new Date(startDate) : undefined, 
            endDate ? new Date(endDate) : undefined
        );
        res.json(result);
    } catch (error) {
        console.error("Error validating policy data:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to validate policy data",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// UTILITY OPERATIONS
// ============================================

export const cleanupSoftDeletedRecords = async (req: Request, res: Response) => {
    try {
        const request: CleanupSoftDeletedRequest = {
            daysOld: parseInt(req.body.daysOld) || 365,
            dryRun: req.body.dryRun !== false // Default to true for safety
        };
        const result = await policyService.cleanupSoftDeletedRecords(request);
        res.json(result);
    } catch (error) {
        console.error("Error cleaning up soft deleted records:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to cleanup soft deleted records",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// EXPORT OPERATIONS
// ============================================

export const exportPolicies = async (req: Request, res: Response) => {
    try {
        const agentId = req.query.agentId as string;
        const format = (req.query.format as 'json' | 'csv') || 'json';
        
        // Use getClientPolicies as fallback since exportPolicies doesn't exist in service
        const policiesResult = await policyService.getClientPolicies({ agentId });
        
        if (!policiesResult.success || !policiesResult.data) {
            return res.status(500).json({
                success: false,
                error: "Failed to retrieve policies for export"
            });
        }

        const policies = policiesResult.data;

        if (format === 'csv') {
            // Simple CSV conversion
            const csvHeader = 'policyId,clientId,policyName,status,startDate,endDate,companyName,typeName\n';
            const csvRows = policies.map(p => 
                `${p.policyId},${p.clientId},"${p.policyName}",${p.status},${p.startDate.toISOString()},${p.endDate.toISOString()},"${p.companyName || ''}","${p.typeName || ''}"`
            ).join('\n');
            
            res.setHeader('Content-Type', 'text/csv');
            res.setHeader('Content-Disposition', 'attachment; filename="policies.csv"');
            res.send(csvHeader + csvRows);
        } else {
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('Content-Disposition', 'attachment; filename="policies.json"');
            res.json({
                success: true,
                data: policies,
                message: 'Policies exported successfully'
            });
        }
    } catch (error) {
        console.error("Error exporting policies:", error);
        res.status(500).json({ 
            success: false,
            error: "Failed to export policies",
            message: error instanceof Error ? error.message : "Unknown error"
        });
    }
};