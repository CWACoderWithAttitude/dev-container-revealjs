import chokidar from 'chokidar';

// One-liner for current directory
chokidar.watch('.').on('all', (event, path) => {
  console.log(event, path);
});

// Extended options
// ----------------

// Initialize watcher.
const watcher = chokidar.watch('file, dir, or array', {
  ignored: (path, stats) => stats?.isFile() && !path.endsWith('.adoc'), // only watch js files
  persistent: true,
});

// Something to use when events are received.
const log = console.log.bind(console);
// Add event listeners.
watcher
  .on('add', (path) => log(`File ${path} has been added`))
  .on('change', (path) => log(`File ${path} has been changed`))
  .on('unlink', (path) => log(`File ${path} has been removed`));