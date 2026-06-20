const fs = require('fs');

const stripJsonComments = (input) => {
  let output = '';
  let inString = false;
  let escaped = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (let index = 0; index < input.length; index += 1) {
    const current = input[index];
    const next = input[index + 1];

    if (inLineComment) {
      if (current === '\n') {
        inLineComment = false;
        output += current;
      }

      continue;
    }

    if (inBlockComment) {
      if (current === '*' && next === '/') {
        inBlockComment = false;
        index += 1;
      }

      continue;
    }

    if (inString) {
      output += current;

      if (escaped) {
        escaped = false;
      } else if (current === '\\') {
        escaped = true;
      } else if (current === '"') {
        inString = false;
      }

      continue;
    }

    if (current === '"') {
      inString = true;
      output += current;
      continue;
    }

    if (current === '/' && next === '/') {
      inLineComment = true;
      index += 1;
      continue;
    }

    if (current === '/' && next === '*') {
      inBlockComment = true;
      index += 1;
      continue;
    }

    output += current;
  }

  return output;
};

const loadJsonFile = (filePath, fallback, options = {}) => {
  if (!fs.existsSync(filePath)) {
    return fallback;
  }

  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (!raw) {
    return fallback;
  }

  return JSON.parse(options.allowComments ? stripJsonComments(raw) : raw);
};

const saveJsonFile = (filePath, data) => {
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`);
};

const ensureObject = (target, key) => {
  if (!target[key] || typeof target[key] !== 'object' || Array.isArray(target[key])) {
    target[key] = {};
  }

  return target[key];
};

const ensureArray = (target, key) => {
  if (!Array.isArray(target[key])) {
    target[key] = [];
  }

  return target[key];
};

const addUniqueValue = (entries, value) => {
  if (!entries.includes(value)) {
    entries.push(value);
  }
};

const ensureHookCommand = (config, eventName, group, command) => {
  const hooks = ensureObject(config, 'hooks');
  const entries = Array.isArray(hooks[eventName]) ? hooks[eventName] : [];
  const alreadyPresent = entries.some((entry) =>
    Array.isArray(entry.hooks) && entry.hooks.some((hook) => hook.type === 'command' && hook.command === command)
  );

  if (!alreadyPresent) {
    entries.push(group);
  }

  hooks[eventName] = entries;
};

module.exports = {
  addUniqueValue,
  ensureArray,
  ensureHookCommand,
  ensureObject,
  loadJsonFile,
  saveJsonFile,
};