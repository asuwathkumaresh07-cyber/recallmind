const path = require('path');
const os = require('os');
const runtime = path.join(os.homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
const sharp = require(path.join(runtime, 'sharp'));
(async () => {
  const entries = [['web/favicon.png', 48], ['web/icons/Icon-192.png', 192], ['web/icons/Icon-512.png', 512], ['web/icons/Icon-maskable-192.png', 192], ['web/icons/Icon-maskable-512.png', 512]];
  for (const [density, size] of [['mdpi',48],['hdpi',72],['xhdpi',96],['xxhdpi',144],['xxxhdpi',192]]) entries.push([`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, size]);
  for (const [file, size] of entries) await sharp('web/brand.svg').resize(size, size).png().toFile(file);
  console.log('RecallMind application icons generated.');
})().catch(e => { console.error(e); process.exit(1); });
