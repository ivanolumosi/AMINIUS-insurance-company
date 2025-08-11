import { Request, Response } from 'express';
import { AnalyticsService } from '../services/analytics.service';

const analyticsService = new AnalyticsService();

export class AnalyticsController {
    // Activity Log
    async createActivityLog(req: Request, res: Response) {
        try {
            const log = await analyticsService.createActivityLog(req.body);
            res.status(201).json(log);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to create activity log', error: error.message });
        }
    }

    async getActivityLogsByAgent(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const limit = req.query.limit ? Number(req.query.limit) : 50;
            const logs = await analyticsService.getActivityLogsByAgent(agentId, limit);
            res.json(logs);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch activity logs', error: error.message });
        }
    }

    async getActivityLogsByDateRange(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { startDate, endDate } = req.query;
            const logs = await analyticsService.getActivityLogsByDateRange(
                agentId,
                new Date(startDate as string),
                new Date(endDate as string)
            );
            res.json(logs);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch logs by date range', error: error.message });
        }
    }

    // Dashboard Statistics
    async getDashboardStatistics(req: Request, res: Response) {
        try {
            const stats = await analyticsService.getDashboardStatistics(req.body);
            res.json(stats);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch dashboard statistics', error: error.message });
        }
    }

    async updateDashboardStatistics(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const stats = await analyticsService.updateDashboardStatistics(agentId, req.body);
            res.json(stats);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to update dashboard statistics', error: error.message });
        }
    }

    // Performance Metrics
    async getPerformanceMetrics(req: Request, res: Response) {
        try {
            const metrics = await analyticsService.getPerformanceMetrics(req.body);
            res.json(metrics);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch performance metrics', error: error.message });
        }
    }

    async updatePerformanceMetrics(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { metricDate, ...metrics } = req.body;
            const updated = await analyticsService.updatePerformanceMetrics(agentId, new Date(metricDate), metrics);
            res.json(updated);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to update performance metrics', error: error.message });
        }
    }

    // Task Summary
    async createTaskSummary(req: Request, res: Response) {
        try {
            const task = await analyticsService.createTaskSummary(req.body);
            res.status(201).json(task);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to create task summary', error: error.message });
        }
    }

    async getTasksSummary(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const taskDate = req.query.taskDate ? new Date(req.query.taskDate as string) : undefined;
            const tasks = await analyticsService.getTasksSummary(agentId, taskDate);
            res.json(tasks);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch tasks summary', error: error.message });
        }
    }

    async updateTaskStatus(req: Request, res: Response) {
        try {
            const { taskId } = req.params;
            const { status, completedDate } = req.body;
            const updated = await analyticsService.updateTaskStatus(taskId, status, completedDate ? new Date(completedDate) : undefined);
            res.json({ success: updated });
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to update task status', error: error.message });
        }
    }

    // Monthly Reports
    async generateMonthlyReport(req: Request, res: Response) {
        try {
            const report = await analyticsService.generateMonthlyReport(req.body);
            res.status(201).json(report);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to generate monthly report', error: error.message });
        }
    }

    async getMonthlyReports(req: Request, res: Response) {
        try {
            const { agentId } = req.params;
            const { startMonth, endMonth } = req.query;
            const reports = await analyticsService.getMonthlyReports(agentId, new Date(startMonth as string), new Date(endMonth as string));
            res.json(reports);
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch monthly reports', error: error.message });
        }
    }

    // Dashboard Views Cache
    async getCachedView(req: Request, res: Response) {
        try {
            const { agentId, viewName } = req.params;
            const { cacheDate } = req.query;
            const data = await analyticsService.getCachedView(agentId, viewName, new Date(cacheDate as string));
            res.json({ cacheData: data });
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to fetch cached view', error: error.message });
        }
    }

    async setCachedView(req: Request, res: Response) {
        try {
            await analyticsService.setCachedView(req.body);
            res.status(204).send();
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to set cached view', error: error.message });
        }
    }

    async clearExpiredCache(req: Request, res: Response) {
        try {
            await analyticsService.clearExpiredCache();
            res.status(204).send();
        } catch (error: any) {
            res.status(500).json({ message: 'Failed to clear expired cache', error: error.message });
        }
    }
}
