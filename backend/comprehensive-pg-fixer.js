const fs = require('fs');

class ComprehensivePostgreSQLFixer {
    constructor() {
        this.fixes = [];
        this.errors = [];
    }

    fixAllSyntaxIssues(filePath) {
        console.log(`🔍 Comprehensive PostgreSQL syntax fix for: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create backup
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupPath = `${filePath}.backup-${timestamp}`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Apply all fixes in order
        content = this.fixDollarQuoting(content);
        content = this.fixLanguageDeclarations(content);
        content = this.fixFunctionReturns(content);
        content = this.fixDeclareSyntax(content);
        content = this.fixSpecificPatterns(content);

        // Write fixed content
        if (content !== originalContent) {
            fs.writeFileSync(filePath, content);
            console.log(`✅ File fixed successfully!`);
            
            if (this.fixes.length > 0) {
                console.log(`🔧 Applied ${this.fixes.length} fixes:`);
                this.fixes.forEach(fix => console.log(`   - ${fix}`));
            }
            
            return true;
        } else {
            console.log(`ℹ️  No changes needed`);
            return false;
        }
    }

    fixDollarQuoting(content) {
        let fixCount = 0;

        // Fix 1: AS $ followed by content -> AS $$
        content = content.replace(/AS\s+\$\s*(?=\s*DECLARE|BEGIN)/g, 'AS $$');
        fixCount++;

        // Fix 2: AS $ followed by $$ -> AS $$
        content = content.replace(/AS\s+\$\s*\$\$/g, 'AS $$');
        fixCount++;

        // Fix 3: Incomplete dollar quotes at end - $; -> $$ LANGUAGE plpgsql;
        content = content.replace(/\$\s*;/g, '$$ LANGUAGE plpgsql;');
        fixCount++;

        // Fix 4: Missing opening $$ after LANGUAGE plpgsql
        content = content.replace(/(LANGUAGE\s+plpgsql)\s+(AS\s+)([^$])/g, '$1\n$2$$\n$3');

        // Fix 5: Ensure proper dollar quote pairing
        content = content.replace(/AS\s+\$([^$])/g, 'AS $$\n$1');

        if (fixCount > 0) {
            this.fixes.push(`Fixed ${fixCount} dollar quoting issues`);
        }

        return content;
    }

    fixLanguageDeclarations(content) {
        let fixCount = 0;

        // Pattern 1: Functions with LANGUAGE before AS - move LANGUAGE after $$
        content = content.replace(
            /(CREATE\s+OR\s+REPLACE\s+FUNCTION[^)]+\))\s*RETURNS?[^L]*LANGUAGE\s+plpgsql\s+AS\s+\$\$/g,
            (match, funcDeclaration) => {
                const returnsMatch = match.match(/RETURNS?\s+[^L]+/);
                const returnsClause = returnsMatch ? returnsMatch[0].replace(/\s*LANGUAGE\s+plpgsql\s+AS\s+\$\$$/, '') : '';
                fixCount++;
                return `${funcDeclaration}\n${returnsClause}\nAS $$`;
            }
        );

        // Pattern 2: Add missing LANGUAGE plpgsql where needed
        content = content.replace(
            /END;\s*\$\$(?!\s*LANGUAGE)/g, 
            'END;\n$$ LANGUAGE plpgsql;'
        );
        
        if (fixCount > 0) {
            this.fixes.push(`Fixed ${fixCount} LANGUAGE declaration issues`);
        }

        return content;
    }

    fixFunctionReturns(content) {
        // Fix RETURNS TABLE with missing VARCHAR lengths
        content = content.replace(
            /RETURNS\s+TABLE\(([^)]*)\)/g, 
            (match, tableFields) => {
                const fixed = tableFields.replace(/\bVARCHAR\b(?!\s*\()/g, 'VARCHAR(200)');
                if (fixed !== tableFields) {
                    this.fixes.push('Fixed VARCHAR types in RETURNS TABLE');
                }
                return `RETURNS TABLE(${fixed})`;
            }
        );

        // Fix return statements formatting
        content = content.replace(
            /RETURN\s+QUERY\s+SELECT\s+([^;]*);(\s*END;)/g,
            'RETURN QUERY\n    SELECT $1;$2'
        );

        return content;
    }

    fixDeclareSyntax(content) {
        // Ensure DECLARE blocks are properly formatted
        content = content.replace(
            /(\$\$\s*)(DECLARE[^B]+)(BEGIN)/g,
            '$1$2\n$3'
        );

        // Fix missing semicolons in DECLARE blocks
        content = content.replace(
            /DECLARE\s*([^;]+)(\s+BEGIN)/g,
            'DECLARE\n    $1;\n$2'
        );

        return content;
    }

    fixSpecificPatterns(content) {
        let fixCount = 0;

        // Fix specific patterns from your code:
        
        // Pattern 1: Fix "AS $ $$" -> "AS $$"
        const pattern1Before = content;
        content = content.replace(/AS\s+\$\s+\$\$/g, 'AS $$');
        if (content !== pattern1Before) {
            fixCount++;
            this.fixes.push('Fixed "AS $ $$" patterns');
        }

        // Pattern 2: Fix functions ending with just "$;"
        const pattern2Before = content;
        content = content.replace(/([^$])\$;/g, '$1$$ LANGUAGE plpgsql;');
        if (content !== pattern2Before) {
            fixCount++;
            this.fixes.push('Fixed incomplete function endings');
        }

        // Pattern 3: Fix "$ LANGUAGE" -> "$$ LANGUAGE"
        const pattern3Before = content;
        content = content.replace(/\$\s+LANGUAGE\s+plpgsql/g, '$$ LANGUAGE plpgsql');
        if (content !== pattern3Before) {
            fixCount++;
            this.fixes.push('Fixed dollar quote before LANGUAGE');
        }

        // Pattern 4: Ensure proper spacing around operators
        content = content.replace(/::(\w+)/g, '::$1');

        return content;
    }

    validateAndReport(content) {
        const issues = [];
        
        // Check for common remaining issues
        if (content.includes('AS $')) {
            const matches = content.match(/AS\s+\$/g) || [];
            issues.push(`Found ${matches.length} potential "AS $" issues`);
        }

        if (content.includes('$;')) {
            const matches = content.match(/\$;/g) || [];
            issues.push(`Found ${matches.length} incomplete dollar quote endings`);
        }

        // Check for unmatched dollar quotes
        const dollarQuotes = content.match(/\$\$/g) || [];
        if (dollarQuotes.length % 2 !== 0) {
            issues.push('Unmatched dollar quotes detected');
        }

        if (issues.length > 0) {
            console.log(`⚠️  Potential remaining issues:`);
            issues.forEach(issue => console.log(`   - ${issue}`));
        } else {
            console.log(`✅ No obvious syntax issues detected`);
        }

        return issues.length === 0;
    }

    // Generate corrected sample of problematic functions
    generateFixedSample() {
        return `-- ============================================
-- CORRECTED UTILITY FUNCTIONS
-- ============================================

-- Calculate Age Function (FIXED)
CREATE OR REPLACE FUNCTION fn_calculate_age(p_date_of_birth DATE)
RETURNS INTEGER
AS $$
BEGIN
    RETURN DATE_PART('year', AGE(CURRENT_DATE, p_date_of_birth))::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Calculate Days Until Expiry Function (FIXED)
CREATE OR REPLACE FUNCTION fn_days_until_expiry(p_expiry_date DATE)
RETURNS INTEGER
AS $$
BEGIN
    RETURN (p_expiry_date - CURRENT_DATE)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Generate ID Function (FIXED)
CREATE OR REPLACE FUNCTION fn_generate_id()
RETURNS UUID
AS $$
BEGIN
    RETURN gen_random_uuid();
END;
$$ LANGUAGE plpgsql;

-- Get Greeting Function (FIXED)
CREATE OR REPLACE FUNCTION sp_get_greeting()
RETURNS TABLE(greeting VARCHAR(20))
AS $$
DECLARE
    v_current_hour INTEGER;
    v_greeting VARCHAR(20);
BEGIN
    v_current_hour := EXTRACT(HOUR FROM CURRENT_TIME);
    
    v_greeting := CASE 
        WHEN v_current_hour < 12 THEN 'Good Morning'
        WHEN v_current_hour < 17 THEN 'Good Afternoon'
        ELSE 'Good Evening'
    END;
    
    RETURN QUERY SELECT v_greeting;
END;
$$ LANGUAGE plpgsql;

-- Cancel Scheduled Notification (FIXED)
CREATE OR REPLACE FUNCTION sp_cancel_scheduled_notification(
    p_notification_id UUID,
    p_agent_id UUID
)
RETURNS TABLE(rows_affected INTEGER)
AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    UPDATE notifications 
    SET status = 'Cancelled'
    WHERE notification_id = p_notification_id 
        AND agent_id = p_agent_id 
        AND status = 'Pending';
    
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    RETURN QUERY SELECT v_rows_affected;
END;
$$ LANGUAGE plpgsql;

-- Process Scheduled Notifications (FIXED)
CREATE OR REPLACE FUNCTION sp_process_scheduled_notifications()
RETURNS TABLE(
    notification_id UUID,
    agent_id UUID,
    notification_type VARCHAR(20),
    recipient VARCHAR(200),
    subject VARCHAR(200),
    body TEXT,
    scheduled_time TIMESTAMPTZ
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.notification_id,
        n.agent_id,
        n.notification_type,
        n.recipient,
        n.subject,
        n.body,
        n.scheduled_time
    FROM notifications n
    WHERE n.status = 'Pending'
        AND n.scheduled_time IS NOT NULL
        AND n.scheduled_time <= NOW()
    ORDER BY n.scheduled_time ASC;
END;
$$ LANGUAGE plpgsql;`;
    }

    analyzeErrorAtPosition(content, position) {
        const lines = content.split('\n');
        let currentPos = 0;
        
        for (let i = 0; i < lines.length; i++) {
            const lineLength = lines[i].length + 1; // +1 for newline
            
            if (currentPos + lineLength > position) {
                const columnPos = position - currentPos;
                console.log(`\n📍 ERROR LOCATION - Line ${i + 1}, Column ${columnPos}:`);
                console.log(`   ${lines[i]}`);
                
                if (columnPos > 0) {
                    console.log(`   ${' '.repeat(Math.max(0, columnPos - 1))}^`);
                }
                
                // Show context
                const start = Math.max(0, i - 3);
                const end = Math.min(lines.length, i + 4);
                console.log(`\n📝 CONTEXT:`);
                for (let j = start; j < end; j++) {
                    const marker = j === i ? '>>> ' : '    ';
                    console.log(`${marker}${j + 1}: ${lines[j]}`);
                }
                
                // Analyze the specific issue
                this.analyzeSpecificError(lines[i], columnPos);
                break;
            }
            currentPos += lineLength;
        }
    }

    analyzeSpecificError(line, column) {
        console.log(`\n🔍 ERROR ANALYSIS:`);
        
        if (line.includes('AS $')) {
            console.log(`   - Found "AS $" - should be "AS $$"`);
        }
        
        if (line.includes('$;')) {
            console.log(`   - Found "$;" - should be "$$ LANGUAGE plpgsql;"`);
        }
        
        if (line.includes('LANGUAGE plpgsql') && line.includes('AS')) {
            console.log(`   - LANGUAGE declaration in wrong position`);
        }
        
        if (line.includes('RETURN') && !line.includes('$$')) {
            console.log(`   - RETURN statement may need proper dollar quoting`);
        }
    }
}

// Main execution
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🔧 Comprehensive PostgreSQL Stored Procedure Syntax Fixer

Usage:
  node comprehensive-pg-fixer.js <sql-file> [options]

Options:
  --analyze-position <position>  Analyze error at specific position
  --create-sample               Generate corrected sample code

Examples:
  node comprehensive-pg-fixer.js ./migrations/999_create_stored_procedure.sql
  node comprehensive-pg-fixer.js ./migrations/999_create_stored_procedure.sql --analyze-position 1558
  node comprehensive-pg-fixer.js --create-sample > fixed_sample.sql
        `);
        process.exit(1);
    }

    const fixer = new ComprehensivePostgreSQLFixer();

    // Handle sample generation
    if (args[0] === '--create-sample') {
        console.log(fixer.generateFixedSample());
        process.exit(0);
    }

    const filePath = args[0];

    // Handle position analysis
    const posIndex = args.indexOf('--analyze-position');
    if (posIndex !== -1 && args[posIndex + 1]) {
        const position = parseInt(args[posIndex + 1]);
        console.log(`🎯 Analyzing error at position ${position}`);
        
        if (fs.existsSync(filePath)) {
            const content = fs.readFileSync(filePath, 'utf8');
            fixer.analyzeErrorAtPosition(content, position);
        }
        console.log('\n');
    }

    // Apply fixes
    const success = fixer.fixAllSyntaxIssues(filePath);
    
    if (success) {
        // Validate the result
        const content = fs.readFileSync(filePath, 'utf8');
        const isValid = fixer.validateAndReport(content);
        
        console.log(`\n🚀 Try running your migration again:`);
        console.log(`   npm run migrate`);
        
        if (!isValid) {
            console.log(`\n⚠️  If issues persist, run with --analyze-position flag`);
        }
    }
}

module.exports = ComprehensivePostgreSQLFixer;