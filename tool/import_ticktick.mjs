#!/usr/bin/env node

/**
 * TickTick Task & Project Exporter & Importer for GetPlanBetter
 * 
 * Usage:
 *   node tool/import_ticktick.mjs --token <YOUR_TICKTICK_API_TOKEN> [--apply]
 *   node tool/import_ticktick.mjs --file <PATH_TO_CSV_OR_JSON> [--apply] [--active-only]
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

// Parse CLI arguments
const args = process.argv.slice(2);
let token = process.env.TICKTICK_TOKEN || '';
let filePath = '';
let applyChanges = false;
let activeOnly = false; // only normal/active tasks (status 0)

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--token' && args[i + 1]) {
    token = args[++i];
  } else if (args[i] === '--file' && args[i + 1]) {
    filePath = args[++i];
  } else if (args[i] === '--apply') {
    applyChanges = true;
  } else if (args[i] === '--active-only') {
    activeOnly = true;
  }
}

function printUsage() {
  console.log(`
TickTick Importer for GetPlanBetter

Usage:
  node tool/import_ticktick.mjs --token <YOUR_TICKTICK_API_TOKEN> [--apply]
  node tool/import_ticktick.mjs --file <PATH_TO_EXPORT_CSV_OR_JSON> [--apply] [--active-only]

Options:
  --token <TOKEN>   Personal access token from TickTick Web (Settings > Account > API Token)
  --file <PATH>     Path to an exported TickTick CSV backup or CLI JSON dump
  --apply           Directly update lib/repositories/mock_data.dart with imported tasks
  --active-only     Import only open/uncompleted tasks
`);
}

function cleanId(id) {
  return String(id).replace(/[^a-zA-Z0-9_-]/g, '_');
}

const PALETTE = [
  0xFF0284C7, // Blue
  0xFF6366F1, // Indigo
  0xFF10B981, // Emerald
  0xFFF59E0B, // Amber
  0xFFEC4899, // Pink
  0xFF8B5CF6, // Purple
  0xFF14B8A6, // Teal
  0xFFF97316, // Orange
  0xFF06B6D4, // Cyan
  0xFF84CC16, // Lime
  0xFFE11D48, // Rose
  0xFF64748B, // Slate
];

function getColorForIndex(idx) {
  return PALETTE[idx % PALETTE.length];
}

function mapPriority(p) {
  const s = String(p).toLowerCase().trim();
  if (s === '5' || s === 'high' || s === 'urgent') return 'urgent';
  if (s === '3' || s === 'medium') return 'medium';
  if (s === '1' || s === 'low') return 'low';
  return 'none';
}

function parseDateTime(val) {
  if (!val) return null;
  const s = String(val).trim();
  if (!s) return null;
  try {
    const d = new Date(s);
    return isNaN(d.getTime()) ? null : d.toISOString();
  } catch {
    return null;
  }
}

function parseCsvFull(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (inQuotes && text[i + 1] === '"') {
        field += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c === ',' && !inQuotes) {
      row.push(field);
      field = '';
    } else if ((c === '\r' || c === '\n') && !inQuotes) {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      field = '';
      if (row.length > 1 || (row.length === 1 && row[0] !== '')) {
        rows.push(row);
      }
      row = [];
    } else {
      field += c;
    }
  }
  if (field || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

function parseCsvFile(csvContent, filterActiveOnly = false) {
  const rows = parseCsvFull(csvContent);
  if (!rows.length) return { projects: [], tasks: [], subtaskCount: 0 };

  // Locate the header row (contains "Title" or "List Name")
  let headerRowIdx = -1;
  for (let i = 0; i < Math.min(25, rows.length); i++) {
    const rLower = rows[i].map(c => String(c).toLowerCase().trim());
    if (rLower.includes('list name') || rLower.includes('title')) {
      headerRowIdx = i;
      break;
    }
  }

  if (headerRowIdx === -1) {
    throw new Error('Could not find CSV column header in the provided file.');
  }

  const header = rows[headerRowIdx];
  const colMap = {};
  header.forEach((h, i) => colMap[h.trim()] = i);

  const listNameIdx = colMap['List Name'] ?? colMap['Folder Name'] ?? -1;
  const folderNameIdx = colMap['Folder Name'] ?? -1;
  const titleIdx = colMap['Title'] ?? -1;
  const notesIdx = colMap['Content'] ?? colMap['Notes'] ?? -1;
  const startIdx = colMap['Start Date'] ?? -1;
  const dueIdx = colMap['Due Date'] ?? -1;
  const priorityIdx = colMap['Priority'] ?? -1;
  const statusIdx = colMap['Status'] ?? -1;
  const completedIdx = colMap['Completed Time'] ?? -1;
  const taskIdIdx = colMap['taskId'] ?? -1;
  const parentIdIdx = colMap['parentId'] ?? -1;

  const projects = [];
  const projectMap = new Map();
  const tasks = [];
  let subtaskCount = 0;

  // Add default Inbox
  const defaultInbox = {
    id: 'proj_inbox',
    name: 'Inbox',
    colorValue: 0xFF64748B,
    sortOrder: 0,
    isDefault: true
  };
  projects.push(defaultInbox);
  projectMap.set('inbox', defaultInbox.id);

  for (let i = headerRowIdx + 1; i < rows.length; i++) {
    const row = rows[i];
    const title = titleIdx >= 0 && titleIdx < row.length ? row[titleIdx].trim() : '';
    if (!title) continue;

    const rawStatus = statusIdx >= 0 && statusIdx < row.length ? row[statusIdx].trim() : '0';
    const isCompleted = rawStatus === '2' || rawStatus === '-1' || rawStatus.toLowerCase() === 'completed';

    if (filterActiveOnly && isCompleted) {
      continue;
    }

    const listName = listNameIdx >= 0 && row[listNameIdx] && row[listNameIdx].trim()
      ? row[listNameIdx].trim()
      : 'Inbox';
    const listKey = listName.toLowerCase();

    let pid = defaultInbox.id;
    if (projectMap.has(listKey)) {
      pid = projectMap.get(listKey);
    } else {
      pid = 'proj_' + cleanId(listName).substring(0, 24) + '_' + projects.length;
      const projItem = {
        id: pid,
        name: listName,
        colorValue: getColorForIndex(projects.length),
        sortOrder: projects.length,
        isDefault: false
      };
      projects.push(projItem);
      projectMap.set(listKey, pid);
    }

    const rawTaskId = taskIdIdx >= 0 && row[taskIdIdx] ? row[taskIdIdx].trim() : '';
    const rawParentId = parentIdIdx >= 0 && row[parentIdIdx] ? row[parentIdIdx].trim() : '';
    const tid = rawTaskId ? 'task_' + cleanId(rawTaskId) : 'task_' + Math.random().toString(36).substring(2, 10);
    const parentTid = rawParentId ? 'task_' + cleanId(rawParentId) : null;

    if (parentTid) subtaskCount++;

    const startDate = startIdx >= 0 ? parseDateTime(row[startIdx]) : null;
    const dueDate = dueIdx >= 0 ? parseDateTime(row[dueIdx]) : null;
    const isTimeBlocked = !!startDate;
    let estimatedMinutes = 30;

    if (startDate && dueDate) {
      const diff = Math.round((new Date(dueDate) - new Date(startDate)) / 60000);
      if (diff > 0) estimatedMinutes = diff;
    }

    const notes = notesIdx >= 0 && row[notesIdx] && row[notesIdx].trim() ? row[notesIdx].trim() : null;

    tasks.push({
      id: tid,
      userId: '',
      title: title,
      notes: notes,
      projectId: pid,
      priority: priorityIdx >= 0 ? mapPriority(row[priorityIdx]) : 'none',
      estimatedMinutes: estimatedMinutes,
      dueDate: dueDate,
      isCompleted: isCompleted,
      completedAt: completedIdx >= 0 ? parseDateTime(row[completedIdx]) : null,
      isTimeBlocked: isTimeBlocked,
      scheduledStart: startDate,
      scheduledEnd: dueDate || (startDate ? new Date(new Date(startDate).getTime() + estimatedMinutes * 60000).toISOString() : null),
      parentTaskId: parentTid
    });
  }

  return { projects, tasks, subtaskCount };
}

async function main() {
  if (!token && !filePath) {
    printUsage();
    process.exit(1);
  }

  let result;
  if (token) {
    // API logic if token provided
    throw new Error('API token flow not called directly with file');
  } else if (filePath) {
    console.log(`Reading TickTick backup from ${filePath}...`);
    const content = fs.readFileSync(filePath, 'utf8');
    result = parseCsvFile(content, activeOnly);
  }

  const exportPath = path.join(projectRoot, 'ticktick_export.json');
  fs.writeFileSync(exportPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`\nExport successfully generated at: ${exportPath}`);
  console.log(`Summary:`);
  console.log(`  - Projects / Lists: ${result.projects.length}`);
  console.log(`  - Total Tasks: ${result.tasks.length}`);
  console.log(`  - Subtasks: ${result.subtaskCount}`);
  const completed = result.tasks.filter(t => t.isCompleted).length;
  const active = result.tasks.length - completed;
  console.log(`  - Active / Open Tasks: ${active}`);
  console.log(`  - Completed Tasks: ${completed}`);

  if (applyChanges) {
    applyToMockData(result);
  } else {
    console.log(`\nRun with --apply to automatically load these projects and tasks into your workspace.`);
  }
}

function applyToMockData(result) {
  const dataPath = path.join(projectRoot, 'lib', 'repositories', 'ticktick_data.dart');
  const jsonText = JSON.stringify(result, null, 2);
  const dartCode = `// Generated TickTick export bundle
const String ticktickExportJson = r'''${jsonText}''';
`;

  fs.writeFileSync(dataPath, dartCode, 'utf8');
  console.log(`\nUpdated ${dataPath} successfully! All ${result.tasks.length} tasks and ${result.projects.length} lists are now active in the app.`);
}

main().catch(err => {
  console.error('Import error:', err);
  process.exit(1);
});
