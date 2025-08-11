import { Router } from 'express';
import { PolicyController } from '../controllers/policy.controller';

const router = Router();
const controller = new PolicyController();

// Policy Catalog
router.post('/catalog', controller.getPolicyCatalog.bind(controller));
router.post('/catalog/create', controller.createPolicyCatalogItem.bind(controller));
router.put('/catalog/update', controller.updatePolicyCatalogItem.bind(controller));
router.delete('/catalog/:agentId/:policyCatalogId', controller.deletePolicyCatalogItem.bind(controller));
router.post('/catalog/upsert', controller.upsertPolicyCatalog.bind(controller));

// Client Policies
router.post('/client', controller.getClientPolicies.bind(controller));
router.post('/client/create', controller.createClientPolicy.bind(controller));
router.put('/client/update', controller.updateClientPolicy.bind(controller));
router.post('/client/upsert', controller.upsertClientPolicy.bind(controller));
router.post('/client/expiring', controller.getExpiringPolicies.bind(controller));
router.get('/client/statistics/:agentId', controller.getPolicyStatistics.bind(controller));

// Policy Templates
router.post('/templates', controller.getPolicyTemplates.bind(controller));
router.post('/templates/create', controller.createPolicyTemplate.bind(controller));
router.delete('/templates/:agentId/:templateId', controller.deletePolicyTemplate.bind(controller));

// Reference Data
router.get('/reference/companies', controller.getInsuranceCompanies.bind(controller));
router.get('/reference/types', controller.getPolicyTypes.bind(controller));
router.get('/reference/categories', controller.getPolicyCategories.bind(controller));

export default router;
