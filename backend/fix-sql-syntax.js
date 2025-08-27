const fs = require('fs');
const path = require('path');

class PostgreSQLFunctionFixer {
    constructor() {
        this.errors = [];
        this.fixes = [];
    }

    fixSQLFile(filePath) {
        console.log(`🔍 Analyzing file: ${filePath}`);
        
        if (!fs.existsSync(filePath)) {
            console.error(`❌ File not found: ${filePath}`);
            return false;
        }

        let content = fs.readFileSync(filePath, 'utf8');
        const originalContent = content;

        // Create backup
        const backupPath = `${filePath}.syntax-backup`;
        fs.writeFileSync(backupPath, originalContent);
        console.log(`💾 Backup created: ${backupPath}`);

        // Fix common PostgreSQL function syntax issues
        content = this.fixFunctionSyntax(content);
        content = this.fixDeclareBlocks(content);
        content = this.fixDollarQuoting(content);
        content = this.fixReturnStatements(content);

        if (content !== originalContent) {
            fs.writeFileSync(filePath, content);
            console.log(`✅ File fixed successfully!`);
            
            if (this.fixes.length > 0) {
                console.log(`🔧 Applied fixes:`);
                this.fixes.forEach(fix => console.log(`   - ${fix}`));
            }
            
            return true;
        } else {
            console.log(`ℹ️  No syntax issues detected in function structure`);
            return false;
        }
    }

    fixFunctionSyntax(content) {
        // Fix CREATE FUNCTION syntax
        content = content.replace(
            /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([^(]+)\s*\([^)]*\)\s*RETURNS?\s+[^$]+?AS\s*([^$])/gi,
            (match, funcName, afterAs) => {
                if (!match.includes('$$') && !match.includes('$BODY$')) {
                    this.fixes.push('Added dollar quoting to function definition');
                    return match.replace(/AS\s*([^$])/, 'AS $$\n$1');
                }
                return match;
            }
        );

        return content;
    }

    fixDeclareBlocks(content) {
        // Fix DECLARE blocks that aren't properly positioned
        content = content.replace(
            /(CREATE\s+OR\s+REPLACE\s+FUNCTION[^$]+\$\$)\s*DECLARE/gi,
            '$1\nDECLARE'
        );

        // Ensure DECLARE comes before BEGIN
        content = content.replace(
            /BEGIN\s*DECLARE/gi,
            'DECLARE'
        );

        // Fix standalone DECLARE without proper context
        content = content.replace(
            /(\$\$\s*)(DECLARE(?:\s+[^;]+;)*)\s*([^B])/gi,
            (match, start, declareBlock, after) => {
                if (!after.startsWith('BEGIN')) {
                    this.fixes.push('Fixed DECLARE block positioning');
                    return `${start}${declareBlock}\nBEGIN\n${after}`;
                }
                return match;
            }
        );

        return content;
    }

    fixDollarQuoting(content) {
        // Find functions that need proper dollar quoting
        const functionRegex = /CREATE\s+OR\s+REPLACE\s+FUNCTION[^;]+;/gi;
        
        content = content.replace(functionRegex, (match) => {
            // If function contains DECLARE or BEGIN but no dollar quoting
            if ((match.includes('DECLARE') || match.includes('BEGIN')) && 
                !match.includes('$$') && !match.includes('$BODY$')) {
                
                this.fixes.push('Added proper dollar quoting');
                
                // Extract the function signature and body
                const asIndex = match.toLowerCase().lastIndexOf(' as ');
                if (asIndex !== -1) {
                    const signature = match.substring(0, asIndex + 4);
                    const body = match.substring(asIndex + 4).replace(/;$/, '').trim();
                    
                    return `${signature} $$\n${body}\n$$ LANGUAGE plpgsql;`;
                }
            }
            return match;
        });

        return content;
    }

    fixReturnStatements(content) {
        // Fix RETURN statements in functions
        content = content.replace(
            /END\s*;?\s*\$\$/gi,
            'END;\n$$'
        );

        // Ensure functions end with proper language specification
        content = content.replace(
            /\$\$\s*;/gi,
            '$$ LANGUAGE plpgsql;'
        );

        return content;
    }

    analyzeErrorPosition(content, position) {
        const lines = content.split('\n');
        let currentPos = 0;
        
        for (let i = 0; i < lines.length; i++) {
            const lineLength = lines[i].length + 1; // +1 for newline
            
            if (currentPos + lineLength > position) {
                const columnPos = position - currentPos;
                console.log(`📍 Error near line ${i + 1}, column ${columnPos}:`);
                console.log(`   ${lines[i]}`);
                console.log(`   ${' '.repeat(Math.max(0, columnPos - 1))}^`);
                
                // Show context
                const start = Math.max(0, i - 2);
                const end = Math.min(lines.length, i + 3);
                console.log(`\n📝 Context:`);
                for (let j = start; j < end; j++) {
                    const marker = j === i ? '>>> ' : '    ';
                    console.log(`${marker}${j + 1}: ${lines[j]}`);
                }
                break;
            }
            currentPos += lineLength;
        }
    }

    validateFunctions(content) {
        const issues = [];
        
        // Check for common issues
        const functions = content.match(/CREATE\s+OR\s+REPLACE\s+FUNCTION[^;]+;/gi) || [];
        
        functions.forEach((func, index) => {
            // Check for DECLARE without BEGIN
            if (func.includes('DECLARE') && !func.includes('BEGIN')) {
                issues.push(`Function ${index + 1}: DECLARE found without BEGIN`);
            }
            
            // Check for missing dollar quoting in complex functions
            if ((func.includes('DECLARE') || func.includes('IF') || func.includes('LOOP')) && 
                !func.includes('$$') && !func.includes('$BODY$')) {
                issues.push(`Function ${index + 1}: Complex function missing dollar quoting`);
            }
            
            // Check for improper END statements
            if (func.includes('BEGIN') && !func.includes('END')) {
                issues.push(`Function ${index + 1}: BEGIN without matching END`);
            }
        });

        if (issues.length > 0) {
            console.log(`⚠️  Potential issues found:`);
            issues.forEach(issue => console.log(`   - ${issue}`));
        }

        return issues;
    }
}

// Main execution
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log(`
🔧 PostgreSQL Function Syntax Fixer

Usage: node fix-sql-syntax.js <path-to-sql-file> [--analyze-position <position>]

Examples:
  node fix-sql-syntax.js ./migrations/999_create_stored_procedure.sql
  node fix-sql-syntax.js ./migrations/999_create_stored_procedure.sql --analyze-position 16008
        `);
        process.exit(1);
    }

    const filePath = args[0];
    const fixer = new PostgreSQLFunctionFixer();

    // Check if we should analyze error position
    const posIndex = args.indexOf('--analyze-position');
    if (posIndex !== -1 && args[posIndex + 1]) {
        const position = parseInt(args[posIndex + 1]);
        console.log(`🎯 Analyzing error at position ${position}`);
        
        if (fs.existsSync(filePath)) {
            const content = fs.readFileSync(filePath, 'utf8');
            fixer.analyzeErrorPosition(content, position);
        }
    }

    // Fix the file
    const success = fixer.fixSQLFile(filePath);
    
    if (success) {
        // Validate the fixed content
        const content = fs.readFileSync(filePath, 'utf8');
        fixer.validateFunctions(content);
        
        console.log(`\n🚀 Try running your migration again:`);
        console.log(`   npm run migrate`);
    } else {
        console.log(`\n🔍 Run with position analysis to debug:`);
        console.log(`   node fix-sql-syntax.js ${filePath} --analyze-position 16008`);
    }
}