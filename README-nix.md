# NixOS Quattro / Omarchy UX Lab

Це експериментальна NixOS-конфігурація для VM `nixos-lab`: модульний
Quickshell/Hyprland desktop, який відтворює потрібний Omarchy UX, але лишається
NixOS-native, декларативним і не залежить від Arch/Omarchy runtime або чужого flake.

Поточний source of truth — цей каталог. Він синхронізується у VM в
`/home/retraut/nixos-lab-config`, після чого застосовується через flake profile
`.#nixos`. Остання перевірена VM generation — NixOS
`26.11.20260816.e5bdc4a`; на момент останнього аудиту system і user systemd мали
по `0` failed units.

Автоматизований checklist для чистого встановлення на фізичний ASUS ROG
Zephyrus G15 GA503QS, включно з Disko, LUKS2, Secure Boot, TPM2 + PIN і
recovery, знаходиться в
[`LAPTOP-INSTALL-RUNBOOK.md`](./LAPTOP-INSTALL-RUNBOOK.md).

## Стан на 2026-08-19

### Базова система

- Піднята й перебудовується тестова NixOS VM через KVM/QEMU.
- Конфігурація збирається через власний flake з профілем `nixos`.
- Конфігурація синхронізується з VM у `/home/retraut/nixos-lab-config`.
- Користувацьке ім'я винесене в параметр `labUserName`, тому конфіг не прив'язаний жорстко до `retraut`.
- Власні залежності відокремлені від основного списку застосунків у `desktop.nix`.
- Додані Ghostty, Chromium, Tailscale, Bitwarden, Codex CLI, screenfetch/exa та потрібні Nerd Fonts.
- Додані NetworkManager/Blueman/Pavucontrol, `qrencode`, PipeWire, UPower,
  power-profiles-daemon, Polkit і системний Tailscale service для повного Control Center.
- Firefox і Foot прибрані; термінал — Ghostty.

### Тема й типографіка

- Підключений Stylix із Tokyo Night палітрою.
- Тема генерується в один `Theme.qml` для Quickshell.
- Stylix-палітра також декларативно генерує `hyprlock.conf` і `fuzzel.ini`;
  runtime theme picker навмисно відсутній.
- Узгоджені параметри:
  - статусбар: `20px`;
  - іконки статусбара: `24px`;
  - текст віджетів: `30px`;
  - cursor: DMZ-Black;
  - шрифт: `JetBrainsMono Nerd Font`.
- Віджети мають гострі прямокутні рамки без rounded corners.
- Popup-вікна більше не залежать від нестабільних початкових `panel.width/panel.height`; вони розраховують розмір від контенту зі стабільними межами.

### Shell, bar і shortcuts

- Перенесений Quattro-style status bar з workspaces, clock, weather, keyboard layout, tray, battery, agents і control center.
- Workspace можна обирати мишкою; індикатор workspace не має зайвого чорного квадрата.
- Додані/налаштовані Super-шорткати для launcher, terminal, Chromium, copy/paste, вкладок, refresh і zoom.
- `Super+Space` відкриває fuzzy application launcher і перемикає input language на English.
- Для Chromium/Ghostty шорткати працюють через Hyprland незалежно від поточної US/UA розкладки.
- Додані tray-елементи для застосунків на кшталт Steam, Bitwarden і ChatGPT.
- Панель за замовчуванням непрозора, щоб текст і tray не губилися на яскравих шпалерах.
- Додані `Super+N` для Notification Center (у Chromium — new browser window), `Super+Escape` для lock,
  `Super+Shift+V` для clipboard history та `Super+Ctrl+Space` для emoji.
- `Print`, `Super+Print` і `Shift+Print` знімають region, active window та fullscreen.
- Media keys керують гучністю, microphone mute та brightness із власним OSD.
- `Super+A` працює як select-all у GUI та через Ghostty-native `Ctrl+Shift+A` у terminal.
- Application launcher пропорційно масштабується через єдиний `uiScale = 1.5`;
  ChatGPT, Bitwarden і Chromium запускаються зі scale factor `1.5` (150%).

Поточний keyboard contract:

| Комбінація | Поведінка |
|---|---|
| `Super+Space` | Launcher 150%; перед відкриттям примусово обирається English layout |
| `Super+Enter` | Ghostty |
| `Super+Shift+B` | Chromium |
| `Super+Shift+F` | Nautilus |
| `Super+Ctrl+O` | Control Center |
| `Super+Ctrl+M` | Desktop menu |
| `Super+N` | Notification Center; у Chromium — саме new browser window |
| `Super+A` | Select all; у Ghostty передається native `Ctrl+Shift+A` |
| `Super+C` / `Super+V` | Universal copy/paste, включно з Ghostty та UA layout |
| `Super+T` / `Super+R` | New tab / refresh у Chromium |
| `Super+W` | Close tab у Chromium, close window в інших застосунках |
| `Super+-` / `Super+=` | Zoom Chromium або Ghostty незалежно від US/UA layout |
| `Super+Shift+V` | Clipboard history |
| `Super+Ctrl+Space` | Emoji picker |
| `Super+Escape` | Lock session |
| `Print` / `Super+Print` / `Shift+Print` | Region / active window / fullscreen screenshot |
| `Super+1…0` | Workspace 1…10; з `Shift` — перенести активне вікно |

### Bar, tray і touchpad interactions

- Порожня ділянка bar: double click перемикає opaque/transparent background.
- Weather: left click відкриває current/hourly view, right або middle click — weekly view.
- Clock відкриває Calendar; keyboard indicator циклічно перемикає US/UA.
- Tray розгортається hover-ом або кліком. Left click активує застосунок, middle click
  викликає secondary action, right click або two-finger tap відкриває його menu.
- Tray menu прив'язане до конкретної іконки справа, має screen-edge slide adjustment і
  власну навігацію по submenu; це виправляє menu ChatGPT, яке раніше з'являлося зліва.
- Дзвіночок: left click відкриває Notification Center; right click/two-finger tap
  перемикає DND. DND state завжди показується окремим popup навіть коли звичайні toast-и muted.
- Шестерня: left click toggle Control Center, right click explicit close. Hover сам
  нічого не відкриває, тому немає open/close race.

### Quickshell-віджети

Реалізовані окремі popup-віджети:

- `agents.qml` — провайдери, usage і запуск доступних CLI.
- `battery-panel.qml` — battery state, top CPU processes і power profile.
- `control-center.qml` — компактний Omarchy-baseline dashboard із system stats, top processes та
  Wi-Fi, Bluetooth, Audio, Display, Tailscale і Power controls.
- `control-panel.qml` — повні stateful підпанелі: Wi-Fi scan/connect/password/disconnect/forget/QR share,
  Bluetooth scan/pair/connect/disconnect/forget, PipeWire output/input/application streams,
  brightness control/read-only monitor state, Tailscale peers/exit nodes і power profiles. Для розширених
  налаштувань залишені прямі переходи в `nm-connection-editor`, Blueman і Pavucontrol.
- `calendar.qml` — календар із перемиканням місяців.
- `weather.qml` — поточна погода, погодинний прогноз і прогноз на 7 днів.
- `menu.qml` — desktop menu для clipboard, emoji, screenshots, notifications і lock.
- `app-launcher.qml` — fuzzy launcher із web app `X`.

### Повний Control Center

Dashboard повторює структуру поточного live Omarchy Control Center, але реалізований
нативно для NixOS. Він має compact typography, system stats (`CPU`, `RAM`, `Swap`,
`Storage`, temperature/power when available), top CPU processes і постійну сітку 2×3.
Laptop controls не зникають у VM — замість цього чесно показують відсутній hardware.

| Панель | Реалізована поведінка |
|---|---|
| Wi-Fi | Adapter/radio state, scan, AP list, signal/security, connect, password prompt, disconnect, forget через right click, advanced NetworkManager settings і QR share активної мережі |
| Bluetooth | Adapter/power state, scan, discovered/paired/connected devices, connect, disconnect, forget і перехід у Blueman |
| Audio | PipeWire output/input volume до 150%, mute, default sink/source, application streams і Pavucontrol |
| Display | Backlight slider лише для справжнього `backlight` device; monitor name/mode/refresh/current scale показуються read-only |
| Tailscale | Backend/auth state, connect/disconnect, self node, peers, online state та exit-node toggle |
| Power | Поточний і доступні profiles через power-profiles-daemon |

Display навмисно safe: runtime scale picker, DPMS off та monitor enable/disable відсутні
і в QML, і в action backend. Scale задається декларативно через `hl.monitor(...)` у
`hyprland.lua`, тому випадковий клік у Control Center не може лишити ноутбук із чорним екраном.

Control Center розділений на read-only state provider `scripts/nixos-control-state`,
mutation helper `scripts/nixos-control-action`, QR helper `scripts/nixos-wifi-qr`,
dashboard `quickshell/control-center.qml` і detail UI `quickshell/control-panel.qml`.
Це тримає QML простим, не використовує shell interpolation для зовнішніх значень і
дозволяє окремо тестувати state та actions.

Wi-Fi QR створюється лише після кліку для активного NetworkManager profile. PSK читається
через `nmcli --show-secrets`, передається `qrencode` через stdin, не потрапляє в process
arguments/state/logs, а PNG записується як `$XDG_RUNTIME_DIR/nixos-wifi-share.png` з mode
`0600`. У VM кнопка disabled через відсутній Wi-Fi adapter; на ноутбуці вона активується
автоматично після підключення.

### Omarchy-style UX без runtime-мутацій

- Quickshell тепер володіє `org.freedesktop.Notifications`: є toast-и, DND,
  in-session history і права панель Notification Center.
- Доданий bottom-center OSD для volume, mute, microphone та brightness.
- `hypridle` і `hyprlock` описані декларативно: lock через 5 хвилин,
  DPMS off через 5:30 і lock перед sleep. У disposable VM `nixos-hypridle.service`
  після rebuild вручну зупиняється, бо тестовий user password невідомий; laptop profile
  має запускати його штатно після налаштування реального password/fingerprint.
- `cliphist` має окремі text/image watchers; вибір історії та emoji працює через Fuzzel.
- Screenshot workflow використовує `grim`, `slurp`, clipboard і desktop notification.
- Quickshell, wallpaper, layout daemon, idle manager і clipboard watchers оформлені
  як Home Manager `systemd --user` services із restart policy.
- UPower, rtkit і Bluetooth увімкнені системно. Laptop controls завжди залишаються
  видимими; у VM вони явно показують, що відповідний adapter відсутній.

Для великих шрифтів додані adaptive layouts: довгі описи, погодинні колонки, weekly rows і launcher entries більше не обрізаються на старті.

### Виправлення, зроблені під час аудиту віджетів

- Виправлений старт Calendar і Weather: IPC повертав успішний код навіть без живого процесу, тому launcher інколи нічого не відкривав.
- Launcher-и тепер перевіряють точний процес Quickshell, без false match по схожих командних рядках.
- Control Center більше не стартує з невидимою карткою `60x44`.
- Control Center використовує окрему компактну типографіку, незалежну від 150% launcher scale.
- Controls повернуті до чистої baseline-сітки 2×3; capability filter більше не ховає laptop-функції у VM.
- Шестерня відкриває Control Center по кліку й тим самим кліком закриває його; hover більше не
  створює випадковий open/close race. Правий клік лишився явним close.
- Підключений сигнал кнопки «назад» із `control-panel.qml` до закриття підпанелі.
- Display використовує тільки справжній `backlight` device, тому keyboard LED не видається за
  яскравість екрана. Runtime scale picker прибраний: scale задається декларативно в
  `hyprland.lua`, а Control Center лише показує поточне значення з Hyprland.
- Display panel не має DPMS off або monitor enable/disable actions: список моніторів навмисно
  read-only, щоб випадковий клік не залишив ноутбук із чорним екраном.
- Wi-Fi пароль передається action helper-у через stdin і не потрапляє в argv/process list.
- Wi-Fi QR генерується тільки на запит для активного NetworkManager profile; QR-файл має mode
  `0600` у `$XDG_RUNTIME_DIR`, а PSK не потрапляє в argv, JSON state або логи.
- Power і Tailscale mutations піднімають графічний `pkexec`, придатний для Polkit/fingerprint на ноутбуці.
- Detail pages мають єдину геометрію та stateful native controls.
- Іконки Control Center збільшені та явно прив'язані до `JetBrainsMono Nerd Font`.
- System stats тепер показує `N/A`, якщо power sensor відсутній, замість незрозумілого `…`.

### Перевірка

- Останній `nixos-rebuild switch --flake ...#nixos` завершився успішно.
- QML-конфіги Agents, Battery, Control Center, Calendar, Weather, Menu і App Launcher завантажуються без fatal/error.
- Dashboard і всі шість detail pages пройшли IPC/visual smoke-test без QML errors або обрізання.
- Toggle-поведінка перевірена повним циклом open → IPC dismiss → closed; повторний close є безпечним no-op.
- Volume action перевірений на поточному значенні, а privileged power action — від root до
  `power-profiles-daemon`; destructive Wi-Fi/Bluetooth/Tailscale actions у VM навмисно не перемикались.
- Display backend smoke-test підтвердив, що `off` і `toggle` повертають unsupported action,
  а monitor list у QML не має clickable mutation target.
- Wi-Fi QR helper у VM коректно повертає JSON error без adapter/active connection; кнопка,
  disabled state і popup QML завантажуються без помилок. Реальне читання PSK/scan QR треба
  фінально перевірити вже на laptop hardware.
- `hyprctl configerrors` не повертає помилок.
- System і user systemd не мають failed units. Background, shell, window-layout і обидва
  cliphist watchers active; `nixos-hypridle.service` у VM навмисно inactive.
- Notification toast, Notification Center, OSD, menu, emoji picker, clipboard watcher
  і fullscreen capture пройшли smoke-тести.
- QEMU використовує `1 socket × 6 cores × 1 thread` і `virtio-vga-gl` через
  `/dev/dri/renderD129`; guest kernel підтверджує `+virgl +context_init`.
- Після virgl Quickshell стартує без `MESA-EGL failed to create dri2 screen`.

## Робота з QEMU VM

VM доступна через forwarded SSH:

```sh
ssh -p 2222 retraut@127.0.0.1
```

Після синхронізації source у `/home/retraut/nixos-lab-config` конфіг застосовується так:

```sh
cd ~/nixos-lab-config
sudo nixos-rebuild switch --flake .#nixos
```

Важливий lab-only крок після кожного rebuild: Home Manager знову може запустити
idle manager, тому до появи відомого VM password його треба одразу зупинити:

```sh
systemctl --user stop nixos-hypridle.service
```

Корисні smoke-checks:

```sh
systemctl --failed
systemctl --user --failed
systemctl --user status nixos-shell.service
hyprctl configerrors
```

Control Center має IPC target `nixos-control-center` з методами `panel(kind)`,
`dashboard()` і `dismiss()`. Launcher script підтримує `toggle`, `open` і `close`;
точний process match не чіпає інші Quickshell instances.

## Відомі обмеження VM

- У поточній QEMU VM немає `/sys/class/power_supply`, тому реальне споживання енергії недоступне. Control Center коректно показує `Power: N/A`.
- У VM також немає battery, backlight, Wi-Fi та Bluetooth devices. Відповідні controls
  залишаються видимими як preview майбутнього laptop profile, але показують відсутній adapter.
- На фізичному ноутбуці, якщо kernel експортує `BAT*/power_now`, значення буде показане у ватах.
- Реальні Wi-Fi/Bluetooth/backlight дії потребують відповідного hardware; NetworkManager,
  BlueZ/Blueman, PipeWire, Tailscale і power-profiles-daemon вже описані декларативно.

## Hardware layers: VM і ноутбук

Спільний desktop описаний у `configuration.nix`, `desktop.nix`, `theme.nix` і Quickshell-файлах. Апаратні та небезпечні для реального ноутбука налаштування винесені в host-модулі:

- `hosts/vm.nix` — QEMU guest agent, VM hardware scan, autologin і passwordless sudo для disposable VM.
- `hosts/laptop.nix` — laptop hostname, login password hash path, GA503QS PRIME
  override і жодних QEMU/autologin/passwordless-sudo settings.
- `hosts/laptop-disko.nix` — GPT + 2 GiB EFI + LUKS2 + Btrfs layout для full wipe.
- `hardware-configuration.nix` — поточний згенерований конфіг VM.
- `hardware/laptop-configuration.nix` — безпечний placeholder; installer замінює
  його актуальним hardware scan у приватному installation snapshot.
- upstream module `asus-zephyrus-ga503` — AMD/NVIDIA та інші model-specific quirks.

Профілі:

```sh
# VM
sudo nixos-rebuild switch --flake .#nixos

# laptop
sudo nixos-rebuild switch --flake .#laptop
```

Чисте встановлення з офіційної NixOS live-флешки запускається одним wrapper-ом.
Він сам знаходить єдиний non-removable whole NVMe й відмовляється вгадувати,
якщо кандидатів немає або їх більше одного:

```sh
git clone https://github.com/retraut/nixos-lab.git
cd nixos-lab
./scripts/install-laptop
```

Wrapper перевіряє GA503QS і target, генерує hardware layer без filesystems,
робить pinned Disko dry-run, просить точне destructive-підтвердження, окремі
login та LUKS passwords, а потім встановлює `.#laptop`. Деталі й stop gates є
в runbook; цей workflow призначений лише для повного стирання диска.

## Apple Silicon / nix-darwin skeleton

Доданий окремий output `darwinConfigurations.macbook` для Apple Silicon. Він використовує `aarch64-darwin` і спільний platform-neutral шар: Nix, flakes, zsh, git, eza, jq та bash aliases.

Окремий [`darwin/homebrew.nix`](/home/retraut/Work/nixos-lab/darwin/homebrew.nix) layer декларативно вмикає Homebrew і додає cask-и `ghostty`, `chromium` та `bitwarden`. Auto-update/upgrade вимкнені, щоб `darwin-rebuild switch` залишався передбачуваним.

Linux-only частини навмисно не імпортуються в macOS-профіль: Hyprland, Quickshell, SDDM, Wayland bindings і Linux systemd services залишаються тільки в NixOS profiles.

На Apple Silicon після встановлення Nix/nix-darwin профіль запускатиметься так:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- \
  switch --flake .#macbook
```

`macUserName` у `flake.nix` — поки placeholder `retraut`; перед першим запуском на Mac його треба змінити на реальне ім'я macOS-користувача. Поточний `nixpkgs-unstable` не має Ghostty для `aarch64-darwin`, тому Ghostty і GUI-застосунки встановлюються через Homebrew layer.

## Наступні кроки

- Виконати installation runbook на ноутбуці й перевірити hardware-specific
  Wi-Fi, audio, suspend, AMD/NVIDIA PRIME та thermals.
- Після кількох стабільних LUKS-passphrase boots окремо додати Lanzaboote,
  recovery material і TPM2 + PIN.
- За потреби додати окреме джерело power для RAPL/hwmon на фізичному ноутбуці.
- Продовжити наближення Control Center, weather і tray до оригінального Omarchy без імпорту Arch/Omarchy update-механізмів або runtime theme picker-а.
