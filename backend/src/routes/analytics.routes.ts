import { Router } from 'express';
import { AnalyticsController } from '../controllers/analytics.controller';

const router = Router();
const controller = new AnalyticsController();

// Activity Logs
router.post('/activity-log', controller.createActivityLog.bind(controller));
router.get('/activity-log/:agentId', controller.getActivityLogsByAgent.bind(controller));
router.get('/activity-log/:agentId/date-range', controller.getActivityLogsByDateRange.bind(controller));

// Dashboard Statistics
router.post('/dashboard-statistics', controller.getDashboardStatistics.bind(controller));
router.put('/dashboard-statistics/:agentId', controller.updateDashboardStatistics.bind(controller));

// Performance Metrics
router.post('/performance-metrics', controller.getPerformanceMetrics.bind(controller));
router.put('/performance-metrics/:agentId', controller.updatePerformanceMetrics.bind(controller));

// Task Summary
router.post('/tasks', controller.createTaskSummary.bind(controller));
router.get('/tasks/:agentId', controller.getTasksSummary.bind(controller));
router.patch('/tasks/:taskId/status', controller.updateTaskStatus.bind(controller));

// Monthly Reports
router.post('/monthly-reports/generate', controller.generateMonthlyReport.bind(controller));
router.get('/monthly-reports/:agentId', controller.getMonthlyReports.bind(controller));

// Dashboard Views Cache
router.get('/dashboard-cache/:agentId/:viewName', controller.getCachedView.bind(controller));
router.post('/dashboard-cache', controller.setCachedView.bind(controller));
router.delete('/dashboard-cache/expired', controller.clearExpiredCache.bind(controller));

export default router;
