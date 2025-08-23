import { Request, Response } from 'express';
import { ReminderService, ReminderStatistics } from '../services/reminder.service';
import { Reminder } from '../interfaces/reminders';

export class RemindersController {
  private reminderService: ReminderService;

  constructor() {
    this.reminderService = new ReminderService();
    console.log('🚀 RemindersController initialized');
  }

  /** =====================
   * Reminder CRUD
   * ===================== */
  async create(req: Request, res: Response) {
    console.log('📝 CREATE REMINDER - Controller method started');
    console.log('📝 Request URL:', req.originalUrl);
    console.log('📝 Request Method:', req.method);
    console.log('📝 Request Headers:', JSON.stringify(req.headers, null, 2));
    
    try {
      const { agentId } = req.params;
      console.log('📝 AgentId from params:', agentId);
      console.log('📝 Request body received:', JSON.stringify(req.body, null, 2));
      console.log('📝 Request body type:', typeof req.body);
      console.log('📝 Request body keys:', Object.keys(req.body || {}));

      // Validate agentId
      if (!agentId) {
        console.error('❌ CREATE REMINDER - Missing agentId');
        return res.status(400).json({ message: "AgentId is required", error: "Missing agentId parameter" });
      }

      // Validate request body
      if (!req.body) {
        console.error('❌ CREATE REMINDER - Missing request body');
        return res.status(400).json({ message: "Request body is required", error: "Missing request body" });
      }

      // Validate required fields
      const requiredFields = ['Title', 'ReminderDate', 'ReminderType'];
      const missingFields = requiredFields.filter(field => !req.body[field]);
      
      if (missingFields.length > 0) {
        console.error('❌ CREATE REMINDER - Missing required fields:', missingFields);
        return res.status(400).json({ 
          message: "Missing required fields", 
          error: `Missing fields: ${missingFields.join(', ')}`,
          requiredFields,
          receivedFields: Object.keys(req.body)
        });
      }

      console.log('✅ CREATE REMINDER - Validation passed, calling service...');
      console.log('✅ Service method: reminderService.createReminder');
      console.log('✅ Service args:', { agentId, body: req.body });

      const reminder = await this.reminderService.createReminder(agentId, req.body);
      
      console.log('✅ CREATE REMINDER - Service returned successfully');
      console.log('✅ Created reminder:', JSON.stringify(reminder, null, 2));
      
      res.status(201).json(reminder);
      console.log('✅ CREATE REMINDER - Response sent with status 201');

    } catch (error: any) {
      console.error('❌ CREATE REMINDER - Error occurred:');
      console.error('❌ Error type:', typeof error);
      console.error('❌ Error constructor:', error.constructor.name);
      console.error('❌ Error message:', error.message);
      console.error('❌ Error stack:', error.stack);
      console.error('❌ Full error object:', error);

      // Check if it's a database error
      if (error.code) {
        console.error('❌ Database error code:', error.code);
        console.error('❌ Database error details:', error.detail);
      }

      // Check if it's a validation error
      if (error.name === 'ValidationError') {
        console.error('❌ Validation error details:', error.errors);
      }

      res.status(500).json({ 
        message: "Failed to create reminder", 
        error: error.message,
        errorType: error.constructor.name,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  async getAll(req: Request, res: Response) {
    console.log('📋 GET ALL REMINDERS - Controller method started');
    console.log('📋 Request URL:', req.originalUrl);
    console.log('📋 Query params:', JSON.stringify(req.query, null, 2));

    try {
      const { agentId } = req.params;
      console.log('📋 AgentId from params:', agentId);

      if (!agentId) {
        console.error('❌ GET ALL REMINDERS - Missing agentId');
        return res.status(400).json({ message: "AgentId is required" });
      }

      console.log('📋 Calling service method: getAllReminders');
      const reminders = await this.reminderService.getAllReminders(agentId, req.query as any);
      
      console.log('✅ GET ALL REMINDERS - Service returned successfully');
      console.log('✅ Reminders count:', Array.isArray(reminders?.reminders) ? reminders.reminders.length : 'Not an array');
      console.log('✅ Response structure:', Object.keys(reminders || {}));
      
      res.json(reminders);
      console.log('✅ GET ALL REMINDERS - Response sent');

    } catch (error: any) {
      console.error('❌ GET ALL REMINDERS - Error occurred:');
      console.error('❌ Error message:', error.message);
      console.error('❌ Error stack:', error.stack);
      console.error('❌ Full error:', error);

      res.status(500).json({ 
        message: "Failed to get reminders", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  async getById(req: Request, res: Response) {
    console.log('🔍 GET REMINDER BY ID - Controller method started');
    console.log('🔍 Request URL:', req.originalUrl);

    try {
      const { agentId, reminderId } = req.params;
      console.log('🔍 AgentId:', agentId);
      console.log('🔍 ReminderId:', reminderId);

      if (!agentId || !reminderId) {
        console.error('❌ GET REMINDER BY ID - Missing parameters');
        return res.status(400).json({ message: "AgentId and ReminderId are required" });
      }

      console.log('🔍 Calling service method: getReminderById');
      const reminder = await this.reminderService.getReminderById(reminderId, agentId);
      
      if (!reminder) {
        console.log('🔍 Reminder not found');
        return res.status(404).json({ message: "Reminder not found" });
      }

      console.log('✅ GET REMINDER BY ID - Service returned successfully');
      res.json(reminder);

    } catch (error: any) {
      console.error('❌ GET REMINDER BY ID - Error:', error);
      res.status(500).json({ 
        message: "Failed to get reminder", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  async update(req: Request, res: Response) {
    console.log('✏️ UPDATE REMINDER - Controller method started');
    console.log('✏️ Request URL:', req.originalUrl);
    console.log('✏️ Request body:', JSON.stringify(req.body, null, 2));

    try {
      const { agentId, reminderId } = req.params;
      console.log('✏️ AgentId:', agentId);
      console.log('✏️ ReminderId:', reminderId);

      if (!agentId || !reminderId) {
        console.error('❌ UPDATE REMINDER - Missing parameters');
        return res.status(400).json({ message: "AgentId and ReminderId are required" });
      }

      console.log('✏️ Calling service method: updateReminder');
      const updated = await this.reminderService.updateReminder(reminderId, agentId, req.body);
      
      console.log('✅ UPDATE REMINDER - Service returned successfully');
      res.json(updated);

    } catch (error: any) {
      console.error('❌ UPDATE REMINDER - Error:', error);
      res.status(500).json({ 
        message: "Failed to update reminder", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  async delete(req: Request, res: Response) {
    console.log('🗑️ DELETE REMINDER - Controller method started');
    console.log('🗑️ Request URL:', req.originalUrl);

    try {
      const { agentId, reminderId } = req.params;
      console.log('🗑️ AgentId:', agentId);
      console.log('🗑️ ReminderId:', reminderId);

      if (!agentId || !reminderId) {
        console.error('❌ DELETE REMINDER - Missing parameters');
        return res.status(400).json({ message: "AgentId and ReminderId are required" });
      }

      console.log('🗑️ Calling service method: deleteReminder');
      const result = await this.reminderService.deleteReminder(reminderId, agentId);
      
      console.log('✅ DELETE REMINDER - Service returned successfully');
      res.json(result);

    } catch (error: any) {
      console.error('❌ DELETE REMINDER - Error:', error);
      res.status(500).json({ 
        message: "Failed to delete reminder", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  /** =====================
   * Reminder Actions
   * ===================== */
  async complete(req: Request, res: Response) {
    console.log('✅ COMPLETE REMINDER - Controller method started');
    console.log('✅ Request URL:', req.originalUrl);

    try {
      const { agentId, reminderId } = req.params;
      const { notes } = req.body;
      console.log('✅ AgentId:', agentId);
      console.log('✅ ReminderId:', reminderId);
      console.log('✅ Notes:', notes);

      if (!agentId || !reminderId) {
        console.error('❌ COMPLETE REMINDER - Missing parameters');
        return res.status(400).json({ message: "AgentId and ReminderId are required" });
      }

      console.log('✅ Calling service method: completeReminder');
      const result = await this.reminderService.completeReminder(reminderId, agentId, notes);
      
      console.log('✅ COMPLETE REMINDER - Service returned successfully');
      res.json(result);

    } catch (error: any) {
      console.error('❌ COMPLETE REMINDER - Error:', error);
      res.status(500).json({ 
        message: "Failed to complete reminder", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  /** =====================
   * Reminder Settings
   * ===================== */
  async getSettings(req: Request, res: Response) {
    console.log('⚙️ GET SETTINGS - Controller method started');

    try {
      const { agentId } = req.params;
      console.log('⚙️ AgentId:', agentId);

      if (!agentId) {
        console.error('❌ GET SETTINGS - Missing agentId');
        return res.status(400).json({ message: "AgentId is required" });
      }

      console.log('⚙️ Calling service method: getReminderSettings');
      const settings = await this.reminderService.getReminderSettings(agentId);
      
      console.log('✅ GET SETTINGS - Service returned successfully');
      res.json(settings);

    } catch (error: any) {
      console.error('❌ GET SETTINGS - Error:', error);
      res.status(500).json({ 
        message: "Failed to get reminder settings", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  async updateSettings(req: Request, res: Response) {
    console.log('⚙️ UPDATE SETTINGS - Controller method started');
    console.log('⚙️ Request body:', JSON.stringify(req.body, null, 2));

    try {
      const { agentId } = req.params;
      const { reminderType, isEnabled, daysBefore, timeOfDay, repeatDaily } = req.body;
      
      console.log('⚙️ AgentId:', agentId);
      console.log('⚙️ Settings data:', { reminderType, isEnabled, daysBefore, timeOfDay, repeatDaily });

      if (!agentId) {
        console.error('❌ UPDATE SETTINGS - Missing agentId');
        return res.status(400).json({ message: "AgentId is required" });
      }

      console.log('⚙️ Calling service method: updateReminderSettings');
      await this.reminderService.updateReminderSettings(agentId, reminderType, isEnabled, daysBefore, timeOfDay, repeatDaily);
      
      console.log('✅ UPDATE SETTINGS - Service returned successfully');
      res.json({ message: "Settings updated successfully" });

    } catch (error: any) {
      console.error('❌ UPDATE SETTINGS - Error:', error);
      res.status(500).json({ 
        message: "Failed to update settings", 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  /** =====================
   * Utility
   * ===================== */
  public getReminderStatistics = async (req: Request, res: Response): Promise<void> => {
    console.log('📊 GET STATISTICS - Controller method started');

    try {
      const { agentId } = req.params;
      console.log('📊 AgentId:', agentId);

      if (!agentId) {
        console.error('❌ GET STATISTICS - Missing agentId');
        res.status(400).json({ message: 'AgentId is required' });
        return;
      }

      console.log('📊 Calling service method: getReminderStatistics');
      const stats: ReminderStatistics = await this.reminderService.getReminderStatistics(agentId);
      
      console.log('✅ GET STATISTICS - Service returned successfully');
      console.log('✅ Statistics:', stats);
      res.status(200).json(stats);

    } catch (error: any) {
      console.error('❌ GET STATISTICS - Error:', error);
      res.status(500).json({ 
        message: 'Failed to fetch reminder statistics', 
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  };

  /**
   * Get reminders filtered by ReminderType
   * Route: GET /api/reminders/:agentId/type/:reminderType
   */
  async getRemindersByType(req: Request, res: Response): Promise<void> {
    console.log('🏷️ GET REMINDERS BY TYPE - Controller method started');
    console.log('🏷️ Request URL:', req.originalUrl);

    try {
      const { agentId, reminderType } = req.params;
      console.log('🏷️ AgentId:', agentId);
      console.log('🏷️ ReminderType:', reminderType);

      if (!agentId || !reminderType) {
        console.error('❌ GET REMINDERS BY TYPE - Missing parameters');
        res.status(400).json({ message: "AgentId and ReminderType are required" });
        return;
      }

      console.log('🏷️ Calling service method: getRemindersByType');
      const reminders: Reminder[] = await this.reminderService.getRemindersByType(agentId, reminderType);

      console.log('✅ GET REMINDERS BY TYPE - Service returned successfully');
      console.log('✅ Found reminders:', reminders?.length || 0);
      res.status(200).json(reminders);

    } catch (error: any) {
      console.error('❌ GET REMINDERS BY TYPE - Error:', error);
      res.status(500).json({ 
        message: 'Failed to fetch reminders by type',
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }

  /**
   * Get reminders filtered by Status
   * Route: GET /api/reminders/:agentId/status/:status
   */
  async getRemindersByStatus(req: Request, res: Response): Promise<void> {
    console.log('📊 GET REMINDERS BY STATUS - Controller method started');
    console.log('📊 Request URL:', req.originalUrl);

    try {
      const { agentId, status } = req.params;
      console.log('📊 AgentId:', agentId);
      console.log('📊 Status:', status);

      if (!agentId || !status) {
        console.error('❌ GET REMINDERS BY STATUS - Missing parameters');
        res.status(400).json({ message: "AgentId and Status are required" });
        return;
      }

      console.log('📊 Calling service method: getRemindersByStatus');
      const reminders: Reminder[] = await this.reminderService.getRemindersByStatus(agentId, status);

      console.log('✅ GET REMINDERS BY STATUS - Service returned successfully');
      console.log('✅ Found reminders:', reminders?.length || 0);
      res.status(200).json(reminders);

    } catch (error: any) {
      console.error('❌ GET REMINDERS BY STATUS - Error:', error);
      res.status(500).json({ 
        message: 'Failed to fetch reminders by status',
        error: error.message,
        ...(process.env.NODE_ENV === 'development' && { stack: error.stack })
      });
    }
  }
}