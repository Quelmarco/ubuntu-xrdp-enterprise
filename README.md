# Ubuntu XRDP Enterprise

Installer automatizzato per configurare XRDP e XFCE su Ubuntu Desktop 26.04.

## Funzionalità

- Installa XRDP, xorgxrdp e XFCE
- Configura sessioni Xorg multiutente
- Disabilita GNOME Remote Desktop sulla porta 3389
- Configura gli utenti esistenti e futuri
- Evita il crash di `xiccd` nelle sessioni remote
- Crea backup dei file modificati
- Registra l'installazione in un file di log
- Verifica servizi e porta RDP al termine

## Requisiti

- Ubuntu Desktop 26.04
- Accesso amministrativo con `sudo`
- Connessione a Internet per l'installazione dei pacchetti
- Client RDP, ad esempio Connessione Desktop remoto di Windows

## Installazione

Scaricare lo script dal repository:

```bash
wget https://raw.githubusercontent.com/Quelmarco/ubuntu-xrdp-enterprise/main/install.sh
```

Renderlo eseguibile:

```bash
chmod +x install.sh
```

Eseguirlo:

```bash
sudo ./install.sh
```

Per disabilitare anche Wayland nella sessione locale:

```bash
sudo ./install.sh --disable-wayland
```

La disabilitazione di Wayland non è normalmente necessaria per XRDP.

## Connessione da Windows

Aprire:

```text
mstsc
```

Inserire l'indirizzo IP o il nome host della macchina Ubuntu.

Nella schermata di XRDP scegliere:

```text
Session: Xorg
```

Accedere con il nome utente e la password dell'account Linux.

## Note multiutente

Ogni persona deve utilizzare un account Linux distinto.

È preferibile non usare contemporaneamente lo stesso account sia nella sessione locale sia tramite XRDP.

## Log

Il log dell'installazione viene salvato in:

```text
/var/log/xrdp-xfce-setup.log
```

## Controlli utili

```bash
systemctl status xrdp xrdp-sesman --no-pager
```

```bash
ss -ltnp | grep 3389
```

```bash
journalctl -u xrdp -u xrdp-sesman -n 100 --no-pager
```

## Compatibilità verificata

- Ubuntu Desktop 26.04
- XRDP con sessione Xorg
- XFCE
- Client RDP Microsoft Windows
- Workstation NVIDIA RTX Ada
