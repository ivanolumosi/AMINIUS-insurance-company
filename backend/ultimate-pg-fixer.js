const fs = require('fs');
const path = require('path');

class UltimatePostgreSQLFixer {
    constructor() {
        this.fixes = [];
        this.errorCount = 0;
    }

    fixAllIssues(filePath) {
        console.log(`🚀 Ultimate PostgreSQL syntax fix for: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create timestamped backup
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupPath = `${filePath}.backup-${timestamp}`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Apply comprehensive fixes in specific order
        content = this.fixBasicSyntaxErrors(content);
        content = this.fixDollarQuoting(content);
        content = this.fixFunctionStructure(content);
        content = this.fixLanguageDeclarations(content);
        content = this.fixDataTypes(content);
        content = this.finalCleanup(content);

        // Validate the result
        const validationResult = this.validateSyntax(content);
        
        if (validationResult.isValid) {
            fs.writeFileSync(filePath, content);
            console.log(`✅ File successfully fixed and validated!`);
            this.reportFixes();
            return true;
        } else {
            console.log(`⚠️  Validation found issues, creating corrected version...`);
            const correctedPath = `${filePath}.corrected`;
            fs.writeFileSync(correctedPath, content);
            console.log(`📄 Corrected file saved as: ${correctedPath}`);
            this.reportFixes();
            this.reportValidationIssues(validationResult);
            return false;
        }
    }

    fixBasicSyntaxErrors(content) {
        console.log('🔧 Fixing basic syntax errors...');
        
        // Fix common typos and malformed patterns
        const fixes = [
            // Fix incomplete dollar quotes
            { pattern: /AS\s+\$(?!\$)/g, replacement: 'AS $$', description: 'Fixed incomplete "AS $" to "AS $$"' },
            { pattern: /\$\s*;/g, replacement: '$$ LANGUAGE plpgsql;', description: 'Fixed "$;" to "$$ LANGUAGE plpgsql;"' },
            { pattern: /\$\s+LANGUAGE/g, replacement: '$$ LANGUAGE', description: 'Fixed "$ LANGUAGE" spacing' },
            
            // Fix function declaration issues
            { pattern: /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([^\s(]+)/gi, replacement: 'CREATE OR REPLACE FUNCTION $1', description: 'Normalized function declarations' },
            { pattern: /RETURNS?\s+TABLE\s*\(/gi, replacement: 'RETURNS TABLE(', description: 'Fixed RETURNS TABLE syntax' },
            
            // Fix common PostgreSQL keywords
            { pattern: /\bINTEGER\b/g, replacement: 'INTEGER', description: 'Normalized INTEGER keyword' },
            { pattern: /\bBOOLEAN\b/g, replacement: 'BOOLEAN', description: 'Normalized BOOLEAN keyword' },
            { pattern: /\bTIMESTAMP\b/g, replacement: 'TIMESTAMP', description: 'Normalized TIMESTAMP keyword' },
        ];

        fixes.forEach(fix => {
            const beforeCount = (content.match(fix.pattern) || []).length;
            content = content.replace(fix.pattern, fix.replacement);
            const afterCount = (content.match(fix.pattern) || []).length;
            
            if (beforeCount > afterCount) {
                this.fixes.push(`${fix.description} (${beforeCount - afterCount} instances)`);
            }
        });

        return content;
    }

    fixDollarQuoting(content) {
        console.log('🔧 Fixing dollar quoting...');
        
        // Split content into functions and fix each one
        const functionBlocks = this.extractFunctionBlocks(content);
        let fixedContent = '';
        
        functionBlocks.forEach((block, index) => {
            if (block.isFunction) {
                const fixedBlock = this.fixSingleFunction(block.content);
                fixedContent += fixedBlock;
            } else {
                fixedContent += block.content;
            }
        });

        return fixedContent;
    }

    extractFunctionBlocks(content) {
        const blocks = [];
        const functionRegex = /(CREATE\s+OR\s+REPLACE\s+FUNCTION[^;]*?(?:\$\$[\s\S]*?\$\$\s*LANGUAGE\s+plpgsql\s*;|\$\s*LANGUAGE\s+plpgsql\s*;|\$\$[\s\S]*?\$\$;?))/gi;
        
        let lastIndex = 0;
        let match;
        
        while ((match = functionRegex.exec(content)) !== null) {
            // Add non-function content before this function
            if (match.index > lastIndex) {
                const beforeContent = content.slice(lastIndex, match.index);
                if (beforeContent.trim()) {
                    blocks.push({ content: beforeContent, isFunction: false });
                }
            }
            
            // Add the function
            blocks.push({ content: match[0], isFunction: true });
            lastIndex = match.index + match[0].length;
        }
        
        // Add any remaining content
        if (lastIndex < content.length) {
            const remainingContent = content.slice(lastIndex);
            if (remainingContent.trim()) {
                blocks.push({ content: remainingContent, isFunction: false });
            }
        }
        
        return blocks;
    }

    fixSingleFunction(functionText) {
        // Extract function parts
        const headerMatch = functionText.match(/(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+[^(]+\([^)]*\)\s*RETURNS?[^A-Z]*?)(?:LANGUAGE\s+plpgsql\s+)?AS\s*/i);
        
        if (!headerMatch) {
            return functionText; // Can't parse, return as-is
        }

        const header = headerMatch[1].trim();
        const bodyStart = headerMatch.index + headerMatch[0].length;
        
        // Extract function body (everything after AS)
        let body = functionText.slice(bodyStart);
        
        // Clean up the body
        body = body.replace(/^\$\$?/, '').replace(/\$\$?\s*LANGUAGE\s+plpgsql\s*;?\s*$/, '').trim();
        body = body.replace(/\$\s*;?\s*$/, '').trim();
        
        // Ensure body has proper structure
        if (!body.includes('BEGIN')) {
            body = `BEGIN\n    ${body}`;
        }
        if (!body.match(/END\s*;?\s*$/)) {
            if (body.endsWith(';')) {
                body = body.slice(0, -1);
            }
            body += '\nEND;';
        } else {
            body = body.replace(/END\s*;?\s*$/, 'END;');
        }

        // Reconstruct the function
        const fixedFunction = `${header}\nAS $$\n${body}\n$$ LANGUAGE plpgsql;\n`;
        
        this.fixes.push(`Fixed function structure: ${header.match(/FUNCTION\s+([^\s(]+)/i)?.[1] || 'unknown'}`);
        return fixedFunction;
    }

    fixFunctionStructure(content) {
        console.log('🔧 Fixing function structure...');
        
        // Ensure proper indentation and formatting
        content = content.replace(/(BEGIN\s*\n)([\s\S]*?)(END;)/gi, (match, begin, body, end) => {
            // Indent the body content
            const indentedBody = body.split('\n')
                .map(line => line.trim() ? '    ' + line.trim() : '')
                .join('\n');
            
            return `${begin}${indentedBody}\n${end}`;
        });

        return content;
    }

    fixLanguageDeclarations(content) {
        console.log('🔧 Fixing LANGUAGE declarations...');
        
        // Ensure all functions end with proper LANGUAGE declaration
        content = content.replace(/END;\s*\$\$(?!\s*LANGUAGE)/g, 'END;\n$$ LANGUAGE plpgsql;');
        
        // Fix any remaining bare $$ at end of functions
        content = content.replace(/END;\s*\$\$\s*$/gm, 'END;\n$$ LANGUAGE plpgsql;');
        
        // Remove duplicate LANGUAGE declarations
        content = content.replace(/(\$\$ LANGUAGE plpgsql;)\s*(\$\$ LANGUAGE plpgsql;)/g, '$1');
        
        this.fixes.push('Normalized LANGUAGE declarations');
        return content;
    }

    fixDataTypes(content) {
        console.log('🔧 Fixing data types...');
        
        // Fix VARCHAR without length specifications
        content = content.replace(/\bVARCHAR\b(?!\s*\()/g, 'VARCHAR(255)');
        
        // Fix common data type issues
        content = content.replace(/\bTEXT\(\d+\)/g, 'TEXT');
        content = content.replace(/\bINT\b/g, 'INTEGER');
        
        this.fixes.push('Fixed data type specifications');
        return content;
    }

    finalCleanup(content) {
        console.log('🔧 Final cleanup...');
        
        // Remove excessive whitespace
        content = content.replace(/\n{3,}/g, '\n\n');
        
        // Ensure proper spacing around keywords
        content = content.replace(/(\w)(AS\s+\$\$)/g, '$1\n$2');
        content = content.replace(/(\$\$ LANGUAGE plpgsql;)(\w)/g, '$1\n\n$2');
        
        // Clean up comments and ensure they're properly formatted
        content = content.replace(/--([^\n]*)/g, '-- $1');
        
        this.fixes.push('Applied final cleanup');
        return content;
    }

    validateSyntax(content) {
        const issues = [];
        let isValid = true;

        // Check for unmatched dollar quotes
        const dollarQuotes = (content.match(/\$\$/g) || []).length;
        if (dollarQuotes % 2 !== 0) {
            issues.push(`Unmatched dollar quotes (found ${dollarQuotes}, should be even)`);
            isValid = false;
        }

        // Check for basic function structure
        const functions = content.match(/CREATE\s+OR\s+REPLACE\s+FUNCTION/gi) || [];
        const languageDeclarations = content.match(/\$\$ LANGUAGE plpgsql;/g) || [];
        
        if (functions.length !== languageDeclarations.length) {
            issues.push(`Function/LANGUAGE mismatch (${functions.length} functions, ${languageDeclarations.length} LANGUAGE declarations)`);
            isValid = false;
        }

        // Check for common syntax errors
        const commonErrors = [
            { pattern: /AS\s+\$(?!\$)/, error: 'Incomplete dollar quoting (AS $)' },
            { pattern: /\$\s*;/, error: 'Malformed function ending ($;)' },
            { pattern: /LANGUAGE\s+plpgsql\s+AS/, error: 'LANGUAGE before AS (should be after)' },
        ];

        commonErrors.forEach(check => {
            if (check.pattern.test(content)) {
                issues.push(check.error);
                isValid = false;
            }
        });

        return { isValid, issues };
    }

    reportFixes() {
        console.log(`\n📋 APPLIED FIXES (${this.fixes.length}):`);
        this.fixes.forEach((fix, index) => {
            console.log(`   ${index + 1}. ${fix}`);
        });
    }

    reportValidationIssues(validationResult) {
        if (validationResult.issues.length > 0) {
            console.log(`\n⚠️  VALIDATION ISSUES:`);
            validationResult.issues.forEach((issue, index) => {
                console.log(`   ${index + 1}. ${issue}`);
            });
        }
    }

    // Create a completely clean template file
    createCleanTemplate(outputPath) {
        const template = `-- ============================================
-- CLEANED PostgreSQL Stored Procedures
-- Generated by Ultimate PostgreSQL Fixer
-- ============================================

-- Get Agent Summary (Dashboard Stats)
CREATE OR REPLACE FUNCTION get_agent_summary(agent_id_param UUID)
RETURNS TABLE(
    total_policies INTEGER,
    active_policies INTEGER,
    expiring_in_30_days INTEGER,
    expiring_in_60_days INTEGER,
    total_companies INTEGER,
    total_clients INTEGER,
    inactive_policies INTEGER
) AS $$
DECLARE
    total_pol INTEGER := 0;
    active_pol INTEGER := 0;
    expiring_30 INTEGER := 0;
    expiring_60 INTEGER := 0;
    total_comp INTEGER := 0;
    total_cli INTEGER := 0;
BEGIN
    -- Get policy counts
    SELECT COUNT(*)::INTEGER
    INTO total_pol
    FROM client_policies cp
    JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = agent_id_param
      AND cp.is_active = TRUE;

    -- Get active policy count
    SELECT COUNT(*)::INTEGER
    INTO active_pol
    FROM client_policies cp
    JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = agent_id_param
      AND cp.is_active = TRUE
      AND cp.status = 'Active';

    -- Get policies expiring in 30 days
    SELECT COUNT(*)::INTEGER
    INTO expiring_30
    FROM client_policies cp
    JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = agent_id_param
      AND cp.is_active = TRUE
      AND cp.status = 'Active'
      AND cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days';

    -- Get policies expiring in 60 days
    SELECT COUNT(*)::INTEGER
    INTO expiring_60
    FROM client_policies cp
    JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = agent_id_param
      AND cp.is_active = TRUE
      AND cp.status = 'Active'
      AND cp.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days';

    -- Get company count
    SELECT COUNT(DISTINCT cp.company_id)::INTEGER
    INTO total_comp
    FROM client_policies cp
    JOIN clients c ON cp.client_id = c.client_id
    WHERE c.agent_id = agent_id_param
      AND cp.is_active = TRUE;

    -- Get client count
    SELECT COUNT(*)::INTEGER
    INTO total_cli
    FROM clients c
    WHERE c.agent_id = agent_id_param
      AND c.is_active = TRUE;

    -- Return result
    RETURN QUERY
    SELECT total_pol as total_policies,
        active_pol as active_policies,
        expiring_30 as expiring_in_30_days,
        expiring_60 as expiring_in_60_days,
        total_comp as total_companies,
        total_cli as total_clients,
        (total_pol - active_pol)::INTEGER as inactive_policies;
END;
$$ LANGUAGE plpgsql;

-- Update Policy Category
CREATE OR REPLACE FUNCTION update_policy_category(
    category_id_param UUID,
    category_name_param VARCHAR(50) DEFAULT NULL,
    description_param VARCHAR(200) DEFAULT NULL,
    is_active_param BOOLEAN DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    rows_affected INTEGER;
BEGIN
    UPDATE policy_categories
    SET 
        category_name = COALESCE(category_name_param, category_name),
        description = COALESCE(description_param, description),
        is_active = COALESCE(is_active_param, is_active)
    WHERE category_id = category_id_param;
    
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected;
END;
$$ LANGUAGE plpgsql;

-- Create Insurance Company
CREATE OR REPLACE FUNCTION sp_create_insurance_company(
    company_name_param VARCHAR(100),
    is_active_param BOOLEAN DEFAULT TRUE
)
RETURNS UUID AS $$
DECLARE
    new_company_id UUID;
BEGIN
    new_company_id := gen_random_uuid();
    
    INSERT INTO insurance_companies (company_id, company_name, is_active, created_date)
    VALUES (new_company_id, company_name_param, is_active_param, NOW());
    
    RETURN new_company_id;
END;
$$ LANGUAGE plpgsql;

-- Get All Insurance Companies
CREATE OR REPLACE FUNCTION sp_get_insurance_companies()
RETURNS TABLE(
    company_id UUID,
    company_name VARCHAR(100),
    is_active BOOLEAN,
    created_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT ic.company_id,
        ic.company_name,
        ic.is_active,
        ic.created_date
    FROM insurance_companies ic
    ORDER BY ic.company_name;
END;
$$ LANGUAGE plpgsql;
`;

        fs.writeFileSync(outputPath, template);
        console.log(`✅ Clean template created: ${outputPath}`);
        return true;
    }
}

// CLI Interface
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🚀 Ultimate PostgreSQL Syntax Fixer

This tool comprehensively fixes PostgreSQL stored procedure syntax issues.

Usage:
  node ultimate-pg-fixer.js <sql-file>                    # Fix existing file
  node ultimate-pg-fixer.js --create-template <output>    # Create clean template
  node ultimate-pg-fixer.js --help                        # Show this help

Examples:
  node ultimate-pg-fixer.js ./migrations/999_create_stored_procedure.sql
  node ultimate-pg-fixer.js --create-template ./clean_procedures.sql

Features:
  ✅ Fixes dollar quoting issues (AS $ → AS $$)
  ✅ Fixes function endings ($; → $$ LANGUAGE plpgsql;)
  ✅ Normalizes LANGUAGE declarations
  ✅ Fixes data type specifications
  ✅ Creates backup before making changes
  ✅ Validates syntax after fixing
  ✅ Provides detailed fix reports
        `);
        process.exit(0);
    }

    const fixer = new UltimatePostgreSQLFixer();

    if (args[0] === '--create-template') {
        const outputPath = args[1] || './clean_procedures.sql';
        fixer.createCleanTemplate(outputPath);
        process.exit(0);
    }

    if (args[0] === '--help') {
        process.argv = ['node', 'ultimate-pg-fixer.js'];
        return;
    }

    const filePath = args[0];
    console.log(`🎯 Processing file: ${filePath}`);
    
    const success = fixer.fixAllIssues(filePath);
    
    if (success) {
        console.log(`\n🎉 SUCCESS! Your file has been fixed and is ready to use.`);
        console.log(`\n📋 Next steps:`);
        console.log(`   1. Review the changes in your file`);
        console.log(`   2. Run your migration: npm run migrate`);
        console.log(`   3. If issues persist, check your database schema`);
    } else {
        console.log(`\n⚠️  Issues detected. Check the .corrected file and validation messages above.`);
    }
}

module.exports = UltimatePostgreSQLFixer;