import { mountApp } from '../public/app.mjs';
import { FakeRelay, invitationCode, snapshot } from './fake-relay.mjs';
const markup = new DOMParser().parseFromString(await (await fetch('../public/index.html')).text(), 'text/html');
const style = document.createElement('link'); style.rel = 'stylesheet'; style.href = '../public/app.css'; document.head.append(style);
document.body.replaceChildren(...markup.body.childNodes);
const label = document.createElement('p'); label.textContent = 'TEST FIXTURE · fictional trip · no real Discord messages'; label.className = 'status'; document.body.prepend(label);
const fake = new FakeRelay(); fake.waiting = true;
fake.bootstrapSnapshot = {
  ...snapshot,
  breakdown: {
    currencies: [{ code: 'MYR', precision: 2, minor: '1250' }],
    categories: [{ id: 'food', name: 'Food', color: '#EF6C00', minor: '1250', count: 1 }],
  },
};
mountApp(document, { initialInvitationCode: invitationCode, clientFactory: () => fake.client(sessionStorage, { locks: navigator.locks }) });
const hold = document.createElement('button'); hold.textContent = 'Test: resume host replies'; hold.type = 'button';
hold.addEventListener('click', () => { fake.waiting = !fake.waiting; hold.textContent = fake.waiting ? 'Test: resume host replies' : 'Test: pause host replies'; });
label.append(document.createTextNode(' '), hold);
