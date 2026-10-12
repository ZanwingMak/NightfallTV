/** 将语言选择保存在本机；网站不发送偏好或统计事件。 */
function applyLanguage(language) {
  const chosen = language === 'zh' ? 'zh' : 'en';
  document.documentElement.lang = chosen === 'zh' ? 'zh-Hans' : 'en';
  document.querySelectorAll('[data-en][data-zh]').forEach(node => { node.textContent = node.dataset[chosen]; });
  document.querySelectorAll('[data-language]').forEach(node => { node.hidden = node.dataset.language !== chosen; });
  document.querySelector('#language').value = chosen;
  try { localStorage.setItem('nightfall-language', chosen); } catch (_) { /* 私密浏览或存储限制不影响内容。 */ }
}
/** 优先沿用用户选择，否则跟随中文或英文系统语言。 */
function preferredLanguage() {
  try { const saved = localStorage.getItem('nightfall-language'); if (saved) return saved; } catch (_) { /* 使用系统语言。 */ }
  return navigator.language.startsWith('zh') ? 'zh' : 'en';
}
applyLanguage(preferredLanguage());
document.querySelector('#language').addEventListener('change', event => applyLanguage(event.target.value));
/** 仅切换真实摄影静态预览，不下载视频或自动发声。 */
function previewScene(button) {
  document.querySelectorAll('[data-preview]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  document.body.dataset.scene = button.dataset.preview;
  const image = document.querySelector('.cover');
  if (button.dataset.preview !== 'black') image.src = 'assets/' + button.dataset.preview + '.jpg';
}
document.querySelectorAll('[data-preview]').forEach(button => button.addEventListener('click', () => previewScene(button)));
