const fs = require('fs');
const http = require('http');
const path = require('path');

const DEFAULT_HOST = '127.0.0.1';
const DEFAULT_PORT = 8123;

const printUsage = () => {
  console.log(`Usage: node .devcontainer/archive/serve-container-html.js --root <dir> --file <name> [options]\n\nOptions:\n  --root <dir>   Directory to serve (required)\n  --file <name>  Default file to open at / (required)\n  --host <host>  Host to bind (default: ${DEFAULT_HOST})\n  --port <port>  Port to bind (default: ${DEFAULT_PORT})\n  --help         Show this help\n`);
};

const parseArgs = (argv) => {
  const options = {
    host: DEFAULT_HOST,
    port: DEFAULT_PORT,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--help') {
      options.help = true;
      continue;
    }

    if (!arg.startsWith('--')) {
      throw new Error(`Unexpected argument: ${arg}`);
    }

    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${arg}`);
    }

    if (arg === '--root') {
      options.root = path.resolve(value);
    } else if (arg === '--file') {
      options.file = value;
    } else if (arg === '--host') {
      options.host = value;
    } else if (arg === '--port') {
      const port = Number.parseInt(value, 10);
      if (!Number.isInteger(port) || port < 1 || port > 65535) {
        throw new Error(`Invalid port: ${value}`);
      }

      options.port = port;
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }

    index += 1;
  }

  if (!options.root) {
    throw new Error('Missing required option: --root');
  }

  if (!options.file) {
    throw new Error('Missing required option: --file');
  }

  return options;
};

const getContentType = (filePath) => {
  if (filePath.endsWith('.html')) {
    return 'text/html; charset=utf-8';
  }

  if (filePath.endsWith('.css')) {
    return 'text/css; charset=utf-8';
  }

  if (filePath.endsWith('.js')) {
    return 'text/javascript; charset=utf-8';
  }

  if (filePath.endsWith('.json')) {
    return 'application/json; charset=utf-8';
  }

  if (filePath.endsWith('.svg')) {
    return 'image/svg+xml';
  }

  if (filePath.endsWith('.png')) {
    return 'image/png';
  }

  return 'application/octet-stream';
};

const main = () => {
  let options;

  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    printUsage();
    process.exitCode = 1;
    return;
  }

  if (options.help) {
    printUsage();
    return;
  }

  if (!fs.existsSync(options.root)) {
    console.error(`Root directory does not exist: ${options.root}`);
    process.exitCode = 1;
    return;
  }

  if (!fs.statSync(options.root).isDirectory()) {
    console.error(`Root path is not a directory: ${options.root}`);
    process.exitCode = 1;
    return;
  }

  const defaultUrl = `http://${options.host}:${options.port}/${encodeURI(options.file)}`;

  const server = http.createServer((request, response) => {
    const rawPath = decodeURIComponent((request.url || '/').split('?')[0]);
    const relativePath = rawPath === '/' ? options.file : rawPath.replace(/^\/+/, '');
    const filePath = path.resolve(options.root, relativePath);

    if (!filePath.startsWith(`${options.root}${path.sep}`) && filePath !== path.resolve(options.root)) {
      response.statusCode = 403;
      response.end('Forbidden');
      return;
    }

    fs.readFile(filePath, (error, data) => {
      if (error) {
        response.statusCode = error.code === 'ENOENT' ? 404 : 500;
        response.end(error.code === 'ENOENT' ? 'Not found' : 'Internal server error');
        return;
      }

      response.setHeader('Content-Type', getContentType(filePath));
      response.end(data);
    });
  });

  server.listen(options.port, options.host, () => {
    console.log(`Serving ${options.root}`);
    console.log(`Open ${defaultUrl}`);
    console.log('Press Ctrl+C to stop');
  });
};

main();