# Ubuntu XRDP Enterprise

![License](https://img.shields.io/badge/license-MIT-green)

Installer automatizzato per configurare un ambiente **XRDP multiutente con XFCE e Xorg** su Ubuntu Desktop 26.04.

Il progetto nasce dal troubleshooting di workstation Ubuntu con GNOME, Wayland e GPU NVIDIA, dove GNOME Remote Desktop o una configurazione XRDP standard potevano produrre schermate nere o chiusure immediate della sessione.

## Funzionalità

- Installa XRDP, xorgxrdp e XFCE
- Configura sessioni remote XFCE su Xorg
- Supporta più utenti Linux con sessioni indipendenti
- Configura gli utenti esistenti e quelli creati successivamente
- Disabilita GNOME Remote Desktop per liberare la porta TCP 3389
- Ripristina i pacchetti necessari
- Evita il crash di `xiccd` nelle sessioni virtuali
- Crea backup dei file modificati
- Registra le operazioni in un file di log
- Verifica servizi, pacchetti e porta RDP al termine
- Può essere eseguito nuovamente senza dover ripristinare manualmente la macchina

## Compatibilità verificata

- Ubuntu Desktop 26.04
- XRDP con xorgxrdp
- XFCE
- Microsoft Remote Desktop Connection (`mstsc`)
- Workstation con GPU NVIDIA RTX Ada

> [!IMPORTANT]
> Lo script è stato sviluppato e verificato su Ubuntu Desktop 26.04. Su altre versioni di Ubuntu potrebbe richiedere adattamenti.

## Installazione rapida

Scaricare lo script:

```bash
wget https://raw.githubusercontent.com/Quelmarco/ubuntu-xrdp-enterprise/main/setup-xrdp-xfce.sh
```

Renderlo eseguibile:

```bash
chmod +x setup-xrdp-xfce.sh
```

Avviarlo con privilegi amministrativi:

```bash
sudo ./setup-xrdp-xfce.sh
```

In alternativa:

```bash
sudo bash setup-xrdp-xfce.sh
```

## Opzione per disabilitare Wayland

XRDP crea una propria sessione Xorg, quindi normalmente non è necessario disabilitare Wayland per il desktop locale.

Quando richiesto:

```bash
sudo ./setup-xrdp-xfce.sh --disable-wayland
```

## Connessione da Windows

1. Aprire **Connessione Desktop remoto** premendo `Win + R`.
2. Digitare:

   ```text
   mstsc
   ```

3. Inserire l’indirizzo IP o il nome host della macchina Ubuntu.
4. Nella schermata di XRDP selezionare:

   ```text
   Session: Xorg
   ```

5. Accedere con nome utente e password dell’account Linux.

## Utilizzo multiutente

Ogni persona deve utilizzare un account Linux distinto.

È preferibile non utilizzare contemporaneamente lo stesso account:

- in una sessione grafica locale;
- in una sessione XRDP.

Per creare un nuovo utente:

```bash
sudo adduser nomeutente
```

Gli utenti creati dopo l’installazione erediteranno automaticamente la configurazione XRDP tramite `/etc/skel`.

## Componenti configurati

Lo script interviene principalmente su:

```text
/etc/xrdp/startwm.sh
/etc/skel/.xsession
/etc/skel/.config/autostart/xiccd.desktop
```

Per gli utenti esistenti configura inoltre:

```text
~/.xsession
~/.config/autostart/xiccd.desktop
```

## Log

Il log dell’installazione viene salvato in:

```text
/var/log/xrdp-xfce-setup.log
```

## Backup

Prima di modificare i file di sistema, lo script crea backup con data e ora in:

```text
/var/backups/xrdp-xfce/
```

## Controlli utili

Stato dei servizi:

```bash
systemctl status xrdp xrdp-sesman --no-pager
```

Verifica della porta RDP:

```bash
sudo ss -ltnp | grep 3389
```

Log recenti:

```bash
sudo journalctl -u xrdp -u xrdp-sesman -n 100 --no-pager
```

Verifica del processo in ascolto:

```bash
sudo ss -ltnp | grep xrdp
```

## Risoluzione dei problemi

### La sessione si chiude dopo il login

Controllare:

```bash
cat ~/.xorgxrdp.*.log
cat ~/.xsession-errors
```

Assicurarsi che il file `/etc/xrdp/startwm.sh` avvii direttamente XFCE.

### Schermata nera

Verificare che:

- nella schermata XRDP sia selezionata la sessione `Xorg`;
- `xorgxrdp` sia installato;
- l’utente non abbia già una sessione grafica locale problematica;
- GNOME Remote Desktop non stia usando la porta 3389.

```bash
dpkg -l | grep xorgxrdp
sudo ss -ltnp | grep 3389
```

### Errore relativo a xiccd

`xiccd` non è necessario nelle normali sessioni virtuali XRDP. Lo script ne disabilita l’avvio automatico per evitare il messaggio:

```text
The application xiccd has closed unexpectedly
```

## Sicurezza

XRDP espone per impostazione predefinita la porta TCP 3389.

Per ambienti raggiungibili da Internet si raccomanda di:

- non pubblicare direttamente la porta 3389;
- utilizzare una VPN;
- limitare l’accesso tramite firewall;
- utilizzare password robuste;
- mantenere il sistema aggiornato.

## Limitazioni

- Le sessioni XRDP utilizzano XFCE, non il desktop GNOME locale.
- L’accelerazione della GPU fisica non è garantita nelle sessioni XRDP.
- Il progetto non configura automaticamente VPN, NAT o port forwarding.
- L’uso simultaneo dello stesso account in locale e da remoto può generare conflitti di sessione.

## Licenza

Questo progetto è distribuito con licenza MIT.

## Contributi

Segnalazioni, correzioni e miglioramenti sono benvenuti tramite Issues e Pull Requests.

## Ringraziamenti

Il progetto nasce durante la configurazione e il troubleshooting di workstation Ubuntu 26.04 multiutente con GPU NVIDIA RTX Ada e client RDP Microsoft Windows.
