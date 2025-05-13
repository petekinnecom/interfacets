const esbuild = require('esbuild');

const isWatch = process.argv.includes('--watch');

const config = {
  entryPoints: {
    'application': 'app/javascript/application.js',
    'worker': 'app/javascript/worker.js',
  },
  bundle: true,
  outdir: 'public/assets',
  format: 'esm',
  platform: 'browser',
  target: 'es2020',
  sourcemap: false,
  minify: true,
  treeShaking: true,
  drop: ['console', 'debugger'],
  legalComments: 'none',
};

if (isWatch) {
  esbuild.context(config).then(ctx => {
    ctx.watch();
    console.log('Watching for changes...');
  });
} else {
  esbuild.build(config).then(() => {
    console.log('Build complete!');
  }).catch(() => process.exit(1));
}
