// routes/clients.routes.ts
import { Router } from 'express';
import { ClientController } from '../controllers/clients.controller';

const router = Router();
const controller = new ClientController();

// Create / Update (upsert)
router.post('/upsert', controller.upsert.bind(controller));

// Create / Update separate
router.post('/', controller.create.bind(controller));
router.put('/', controller.update.bind(controller));

// Statistics (specific first)
router.get('/:agentId/statistics/enhanced', controller.enhancedStatistics.bind(controller));
router.get('/:agentId/statistics', controller.statistics.bind(controller));

// Birthdays
router.get('/:agentId/birthdays', controller.birthdays.bind(controller));

// Advanced filters & pagination
router.get('/:agentId/all/paginated', controller.allClientsPaginated.bind(controller));

// Search
router.get('/:agentId/search', controller.search.bind(controller));

// By insurance type
router.get('/:agentId/insurance/:insuranceType', controller.byInsuranceType.bind(controller));

// With policies
router.get('/:agentId/:clientId/policies', controller.withPolicies.bind(controller));

// Get client by id
router.get('/:agentId/:clientId', controller.getById.bind(controller));

// Convert to client
router.put('/:agentId/:clientId/convert', controller.convert.bind(controller));

// Delete client
router.delete('/:agentId/:clientId', controller.delete.bind(controller));

// Get all clients (least specific — last)
router.get('/:agentId', controller.getAll.bind(controller));

export default router;
