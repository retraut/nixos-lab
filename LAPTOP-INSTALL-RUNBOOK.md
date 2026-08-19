# NixOS laptop install runbook — ROG Zephyrus G15 GA503QS

Цей документ — чекліст для перенесення перевіреної VM-конфігурації на
фізичний ноутбук. Ми не клонуємо диск VM: флешка дає live-середовище, а на
ноутбук встановлюється flake profile `.#laptop` із окремим hardware layer.

## Цільова схема

- UEFI boot;
- окремий EFI System Partition;
- root-диск у LUKS2;
- Btrfs усередині LUKS2;
- `NixOS/nixos-hardware` profile `asus-zephyrus-ga503`;
- локальний `hardware/laptop-configuration.nix` для initrd, LUKS, UUID і
  файлових систем;
- спочатку unlock через довгу LUKS passphrase;
- після перевіреного першого boot — Secure Boot через Lanzaboote;
- після стабільного Secure Boot — TPM2 + PIN;
- passphrase/recovery key завжди лишаються запасним способом входу.

Відоме залізо цього ноутбука:

| Компонент | Значення |
|---|---|
| Модель | ASUS ROG Zephyrus G15 `GA503QS` |
| CPU/iGPU | AMD Cezanne, PCI `06:00.0` |
| dGPU | NVIDIA RTX 3080 Mobile, PCI `01:00.0` |
| Wi-Fi | Intel AX210 |
| TPM | TPM 2.0, `/dev/tpm0` і `/dev/tpmrm0` |
| Firmware | UEFI; Secure Boot зараз вимкнений |

Офіційний GA503 profile містить AMD/NVIDIA PRIME defaults, але має
`amdgpuBusId = "PCI:7:0:0"`. Для цього конкретного GA503QS треба перевірене
локальне override-значення `PCI:6:0:0`.

## Stop gates перед стиранням диска

Не переходити до partition/format, доки не виконані всі пункти:

- [ ] Визначено режим: повне стирання диска або dual boot.
- [ ] Є перевірена копія важливих файлів із `/home/retraut` на іншому носії.
- [ ] Експортовані або синхронізовані password manager, SSH/GPG keys,
      browser data, game saves та інші локальні дані.
- [ ] Каталог `nixos-lab` доступний не лише на диску, який буде стерто:
      remote Git, друга флешка або інша перевірена копія.
- [ ] Відомо, як відновити доступ до цієї копії з NixOS live ISO.
- [ ] Ноутбук підключений до живлення.
- [ ] ISO завантажений тільки з офіційного `nixos.org` і SHA-256 перевірено.
- [ ] Перед destructive-командою target disk звірений за model, size,
      transport і `/dev/disk/by-id`.
- [ ] Target — саме внутрішній диск ноутбука; флешка та backup-диск не
      потрапляють під partition/format.

На момент написання в ноутбуці видно один внутрішній NVMe приблизно 1 TB.
Це лише орієнтир, а не дозвіл використовувати зашите ім'я `/dev/nvme0n1`:
live ISO може призначити пристроям інші імена.

## 1. Підготувати flake до фізичного ноутбука

- [ ] Додати input `github:NixOS/nixos-hardware` у `flake.nix`.
- [ ] Додати `nixos-hardware.nixosModules.asus-zephyrus-ga503` лише до
      profile `.#laptop`.
- [ ] У laptop host module перевизначити AMD PRIME Bus ID:

```nix
hardware.nvidia.prime.amdgpuBusId = lib.mkForce "PCI:6:0:0";
```

- [ ] Не переносити VM-only QEMU, autologin або passwordless-sudo settings.
- [ ] Перевірити evaluation/build `.#laptop` до перезавантаження ноутбука.
- [ ] Зберегти перевірену копію flake поза target-диском.

## 2. Підготувати інсталяційну флешку

Коли флешка вставлена:

1. Зняти `lsblk` до і після підключення.
2. Звірити USB transport, виробника, модель, serial і місткість.
3. Завантажити актуальний офіційний NixOS Graphical ISO.
4. Перевірити SHA-256 за офіційним checksum-файлом.
5. Відмонтувати всі розділи лише цієї флешки.
6. Показати користувачу точний `/dev/disk/by-id/...` і дочекатися явного
   підтвердження: запис ISO повністю знищить поточний вміст флешки.
7. Записати ISO через `pkexec`, використовуючи перевірений by-id path.
8. Виконати `sync`, перечитати partition table і перевірити, що носій
   розпізнається як NixOS installer.

Не використовувати широкі glob-и або неперевірене `/dev/sdX`.

## 3. Boot у live ISO

- [ ] Завантажити флешку саме в UEFI mode.
- [ ] На перший етап залишити Secure Boot вимкненим.
- [ ] Підключити мережу та перевірити DNS/доступ до flake inputs.
- [ ] Скопіювати `nixos-lab` у live filesystem.
- [ ] Ще раз упевнитися, що копія конфігурації та backup не залежать від
      target-диска після його стирання.
- [ ] Записати результати `lsblk --fs` і `lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN`.

## 4. Розмітка й LUKS2

Цей runbook припускає повне чисте встановлення. Якщо обрано dual boot,
розмітку треба спроєктувати окремо — не адаптувати destructive-команди на
ходу.

- [ ] Остаточно підтвердити target через стабільний `/dev/disk/by-id/...`.
- [ ] Створити GPT.
- [ ] Створити EFI System Partition достатнього розміру для NixOS
      generations і Secure Boot artifacts.
- [ ] Решту цільового простору оформити як LUKS2.
- [ ] Встановити довгу унікальну LUKS passphrase.
- [ ] Не додавати TPM на цьому етапі.
- [ ] Усередині відкритого LUKS створити Btrfs і погоджені subvolumes.
- [ ] Змонтувати root та EFI під `/mnt`.
- [ ] Перевірити mounts перед генерацією hardware config.

Точні partition/format-команди записуються окремо після фінального рішення
щодо full wipe/dual boot і перевірки актуального `lsblk`. Це навмисний safety
gate.

## 5. Hardware config та інсталяція

Після монтування скопіювати робочий flake у постійне місце на майбутньому
root, наприклад `/mnt/etc/nixos`, і виконувати наступні команди саме з цього
каталогу. Так згенерований hardware layer не зникне разом із live session.

Зі змонтованою майбутньою системою та з каталогу flake:

```sh
nixos-generate-config --root /mnt --show-hardware-config \
  > hardware/laptop-configuration.nix
```

- [ ] Переглянути згенерований файл: LUKS mapping, initrd modules, root/EFI
      UUID, Btrfs options.
- [ ] Зробити додаткову копію нового `hardware/laptop-configuration.nix` на
      backup-носій або remote Git до першого reboot.
- [ ] Переконатися, що flake реально бачить новий файл.
- [ ] Перевірити, що `.#laptop` імпортує GA503 profile і саме laptop hardware.
- [ ] Встановити:

```sh
pkexec nixos-install --root /mnt --flake .#laptop
```

- [ ] Встановити пароль користувача `retraut` у новій системі.
- [ ] Не вмикати autologin і passwordless sudo.
- [ ] Не очищати live session та не перезавантажуватися, поки install не
      завершився без помилок.

На live ISO `pkexec` може бути недоступний. Тоді використовувати штатний
інтерактивний `sudo`; пароль ніколи не передавати в command arguments або чат.

## 6. Перший boot: тільки passphrase

- [ ] Від'єднати installer USB і завантажитися з внутрішнього диска.
- [ ] Успішно розблокувати LUKS довгою passphrase.
- [ ] Увійти як `retraut`.
- [ ] Перевірити system і user units:

```sh
systemctl --failed
systemctl --user --failed
hyprctl configerrors
```

- [ ] Перевірити Wi-Fi, Ethernet/USB networking, Bluetooth, audio/mic,
      brightness, suspend/resume, touchpad і keyboard layout.
- [ ] Перевірити AMD desktop rendering і NVIDIA offload окремо.
- [ ] Перевірити battery/power profile та thermals/fans під навантаженням.
- [ ] Виконати щонайменше два успішні cold boots із passphrase.
- [ ] Зробити першу відому робочу NixOS generation і не видаляти її.

## 7. Secure Boot через Lanzaboote

Це окремий етап після стабільного незахищеного boot:

- [ ] Додати й pin-нути Lanzaboote input/module.
- [ ] Створити власні Secure Boot keys і захистити private keys.
- [ ] Перевірити signed boot artifacts до зміни firmware settings.
- [ ] Зрозуміти, чи потрібно лишати Microsoft keys для option ROM/device
      compatibility.
- [ ] Enroll-нути keys у firmware контрольованим способом.
- [ ] Увімкнути Secure Boot.
- [ ] Перевірити `bootctl status`/`sbctl status` і кілька boots.
- [ ] Поставити firmware setup password, якщо це входить у threat model.

Не enroll-ити TPM unlock до остаточно стабільного Secure Boot state: зміна PCR
після enrollment інакше одразу переведе boot на recovery/passphrase.

## 8. Recovery material перед TPM

- [ ] Додати окремий LUKS recovery key через `systemd-cryptenroll`.
- [ ] Зберегти recovery key у password manager та ще в одному офлайн-місці.
- [ ] Не зберігати єдину recovery-копію на цьому ж зашифрованому диску.
- [ ] Зробити LUKS header backup на окремий зашифрований носій.
- [ ] Перевірити, що звичайна passphrase все ще працює.

Recovery key і header backup є секретами. Не вставляти їх у flake, Git,
terminal history, process arguments, логи або чат.

## 9. TPM2 + PIN

Після стабільного Secure Boot:

- [ ] Увімкнути systemd initrd TPM unlock для LUKS mapping:

```nix
{
  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices."root" = {
    device = "/dev/disk/by-uuid/LUKS-UUID";
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  security.tpm2.enable = true;
}
```

- [ ] Вибрати PCR/signed-policy strategy після вимірювання реального boot
      chain; не копіювати випадковий PCR list з Інтернету.
- [ ] Enroll-нути TPM2 з PIN через `systemd-cryptenroll`.
- [ ] Не використовувати passwordless TPM unlock для основного laptop threat
      model без окремого свідомого рішення.
- [ ] Перезавантажитися й перевірити TPM + PIN.
- [ ] Окремо симулювати fallback і перевірити recovery key/passphrase.
- [ ] Перевірити ще один boot після звичайного NixOS rebuild.

Passphrase не видаляти навіть після успішного TPM enrollment.

## 10. Що очікувати при збоях

- Після зміни BIOS settings, BIOS update, Secure Boot keys або boot chain TPM
  може відмовити в auto-unlock — тоді використовуємо passphrase/recovery key.
- Після TPM clear або заміни motherboard старий TPM token не працюватиме —
  диск відкривається recovery material і TPM enroll-иться заново.
- Перед firmware update перевірити наявність recovery material, а після update
  бути готовим до повторного TPM enrollment.
- Ніколи не очищати LUKS keyslots, доки альтернативний спосіб unlock не
  перевірений реальним reboot.

## Definition of done

- [ ] Ноутбук завантажується тільки через перевірений Secure Boot chain.
- [ ] Root — LUKS2; unlock працює через TPM2 + PIN.
- [ ] Passphrase та recovery key перевірені як fallback.
- [ ] Recovery material і LUKS header backup зберігаються поза ноутбуком.
- [ ] `.#laptop` перебудовується без VM-only settings.
- [ ] Wi-Fi, Bluetooth, audio, suspend, AMD graphics і NVIDIA offload працюють.
- [ ] Немає failed system/user units і Hyprland config errors.
- [ ] Документ оновлено фактичними UUID, final disk layout і PCR strategy без
      додавання будь-яких секретів.
