import { Router } from 'express';
import { PolicyController } from '../controllers/policy.controller';

const router = Router();
const controller = new PolicyController();

// ============================================
// HEALTH CHECK
// ============================================
router.get('/health', controller.healthCheck.bind(controller));

// ============================================
// POLICY CATALOG ROUTES
// ============================================
router.get('/catalog', controller.getPolicyCatalog.bind(controller));
router.post('/catalog', controller.createPolicyCatalogItem.bind(controller));
router.put('/catalog/:id', controller.updatePolicyCatalogItem.bind(controller));
router.delete('/catalog/:id', controller.deletePolicyCatalogItem.bind(controller));
router.post('/catalog/upsert', controller.upsertPolicyCatalog.bind(controller));

// ============================================
// CLIENT POLICY ROUTES
// ============================================
router.get('/policies', controller.getClientPolicies.bind(controller));
router.get('/policies/:id', controller.getPolicyById.bind(controller));
router.post('/policies', controller.createClientPolicy.bind(controller));
router.put('/policies/:id', controller.updateClientPolicy.bind(controller));
router.delete('/policies/:id', controller.deleteClientPolicy.bind(controller));
router.post('/policies/upsert', controller.upsertClientPolicy.bind(controller));

// ============================================
// POLICY SEARCH AND FILTERING
// ============================================
router.get('/policies/search', controller.searchPolicies.bind(controller));
router.get('/policies/status', controller.getPoliciesByStatus.bind(controller));

// ============================================
// POLICY EXPIRATION AND RENEWAL
// ============================================
router.get('/policies/expiring', controller.getExpiringPolicies.bind(controller));
router.post('/policies/:id/renew', controller.renewPolicy.bind(controller));
router.get('/policies/renewal-candidates', controller.getPolicyRenewalCandidates.bind(controller));

// ============================================
// BULK OPERATIONS
// ============================================
router.put('/policies/bulk/status', controller.bulkUpdatePolicyStatus.bind(controller));
router.post('/policies/bulk/create', controller.bulkCreatePolicies.bind(controller));
router.put('/policies/bulk/update', controller.bulkUpdatePolicies.bind(controller));
router.post('/policies/bulk/expire', controller.batchExpirePolicies.bind(controller));

// ============================================
// POLICY TEMPLATES
// ============================================
router.get('/templates', controller.getPolicyTemplates.bind(controller));
router.post('/templates', controller.createPolicyTemplate.bind(controller));
router.put('/templates/:id', controller.updatePolicyTemplate.bind(controller));
router.delete('/templates/:id', controller.deletePolicyTemplate.bind(controller));

// ============================================
// REFERENCE DATA - INSURANCE COMPANIES
// ============================================
router.get('/companies', controller.getInsuranceCompanies.bind(controller));
router.post('/companies', controller.createInsuranceCompany.bind(controller));
router.put('/companies/:id', controller.updateInsuranceCompany.bind(controller));

// ============================================
// REFERENCE DATA - POLICY TYPES
// ============================================
router.get('/types', controller.getPolicyTypes.bind(controller));
router.post('/types', controller.createPolicyType.bind(controller));
router.put('/types/:id', controller.updatePolicyType.bind(controller));

// ============================================
// REFERENCE DATA - POLICY CATEGORIES
// ============================================
router.get('/categories', controller.getPolicyCategories.bind(controller));
router.post('/categories', controller.createPolicyCategory.bind(controller));
router.put('/categories/:id', controller.updatePolicyCategory.bind(controller));

// ============================================
// ANALYTICS AND REPORTING
// ============================================
router.get('/statistics', controller.getPolicyStatistics.bind(controller));
router.get('/statistics/detailed', controller.getPolicyStatisticsDetailed.bind(controller));
router.get('/dashboard/:agentId', controller.getAgentDashboardSummary.bind(controller));
router.get('/history/:clientId', controller.getPolicyHistory.bind(controller));

// ============================================
// VALIDATION
// ============================================
router.post('/validate', controller.validatePolicy.bind(controller));

// ============================================
// EXPORT OPERATIONS
// ============================================
router.get('/export', controller.exportPolicies.bind(controller));

// ============================================
// UTILITY OPERATIONS
// ============================================
router.post('/cleanup/soft-deleted', controller.cleanupSoftDeletedRecords.bind(controller));

// ============================================
// LEGACY SUPPORT ROUTES (if still needed)
// ============================================

// Legacy client policy routes
router.get('/client/:clientId', controller.getClientPolicies.bind(controller));
router.get('/client/policy/:policyId', controller.getPolicyById.bind(controller));
router.post('/client', controller.createClientPolicy.bind(controller));
router.put('/client/:policyId', controller.updateClientPolicy.bind(controller));
router.delete('/client/:policyId', controller.deleteClientPolicy.bind(controller));

// Legacy expiring policies route
router.get('/client/expiring/:agentId', controller.getExpiringPolicies.bind(controller));

// Legacy statistics routes
router.get('/client/statistics/:agentId', controller.getPolicyStatistics.bind(controller));
router.get('/client/statistics/detailed/:agentId', controller.getPolicyStatisticsDetailed.bind(controller));

// Legacy search routes
router.get('/search/:agentId', controller.searchPolicies.bind(controller));
router.get('/status/:agentId/:status', controller.getPoliciesByStatus.bind(controller));

// Legacy renewal route
router.put('/renew/:policyId', controller.renewPolicy.bind(controller));

// Legacy bulk status route
router.put('/bulk/status', controller.bulkUpdatePolicyStatus.bind(controller));

// Legacy template routes
router.get('/templates/:agentId', controller.getPolicyTemplates.bind(controller));
router.put('/templates/:templateId', controller.updatePolicyTemplate.bind(controller));
router.delete('/templates/:templateId', controller.deletePolicyTemplate.bind(controller));

// Legacy reference data routes
router.get('/reference/companies', controller.getInsuranceCompanies.bind(controller));
router.get('/reference/types', controller.getPolicyTypes.bind(controller));
router.get('/reference/categories', controller.getPolicyCategories.bind(controller));
router.post('/reference/categories', controller.createPolicyCategory.bind(controller));

// Legacy catalog routes
router.post('/catalog/item', controller.createPolicyCatalogItem.bind(controller));
router.put('/catalog/:policyCatalogId', controller.updatePolicyCatalogItem.bind(controller));
router.delete('/catalog/:policyCatalogId', controller.deletePolicyCatalogItem.bind(controller));
router.put('/catalog/upsert', controller.upsertPolicyCatalog.bind(controller));

export default router;