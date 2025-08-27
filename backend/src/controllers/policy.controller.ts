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
// POLICY CATALOG ENDPOINTS
// ============================================

export const getPolicyCatalog = async (req: Request, res: Response) => {
    try {
        const request: PolicyCatalogFilterRequest = getRequestData(req);
        const result = await policyService.getPolicyCatalogSafe(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policy catalog:", error);
        res.status(500).json({ error: "Failed to get policy catalog" });
    }
};

export const getClientsWithPolicies = async (req: Request, res: Response) => {
    try {
        const request: ClientWithPoliciesFilterRequest = {
            agentId: req.query.agentId as string | undefined,
            clientId: req.query.clientId as string | undefined,
            includeInactive: req.query.includeInactive === 'true',
        };

        const result = await policyService.getClientsWithPolicies(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting clients with policies:", error);
        res.status(500).json({ error: "Failed to fetch clients with policies" });
    }
};

export const createPolicyCatalogItem = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyCatalogRequest = req.body;
        const result = await policyService.createPolicyCatalogItem(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error creating policy catalog item:", error);
        res.status(500).json({ error: "Failed to create policy catalog item" });
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
        console.error("❌ Error updating policy catalog item:", error);
        res.status(500).json({ error: "Failed to update policy catalog item" });
    }
};

export const upsertPolicyCatalog = async (req: Request, res: Response) => {
    try {
        const request: UpsertPolicyCatalogRequest = req.body;
        const result = await policyService.upsertPolicyCatalog(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error upserting policy catalog:", error);
        res.status(500).json({ error: "Failed to upsert policy catalog" });
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
        console.error("❌ Error getting client policies:", error);
        res.status(500).json({ error: "Failed to get client policies" });
    }
};

export const getPolicyById = async (req: Request, res: Response) => {
    try {
        const result = await policyService.getPolicyById(req.params.id);
        if (!result) {
            return res.status(404).json({ error: "Policy not found" });
        }
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policy by ID:", error);
        res.status(500).json({ error: "Failed to get policy" });
    }
};

export const createClientPolicy = async (req: Request, res: Response) => {
    try {
        const request: CreateClientPolicyRequest = req.body;
        const result = await policyService.createClientPolicySafe(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error creating client policy:", error);
        res.status(500).json({ error: "Failed to create client policy" });
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
        console.error("❌ Error updating client policy:", error);
        res.status(500).json({ error: "Failed to update client policy" });
    }
};

export const upsertClientPolicy = async (req: Request, res: Response) => {
    try {
        const request: UpsertClientPolicyRequest = req.body;
        const result = await policyService.upsertClientPolicy(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error upserting client policy:", error);
        res.status(500).json({ error: "Failed to upsert client policy" });
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
        console.error("❌ Error searching policies:", error);
        res.status(500).json({ error: "Failed to search policies" });
    }
};

export const getPoliciesByStatus = async (req: Request, res: Response) => {
    try {
        const request: GetPoliciesByStatusRequest = getRequestData(req);
        const result = await policyService.getPoliciesByStatus(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policies by status:", error);
        res.status(500).json({ error: "Failed to get policies by status" });
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
        console.error("❌ Error getting expiring policies:", error);
        res.status(500).json({ error: "Failed to get expiring policies" });
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
        console.error("❌ Error renewing policy:", error);
        res.status(500).json({ error: "Failed to renew policy" });
    }
};

export const getPolicyRenewalCandidates = async (req: Request, res: Response) => {
    try {
        const request: GetRenewalCandidatesRequest = getRequestData(req);
        const result = await policyService.getPolicyRenewalCandidates(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policy renewal candidates:", error);
        res.status(500).json({ error: "Failed to get policy renewal candidates" });
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
        console.error("❌ Error bulk updating policy status:", error);
        res.status(500).json({ error: "Failed to bulk update policy status" });
    }
};

export const bulkCreatePolicies = async (req: Request, res: Response) => {
    try {
        const policies: CreateClientPolicyRequest[] = req.body.policies;
        const result = await policyService.bulkCreatePolicies(policies);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error bulk creating policies:", error);
        res.status(500).json({ error: "Failed to bulk create policies" });
    }
};

export const bulkUpdatePolicies = async (req: Request, res: Response) => {
    try {
        const updates: UpdateClientPolicyRequest[] = req.body.updates;
        const result = await policyService.bulkUpdatePolicies(updates);
        res.json(result);
    } catch (error) {
        console.error("❌ Error bulk updating policies:", error);
        res.status(500).json({ error: "Failed to bulk update policies" });
    }
};

export const batchExpirePolicies = async (req: Request, res: Response) => {
    try {
        const request: BatchExpirePoliciesRequest = req.body;
        const result = await policyService.batchExpirePolicies(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error batch expiring policies:", error);
        res.status(500).json({ error: "Failed to batch expire policies" });
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
        console.error("❌ Error getting policy templates:", error);
        res.status(500).json({ error: "Failed to get policy templates" });
    }
};

export const createPolicyTemplate = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyTemplateRequest = req.body;
        const result = await policyService.createPolicyTemplate(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error creating policy template:", error);
        res.status(500).json({ error: "Failed to create policy template" });
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
        console.error("❌ Error updating policy template:", error);
        res.status(500).json({ error: "Failed to update policy template" });
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
        console.error("❌ Error getting insurance companies:", error);
        res.status(500).json({ error: "Failed to get insurance companies" });
    }
};

export const createInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const request: CreateInsuranceCompanyRequest = req.body;
        const result = await policyService.createInsuranceCompany(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error creating insurance company:", error);
        res.status(500).json({ error: "Failed to create insurance company" });
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
        console.error("❌ Error updating insurance company:", error);
        res.status(500).json({ error: "Failed to update insurance company" });
    }
};

export const getPolicyTypes = async (req: Request, res: Response) => {
    try {
        const isActive = req.query.isActive !== 'false';
        const result = await policyService.getPolicyTypes(isActive);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policy types:", error);
        res.status(500).json({ error: "Failed to get policy types" });
    }
};

export const createPolicyType = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyTypeRequest = req.body;
        const result = await policyService.createPolicyType(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error creating policy type:", error);
        res.status(500).json({ error: "Failed to create policy type" });
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
        console.error("❌ Error updating policy type:", error);
        res.status(500).json({ error: "Failed to update policy type" });
    }
};

export const getPolicyCategories = async (req: Request, res: Response) => {
    try {
        const isActive = req.query.isActive !== 'false';
        const result = await policyService.getPolicyCategories(isActive);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policy categories:", error);
        res.status(500).json({ error: "Failed to get policy categories" });
    }
};

export const createPolicyCategory = async (req: Request, res: Response) => {
    try {
        const request: CreatePolicyCategoryRequest = req.body;
        const result = await policyService.createPolicyCategory(request);
        res.status(201).json(result);
    } catch (error) {
        console.error("❌ Error creating policy category:", error);
        res.status(500).json({ error: "Failed to create policy category" });
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
        console.error("❌ Error updating policy category:", error);
        res.status(500).json({ error: "Failed to update policy category" });
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
        console.error("❌ Error getting policy statistics:", error);
        res.status(500).json({ error: "Failed to get policy statistics" });
    }
};

export const getPolicyStatisticsDetailed = async (req: Request, res: Response) => {
    try {
        const request: PolicyStatisticsRequest = getRequestData(req);
        const result = await policyService.getPolicyStatisticsDetailed(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting detailed policy statistics:", error);
        res.status(500).json({ error: "Failed to get detailed policy statistics" });
    }
};

export const getAgentDashboardSummary = async (req: Request, res: Response) => {
    try {
        const agentId = req.params.agentId || req.query.agentId as string;
        if (!agentId) {
            return res.status(400).json({ error: "Agent ID is required" });
        }
        const result = await policyService.getAgentDashboardSummary(agentId);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting agent dashboard summary:", error);
        res.status(500).json({ error: "Failed to get agent dashboard summary" });
    }
};

export const getPolicyHistory = async (req: Request, res: Response) => {
    try {
        const request: GetPolicyHistoryRequest = {
            clientId: req.params.clientId || req.query.clientId as string,
            includeInactive: req.query.includeInactive === 'true'
        };
        if (!request.clientId) {
            return res.status(400).json({ error: "Client ID is required" });
        }
        const result = await policyService.getPolicyHistory(request);
        res.json(result);
    } catch (error) {
        console.error("❌ Error getting policy history:", error);
        res.status(500).json({ error: "Failed to get policy history" });
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
        console.error("❌ Error validating policy:", error);
        res.status(500).json({ error: "Failed to validate policy" });
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
        console.error("❌ Error cleaning up soft deleted records:", error);
        res.status(500).json({ error: "Failed to cleanup soft deleted records" });
    }
};

// ============================================
// EXPORT OPERATIONS
// ============================================

export const exportPolicies = async (req: Request, res: Response) => {
    try {
        const agentId = req.query.agentId as string;
        const format = (req.query.format as 'json' | 'csv') || 'json';
        
        const result = await policyService.exportPolicies(agentId, format);

        if (format === 'csv') {
            res.setHeader('Content-Type', 'text/csv');
            res.setHeader('Content-Disposition', 'attachment; filename="policies.csv"');
            res.send(result);
        } else {
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('Content-Disposition', 'attachment; filename="policies.json"');
            res.json(result);
        }
    } catch (error) {
        console.error("❌ Error exporting policies:", error);
        res.status(500).json({ error: "Failed to export policies" });
    }
};

// ============================================
// HEALTH CHECK
// ============================================

export const healthCheck = async (req: Request, res: Response) => {
    try {
        // Simple health check - you could add more comprehensive checks here
        const result = await policyService.getPolicyCategories(true);
        res.status(200).json({
            message: "Policy service is healthy",
            timestamp: new Date().toISOString(),
            status: "OK"
        });
    } catch (error) {
        console.error("❌ Policy service health check failed:", error);
        res.status(503).json({
            message: "Policy service is unhealthy",
            timestamp: new Date().toISOString(),
            status: "ERROR",
            error: error instanceof Error ? error.message : "Unknown error"
        });
    }
};

// ============================================
// SOFT DELETE OPERATIONS
// ============================================

export const deleteInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        const hardDelete = req.query.hardDelete === 'true';
        const result = await policyService.deleteInsuranceCompany(companyId, { hardDelete });
        res.json(result);
    } catch (error) {
        console.error("❌ Error deleting insurance company:", error);
        res.status(500).json({ error: "Failed to delete insurance company" });
    }
};

export const softDeletePolicyTemplate = async (req: Request, res: Response) => {
    try {
        const { templateId } = req.params;
        await policyService.softDeletePolicyTemplate(templateId);
        res.json({ message: "Template soft deleted successfully" });
    } catch (error) {
        console.error("❌ Error soft deleting policy template:", error);
        res.status(500).json({ error: "Failed to soft delete policy template" });
    }
};

export const softDeletePolicyCatalog = async (req: Request, res: Response) => {
    try {
        const { policyCatalogId } = req.params;
        await policyService.softDeletePolicyCatalog(policyCatalogId);
        res.json({ message: "Policy catalog soft deleted successfully" });
    } catch (error) {
        console.error("❌ Error soft deleting policy catalog:", error);
        res.status(500).json({ error: "Failed to soft delete policy catalog" });
    }
};

export const softDeletePolicyCategory = async (req: Request, res: Response) => {
    try {
        const { categoryId } = req.params;
        await policyService.softDeletePolicyCategory(categoryId);
        res.json({ message: "Policy category soft deleted successfully" });
    } catch (error) {
        console.error("❌ Error soft deleting policy category:", error);
        res.status(500).json({ error: "Failed to soft delete policy category" });
    }
};

export const softDeleteInsuranceCompany = async (req: Request, res: Response) => {
    try {
        const { companyId } = req.params;
        await policyService.softDeleteInsuranceCompany(companyId);
        res.json({ message: "Insurance company soft deleted successfully" });
    } catch (error) {
        console.error("❌ Error soft deleting insurance company:", error);
        res.status(500).json({ error: "Failed to soft delete insurance company" });
    }
};

export const softDeleteClientPolicy = async (req: Request, res: Response) => {
    try {
        const { policyId } = req.params;
        await policyService.softDeleteClientPolicy(policyId);
        res.json({ message: "Client policy soft deleted successfully" });
    } catch (error) {
        console.error("❌ Error soft deleting client policy:", error);
        res.status(500).json({ error: "Failed to soft delete client policy" });
    }
};

export const softDeletePolicyType = async (req: Request, res: Response) => {
    try {
        const { typeId } = req.params;
        const result = await policyService.softDeletePolicyType(typeId);
        res.json(result);
    } catch (error) {
        console.error("❌ Error soft deleting policy type:", error);
        res.status(500).json({ error: "Failed to soft delete policy type" });
    }
};

// ============================================
// AUTOCOMPLETE METHODS
// ============================================

export const autocompleteInsuranceCompanies = async (req: Request, res: Response) => {
    try {
        const { term = '' } = req.query;
        const result = await policyService.searchInsuranceCompanies(String(term));
        res.json(result);
    } catch (error) {
        console.error("❌ Error autocompleting insurance companies:", error);
        res.status(500).json({ error: "Failed to autocomplete insurance companies" });
    }
};

export const autocompletePolicyCatalog = async (req: Request, res: Response) => {
    try {
        const { agentId, term = '' } = req.query;
        const result = await policyService.searchPolicyCatalog(String(agentId), String(term));
        res.json(result);
    } catch (error) {
        console.error("❌ Error autocompleting policy catalog:", error);
        res.status(500).json({ error: "Failed to autocomplete policy catalog" });
    }
};

export const autocompletePolicyCategories = async (req: Request, res: Response) => {
    try {
        const { term = '' } = req.query;
        const result = await policyService.searchPolicyCategories(String(term));
        res.json(result);
    } catch (error) {
        console.error("❌ Error autocompleting policy categories:", error);
        res.status(500).json({ error: "Failed to autocomplete policy categories" });
    }
};

export const autocompletePolicyTemplates = async (req: Request, res: Response) => {
    try {
        const { agentId, term = '' } = req.query;
        const result = await policyService.searchPolicyTemplates(String(agentId), String(term));
        res.json(result);
    } catch (error) {
        console.error("❌ Error autocompleting policy templates:", error);
        res.status(500).json({ error: "Failed to autocomplete policy templates" });
    }
};

export const autocompletePolicyTypes = async (req: Request, res: Response) => {
    try {
        const { term = '' } = req.query;
        const result = await policyService.searchPolicyTypes(String(term));
        res.json(result);
    } catch (error) {
        console.error("❌ Error autocompleting policy types:", error);
        res.status(500).json({ error: "Failed to autocomplete policy types" });
    }
};

export const autocompleteClientPolicies = async (req: Request, res: Response) => {
    try {
        const { clientId, term = '' } = req.query;
        const result = await policyService.searchClientPolicies(String(clientId), String(term));
        res.json(result);
    } catch (error) {
        console.error("❌ Error autocompleting client policies:", error);
        res.status(500).json({ error: "Failed to autocomplete client policies" });
    }
};