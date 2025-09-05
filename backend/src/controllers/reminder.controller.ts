import { Request, Response } from 'express';
import { ReminderService } from '../services/reminder.service';
import { 
    CreateReminderRequest, 
    UpdateReminderRequest, 
    ReminderFilters 
} from '../interfaces/reminders';

export class RemindersController {
    private reminderService: ReminderService;

    constructor() {
        this.reminderService = new ReminderService();
    }

    /** Extract agentId from params - frontend always uses URL params */
    private extractAgentId(req: Request): string {
        return req.params.agentId;
    }

    /** Create a new reminder */
    public createReminder = async (req: Request, res: Response): Promise<void> => {
        console.log('🎯 CONTROLLER: createReminder - Starting...');
        console.log('🎯 Request params:', req.params);
        console.log('🎯 Request headers:', req.headers);
        console.log('🎯 Request body:', JSON.stringify(req.body, null, 2));
        
        try {
            const agentId = this.extractAgentId(req);
            console.log('🎯 Extracted agentId:', agentId);
            
            if (!agentId) {
                console.error('❌ No agentId found in params or headers');
                res.status(400).json({ 
                    error: 'Agent ID is required',
                    message: 'Provide agentId in URL path or x-agent-id header' 
                });
                return;
            }

            const reminderData: CreateReminderRequest = req.body;
            console.log('🎯 Calling service with agentId:', agentId);
            
            const result = await this.reminderService.createReminder(agentId, reminderData);
            console.log('✅ CONTROLLER: createReminder - Success:', result);
            
            res.status(201).json(result);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: createReminder - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to create reminder', 
                message: errorMessage 
            });
        }
    };

    /** Get all reminders with filters and pagination */
    public getAllReminders = async (req: Request, res: Response): Promise<void> => {
        console.log('🔍 CONTROLLER: getAllReminders - Starting...');
        console.log('🔍 Request params:', req.params);
        console.log('🔍 Request query:', req.query);
        
        try {
            const agentId = this.extractAgentId(req);
            console.log('🔍 Extracted agentId:', agentId);
            
            if (!agentId) {
                console.error('❌ No agentId found in params or headers');
                res.status(400).json({ 
                    error: 'Agent ID is required',
                    message: 'Provide agentId in URL path or x-agent-id header' 
                });
                return;
            }

            // Parse query parameters for filters
            const filters: ReminderFilters = {
                ReminderType: req.query.ReminderType as any,
                Status: req.query.Status as any,
                Priority: req.query.Priority as any,
                StartDate: req.query.StartDate as string,
                EndDate: req.query.EndDate as string,
                ClientId: req.query.ClientId as string,
                PageSize: req.query.PageSize ? parseInt(req.query.PageSize as string) : 20,
                PageNumber: req.query.PageNumber ? parseInt(req.query.PageNumber as string) : 1
            };
            
            console.log('🔍 Parsed filters:', filters);
            
            const result = await this.reminderService.getAllReminders(agentId, filters);
            console.log('✅ CONTROLLER: getAllReminders - Success:', {
                totalReminders: result.reminders?.length || 0,
                totalRecords: result.totalRecords
            });
            
            res.status(200).json(result);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getAllReminders - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch reminders', 
                message: errorMessage 
            });
        }
    };

    /** Get reminder by ID */
    public getReminderById = async (req: Request, res: Response): Promise<void> => {
        console.log('🔍 CONTROLLER: getReminderById - Starting...');
        console.log('🔍 Request params:', req.params);
        
        try {
            const agentId = this.extractAgentId(req);
            const reminderId = req.params.reminderId;
            
            console.log('🔍 AgentId:', agentId);
            console.log('🔍 ReminderId:', reminderId);
            
            if (!agentId || !reminderId) {
                console.error('❌ Missing required parameters');
                res.status(400).json({ 
                    error: 'Agent ID and Reminder ID are required' 
                });
                return;
            }

            const reminder = await this.reminderService.getReminderById(reminderId, agentId);
            
            if (!reminder) {
                console.log('ℹ️ Reminder not found');
                res.status(404).json({ 
                    error: 'Reminder not found' 
                });
                return;
            }
            
            console.log('✅ CONTROLLER: getReminderById - Success:', reminder.Title);
            res.status(200).json(reminder);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getReminderById - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch reminder', 
                message: errorMessage 
            });
        }
    };

    /** Update a reminder */
    public updateReminder = async (req: Request, res: Response): Promise<void> => {
        console.log('✏️ CONTROLLER: updateReminder - Starting...');
        console.log('✏️ Request params:', req.params);
        console.log('✏️ Request body:', JSON.stringify(req.body, null, 2));
        
        try {
            const agentId = this.extractAgentId(req);
            const reminderId = req.params.reminderId;
            
            if (!agentId || !reminderId) {
                console.error('❌ Missing required parameters');
                res.status(400).json({ 
                    error: 'Agent ID and Reminder ID are required' 
                });
                return;
            }

            const updateData: UpdateReminderRequest = req.body;
            const reminder = await this.reminderService.updateReminder(reminderId, agentId, updateData);
            console.log('✅ CONTROLLER: updateReminder - Success:', reminder.Title);
            
            res.status(200).json(reminder);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: updateReminder - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to update reminder', 
                message: errorMessage 
            });
        }
    };

    /** Delete a reminder */
    public deleteReminder = async (req: Request, res: Response): Promise<void> => {
        console.log('🗑️ CONTROLLER: deleteReminder - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            const reminderId = req.params.reminderId;
            
            if (!agentId || !reminderId) {
                console.error('❌ Missing required parameters');
                res.status(400).json({ 
                    error: 'Agent ID and Reminder ID are required' 
                });
                return;
            }

            const result = await this.reminderService.deleteReminder(reminderId, agentId);
            console.log('✅ CONTROLLER: deleteReminder - Success:', result);
            
            res.status(200).json(result);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: deleteReminder - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to delete reminder', 
                message: errorMessage 
            });
        }
    };

    /** Complete a reminder */
    public completeReminder = async (req: Request, res: Response): Promise<void> => {
        console.log('✅ CONTROLLER: completeReminder - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            const reminderId = req.params.reminderId;
            const { notes } = req.body;
            
            if (!agentId || !reminderId) {
                console.error('❌ Missing required parameters');
                res.status(400).json({ 
                    error: 'Agent ID and Reminder ID are required' 
                });
                return;
            }

            const result = await this.reminderService.completeReminder(reminderId, agentId, notes);
            console.log('✅ CONTROLLER: completeReminder - Success:', result);
            
            res.status(200).json(result);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: completeReminder - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to complete reminder', 
                message: errorMessage 
            });
        }
    };

    /** Get today's reminders */
    public getTodayReminders = async (req: Request, res: Response): Promise<void> => {
        console.log('📅 CONTROLLER: getTodayReminders - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            
            if (!agentId) {
                console.error('❌ No agentId found');
                res.status(400).json({ 
                    error: 'Agent ID is required' 
                });
                return;
            }

            const reminders = await this.reminderService.getTodayReminders(agentId);
            console.log('✅ CONTROLLER: getTodayReminders - Success:', reminders.length);
            
            res.status(200).json(reminders);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getTodayReminders - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch today\'s reminders', 
                message: errorMessage 
            });
        }
    };

    /** Get reminders by type */
    public getRemindersByType = async (req: Request, res: Response): Promise<void> => {
        console.log('🏷️ CONTROLLER: getRemindersByType - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            const reminderType = req.params.reminderType;
            
            if (!agentId || !reminderType) {
                console.error('❌ Missing required parameters');
                res.status(400).json({ 
                    error: 'Agent ID and Reminder Type are required' 
                });
                return;
            }

            const reminders = await this.reminderService.getRemindersByType(agentId, reminderType);
            console.log('✅ CONTROLLER: getRemindersByType - Success:', reminders.length);
            
            res.status(200).json(reminders);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getRemindersByType - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch reminders by type', 
                message: errorMessage 
            });
        }
    };

    /** Get reminders by status */
    public getRemindersByStatus = async (req: Request, res: Response): Promise<void> => {
        console.log('📊 CONTROLLER: getRemindersByStatus - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            const status = req.params.status;
            
            if (!agentId || !status) {
                console.error('❌ Missing required parameters');
                res.status(400).json({ 
                    error: 'Agent ID and Status are required' 
                });
                return;
            }

            const reminders = await this.reminderService.getRemindersByStatus(agentId, status);
            console.log('✅ CONTROLLER: getRemindersByStatus - Success:', reminders.length);
            
            res.status(200).json(reminders);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getRemindersByStatus - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch reminders by status', 
                message: errorMessage 
            });
        }
    };

    /** Get birthday reminders */
    public getBirthdayReminders = async (req: Request, res: Response): Promise<void> => {
        console.log('🎂 CONTROLLER: getBirthdayReminders - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            
            if (!agentId) {
                console.error('❌ No agentId found');
                res.status(400).json({ 
                    error: 'Agent ID is required' 
                });
                return;
            }

            const reminders = await this.reminderService.getBirthdayReminders(agentId);
            console.log('✅ CONTROLLER: getBirthdayReminders - Success:', reminders.length);
            
            res.status(200).json(reminders);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getBirthdayReminders - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch birthday reminders', 
                message: errorMessage 
            });
        }
    };

    /** Get policy expiry reminders */
    public getPolicyExpiryReminders = async (req: Request, res: Response): Promise<void> => {
        console.log('📋 CONTROLLER: getPolicyExpiryReminders - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            const daysAhead = req.query.daysAhead ? parseInt(req.query.daysAhead as string) : 30;
            
            if (!agentId) {
                console.error('❌ No agentId found');
                res.status(400).json({ 
                    error: 'Agent ID is required' 
                });
                return;
            }

            const reminders = await this.reminderService.getPolicyExpiryReminders(agentId, daysAhead);
            console.log('✅ CONTROLLER: getPolicyExpiryReminders - Success:', reminders.length);
            
            res.status(200).json(reminders);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getPolicyExpiryReminders - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch policy expiry reminders', 
                message: errorMessage 
            });
        }
    };

    /** Get reminder statistics */
    public getReminderStatistics = async (req: Request, res: Response): Promise<void> => {
        console.log('📊 CONTROLLER: getReminderStatistics - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            
            if (!agentId) {
                console.error('❌ No agentId found');
                res.status(400).json({ 
                    error: 'Agent ID is required' 
                });
                return;
            }

            const statistics = await this.reminderService.getReminderStatistics(agentId);
            console.log('✅ CONTROLLER: getReminderStatistics - Success:', statistics);
            
            res.status(200).json(statistics);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getReminderStatistics - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch reminder statistics', 
                message: errorMessage 
            });
        }
    };

    /** Get reminder settings */
    public getReminderSettings = async (req: Request, res: Response): Promise<void> => {
        console.log('⚙️ CONTROLLER: getReminderSettings - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            
            if (!agentId) {
                console.error('❌ No agentId found');
                res.status(400).json({ 
                    error: 'Agent ID is required' 
                });
                return;
            }

            const settings = await this.reminderService.getReminderSettings(agentId);
            console.log('✅ CONTROLLER: getReminderSettings - Success:', settings.length);
            
            res.status(200).json(settings);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: getReminderSettings - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to fetch reminder settings', 
                message: errorMessage 
            });
        }
    };

    /** Update reminder settings */
    public updateReminderSettings = async (req: Request, res: Response): Promise<void> => {
        console.log('⚙️ CONTROLLER: updateReminderSettings - Starting...');
        
        try {
            const agentId = this.extractAgentId(req);
            
            if (!agentId) {
                console.error('❌ No agentId found');
                res.status(400).json({ 
                    error: 'Agent ID is required' 
                });
                return;
            }

            const settings = req.body;
            await this.reminderService.updateReminderSettings(agentId, settings);
            console.log('✅ CONTROLLER: updateReminderSettings - Success');
            
            res.status(200).json({ message: 'Settings updated successfully' });
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: updateReminderSettings - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to update reminder settings', 
                message: errorMessage 
            });
        }
    };

    /** Validate phone number */
    public validatePhoneNumber = async (req: Request, res: Response): Promise<void> => {
        console.log('📞 CONTROLLER: validatePhoneNumber - Starting...');
        
        try {
            const { phoneNumber, countryCode } = req.body;
            
            if (!phoneNumber) {
                console.error('❌ Phone number is required');
                res.status(400).json({ 
                    error: 'Phone number is required' 
                });
                return;
            }

            const result = await this.reminderService.validatePhoneNumber(phoneNumber, countryCode);
            console.log('✅ CONTROLLER: validatePhoneNumber - Success:', result);
            
            res.status(200).json(result);
        } catch (error: unknown) {
            console.error('❌ CONTROLLER: validatePhoneNumber - Error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({ 
                error: 'Failed to validate phone number', 
                message: errorMessage 
            });
        }
    };
}