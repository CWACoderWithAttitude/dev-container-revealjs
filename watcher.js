// ...existing code...
import chokidar from 'chokidar';
import { spawn } from 'child_process';

const DEBOUNCE_MS = 300;
let compileTimer = null;

function runCompile() {
  console.log('Running: npm run compile');
  const p = spawn('npm', ['run', 'compile'], { stdio: 'inherit' });
  p.on('error', (err) => console.error('Failed to start compile:', err));
  p.on('exit', (code, signal) => {
    if (code !== null) console.log(`compile exited with code ${code}`);
    else console.log(`compile killed by signal ${signal}`);
  });
}

function scheduleCompile() {
  if (compileTimer) clearTimeout(compileTimer);
  compileTimer = setTimeout(() => {
    runCompile();
    compileTimer = null;
  }, DEBOUNCE_MS);
}

//const watcher = chokidar.watch('**/*.adoc', {
const watcher = chokidar.watch('**/*.adoc', {
  ignored: /(^|[\/\\])\../, // ignore dotfiles
  ignoreInitial: false,
  persistent: true,
});

watcher
  .on('add', (path) => {
    console.log(`File added: ${path}`);
    scheduleCompile();
  })
  .on('change', (path) => {
    console.log(`File changed: ${path}`);
    scheduleCompile();
  })
  .on('unlink', (path) => console.log(`File removed: ${path}`))
  .on('error', (err) => console.error('Watcher error:', err));