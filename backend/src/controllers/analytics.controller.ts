import { Request, Response } from "express";
import { AnalyticsService } from "../services/analytics.service";

const analyticsService = new AnalyticsService();

export class AnalyticsController {
  // Activity Log
  async createActivityLog(req: Request, res: Response) {
    try {
      const log = await analyticsService.createActivityLog(req.body);
      return res.status(201).json(log);
    } catch (error: any) {
      console.error("Error creating activity log:", error);
      return res.status(500).json({ error: "Failed to create activity log" });
    }
  }

  async getActivityLogsByAgent(req: Request, res: Response) {
    try {
      const { agentId } = req.params;
      const limit = req.query.limit ? Number(req.query.limit) : 50;
      const logs = await analyticsService.getActivityLogsByAgent(agentId, limit);
      return res.json(logs);
    } catch (error: any) {
      console.error("Error fetching activity logs:", error);
      return res.status(500).json({ error: "Failed to fetch activity logs" });
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
      return res.json(logs);
    } catch (error: any) {
      console.error("Error fetching logs by date range:", error);
      return res.status(500).json({ error: "Failed to fetch logs by date range" });
    }
  }

  // Dashboard Statistics
  async getDashboardStatistics(req: Request, res: Response) {
    try {
      const stats = await analyticsService.getDashboardStatistics(req.body);
      return res.json(stats);
    } catch (error: any) {
      console.error("Error fetching dashboard stats:", error);
      return res.status(500).json({ error: "Failed to fetch dashboard statistics" });
    }
  }

  async updateDashboardStatistics(req: Request, res: Response) {
    try {
      const { agentId } = req.params;
      const stats = await analyticsService.updateDashboardStatistics(agentId, req.body);
      return res.json(stats);
    } catch (error: any) {
      console.error("Error updating dashboard stats:", error);
      return res.status(500).json({ error: "Failed to update dashboard statistics" });
    }
  }

  // Performance Metrics
  async getPerformanceMetrics(req: Request, res: Response) {
    try {
      const metrics = await analyticsService.getPerformanceMetrics(req.body);
      return res.json(metrics);
    } catch (error: any) {
      console.error("Error fetching performance metrics:", error);
      return res.status(500).json({ error: "Failed to fetch performance metrics" });
    }
  }

  async updatePerformanceMetrics(req: Request, res: Response) {
    try {
      const { agentId } = req.params;
      const { metricDate, ...metrics } = req.body;
      const updated = await analyticsService.updatePerformanceMetrics(
        agentId,
        new Date(metricDate),
        metrics
      );
      return res.json(updated);
    } catch (error: any) {
      console.error("Error updating performance metrics:", error);
      return res.status(500).json({ error: "Failed to update performance metrics" });
    }
  }

  // Task Summary
  async createTaskSummary(req: Request, res: Response) {
    try {
      const task = await analyticsService.createTaskSummary(req.body);
      return res.status(201).json(task);
    } catch (error: any) {
      console.error("Error creating task summary:", error);
      return res.status(500).json({ error: "Failed to create task summary" });
    }
  }

  async getTasksSummary(req: Request, res: Response) {
    try {
      const { agentId } = req.params;
      const taskDate = req.query.taskDate ? new Date(req.query.taskDate as string) : undefined;
      const tasks = await analyticsService.getTasksSummary(agentId, taskDate);
      return res.json(tasks);
    } catch (error: any) {
      console.error("Error fetching tasks summary:", error);
      return res.status(500).json({ error: "Failed to fetch tasks summary" });
    }
  }

  async updateTaskStatus(req: Request, res: Response) {
    try {
      const { taskId } = req.params;
      const { status, completedDate } = req.body;
      const updated = await analyticsService.updateTaskStatus(
        taskId,
        status,
        completedDate ? new Date(completedDate) : undefined
      );
      return res.json({ success: updated });
    } catch (error: any) {
      console.error("Error updating task status:", error);
      return res.status(500).json({ error: "Failed to update task status" });
    }
  }

  // Monthly Reports
  async generateMonthlyReport(req: Request, res: Response) {
    try {
      const report = await analyticsService.generateMonthlyReport(req.body);
      return res.status(201).json(report);
    } catch (error: any) {
      console.error("Error generating monthly report:", error);
      return res.status(500).json({ error: "Failed to generate monthly report" });
    }
  }

  async getMonthlyReports(req: Request, res: Response) {
    try {
      const { agentId } = req.params;
      const { startMonth, endMonth } = req.query;
      const reports = await analyticsService.getMonthlyReports(
        agentId,
        new Date(startMonth as string),
        new Date(endMonth as string)
      );
      return res.json(reports);
    } catch (error: any) {
      console.error("Error fetching monthly reports:", error);
      return res.status(500).json({ error: "Failed to fetch monthly reports" });
    }
  }

  // Dashboard Views Cache
  async getCachedView(req: Request, res: Response) {
    try {
      const { agentId, viewName } = req.params;
      const { cacheDate } = req.query;
      const data = await analyticsService.getCachedView(
        agentId,
        viewName,
        new Date(cacheDate as string)
      );
      return res.json({ cacheData: data });
    } catch (error: any) {
      console.error("Error fetching cached view:", error);
      return res.status(500).json({ error: "Failed to fetch cached view" });
    }
  }

  async setCachedView(req: Request, res: Response) {
    try {
      await analyticsService.setCachedView(req.body);
      return res.status(204).send();
    } catch (error: any) {
      console.error("Error setting cached view:", error);
      return res.status(500).json({ error: "Failed to set cached view" });
    }
  }

  async clearExpiredCache(_req: Request, res: Response) {
    try {
      await analyticsService.clearExpiredCache();
      return res.status(204).send();
    } catch (error: any) {
      console.error("Error clearing expired cache:", error);
      return res.status(500).json({ error: "Failed to clear expired cache" });
    }
  }
}
