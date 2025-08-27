const fs = require('fs');

class AggressivePostgreSQLFixer {
    constructor() {
        this.fixes = [];
    }

    fixAllIssues(filePath) {
        console.log(`🔧 Aggressive PostgreSQL syntax fix for: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create backup
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupPath = `${filePath}.aggressive-backup-${timestamp}`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Apply aggressive fixes
        content = this.aggressivelyFixDollarQuotes(content);
        content = this.fixLanguageDeclarations(content);
        content = this.fixSpecificPatterns(content);
        content = this.validateAndCleanup(content);

        // Write the fixed content
        fs.writeFileSync(filePath, content);
        
        console.log(`✅ Aggressive fix completed!`);
        if (this.fixes.length > 0) {
            console.log(`🔧 Applied fixes:`);
            this.fixes.forEach(fix => console.log(`   - ${fix}`));
        }

        return true;
    }

    aggressivelyFixDollarQuotes(content) {
        let fixCount = 0;

        // Fix 1: ALL "AS $" patterns (with various whitespace) -> "AS $$"
        const beforeFix1 = content;
        content = content.replace(/AS\s+\$(?!\$)/g, 'AS $$');
        if (content !== beforeFix1) {
            fixCount++;
            this.fixes.push('Fixed all "AS $" patterns to "AS $$"');
        }

        // Fix 2: ALL "$;" patterns -> "$$ LANGUAGE plpgsql;"
        const beforeFix2 = content;
        content = content.replace(/\$\s*;/g, '$$ LANGUAGE plpgsql;');
        if (content !== beforeFix2) {
            fixCount++;
            this.fixes.push('Fixed all "$;" to "$$ LANGUAGE plpgsql;"');
        }

        // Fix 3: Pattern "$ LANGUAGE" -> "$$ LANGUAGE"
        const beforeFix3 = content;
        content = content.replace(/\$\s+LANGUAGE/g, '$$ LANGUAGE');
        if (content !== beforeFix3) {
            fixCount++;
            this.fixes.push('Fixed "$ LANGUAGE" patterns');
        }

        // Fix 4: Functions with LANGUAGE before AS - completely restructure
        const functionRegex = /(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+[^(]+\([^)]*\)\s*RETURNS?[^L]*?)LANGUAGE\s+plpgsql\s+AS\s+\$\$([^]*?)(?=CREATE\s+OR\s+REPLACE\s+FUNCTION|$)/gi;
        
        content = content.replace(functionRegex, (match, funcDeclaration, body) => {
            fixCount++;
            // Clean the function declaration
            const cleanDeclaration = funcDeclaration.trim();
            // Clean the body and ensure it ends properly
            let cleanBody = body.trim();
            
            // Remove any trailing $$ LANGUAGE plpgsql; from body
            cleanBody = cleanBody.replace(/\$\$\s*LANGUAGE\s+plpgsql\s*;?\s*$/, '');
            cleanBody = cleanBody.replace(/\$\s*;?\s*$/, '');
            
            // Ensure body ends with END;
            if (!cleanBody.match(/END\s*;?\s*$/)) {
                cleanBody += '\nEND;';
            } else {
                cleanBody = cleanBody.replace(/END\s*;?\s*$/, 'END;');
            }
            
            return `${cleanDeclaration}\nAS $$\n${cleanBody}\n$$ LANGUAGE plpgsql;\n\n`;
        });

        if (fixCount > 0) {
            this.fixes.push(`Applied ${fixCount} aggressive dollar quote fixes`);
        }

        return content;
    }

    fixLanguageDeclarations(content) {
        // Ensure all functions end with proper LANGUAGE declaration
        content = content.replace(/END;\s*\$\$(?!\s*LANGUAGE)/g, 'END;\n$$ LANGUAGE plpgsql;');
        
        // Fix any remaining bare $$ at end of functions
        content = content.replace(/END;\s*\$\$\s*$/gm, 'END;\n$$ LANGUAGE plpgsql;');
        
        this.fixes.push('Fixed LANGUAGE declarations');
        return content;
    }

    fixSpecificPatterns(content) {
        // Fix VARCHAR without length in RETURNS TABLE
        content = content.replace(/RETURNS\s+TABLE\s*\([^)]*\bVARCHAR\b(?!\s*\()[^)]*\)/g, (match) => {
            return match.replace(/\bVARCHAR\b(?!\s*\()/g, 'VARCHAR(200)');
        });

        // Fix any remaining orphaned $ characters
        content = content.replace(/(\w)\$(\s)/g, '$1$$');

        // Ensure proper spacing around AS $$
        content = content.replace(/AS\s*\$\$\s*/g, 'AS $$\n');

        // Clean up multiple newlines
        content = content.replace(/\n{3,}/g, '\n\n');

        this.fixes.push('Fixed specific SQL patterns');
        return content;
    }

    validateAndCleanup(content) {
        // Final validation and cleanup
        
        // Count and report dollar quotes
        const dollarQuotes = content.match(/\$\$/g) || [];
        console.log(`📊 Found ${dollarQuotes.length} dollar quotes`);
        
        if (dollarQuotes.length % 2 !== 0) {
            console.log(`⚠️  Uneven number of dollar quotes - adding missing closing quote`);
            content += '\n$$';
        }

        // Ensure all functions are properly terminated
        content = content.replace(/(\$\$ LANGUAGE plpgsql);?/g, '$1;');

        return content;
    }

    analyzeAndShow(filePath, position) {
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return;
        }

        const content = fs.readFileSync(filePath, 'utf8');
        
        console.log(`🎯 Analyzing error at position ${position}`);
        
        // Find the exact location
        const lines = content.split('\n');
        let currentPos = 0;
        
        for (let i = 0; i < lines.length; i++) {
            const lineLength = lines[i].length + 1; // +1 for newline
            
            if (currentPos + lineLength > position) {
                const columnPos = position - currentPos;
                console.log(`\n📍 ERROR at Line ${i + 1}, Column ${columnPos}:`);
                console.log(`   ${lines[i]}`);
                
                if (columnPos > 0 && columnPos < lines[i].length) {
                    console.log(`   ${' '.repeat(columnPos - 1)}^`);
                }
                
                // Show more context
                const start = Math.max(0, i - 5);
                const end = Math.min(lines.length, i + 6);
                console.log(`\n📝 EXTENDED CONTEXT:`);
                for (let j = start; j < end; j++) {
                    const marker = j === i ? '>>> ' : '    ';
                    const lineNum = (j + 1).toString().padStart(3, ' ');
                    console.log(`${marker}${lineNum}: ${lines[j]}`);
                }
                
                // Analyze the specific issue
                this.diagnoseError(lines, i);
                break;
            }
            currentPos += lineLength;
        }
    }

    diagnoseError(lines, errorLine) {
        const currentLine = lines[errorLine];
        const prevLine = errorLine > 0 ? lines[errorLine - 1] : '';
        const nextLine = errorLine < lines.length - 1 ? lines[errorLine + 1] : '';

        console.log(`\n🔍 DIAGNOSIS:`);
        
        if (currentLine.includes('RETURN') && prevLine.includes('AS $')) {
            console.log(`   - RETURN statement after incomplete "AS $" - missing second $`);
            console.log(`   - FIX: Change "AS $" to "AS $$" in previous line`);
        }
        
        if (currentLine.includes('AS $') && !currentLine.includes('$$')) {
            console.log(`   - Incomplete dollar quoting: "AS $" should be "AS $$"`);
        }
        
        if (currentLine.includes('$;')) {
            console.log(`   - Incomplete function ending: "$;" should be "$$ LANGUAGE plpgsql;"`);
        }

        if (currentLine.includes('LANGUAGE plpgsql') && currentLine.includes('AS')) {
            console.log(`   - LANGUAGE declaration in wrong position - should be after function body`);
        }

        // Look for common function structure issues
        let inFunction = false;
        let hasBegin = false;
        let hasEnd = false;
        
        for (let i = Math.max(0, errorLine - 10); i <= Math.min(lines.length - 1, errorLine + 10); i++) {
            const line = lines[i];
            if (line.includes('CREATE OR REPLACE FUNCTION')) inFunction = true;
            if (line.includes('BEGIN')) hasBegin = true;
            if (line.includes('END;')) hasEnd = true;
        }

        if (inFunction && !hasBegin) {
            console.log(`   - Function missing BEGIN statement`);
        }
        if (inFunction && !hasEnd) {
            console.log(`   - Function missing END; statement`);
        }
    }

    // Method to create a minimal working example
    createMinimalExample() {
        return `-- MINIMAL WORKING POSTGRESQL FUNCTION EXAMPLE
CREATE OR REPLACE FUNCTION sp_test_function(p_input VARCHAR(50))
RETURNS TABLE(result VARCHAR(50))
AS $$
BEGIN
    RETURN QUERY SELECT p_input;
END;
$$ LANGUAGE plpgsql;`;
    }
}

// Main execution
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🔧 Aggressive PostgreSQL Syntax Fixer

This tool will aggressively fix ALL PostgreSQL syntax issues in your stored procedures.

Usage:
  node aggressive-pg-fixer.js <sql-file> [options]

Options:
  --analyze <position>     Analyze error at specific position first
  --minimal-example        Show minimal working function example

Examples:
  node aggressive-pg-fixer.js ./migrations/999_create_stored_procedure.sql --analyze 1575
  node aggressive-pg-fixer.js ./migrations/999_create_stored_procedure.sql
  node aggressive-pg-fixer.js --minimal-example
        `);
        process.exit(1);
    }

    const fixer = new AggressivePostgreSQLFixer();

    if (args[0] === '--minimal-example') {
        console.log(fixer.createMinimalExample());
        process.exit(0);
    }

    const filePath = args[0];

    // Handle analysis first if requested
    const analyzeIndex = args.indexOf('--analyze');
    if (analyzeIndex !== -1 && args[analyzeIndex + 1]) {
        const position = parseInt(args[analyzeIndex + 1]);
        fixer.analyzeAndShow(filePath, position);
        console.log('\n' + '='.repeat(60) + '\n');
    }

    // Apply the aggressive fix
    console.log(`🚀 Starting aggressive fix process...`);
    const success = fixer.fixAllIssues(filePath);
    
    if (success) {
        console.log(`\n✅ ALL FIXES APPLIED! Try your migration now:`);
        console.log(`   npm run migrate`);
        console.log(`\n📋 If it still fails, the issue might be with your table structure or data types.`);
    }
}

module.exports = AggressivePostgreSQLFixer;