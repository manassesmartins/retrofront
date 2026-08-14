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
- Temas visuais (cores) podem ser criados, importados e aplicados em
  **Configurações → Interface → Tema**.

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

<AppData>/                    ← dados do app (gamelists, mídia, temas, custom systems)
├── gamelists/
│   └── <sistema>.json        ← gamelist.json por sistema
├── downloaded_media/
│   └── <sistema>/box2d/*.png
├── custom_systems/
│   └── es_systems.json       ← override de sistemas
└── themes/
    └── <tema>/theme.json     ← temas criados/importados pelo usuário
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

## Temas (aparência)

O RetroFront é personalizável: qualquer pessoa pode criar um tema e aplicar na
hora em **Configurações → Interface → Tema**. Um tema é apenas um arquivo
**JSON** com cores para os modos escuro e claro.

### Onde ficam os temas

- **Oficiais (incluídos no app):** `assets/themes/<id>/theme.json`
- **Do usuário:** `<AppData>/themes/<id>/theme.json` — criados, importados ou
  exportados pela tela de Temas. Tem prioridade sobre um tema oficial com o
  mesmo id.

### Formato

```json
{
  "name": "Meu Tema",
  "author": "Seu Nome",
  "version": "1.0.0",
  "dark": {
    "background": "#0A0C12",
    "surface": "#141823",
    "surfaceHigh": "#1E2432",
    "accent": "#8B5CF6",
    "accentAlt": "#22D3EE",
    "textPrimary": "#F4F5F9",
    "textSecondary": "#B4BAC9",
    "textFaint": "#6E7687"
  },
  "light": {
    "background": "#F4F5F9",
    "surface": "#FFFFFF",
    "accent": "#6D3BF0"
  }
}
```

- Cores em hex `#RRGGBB` (ou `#AARRGGBB`). Qualquer campo pode ser omitido —
  nesse caso o tema usa a cor padrão do RetroFront.
- O `id` do tema (nome da pasta) é derivado do `name` (minúsculas, sem
  acentos, espaços viram `_`).
- Exemplos prontos para copiar: `assets/themes/` (`oled_preto`,
  `fosforo_crt`, `retro_sunset`).

### Criar, aplicar e compartilhar

Na tela **Configurações → Interface → Tema**:

- **Aplicar** — navegue até o tema e confirme; vale na hora e fica salvo.
- **Novo tema** — cria um tema a partir do visual atual (basta dar o nome).
- **Importar** — escolha um arquivo `.json` de tema compartilhado.
- **Opções do tema** (botão Select/long-press) — exportar o JSON para
  compartilhar com a comunidade ou excluir temas criados por você.

### Artes de fundo por console (SYSTEMART)

As artes oficiais de cada console ficam empacotadas no app
(`assets/systems/art/`) e são copiadas para a pasta `SYSTEMART` da biblioteca
no primeiro uso — o console já aparece com fundo na instalação. Imagens suas já
existentes em `SYSTEMART` nunca são sobrescritas. Para recopiar as oficiais
(faltantes) a qualquer momento: **Configurações → Interface → Restaurar artes
de fundo (SYSTEMART)**.

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
│   ├── settings/             # configurações (SharedPreferences)
│   ├── systems/              # definições de sistemas + arte SYSTEMART
│   └── themes/               # temas: bundled + do usuário (criar/importar/aplicar)
├── gamepad/
│   └── gamepad_manager.dart  # gamepad → GamepadAction (com repetição)
├── models/                   # System, Game, GameEntry, GameMetadata, ThemePalette
└── ui/
    ├── system_view.dart      # grade de sistemas
    ├── gamelist_view.dart    # lista de jogos de um sistema
    ├── game_detail_view.dart # detalhe + scraping individual
    ├── settings_view.dart
    ├── themes_view.dart      # aplicar/importar/criar/exportar temas
    └── widgets/              # navegação, capas, tiles, avaliação
```
