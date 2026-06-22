export class DevToolsClient {
  constructor(webSocketUrl) {
    this.webSocketUrl = webSocketUrl;
    this.nextId = 1;
    this.pending = new Map();
    this.handlers = new Map();
  }

  async connect() {
    this.ws = new WebSocket(this.webSocketUrl);
    this.ws.onmessage = (event) => this.handleMessage(JSON.parse(event.data));
    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
  }

  handleMessage(message) {
    if (message.id && this.pending.has(message.id)) {
      this.pending.get(message.id)(message);
      this.pending.delete(message.id);
      return;
    }

    const handlers = this.handlers.get(message.method) || [];
    for (const handler of handlers) handler(message.params);
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve) => {
      this.pending.set(id, resolve);
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  on(method, handler) {
    const handlers = this.handlers.get(method) || [];
    handlers.push(handler);
    this.handlers.set(method, handlers);
  }

  close() {
    this.ws?.close();
  }
}
