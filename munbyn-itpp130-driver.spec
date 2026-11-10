%global debug_package %{nil}
Name: munbyn-itpp130-driver
Version: 1.0.3
Release: 5.local%{?dist}
Summary: Reviewed Munbyn ITPP130B USB/Bluetooth label driver with true 4 x 6 inch support
License: GPL-2.0-or-later
Packager: Rob Tagg <rob@tagg.co.uk>
URL: https://github.com/robtagg/munbyn-itpp130b-linux
Source0: %{name}-%{version}.tar.gz
BuildRequires: gcc
BuildRequires: cups-devel
BuildRequires: cups
BuildRequires: python3
BuildRequires: redhat-rpm-config
Requires: cups >= 1:2.4
Requires: cups < 1:3
Requires: cups-filters
Requires: ghostscript
Requires: bash
Requires: systemd
# Only needed for Bluetooth queues; USB works without it. This package supplies
# /usr/lib/cups/backend/bluetooth, which opens the printer's RFCOMM socket.
Recommends: bluez-cups
Conflicts: itpp130-linux-driver

%description
Locally maintained packaging of the audited ITPP130/ITPP130B CUPS driver.
Includes corrected PDF wrapper argument handling, absolute filter paths,
true 4 x 6 inch defaults, and an explicit setup command for USB and Bluetooth.
No network sharing or printer queues are enabled by RPM installation.
Run sudo munbyn-setup after connecting the printer, or
sudo munbyn-setup --bluetooth AA:BB:CC:DD:EE:FF for a paired Bluetooth printer.
The rendering filters are transport-independent; only the CUPS backend differs.

%prep
%setup -q

%build
%set_build_flags
%{__cc} $CFLAGS -D_FORTIFY_SOURCE=3 -fstack-protector-strong -fPIE \
  -Wall -Wextra -Wformat=2 -Werror -Wno-deprecated-declarations \
  rastertolabel-itpp130.c -o rastertolabel-itpp130 \
  $LDFLAGS -pie -Wl,-z,relro,-z,now -lcups -lcupsimage

%check
tests/run-tests.sh ./rastertolabel-itpp130
cupstestppd -I filters -q ITPP130-Label-printer.ppd
bash -n gstoraster2tspl munbyn-setup

%install
install -D -m 755 rastertolabel-itpp130 %{buildroot}%{_prefix}/lib/cups/filter/rastertolabel-itpp130
install -D -m 755 gstoraster2tspl %{buildroot}%{_prefix}/lib/cups/filter/gstoraster2tspl
install -D -m 644 ITPP130-Label-printer.ppd %{buildroot}%{_datadir}/cups/model/munbyn/ITPP130-Label-printer.ppd
install -D -m 755 munbyn-setup %{buildroot}%{_bindir}/munbyn-setup

%files
%license LICENSE
%doc README.md NOTICE calib.pdf
%{_prefix}/lib/cups/filter/rastertolabel-itpp130
%{_prefix}/lib/cups/filter/gstoraster2tspl
%dir %{_datadir}/cups/model/munbyn
%{_datadir}/cups/model/munbyn/ITPP130-Label-printer.ppd
%{_bindir}/munbyn-setup

%changelog
* Tue Nov 10 2026 Rob Tagg <rob@tagg.co.uk> - 1.0.3-5.local
- Licensing and documentation only; no functional change.
- Record upstream's copyright (DaaarQ) on the files taken from upstream, and
  add GPL-2 section 2(a) change notices to the files modified here.
- Prefix source/NOTICE to make clear its text is upstream's and describes
  upstream's tree.
- Point URL at this project's own repository and document building the RPM
  from source rather than installing a prebuilt one.

* Tue Nov 10 2026 Rob Tagg <rob@tagg.co.uk> - 1.0.3-4.local
- Fix every job that did not name an explicit PPD page size failing with
  "No pages were found".  pdftopdf honours only a PageSize naming one of the
  PPD's own sizes; given none, or a Custom.WIDTHxHEIGHT value as print
  dialogues send, it rendered A4.  At 203 dpi that is 1678 x 2374 dots
  against an 832-dot head, so the raster was rejected and nothing printed.
- gstoraster2tspl now substitutes *DefaultPageSize for an unusable request
  and passes a size the PPD does offer through untouched.
* Tue Nov 10 2026 Rob Tagg <rob@tagg.co.uk> - 1.0.3-3.local
- Add Bluetooth support via --bluetooth MAC, using the bluez SPP CUPS backend.
- Verify the device is paired and trusted before creating a Bluetooth queue.
- Bluetooth queues retry jobs on error rather than stopping the printer.
- Recommend bluez-cups; no change to the filters, PPD or USB behaviour.

* Thu Sep 24 2026 Rob Tagg <rob@tagg.co.uk> - 1.0.3-2.local
- Correct shell filter argument count and pin filter executable paths.
- Add true 4 x 6 inch default and automatic USB setup.
- Build and test unprivileged in private temporary staging.
