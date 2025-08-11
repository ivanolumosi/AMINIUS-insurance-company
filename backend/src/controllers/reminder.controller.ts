// src/controllers/reminders.controller.ts
import { Request, Response } from 'express';
import { ReminderService } from '../services/reminder.service';

export class RemindersController {
    private reminderService: ReminderService;

    constructor() {
        this.reminderService = new ReminderService();
    }

    async create(req: Request, res: Response) {
        try {
            const result = await this.reminderService.createReminder(req.params.agentId, req.body);
            res.status(201).json(result);
        } catch (error) {
            console.error('Create Reminder Error:', error);
            res.status(500).json({ error: 'Failed to create reminder' });
        }
    }

    async getAll(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getAllReminders(req.params.agentId, req.query);
            res.json(result);
        } catch (error) {
            console.error('Get All Reminders Error:', error);
            res.status(500).json({ error: 'Failed to fetch reminders' });
        }
    }

    async getById(req: Request, res: Response) {
        try {
            const reminder = await this.reminderService.getReminderById(req.params.reminderId, req.params.agentId);
            if (!reminder) return res.status(404).json({ error: 'Reminder not found' });
            res.json(reminder);
        } catch (error) {
            console.error('Get Reminder Error:', error);
            res.status(500).json({ error: 'Failed to fetch reminder' });
        }
    }

    async update(req: Request, res: Response) {
        try {
            const result = await this.reminderService.updateReminder(req.params.reminderId, req.params.agentId, req.body);
            res.json(result);
        } catch (error) {
            console.error('Update Reminder Error:', error);
            res.status(500).json({ error: 'Failed to update reminder' });
        }
    }

    async delete(req: Request, res: Response) {
        try {
            const result = await this.reminderService.deleteReminder(req.params.reminderId, req.params.agentId);
            res.json(result);
        } catch (error) {
            console.error('Delete Reminder Error:', error);
            res.status(500).json({ error: 'Failed to delete reminder' });
        }
    }

    async complete(req: Request, res: Response) {
        try {
            const result = await this.reminderService.completeReminder(req.params.reminderId, req.params.agentId, req.body.notes);
            res.json(result);
        } catch (error) {
            console.error('Complete Reminder Error:', error);
            res.status(500).json({ error: 'Failed to complete reminder' });
        }
    }

    async getToday(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getTodayReminders(req.params.agentId);
            res.json(result);
        } catch (error) {
            console.error('Get Today Reminders Error:', error);
            res.status(500).json({ error: 'Failed to fetch today reminders' });
        }
    }

    async getUpcoming(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getUpcomingReminders(req.params.agentId, Number(req.query.daysAhead) || 7);
            res.json(result);
        } catch (error) {
            console.error('Get Upcoming Reminders Error:', error);
            res.status(500).json({ error: 'Failed to fetch upcoming reminders' });
        }
    }

    async getCompleted(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getCompletedReminders(
                req.params.agentId,
                req.query.startDate ? new Date(req.query.startDate as string) : undefined,
                req.query.endDate ? new Date(req.query.endDate as string) : undefined,
                Number(req.query.pageSize) || 50,
                Number(req.query.pageNumber) || 1
            );
            res.json(result);
        } catch (error) {
            console.error('Get Completed Reminders Error:', error);
            res.status(500).json({ error: 'Failed to fetch completed reminders' });
        }
    }

    async getBirthdays(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getTodayBirthdayReminders(req.params.agentId);
            res.json(result);
        } catch (error) {
            console.error('Get Birthday Reminders Error:', error);
            res.status(500).json({ error: 'Failed to fetch birthday reminders' });
        }
    }

    async getPolicyExpiries(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getPolicyExpiryReminders(req.params.agentId, Number(req.query.daysAhead) || 30);
            res.json(result);
        } catch (error) {
            console.error('Get Policy Expiry Reminders Error:', error);
            res.status(500).json({ error: 'Failed to fetch policy expiry reminders' });
        }
    }

    async validatePhone(req: Request, res: Response) {
        try {
            const result = await this.reminderService.validatePhoneNumber(req.query.phoneNumber as string, req.query.countryCode as string);
            res.json(result);
        } catch (error) {
            console.error('Validate Phone Error:', error);
            res.status(500).json({ error: 'Failed to validate phone number' });
        }
    }

    async getSettings(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getReminderSettings(req.params.agentId);
            res.json(result);
        } catch (error) {
            console.error('Get Settings Error:', error);
            res.status(500).json({ error: 'Failed to fetch settings' });
        }
    }

    async updateSettings(req: Request, res: Response) {
        try {
            await this.reminderService.updateReminderSettings(
                req.params.agentId,
                req.body.ReminderType,
                req.body.IsEnabled,
                req.body.DaysBefore,
                req.body.TimeOfDay,
                req.body.RepeatDaily
            );
            res.json({ message: 'Settings updated' });
        } catch (error) {
            console.error('Update Settings Error:', error);
            res.status(500).json({ error: 'Failed to update settings' });
        }
    }

    async stats(req: Request, res: Response) {
        try {
            const result = await this.reminderService.getReminderStatistics(req.params.agentId);
            res.json(result);
        } catch (error) {
            console.error('Get Statistics Error:', error);
            res.status(500).json({ error: 'Failed to fetch statistics' });
        }
    }
}
