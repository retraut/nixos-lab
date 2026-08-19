# NixOS laptop install runbook — ROG Zephyrus G15 GA503QS

Це чекліст для повного чистого встановлення перевіреної VM-конфігурації на
фізичний GA503QS. Диск VM не клонується: офіційна NixOS live-флешка запускає
`scripts/install-laptop`, а Disko відтворює описану у Git схему диска й
встановлює flake profile `.#laptop`.

## Що вже автоматизовано

- офіційний `NixOS/nixos-hardware` profile `asus-zephyrus-ga503`;
- локальний override AMD iGPU: `PCI:6:0:0` замість upstream `PCI:7:0:0`;
- GPT і EFI System Partition 2 GiB;
- LUKS2 на всьому основному просторі;
- Btrfs subvolumes для `/`, `/home`, `/nix` і `/var/log`;
- host-specific hardware scan без дублювання `fileSystems`;
- pinned `disko-install` та `mkpasswd` із цього `flake.lock`;
- root-only yescrypt hash початкового login/sudo password;
- копія фактично встановленого flake у `/etc/nixos`;
- dry-run і кілька fail-closed перевірок перед destructive-кроком.

Інсталяція не додає TPM unlock одразу. Спочатку диск відкривається окремою
довгою LUKS passphrase. Secure Boot, recovery material і TPM2 + PIN — наступні
етапи після кількох стабільних boots.

## Stop gates перед стиранням

Не запускати інсталятор, доки кожен пункт нижче не виконаний:

- [ ] Обрано саме **повне стирання внутрішнього NVMe**, не dual boot.
- [ ] Важливі файли з поточної системи перевірено відкриваються з іншого носія.
- [ ] Password manager, SSH/GPG keys, browser data, game saves та локальні
      проєкти синхронізовані або експортовані.
- [ ] Репозиторій доступний публічно за
      `https://github.com/retraut/nixos-lab`.
- [ ] Ноутбук підключений до живлення й мережі.
- [ ] Secure Boot поки вимкнений.
- [ ] Завантажено саме офіційну NixOS installer USB у UEFI mode.
- [ ] Відомі дві **різні** сильні фрази: login/sudo password і LUKS passphrase.

Скрипт підтримує лише full wipe. Для dual boot потрібен окремий disk layout;
не адаптувати destructive-команди на ходу.

## Boot у live ISO

1. Завантажитися з NixOS USB у UEFI mode.
2. Підключити Wi-Fi/мережу й відкрити terminal.
3. Перевірити, що GitHub доступний:

```sh
git ls-remote https://github.com/retraut/nixos-lab.git HEAD
```

4. Клонувати конфіг:

```sh
git clone https://github.com/retraut/nixos-lab.git
cd nixos-lab
```

5. Подивитися стабільні імена внутрішніх NVMe:

```sh
ls -l /dev/disk/by-id/nvme-*
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,RM,FSTYPE,MOUNTPOINTS
```

Не копіювати device name із цього документа. Live ISO може інакше назвати
`/dev/nvme0n1`; аргументом має бути актуальний whole-disk symlink із
`/dev/disk/by-id/`, без суфікса `-partN`.

## Один інсталяційний запуск

Підставити **власний перевірений** by-id path:

```sh
./scripts/install-laptop /dev/disk/by-id/nvme-EXACT_INTERNAL_DISK_ID
```

Скрипт сам:

1. Підніме права через графічний `pkexec`; якщо Polkit недоступний у live ISO,
   використає інтерактивний `sudo`.
2. Відмовиться працювати не на ASUS GA503QS.
3. Перевірить, що target — non-removable whole NVMe за by-id і що він не
   змонтований.
4. Покаже model, size, serial, transport і resolved device.
5. Створить приватний installation snapshot конфігурації та додасть актуальний
   `hardware/laptop-configuration.nix`.
6. Збере Disko й повний `.#laptop` у режимі `--dry-run`, не змінюючи диск.
7. Попросить набрати точний довгий рядок `ERASE ...`.
8. Приховано попросить login/sudo password для `retraut`.
9. Приховано двічі попросить **окрему** LUKS passphrase.
10. Зітре target, створить GPT + EFI + LUKS2 + Btrfs, встановить NixOS і
    збереже встановлений snapshot у `/etc/nixos`.

Паролі не передаються в argv, Git або чат. Login password стає salted yescrypt
hash у root-only `/etc/nixos-install-user-password-hash`; LUKS passphrase
Disko тримає лише в пам'яті поточного процесу. Якщо будь-яка перевірка або
точне підтвердження не проходить, wipe не починається.

## Перший boot: тільки passphrase

Після повідомлення `Install complete`:

1. Виконати shutdown, від'єднати USB і завантажитися з internal NVMe.
2. Ввести LUKS passphrase.
3. Увійти як `retraut` із login password.
4. Перевірити:

```sh
systemctl --failed
systemctl --user --failed
hyprctl configerrors
lsblk --fs
findmnt / /boot /home /nix /var/log
sudo cryptsetup luksDump /dev/disk/by-label/NIXOS_CRYPT
```

- [ ] Root справді знаходиться всередині `cryptroot`/LUKS2.
- [ ] `/`, `/home`, `/nix`, `/var/log` — очікувані Btrfs subvolumes.
- [ ] `sudo` вимагає пароль; passwordless sudo лишився тільки у `hosts/vm.nix`.
- [ ] Немає autologin.
- [ ] Працюють Wi-Fi, Bluetooth, audio/mic, brightness і touchpad.
- [ ] Працюють suspend/resume та keyboard layout.
- [ ] AMD desktop rendering і NVIDIA offload перевірені окремо.
- [ ] Перевірені battery profile, fans і thermals.
- [ ] Виконано щонайменше два успішні cold boots із passphrase.
- [ ] Відома робоча NixOS generation не видалена.

Після першого boot source of truth є і в публічному Git, і локально в
`/etc/nixos`. Згенерований hardware scan можна пізніше перенести назад у Git;
UUID і hardware module list не є паролями, але перед commit усе одно слід
переглянути diff.

## Secure Boot через Lanzaboote — окремо

Робити тільки після стабільної системи з passphrase:

- [ ] Додати й pin-нути Lanzaboote input/module.
- [ ] Створити власні Secure Boot keys і захистити private keys.
- [ ] Перевірити signed boot artifacts до зміни firmware settings.
- [ ] Вирішити, чи залишати Microsoft keys для device compatibility.
- [ ] Контрольовано enroll-нути keys у firmware й увімкнути Secure Boot.
- [ ] Перевірити `bootctl status`, `sbctl status` і кілька boots.

Не enroll-ити TPM до стабільного Secure Boot state: зміна PCR після enrollment
інакше одразу переведе boot на fallback passphrase.

## Recovery material перед TPM

- [ ] Додати окремий LUKS recovery key через `systemd-cryptenroll`.
- [ ] Зберегти recovery key у password manager і ще в одному offline-місці.
- [ ] Зробити LUKS header backup на окремий зашифрований носій.
- [ ] Реальним reboot перевірити, що звичайна passphrase все ще працює.

Recovery key і header backup є секретами. Не вставляти їх у flake, Git,
terminal history, process arguments, логи або чат.

## TPM2 + PIN — після recovery і Secure Boot

Після стабільного Secure Boot:

- [ ] Увімкнути systemd initrd і TPM2 support у NixOS.
- [ ] Вибрати PCR/signed-policy strategy для фактичного boot chain, а не
      копіювати випадковий PCR list.
- [ ] Enroll-нути TPM2 з PIN через `systemd-cryptenroll`.
- [ ] Не видаляти LUKS passphrase.
- [ ] Перевірити TPM + PIN, fallback passphrase і recovery key.
- [ ] Перевірити boot після звичайного NixOS rebuild і firmware update plan.

Після BIOS settings change, BIOS update, Secure Boot key change, TPM clear або
заміни motherboard TPM unlock може не спрацювати. Це очікувано: диск тоді
відкривається passphrase/recovery key, а TPM enroll-иться заново.

## Definition of done

- [ ] Інсталяція відтворюється однією командою з перевіреним by-id target.
- [ ] Root — LUKS2/Btrfs, перші boots стабільні з passphrase.
- [ ] Login і `sudo` працюють із паролем; VM-only passwordless sudo відсутній.
- [ ] `.#laptop` перебудовується без QEMU/autologin settings.
- [ ] Працюють Wi-Fi, Bluetooth, audio, suspend, AMD і NVIDIA offload.
- [ ] Немає failed system/user units і Hyprland config errors.
- [ ] Пізніше ввімкнено перевірений Secure Boot і TPM2 + PIN.
- [ ] Passphrase, recovery key і header backup перевірені як fallback.
