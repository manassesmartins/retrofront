# retrofront

Frontend multiplataforma estilo ES-DE para navegar, organizar e lançar jogos
retro. Lista ROMs por pastas de sistema, baixa capas e metadados (scraping) e
abre os jogos no RetroArch — com suporte total a navegação por gamepad USB ou
Bluetooth. Código novo, sem derivar do ES-DE (inspirado na arquitetura).

## Plataformas

| Plataforma | Build |
|---|---|
| Linux (desktop) | `flutter build linux` |
| Android (ARMv7a/ARM64/x86_64) | `flutter build apk --target-platform android-arm` |

## Como funciona

- Sistemas são definidos em `assets/systems/es_systems.json` (estilo
  `es_systems.xml`), com nome, título, extensões de ROM e cores.
- ROMs vivem em `<AppData>/ROMs/<sistema>/...` — qualquer subpasta é navegável.
- Cada sistema tem um `gamelist.json` (estilo `gamelist.xml` do ES-DE) com
  metadados salvos (título corrigido, capa, descrição, ano, gêneros, nota...).
- Capas são baixadas para `<AppData>/downloaded_media/<sistema>/box2d/`.
- `custom_systems/es_systems.json` faz override dos sistemas sem editar o asset.

### Estrutura de pastas

```
<ROMs>/                      ← raiz da biblioteca (varia por plataforma)
├── nes/            ← Nintendo (extensões .nes .NES .7z .zip)
│   ├── Super Mario Bros.nes
│   └── Action/     ← subpastas navegáveis
│       └── Contra.nes
├── snes/
├── genesis/
├── gb/  gba/  gbc/
├── n64/  nds/  psx/  psp/  gc/  wii/ ...
└── ...             ← qualquer pasta que exista em es_systems.json

<AppData>/                    ← dados do app (gamelists, mídia, custom systems)
├── gamelists/
│   └── <sistema>.json        ← gamelist.json por sistema
├── downloaded_media/
│   └── <sistema>/box2d/*.png
├── custom_systems/
│   └── es_systems.json       ← override de sistemas
└── settings.json
```

Localização do `<ROMs>`:

- **Linux:** `~/ROMs`
- **Android:** `/storage/emulated/0/ROMs` (ou o diretório externo do app)

Localização do `<AppData>`:

- **Linux:** `~/.local/share/<app>/RetroFront`
- **Android:** diretório de dados do app

> Dica: defina a variável de ambiente `RETROFRONT_ROMS_ROOT` (ou use a opção
> nas Configurações) para usar uma biblioteca externa — ex.: um HD com ROMs.

## Scraping (capas + metadados)

Disponível em **Editar** na tela de lista de jogos (lote) e no detalhe do jogo
(individual).

| Fonte | O que traz | Chave |
|---|---|---|
| libretro-thumbnails | Capas (padrão ES-DE, sem chave) | nenhuma |
| TheGamesDB | Metadados completos + capa alternativa | opcional |

Configure a chave do TheGamesDB em **Configurações → Scraping**. O lote
preenche o que faltar em ordem: TheGamesDB primeiro, depois libretro.

## Controles

| Ação | Teclado | Gamepad |
|---|---|---|
| Navegar | Setas / PageUp / PageDown | D-pad ou analógico esquerdo |
| Confirmar | Enter | A / Botão inferior |
| Voltar | Esc / Backspace | B / Botão direito |
| Menu de opções | Delete | Start / botão central |
| Ajuda | F1 | Select / botão esquerdo |

## Launcher (RetroArch)

Nas configurações informe o caminho do executável do RetroArch e o nome do
núcleo para cada sistema:

- **Desktop:** preencha `EMULATOR_RETROARCH` (caminho do RetroArch) e
  `CORE_RETROARCH` (ex.: `mednafen_snes_libretro.so`). Variáveis de ambiente
  `%EMULATOR_RETROARCH%` / `%CORE_RETROARCH%` também são respeitadas.
- **Android:** se o RetroArch estiver instalado, o jogo é aberto por intent
  (FileProvider). Nenhuma configuração extra necessária.

## Builds

Requisitos: Flutter 3.44+ e os SDKs da plataforma (Android NDK 28.2 para
Android). No Linux, as dependências GTK podem vir do sistema (`dnf`/`apt`) ou do
Homebrew (`brew install cmake ninja llvm gtk+3 xz pkg-config xorgproto`) — neste
caso use o script `./build_linux.sh` que configura o ambiente.

```bash
flutter pub get

# Linux (release)
./build_linux.sh release

# Android ARMv7a (ex.: consoles portáteis / emuladores com telas)
flutter build apk --target-platform android-arm

# Android completo (release)
flutter build apk --release
```

### Assinatura do APK

Para assinar o release com uma chave própria (necessária para distribuir o APK):

```bash
keytool -genkeypair -v -keystore android/app/upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 -storepass SUA_SENHA -keypass SUA_SENHA \
  -dname "CN=RetroFront, OU=Retro, O=RetroFront, L=SP, ST=SP, C=BR"
```

Depois crie `android/key.properties`:

```
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=upload-keystore.jks
```

O Gradle usa essa configuração automaticamente no `flutter build apk --release`.
Sem o `key.properties`, o release é assinado com a chave de debug (só para testes).
O arquivo `key.properties` e o `*.jks` já estão no `.gitignore`.

### Auto-versionamento e Releases (GitHub Actions)

O projeto usa auto-versionamento Nightly/Beta/Stable via GitHub Actions:

- **A cada 10 commits** na `main`, o workflow `release.yml` gera automaticamente
  uma **pré-release** `v1.0.<commits>-beta` (ex.: `v1.0.20-beta`) com o APK e o
  bundle Linux, marcada como `pre-release` no GitHub.
- **Release estável** (ex.: `v1.1.0`) é criada manualmente: **Actions →
  Release → Run workflow** informando a versão desejada.
- A versão é injetada no Gradle via variáveis de ambiente
  (`ANDROID_VERSION_CODE` e `ANDROID_VERSION_NAME`); localmente, sem as
  variáveis, usa a versão do `pubspec.yaml`.

### Auto-update (in-app)

O app consulta as releases do GitHub (`github.com/manassesmartins/retrofront`):

- **Configurações → Sistema → Atualizações**: verifica a versão mais recente,
  exibe o changelog e, no Android, baixa e instala o APK (botão
  "Baixar e instalar"). No Linux abre a página de releases.
- **Verificar atualizações ao iniciar**: consulta o GitHub quando o app abre e
  avisa se houver versão nova (SnackBar).
- **Incluir versões pré-lançamento**: considera releases beta/nightly na
  verificação.

Testes e análise estática:

```bash
flutter analyze
flutter test
```

## Estrutura do código

```
lib/
├── app.dart                  # RetroFrontApp + AppScope (serviços)
├── main.dart
├── core/
│   ├── app_dirs.dart         # resolução de todas as pastas de dados
│   └── app_scope.dart        # construção/injeção de serviços
├── data/
│   ├── roms/rom_scanner.dart # varredura de ROMs por sistema/subpasta
│   ├── gamelist/             # gamelist.json por sistema
│   ├── scraping/             # libretro-thumbnails, TheGamesDB, cache, orquestrador
│   ├── launch/               # launcher desktop (Process) + Android (MethodChannel)
│   └── settings/             # configurações (SharedPreferences)
├── gamepad/
│   └── gamepad_manager.dart  # gamepad → GamepadAction (com repetição)
├── models/                   # System, Game, GameEntry, GameMetadata
└── ui/
    ├── system_view.dart      # grade de sistemas
    ├── gamelist_view.dart    # lista de jogos de um sistema
    ├── game_detail_view.dart # detalhe + scraping individual
    ├── settings_view.dart
    └── widgets/              # navegação, capas, tiles, avaliação
```
