// Mock: simulate the "优化输入" button click flow (Codex observer -> daemon -> /enhance body)
// Prints the exact request body that daemon.handleOptimizeRequest would POST.
// No real DOM; we synthesize document.body.innerText to verify whether AI answers are carried.

// --- Replicate observer_script.js visibleContext() ---
function visibleContext(bodyInnerText) {
  const text = (bodyInnerText || '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return text.slice(Math.max(0, text.length - 6000));
}

// --- Replicate observer_script.js optimize(): build the request pushed to pendingRequests ---
function buildOptimizeRequest(draft, bodyInnerText) {
  return {
    type: 'optimize-request',
    requestId: 1,
    draft,
    context: 'Visible Codex context:\n' + visibleContext(bodyInnerText),
    beforeLength: draft.length,
    capturedAt: Date.now(),
  };
}

// --- Replicate daemon.js handleOptimizeRequest(): build the fetch body sent to /enhance ---
function buildEnhanceBody(payload) {
  return JSON.stringify({
    draft: payload.draft,
    context: payload.context,
  });
}

// --- Synthetic page: user asks, AI answers with code, then user types a vague follow-up ---
const syntheticBodyInnerText = [
  'Codex',
  'New chat',
  'You: 帮我看看登录模块这个接口是什么',
  'Codex: 我读取了 src/auth.py 和 src/session.py。login() 会校验密码并调用 create_session()，validate_session() 负责后续请求校验。当 token 查找失败时会返回 401 Unauthorized。',
  '```python',
  'def validate_session(token):',
  '    user = token_store.get(token)',
  '    if not user:',
  '        return unauthorized(401)',
  '    return user',
  '```',
  'You: 那这个怎么改',
  '优化输入',
].join('\n');

const draft = '那这个怎么改';
const request = buildOptimizeRequest(draft, syntheticBodyInnerText);
const body = buildEnhanceBody(request);

console.log('===== observer -> pendingRequests request object =====');
console.log(JSON.stringify(request, null, 2));
console.log('\n===== daemon -> POST /enhance body =====');
console.log(body);
console.log('\n===== parsed body fields =====');
const parsed = JSON.parse(body);
console.log('draft      =', JSON.stringify(parsed.draft));
console.log('has conversation field?', 'conversation' in parsed);
console.log('has code_facts field?   ', 'code_facts' in parsed);
console.log('has task_state field?   ', 'task_state' in parsed);
console.log('has current_file field? ', 'current_file' in parsed);
console.log('context length =', parsed.context.length, 'chars');
console.log('\n===== context content (what the enhancer model actually sees) =====');
console.log(parsed.context);
console.log('\n===== AI answer carried into context? =====');
console.log('contains "validate_session":', parsed.context.includes('validate_session'));
console.log('contains "401 Unauthorized":', parsed.context.includes('401 Unauthorized'));
console.log('contains AI code block:    ', parsed.context.includes('def validate_session(token)'));
console.log('contains "Codex:" prefix:  ', parsed.context.includes('Codex:'));
