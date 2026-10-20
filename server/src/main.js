import { createApp } from './app.js';
const port = Number(process.env.PORT ?? 8080);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');
const app = await createApp({ webRoot:process.env.WEB_ROOT, logger: { redact: ['req.headers.authorization', 'req.headers.cookie'] } });
for (const signal of ['SIGTERM', 'SIGINT']) process.once(signal, async () => { await app.close(); process.exit(0); });
await app.listen({ host: process.env.HOST ?? '127.0.0.1', port });
