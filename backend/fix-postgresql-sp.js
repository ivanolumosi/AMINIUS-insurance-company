const fs = require('fs');

class PostgreSQLStoredProcedureFixer {
    constructor() {
        this.fixes = [];
    }

    fixSQLFile(filePath) {
        console.log(`🔍 Fixing PostgreSQL stored procedures: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create backup
        const backupPath = `${filePath}.fixed-backup`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Apply fixes
        content = this.fixDollarQuoting(content);
        content = this.fixReturnStatements(content);
        content = this.fixLanguageDeclaration(content);
        content = this.fixFunctionBodies(content);

        if (content !== originalContent) {
            fs.writeFileSync(filePath, content);
            console.log(`✅ File fixed successfully!`);
            
            if (this.fixes.length > 0) {
                console.log(`🔧 Applied ${this.fixes.length} fixes:`);
                this.fixes.forEach(fix => console.log(`   - ${fix}`));
            }
            
            return true;
        } else {
            console.log(`ℹ️  No fixes needed`);
            return false;
        }
    }

    fixDollarQuoting(content) {
        // Pattern 1: Fix incomplete dollar quoting like "AS $" -> "AS $$"
        content = content.replace(/AS\s+\$\s*\$\$/g, 'AS $$');
        
        // Pattern 2: Fix functions that end with just "$;" instead of "$$;"
        content = content.replace(/\$;/g, '$$;');
        
        // Pattern 3: Fix mismatched dollar quotes in the middle of functions
        content = content.replace(/AS\s+\$\s*\n/g, 'AS $$\n');
        
        this.fixes.push('Fixed dollar quoting syntax');
        return content;
    }

    fixReturnStatements(content) {
        // Fix RETURN statements that might be causing issues
        content = content.replace(/RETURN QUERY\s+SELECT\s+([^;]+);?\s*END;?\s*\$\$/g, 
            'RETURN QUERY\n    SELECT $1;\nEND;\n$$');
        
        this.fixes.push('Fixed RETURN statement formatting');
        return content;
    }

    fixLanguageDeclaration(content) {
        // Ensure all functions have proper LANGUAGE declaration
        content = content.replace(/\$\$\s*;/g, '$$ LANGUAGE plpgsql;');
        
        // Fix functions where LANGUAGE is declared before AS clause
        content = content.replace(
            /(CREATE OR REPLACE FUNCTION[^)]+\))\s*LANGUAGE\s+plpgsql\s+AS\s+\$\$/g,
            '$1\nAS $$'
        );
        
        // Add LANGUAGE plpgsql after $$ if missing
        content = content.replace(
            /END;\s*\$\$(?!\s*LANGUAGE)/g,
            'END;\n$$ LANGUAGE plpgsql'
        );
        
        this.fixes.push('Fixed LANGUAGE declarations');
        return content;
    }

    fixFunctionBodies(content) {
        // Fix specific patterns that cause syntax errors
        
        // Pattern 1: Fix VARCHAR without length specification in RETURNS
        content = content.replace(/RETURNS TABLE\([^)]*company_name VARCHAR\)/g, 
            (match) => match.replace('VARCHAR)', 'VARCHAR(200))'));
        
        content = content.replace(/RETURNS TABLE\([^)]*type_name VARCHAR\)/g, 
            (match) => match.replace('VARCHAR)', 'VARCHAR(200))'));

        // Pattern 2: Ensure proper spacing around operators
        content = content.replace(/::INTEGER/g, '::INTEGER');
        content = content.replace(/::TEXT/g, '::TEXT');
        content = content.replace(/::UUID/g, '::UUID');
        content = content.replace(/::VARCHAR\((\d+)\)/g, '::VARCHAR($1)');
        content = content.replace(/::JSON/g, '::JSON');

        // Pattern 3: Fix malformed AS clauses
        content = content.replace(/AS\s+\$\s+\$\$/g, 'AS $$');

        this.fixes.push('Fixed function body syntax');
        return content;
    }

    // Method to create a completely corrected version of the sample functions
    generateCorrectedSample() {
        return `-- ============================================
-- Agent Management Functions - PostgreSQL Version
-- ============================================

-- Upsert Agent Function
CREATE OR REPLACE FUNCTION sp_upsert_agent(
    p_first_name VARCHAR(50),
    p_last_name VARCHAR(50),
    p_email VARCHAR(100),
    p_phone VARCHAR(20),
    p_password_hash VARCHAR(200),
    p_agent_id UUID DEFAULT NULL,
    p_avatar TEXT DEFAULT NULL
)
RETURNS TABLE(agent_id UUID)
AS $$
DECLARE
    v_agent_id UUID;
BEGIN
    IF p_agent_id IS NULL THEN
        v_agent_id := gen_random_uuid();

        INSERT INTO agent (agent_id, first_name, last_name, email, phone, password_hash, avatar)
        VALUES (v_agent_id, p_first_name, p_last_name, p_email, p_phone, p_password_hash, p_avatar);

        -- Insert default reminder settings for new agent
        INSERT INTO reminder_settings (agent_id, reminder_type, days_before, time_of_day)
        VALUES 
            (v_agent_id, 'Policy Expiry', 30, '09:00'),
            (v_agent_id, 'Birthday', 1, '08:00'),
            (v_agent_id, 'Appointment', 1, '18:00'),
            (v_agent_id, 'Call', 0, '10:00');
    ELSE
        v_agent_id := p_agent_id;
        
        UPDATE agent
        SET 
            first_name = p_first_name,
            last_name = p_last_name,
            email = p_email,
            phone = p_phone,
            password_hash = p_password_hash,
            avatar = p_avatar,
            modified_date = NOW()
        WHERE agent.agent_id = p_agent_id;
    END IF;

    RETURN QUERY SELECT v_agent_id;
END;
$$ LANGUAGE plpgsql;

-- Get Agent Profile
CREATE OR REPLACE FUNCTION sp_get_agent(p_agent_id UUID)
RETURNS TABLE(
    agent_id UUID,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    password_hash VARCHAR(200),
    avatar TEXT,
    created_date TIMESTAMP,
    modified_date TIMESTAMP,
    is_active BOOLEAN,
    dark_mode BOOLEAN,
    email_notifications BOOLEAN,
    sms_notifications BOOLEAN,
    whatsapp_notifications BOOLEAN,
    push_notifications BOOLEAN,
    sound_enabled BOOLEAN
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.agent_id,
        a.first_name,
        a.last_name,
        a.email,
        a.phone,
        a.password_hash,
        a.avatar,
        a.created_date,
        a.modified_date,
        a.is_active,
        s.dark_mode,
        s.email_notifications,
        s.sms_notifications,
        s.whatsapp_notifications,
        s.push_notifications,
        s.sound_enabled
    FROM agent a
    LEFT JOIN agent_settings s ON a.agent_id = s.agent_id
    WHERE a.agent_id = p_agent_id AND a.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Update Agent Settings
CREATE OR REPLACE FUNCTION sp_update_agent_settings(
    p_agent_id UUID,
    p_dark_mode BOOLEAN DEFAULT NULL,
    p_email_notifications BOOLEAN DEFAULT NULL,
    p_sms_notifications BOOLEAN DEFAULT NULL,
    p_whatsapp_notifications BOOLEAN DEFAULT NULL,
    p_push_notifications BOOLEAN DEFAULT NULL,
    p_sound_enabled BOOLEAN DEFAULT NULL
)
RETURNS VOID
AS $$
BEGIN
    -- Check if settings exist, create if not
    IF NOT EXISTS (SELECT 1 FROM agent_settings WHERE agent_id = p_agent_id) THEN
        INSERT INTO agent_settings (agent_id) VALUES (p_agent_id);
    END IF;
    
    UPDATE agent_settings 
    SET 
        dark_mode = COALESCE(p_dark_mode, dark_mode),
        email_notifications = COALESCE(p_email_notifications, email_notifications),
        sms_notifications = COALESCE(p_sms_notifications, sms_notifications),
        whatsapp_notifications = COALESCE(p_whatsapp_notifications, whatsapp_notifications),
        push_notifications = COALESCE(p_push_notifications, push_notifications),
        sound_enabled = COALESCE(p_sound_enabled, sound_enabled),
        modified_date = NOW()
    WHERE agent_id = p_agent_id;
END;
$$ LANGUAGE plpgsql;

-- Get Insurance Companies
CREATE OR REPLACE FUNCTION sp_get_insurance_companies()
RETURNS TABLE(company_id INTEGER, company_name VARCHAR(200))
AS $$
BEGIN
    RETURN QUERY
    SELECT ic.company_id, ic.company_name
    FROM insurance_companies ic
    WHERE ic.is_active = true
    ORDER BY ic.company_name;
END;
$$ LANGUAGE plpgsql;

-- Get Policy Types
CREATE OR REPLACE FUNCTION sp_get_policy_types()
RETURNS TABLE(type_id INTEGER, type_name VARCHAR(200))
AS $$
BEGIN
    RETURN QUERY
    SELECT pt.type_id, pt.type_name
    FROM policy_types pt
    WHERE pt.is_active = true
    ORDER BY pt.type_name;
END;
$$ LANGUAGE plpgsql;

-- Authenticate Agent
CREATE OR REPLACE FUNCTION sp_authenticate_agent(p_email VARCHAR(100))
RETURNS TABLE(
    agent_id UUID,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    password_hash VARCHAR(200)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.agent_id,
        a.first_name,
        a.last_name,
        a.email,
        a.phone,
        a.password_hash
    FROM agent a
    WHERE a.email = p_email AND a.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Get Dashboard Overview
CREATE OR REPLACE FUNCTION sp_get_dashboard_overview(p_agent_id UUID)
RETURNS TABLE(
    total_clients BIGINT,
    total_prospects BIGINT,
    active_policies BIGINT,
    today_appointments BIGINT,
    week_appointments BIGINT,
    month_appointments BIGINT,
    completed_appointments BIGINT,
    pending_reminders BIGINT,
    today_birthdays BIGINT,
    expiring_policies BIGINT
)
AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_week_start DATE := v_today - EXTRACT(DOW FROM v_today)::INTEGER;
    v_week_end DATE := v_week_start + 6;
    v_month_start DATE := DATE_TRUNC('month', v_today)::DATE;
    v_month_end DATE := (DATE_TRUNC('month', v_today) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    RETURN QUERY
    SELECT 
        -- Client Statistics
        COUNT(DISTINCT CASE WHEN c.is_client = true THEN c.client_id END) AS total_clients,
        COUNT(DISTINCT CASE WHEN c.is_client = false THEN c.client_id END) AS total_prospects,
        
        -- Policy Statistics
        COUNT(DISTINCT CASE WHEN cp.status = 'Active' THEN cp.policy_id END) AS active_policies,
        
        -- Appointment Statistics
        COUNT(DISTINCT CASE WHEN a.appointment_date = v_today THEN a.appointment_id END) AS today_appointments,
        COUNT(DISTINCT CASE WHEN a.appointment_date BETWEEN v_week_start AND v_week_end THEN a.appointment_id END) AS week_appointments,
        COUNT(DISTINCT CASE WHEN a.appointment_date BETWEEN v_month_start AND v_month_end THEN a.appointment_id END) AS month_appointments,
        COUNT(DISTINCT CASE WHEN a.status = 'Completed' THEN a.appointment_id END) AS completed_appointments,
        
        -- Reminder Statistics
        COUNT(DISTINCT CASE WHEN r.status = 'Active' AND r.reminder_date <= v_today THEN r.reminder_id END) AS pending_reminders,
        
        -- Birthday Statistics
        COUNT(DISTINCT CASE WHEN EXTRACT(DAY FROM c.date_of_birth) = EXTRACT(DAY FROM v_today) 
                                AND EXTRACT(MONTH FROM c.date_of_birth) = EXTRACT(MONTH FROM v_today) 
                           THEN c.client_id END) AS today_birthdays,
        
        -- Expiring Policies
        COUNT(DISTINCT CASE WHEN cp.end_date BETWEEN v_today AND v_today + 30 AND cp.status = 'Active' 
                           THEN cp.policy_id END) AS expiring_policies
        
    FROM clients c
    LEFT JOIN client_policies cp ON c.client_id = cp.client_id AND cp.is_active = true
    LEFT JOIN appointments a ON c.client_id = a.client_id AND a.is_active = true
    LEFT JOIN reminders r ON c.client_id = r.client_id
    WHERE c.agent_id = p_agent_id AND c.is_active = true;
END;
$$ LANGUAGE plpgsql;`;
    }
}

// Main execution
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🔧 PostgreSQL Stored Procedure Fixer

Usage: 
  node fix-postgresql-sp.js <path-to-sql-file>
  node fix-postgresql-sp.js --create-sample

Examples:
  node fix-postgresql-sp.js ./migrations/999_create_stored_procedure.sql
  node fix-postgresql-sp.js --create-sample > corrected_sample.sql
        `);
        process.exit(1);
    }

    const fixer = new PostgreSQLStoredProcedureFixer();

    if (args[0] === '--create-sample') {
        console.log(fixer.generateCorrectedSample());
        process.exit(0);
    }

    const filePath = args[0];
    const success = fixer.fixSQLFile(filePath);
    
    if (success) {
        console.log(`\n🚀 Try running your migration again:`);
        console.log(`   npm run migrate`);
    } else {
        console.log(`\n📝 If issues persist, check the specific syntax around the error positions.`);
    }
}

module.exports = PostgreSQLStoredProcedureFixer;