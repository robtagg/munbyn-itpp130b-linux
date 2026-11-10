# Munbyn ITPP130B installer for Fedora / Nobara

Reusable USB **and Bluetooth** setup based on the working Nobara 44 installation.
Supports CUPS 2, defaults to true **4 x 6 inch (101.6 x 152.4 mm)** labels and
203 dpi. The same filters drive both transports: only the CUPS backend differs.

## Recommended: build and install on the destination computer

Extract the source bundle, open a terminal in its folder, connect/power on the
printer, then run as your normal user:

```sh
./install.sh
```

The script uses DNF/sudo to install distribution build dependencies, builds and
tests the included source without root, installs its local RPM, then detects and
configures the USB printer. DNF asks before installing packages. Internet access
is needed for missing distribution dependencies; no driver code is downloaded.

If the printer is not connected, the RPM remains installed and setup reports the
problem. Connect it and run `sudo munbyn-setup` later. Sudo and a systemd-based,
mutable Fedora/Nobara installation are required. Atomic desktops and CUPS 3 are
not supported by this installer.

## Build the RPM yourself

No binary package is distributed here, so build one on the machine that will use
it. `./install.sh` does this for you; to build and install in two steps instead:

```sh
./build-rpm.sh
sudo dnf install ./dist/munbyn-itpp130-driver-*.x86_64.rpm
sudo munbyn-setup
```

The resulting RPM is locally built and unsigned, and is pinned to the Fedora
release and CPU architecture that built it. On a different release, rebuild --
either rerun `./build-rpm.sh`, or use `rpmbuild --rebuild` on the source RPM
that lands beside it. `SHA256SUMS` checks the integrity of a copied source tree,
not publisher authenticity. No third-party repository, signing key or automatic
updater is added.

## Bluetooth

The ITPP130B is dual-mode and advertises **two separate addresses**:

| Name | Address kind | Profile | Use |
| --- | --- | --- | --- |
| `ITPP130B-XXXX` | public (Classic) | Serial Port, `0x1101` | **this one, for CUPS** |
| `ITPP130B-XXXX-LE` | random (BLE) | vendor GATT, `0xfee7` | the vendor phone app only |

Use the **Classic** address. The `-LE` endpoint is Bluetooth Low Energy, speaks a
vendor GATT protocol, and CUPS cannot print to it. Picking it is the most likely
reason for a Bluetooth queue that never prints.

Pair and trust the printer first, as your normal user. Discovery must stay running
while pairing, because BlueZ discards an unpaired device once a scan stops:

```sh
bluetoothctl --timeout 30 scan on &
bluetoothctl pair AA:BB:CC:DD:EE:FF
bluetoothctl trust AA:BB:CC:DD:EE:FF
bluetoothctl info AA:BB:CC:DD:EE:FF     # expect Paired: yes and Trusted: yes
```

Pairing is what matters: the backend needs the bond to open the socket, and it
runs as the unprivileged `lp` user, so it cannot answer any prompt from inside a
print job. Trusting costs nothing and removes a class of authorisation surprise.
Then:

```sh
sudo dnf install bluez-cups
sudo munbyn-setup --bluetooth AA:BB:CC:DD:EE:FF
```

The MAC may be written with or without colons. Bluetooth queues default to the
name `ITPP130BT`, so a USB queue and a Bluetooth queue for the same printer can
coexist, and they use `printer-error-policy=retry-job` because a radio link drops
more readily than a cable.

Bluetooth printers are **not** auto-discovered, so the MAC is required. This is a
BlueZ limitation, not an oversight: its CUPS backend only lists printers
advertising the HCRP profile (`0x1126`), while this printer offers Serial Port, so
it never appears in `lpinfo -v`. Printing is unaffected, because the backend does
look up Serial Port when it actually opens the connection.

Expect Bluetooth to be slower than USB. A 4 x 6 inch label at 203 dpi is roughly
124 KB of bitmap, and RFCOMM carries it well below USB speed. Keep the printer
within a few metres; a weak signal shows up as failed or truncated labels.

## Options and printing

```sh
sudo munbyn-setup --paper 100x150
sudo munbyn-setup --queue ShippingLabels
sudo munbyn-setup --dry-run
sudo lpinfo -v
sudo munbyn-setup --uri 'usb://Printer/ITPP130?serial=YOUR_SERIAL&interface=1'
sudo munbyn-setup --bluetooth AA:BB:CC:DD:EE:FF
sudo munbyn-setup --bluetooth aabbccddeeff --queue ShipBT --paper 100x150
lp -d ITPP130 label.pdf
lp -d ITPP130BT label.pdf
```

Options also work with `./install.sh`, which also installs `bluez-cups` when
`--bluetooth` is used. Only one matching USB printer is selected automatically;
multiple matches require an explicit URI. `--bluetooth` and `--uri` are mutually
exclusive. An existing queue for a
different device is never overwritten. Re-running setup for the same printer is
supported and resets its paper default to the selected size. The default queue
name is `ITPP130`. Network sharing is disabled, and the global default printer is
not changed. Setup enables CUPS at boot. It does not print automatically.

Choose the correct paper size in your print application as well. The calibration
PDF is at `/usr/share/doc/munbyn-itpp130-driver/calib.pdf` after installation:

```sh
lp -d ITPP130 /usr/share/doc/munbyn-itpp130-driver/calib.pdf
```

This prints **one** calibration label. Check its alignment before printing a batch.

## If nothing prints

A job that leaves `No pages were found` in `journalctl -u cups` asked for a page
size the driver had to reject. `pdftopdf`, the first filter in the chain, acts
only on a `PageSize` naming one of the PPD's own sizes. Given no page size at
all, or the `Custom.WIDTHxHEIGHT` value many print dialogues send once they
subtract their own margins, it renders A4 instead. A4 at 203 dpi is
1678 x 2374 dots against an 832-dot head, so the raster cannot be printed and
the job dies after the page has already been rendered.

Since 1.0.3-4 the filter substitutes the PPD default for an unusable request,
noting the substitution in the job log when `LogLevel debug` is set, and passes
a size the PPD does offer through untouched. Naming the label size explicitly stays the most predictable
option:

```sh
lp -d ITPP130BT -o PageSize=w288h432 label.pdf
```

On Bluetooth, `Can't open Bluetooth connection` means the RFCOMM socket never
opened. This has been seen intermittently with the printer close by, awake and
paired, so the cause is not settled; it is why Bluetooth queues are created
with `retry-job`, letting CUPS re-send the job instead of disabling the queue.
If it persists, check the printer is awake and not already connected to a
phone, and that `bluetoothctl info` still reports it paired and trusted.

## Build only

Install `gcc make rpm-build redhat-rpm-config cups-devel cups python3` through DNF,
then run `./build-rpm.sh`. Binary and source RPMs appear in `dist/`. The source RPM
can also be rebuilt using `rpmbuild --rebuild`, with the required build dependencies.

## Provenance and security

Upstream: https://github.com/DaaarQ/itpp130-linux-driver

Copyright 2026 DaaarQ <DaaarQ@users.noreply.github.com>, GPL-2.0-or-later.

Pinned source commit: `ecdace159cf87e056d6ba0223299b7e8336462b7`.

This bundle contains source and GPL-2.0-or-later license/notice files. Local changes
correct the PDF wrapper's shell argument count, use absolute CUPS filter paths,
and add a correctly dimensioned 4 x 6 inch paper choice. The approximately
100 x 150 mm choice remains available. No printer serial number is bundled.

A source review of all 27 upstream files found no malicious behavior or reported
runtime vulnerability. It identified a low-severity local staging race in the
upstream optional package builder. That builder and the upstream root-running
installer are **excluded**. This replacement allocates private staging atomically
with `mktemp -d`, builds/tests without root, and uses RPM for file ownership/removal.

The installed runtime was tested with 14 regression checks, the same checks under
Clang AddressSanitizer/UndefinedBehaviorSanitizer, PDF file/stdin conversion, and a
successful physical USB print on Nobara 44. The RPM build repeats regression and
PPD validation. Security review cannot guarantee absence of vulnerabilities;
external CUPS/Ghostscript code and printer firmware were outside that source audit.
This new packaging is locally maintained, not an official Munbyn product.

## Author

This installer, its RPM packaging, the `munbyn-setup` command and the Bluetooth
support are written and maintained by **Rob Tagg <rob@tagg.co.uk>**, and are licensed
GPL-2.0-or-later.

The driver itself is the work of the upstream project above -- copyright 2026
DaaarQ <DaaarQ@users.noreply.github.com> -- under the same licence, used at the
pinned commit. Comparing this tree against that commit:

| File | Relationship to upstream |
| --- | --- |
| `source/rastertolabel-itpp130.c` | byte-for-byte upstream |
| `source/tests/`, `source/calib.pdf` | byte-for-byte upstream |
| `source/gstoraster2tspl` | upstream, modified here |
| `source/ITPP130-Label-printer.ppd` | upstream, modified here |
| `install.sh` | upstream's, substantially rewritten here |
| `munbyn-setup`, `build-rpm.sh`, `munbyn-itpp130-driver.spec` | original work here |

Every modified file carries a change notice in its header saying what was
changed and when, as GPL-2 section 2(a) requires. Those changes are the work
maintained here. See
`source/NOTICE` for upstream's provenance and reverse-engineering statement. Munbyn and ITPP130 are trademarks of their
respective owners; this project is not affiliated with or endorsed by Munbyn.

## Remove

Remove the queue first, substituting your queue name if changed:

```sh
sudo lpadmin -x ITPP130
sudo lpadmin -x ITPP130BT                      # if a Bluetooth queue was created
sudo dnf remove munbyn-itpp130-driver
```

Removing the package leaves the Bluetooth pairing in place. Drop it separately
with `bluetoothctl remove AA:BB:CC:DD:EE:FF`.

The RPM owns only this driver's filters, model file, setup command and documentation.
It does not remove CUPS or other printer drivers. Package removal deliberately does
not delete printer queues automatically. If upgrading from a previous manual
installation, RPM adopts the same file paths; removing it removes those driver
files, so keep the source bundle for reinstalling.
