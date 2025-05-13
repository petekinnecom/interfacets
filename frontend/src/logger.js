const LOG_LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
  fatal: 4
}

class Logger {
  constructor(level = 'fatal') {
    this.level = level
  }

  setLevel(level) {
    if (LOG_LEVELS[level] === undefined) {
      throw new Error(`Invalid log level: ${level}`)
    }
    this.level = level
  }

  shouldLog(level) {
    return LOG_LEVELS[level] >= LOG_LEVELS[this.level]
  }

  debug(...args) {
    if (this.shouldLog('debug')) {
      console.debug('[DEBUG]', ...args)
    }
  }

  info(...args) {
    if (this.shouldLog('info')) {
      console.info('[INFO]', ...args)
    }
  }

  warn(...args) {
    if (this.shouldLog('warn')) {
      console.warn('[WARN]', ...args)
    }
  }

  error(...args) {
    if (this.shouldLog('error')) {
      console.error('[ERROR]', ...args)
    }
  }

  fatal(...args) {
    if (this.shouldLog('fatal')) {
      console.error('[FATAL]', ...args)
    }
  }

  log(...args) {
    this.info(...args)
  }
}

export const logger = new Logger('fatal')
