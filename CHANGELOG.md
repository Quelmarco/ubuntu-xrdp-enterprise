# Changelog

Tutte le modifiche rilevanti del progetto saranno documentate in questo file.
## [1.1.0] - 2026-07-30

### Changed

- Refactored the installer into a modular project structure.
- Moved XRDP templates into the `files/` directory.
- Installer now validates required template files before execution.
- Updated installation instructions to clone the complete repository instead of downloading a single script.

### Improved

- Easier maintenance of XRDP configuration files.
- Cleaner project structure.
- Better separation between code and configuration.
- 
## [1.0.0] - 2026-07-30

### Added

- Installazione automatica di XRDP e xorgxrdp
- Configurazione XFCE per sessioni remote Xorg
- Supporto per utenti esistenti e futuri
- Disabilitazione di GNOME Remote Desktop
- Gestione della porta TCP 3389
- Disabilitazione di xiccd nelle sessioni remote
- Backup automatici
- Logging dell'installazione
- Verifiche finali di servizi, pacchetti e porta RDP
- Opzione facoltativa per disabilitare Wayland
