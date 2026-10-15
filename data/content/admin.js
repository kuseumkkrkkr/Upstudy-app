'use strict';
// Credentials intentionally never go to URLs, localStorage, sessionStorage or logs.
const $ = (id) => document.getElementById(id);
let token = '', apiKey = '', items = [], version = 0, pending = null;
const kinds = {course:'코스', exam:'시험지', problem_set:'문제집'};
function status(message) { $('status').textContent = message; }
async function api(path, options = {}) {
  const response = await fetch(path, {...options, cache:'no-store', redirect:'error',
    headers:{'Content-Type':'application/json', Authorization:`Bearer ${token}`, 'X-Admin-Api-Key':apiKey, ...(options.headers || {})}});
  const data = await response.json();
  if (!response.ok) throw new Error(`${response.status}: ${typeof data.detail === 'string' ? data.detail : '입력 또는 인증 상태를 확인해 주세요.'}`);
  return data;
}
function busy(value) { for (const button of document.querySelectorAll('button')) button.disabled = value; }
async function action(fn) { busy(true); try { await fn(); } catch (error) { status(error.message); } finally { busy(false); } }
function draw() {
  $('items').replaceChildren();
  const query = $('search').value.trim().toLocaleLowerCase();
  for (const row of items.filter(row => (!$('kindFilter').value || row.payload.kind === $('kindFilter').value) &&
      `${row.payload.title} ${row.id}`.toLocaleLowerCase().includes(query))) {
    const li = document.createElement('li'), span = document.createElement('span'), small = document.createElement('small');
    span.textContent = row.payload.title;
    small.textContent = `${kinds[row.payload.kind]} · ${row.id} · v${row.version}${row.archived ? ' · 보관됨' : ''}`;
    span.append(small); li.append(span);
    const edit = document.createElement('button'); edit.className='secondary'; edit.textContent='조회·편집';
    edit.onclick = () => {
      version = row.version; const p=row.payload;
      $('contentId').value=row.id; $('contentId').readOnly=true; $('kind').value=p.kind;
      $('title').value=p.title; $('description').value=p.description || ''; $('grade').value=p.grade_band;
      $('difficulty').value=p.difficulty; $('questions').value=(p.problem_ids || []).join('\n');
      $('editor').scrollIntoView({block:'start'});
    }; li.append(edit);
    if (row.archived) {
      const restore = document.createElement('button'); restore.textContent='복원';
      restore.onclick=() => action(async () => {
        await mutate(`/admin/api/content/${encodeURIComponent(row.id)}/restore?version=${row.version}`, 'POST');
        await reload(); status('공개 목록에 복원했습니다.');
      }); li.append(restore);
    } else {
      const archive = document.createElement('button'); archive.textContent='보관';
      archive.onclick = () => { if (confirm(`“${row.payload.title}”을 공개 목록에서 숨길까요? 학생 기록은 유지됩니다.`)) action(async () => {
        await mutate(`/admin/api/content/${encodeURIComponent(row.id)}?version=${row.version}`, 'DELETE');
        await reload(); status('보관했습니다.');
      }); }; li.append(archive);
    }
    $('items').append(li);
  }
}
async function reload() { items=(await api('/admin/api/content')).items; draw(); }
async function mutate(path, method, body) {
  const fingerprint=JSON.stringify({path,method,body});
  // An unknown network outcome retains the key. Do not overwrite it with a new action.
  if (pending && pending.fingerprint !== fingerprint) throw new Error('응답이 불명확한 요청이 있습니다. 같은 요청을 재시도하거나 목록을 확인한 후 연결을 해제해 주세요.');
  pending ||= {fingerprint,key:crypto.randomUUID()};
  try {
    const result=await api(path,{method,body:body === undefined ? undefined : JSON.stringify(body),headers:{'X-Idempotency-Key':pending.key}});
    pending=null; return result;
  } catch (error) { if (/^(4\d\d):/.test(error.message)) pending=null; throw error; }
}
$('login').onsubmit = event => { event.preventDefault(); action(async () => {
  token=''; apiKey=$('apiKey').value;
  const username=$('username').value, password=$('password').value;
  $('password').value=''; $('apiKey').value='';
  const response=await fetch('/auth/login',{method:'POST',redirect:'error',headers:{'Content-Type':'application/json'},body:JSON.stringify({username,password})});
  if (!response.ok) throw new Error('로그인 실패: 계정과 비밀번호를 확인해 주세요.');
  token=(await response.json()).token;
  try { await reload(); } catch (error) { token=''; apiKey=''; throw error; }
  $('login').hidden=true; $('logout').hidden=false; $('workspace').hidden=false; $('editor').hidden=false;
  status('관리자 계정과 API 키가 확인되었습니다.');
}); };
$('logout').onclick=() => { token=''; apiKey=''; items=[]; pending=null; version=0; $('items').replaceChildren(); $('content').reset();
  $('contentId').readOnly=false; $('workspace').hidden=true; $('editor').hidden=true; $('login').hidden=false; $('logout').hidden=true; status('연결을 해제했습니다.'); };
$('reload').onclick=() => action(async () => { await reload(); status('목록을 갱신했습니다.'); });
$('kindFilter').onchange=draw; $('search').oninput=draw;
$('new').onclick=() => { $('content').reset(); $('contentId').readOnly=false; version=0; };
$('content').onsubmit=event => { event.preventDefault(); action(async () => {
  const id=$('contentId').value.trim();
  const body={id,kind:$('kind').value,title:$('title').value,description:$('description').value,
    grade_band:$('grade').value,difficulty:$('difficulty').value,
    problem_ids:$('questions').value.split('\n').map(s=>s.trim()).filter(Boolean),version};
  const result=await mutate(`/admin/api/content/${encodeURIComponent(id)}`,'PUT',body); version=result.version;
  $('contentId').readOnly=true; await reload(); status(`저장했습니다. 버전 ${version}`);
}); };
